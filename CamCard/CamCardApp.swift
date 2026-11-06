import SwiftUI

@main
struct CamCardApp: App {
    private let repository: CardRepository

    init() {
        let demoMode = ProcessInfo.processInfo.arguments.contains("--demo-cards")
        let arguments = ProcessInfo.processInfo.arguments
        if demoMode || arguments.contains("--empty-library") {
            repository = CardRepository(cards: demoMode ? [DemoCard.card] : [])
        } else {
            let support = URL.applicationSupportDirectory
            let testLibrary = arguments.contains("--test-library")
            let directory = support.appendingPathComponent(testLibrary ? "CamCardUITests" : "CamCard", isDirectory: true)
            if testLibrary, arguments.contains("--reset-test-library") {
                try? FileManager.default.removeItem(at: directory)
            }
            repository = CardRepository(directory: directory)
        }
    }

    var body: some Scene {
        WindowGroup {
            CardLibraryView(repository: repository)
                .preferredColorScheme(.light)
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
