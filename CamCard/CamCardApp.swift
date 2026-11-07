import SwiftUI

@main
struct CamCardApp: App {
    private let repository: CardRepository
    @State private var detailVisible = false

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
            content
                .environment(\.colorScheme, .light)
                .environment(\.setDetailVisible, { detailVisible = $0 })
                .preferredColorScheme(detailVisible ? .dark : .light)
        }
    }

    @ViewBuilder private var content: some View {
#if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--test-open-urls") {
            URLCapture(content: CardLibraryView(repository: repository))
        } else {
            CardLibraryView(repository: repository)
        }
#else
        CardLibraryView(repository: repository)
#endif
    }
}

private struct DetailVisibilityKey: EnvironmentKey {
    static let defaultValue: (Bool) -> Void = { _ in }
}

extension EnvironmentValues {
    var setDetailVisible: (Bool) -> Void {
        get { self[DetailVisibilityKey.self] }
        set { self[DetailVisibilityKey.self] = newValue }
    }
}

#if DEBUG && targetEnvironment(simulator)
private struct URLCapture<Content: View>: View {
    let content: Content
    @State private var url: URL?

    var body: some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                self.url = url
                return .handled
            })
            .overlay(alignment: .bottom) {
                if let url {
                    Text(url.absoluteString)
                        .font(.caption)
                        .background(.white)
                        .accessibilityIdentifier("test-opened-url")
                        .allowsHitTesting(false)
                }
            }
    }
}
#endif

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
