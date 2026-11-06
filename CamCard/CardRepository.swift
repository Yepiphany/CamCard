import Foundation
import ImageIO
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class CardRepository {
    private struct Library: Codable {
        var cards: [BusinessCard] = []
        var groups: [CardGroup] = []
    }

    private var library = Library()
    private let directory: URL?
    private var memoryImages: [String: CGImage] = [:]
    private(set) var loadFailed = false

    var cards: [BusinessCard] {
        library.cards.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
    var groups: [CardGroup] { library.groups }

    init(directory: URL? = nil, cards: [BusinessCard] = []) {
        self.directory = directory
        library.cards = cards
        reload()
    }

    func reload() {
        guard let directory else { return }
        let index = directory.appendingPathComponent("library.json")
        do {
            let data = try Data(contentsOf: index)
            library = try JSONDecoder().decode(Library.self, from: data)
            loadFailed = false
            removeUnreferencedImages()
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    func card(id: UUID) -> BusinessCard? {
        library.cards.first { $0.id == id }
    }

    func save(_ card: BusinessCard) throws {
        try save([card])
    }

    func save(_ cards: [BusinessCard]) throws {
        var updated = library
        for card in cards {
            if let index = updated.cards.firstIndex(where: { $0.id == card.id }) {
                updated.cards[index] = card
            } else {
                updated.cards.append(card)
            }
        }
        try commit(updated)
    }

    func save(_ card: BusinessCard, original: CGImage, corrected: CGImage) throws {
        if self.card(id: card.id) != nil { return }
        var updated = card
        let originalName = "\(card.id)-original.png"
        let correctedName = "\(card.id)-corrected.png"
        updated.originalImagePath = originalName
        updated.correctedImagePath = correctedName
        do {
            try writeImage(original, name: originalName)
            try writeImage(corrected, name: correctedName)
            try save(updated)
        } catch {
            removeImage(originalName)
            removeImage(correctedName)
            throw error
        }
    }

    func image(_ name: String?) -> CGImage? {
        guard let name else { return nil }
        guard let directory else { return memoryImages[name] }
        guard let source = CGImageSourceCreateWithURL(directory.appendingPathComponent(name) as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    func delete(_ card: BusinessCard) throws {
        try deleteCards([card])
    }

    func deleteCards(_ cards: [BusinessCard]) throws {
        let ids = Set(cards.map(\.id))
        var updated = library
        updated.cards.removeAll { ids.contains($0.id) }
        try commit(updated)
        for card in cards {
            for path in [card.originalImagePath, card.correctedImagePath].compactMap({ $0 }) {
                removeImage(path)
            }
        }
    }

    func save(_ group: CardGroup) throws {
        var updated = library
        if let index = updated.groups.firstIndex(where: { $0.id == group.id }) {
            updated.groups[index] = group
        } else {
            updated.groups.append(group)
        }
        try commit(updated)
    }

    func moveGroup(id: UUID, to target: UUID) throws {
        guard id != target,
              let sourceIndex = library.groups.firstIndex(where: { $0.id == id }),
              let targetIndex = library.groups.firstIndex(where: { $0.id == target }) else { return }
        var updated = library
        let group = updated.groups.remove(at: sourceIndex)
        updated.groups.insert(group, at: targetIndex)
        try commit(updated)
    }

    func delete(_ group: CardGroup) throws {
        var updated = library
        updated.groups.removeAll { $0.id == group.id }
        for index in updated.cards.indices {
            updated.cards[index].groupIDs.remove(group.id)
        }
        try commit(updated)
    }

    private func commit(_ updated: Library) throws {
        guard !loadFailed else { throw CocoaError(.fileReadCorruptFile) }
        if let directory {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(updated).write(to: directory.appendingPathComponent("library.json"), options: .atomic)
        }
        library = updated
    }

    private func writeImage(_ image: CGImage, name: String) throws {
        guard let directory else {
            memoryImages[name] = image
            return
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = NSMutableData()
        guard let output = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(output, image, nil)
        guard CGImageDestinationFinalize(output) else { throw CocoaError(.fileWriteUnknown) }
        try (data as Data).write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    private func removeUnreferencedImages() {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        let referenced = Set(library.cards.flatMap { [$0.originalImagePath, $0.correctedImagePath].compactMap { $0 } })
        for name in files where !referenced.contains(name) &&
            (name.hasSuffix("-original.png") || name.hasSuffix("-corrected.png")) {
            removeImage(name)
        }
    }

    private func removeImage(_ name: String) {
        if let directory {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        } else {
            memoryImages.removeValue(forKey: name)
        }
    }
}
