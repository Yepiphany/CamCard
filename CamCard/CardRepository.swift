import Foundation

@MainActor
protocol CardRepository {
    func listCards() throws -> [BusinessCard]
    func card(id: UUID) throws -> BusinessCard?
    func save(_ card: BusinessCard) throws
    func delete(id: UUID) throws
}

@MainActor
final class InMemoryCardRepository: CardRepository {
    private var cards: [UUID: BusinessCard] = [:]

    init(cards: [BusinessCard] = []) {
        for card in cards {
            save(card)
        }
    }

    func listCards() -> [BusinessCard] {
        cards.values.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func card(id: UUID) -> BusinessCard? {
        cards[id]
    }

    func save(_ card: BusinessCard) {
        cards[card.id] = card
    }

    func delete(id: UUID) {
        cards.removeValue(forKey: id)
    }
}
