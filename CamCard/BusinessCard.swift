import Foundation

struct ContactFields: Codable, Equatable {
    var name: String?
    var company: String?
    var jobTitle: String?
    var mobile: [String] = []
    var officePhone: [String] = []
    var email: [String] = []
    var website: String?
    var address: String?
    var fax: [String] = []

    private static let singleValues: [WritableKeyPath<Self, String?>] = [
        \.name, \.company, \.jobTitle, \.website, \.address
    ]
    private static let multipleValues: [WritableKeyPath<Self, [String]>] = [
        \.mobile, \.officePhone, \.email, \.fax
    ]

    var cleaned: Self {
        var result = self
        for keyPath in Self.singleValues {
            result[keyPath: keyPath] = Self.nonblank(self[keyPath: keyPath])
        }
        for keyPath in Self.multipleValues {
            result[keyPath: keyPath] = self[keyPath: keyPath].compactMap(Self.nonblank)
        }
        return result
    }

    mutating func refreshUnedited(from previous: Self, with updated: Self) {
        for keyPath in Self.singleValues where self[keyPath: keyPath] == previous[keyPath: keyPath] {
            self[keyPath: keyPath] = updated[keyPath: keyPath]
        }
        for keyPath in Self.multipleValues where self[keyPath: keyPath] == previous[keyPath: keyPath] {
            self[keyPath: keyPath] = updated[keyPath: keyPath]
        }
    }

    private static func nonblank(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

struct RecognitionRecord: Codable, Equatable {
    struct TextRegion: Codable, Equatable {
        var text: String
        var x: Double
        var y: Double
        var width: Double
        var height: Double
    }

    var languages: [String]
    var rawText: String
    var regions: [TextRegion]
    var candidates: ContactFields
    var recognizedAt: Date
}

struct BusinessCard: Identifiable, Codable, Equatable {
    let id: UUID
    var originalImagePath: String?
    var correctedImagePath: String?
    var fields: ContactFields
    var recognition: RecognitionRecord?
    var groupIDs: Set<UUID> = []
    var note: String?
    let createdAt: Date
    var updatedAt: Date
}

struct CardGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
}
