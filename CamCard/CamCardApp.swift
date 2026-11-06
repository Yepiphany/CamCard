import SwiftUI

@main
struct CamCardApp: App {
    private let repository: InMemoryCardRepository

    init() {
        let demoMode = ProcessInfo.processInfo.arguments.contains("--demo-cards")
        repository = InMemoryCardRepository(cards: demoMode ? [DemoCard.card] : [])
    }

    var body: some Scene {
        WindowGroup {
            CardLibraryView(repository: repository)
        }
    }
}

private enum DemoCard {
    static let card = BusinessCard(
        id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
        fields: ContactFields(
            name: "Mara Quill",
            company: "Northglass Studio",
            jobTitle: "Design Director",
            mobile: ["+1 202-555-0101"],
            officePhone: ["+1 202-555-0102"],
            email: ["mara@example.com"],
            website: "northglass.example",
            address: "10 Example Lane"
        ),
        createdAt: Date(timeIntervalSince1970: 1_794_096_000),
        updatedAt: Date(timeIntervalSince1970: 1_794_096_000)
    )
}
