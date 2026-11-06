import SwiftUI

enum CardPalette {
    static let blue = Color(red: 0.10, green: 0.65, blue: 0.95)
    static let navy = Color(red: 0.08, green: 0.21, blue: 0.39)
    static let background = Color(white: 0.94)
}

struct CardLibraryView: View {
    let repository: CardRepository
    private var cards: [BusinessCard] { repository.cards }
    @State private var showsScanner = false
    @State private var savedCard: UUID?
    @State private var showSavedDetail = false
    @State private var managing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    searchBar
                    shortcuts
                    cardPanel
                }
            }
            .background(CardPalette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showsScanner, onDismiss: {
                showSavedDetail = savedCard != nil
            }) {
                ScannerView(onSave: saveScan)
            }
            .navigationDestination(isPresented: $showSavedDetail) {
                if let savedCard {
                    CardDetailView(id: savedCard, repository: repository)
                }
            }
            .onChange(of: showSavedDetail) { _, shown in
                if !shown { savedCard = nil }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "ellipsis.message").font(.title2)
                .overlay(alignment: .topTrailing) {
                    Circle().fill(.red).frame(width: 6, height: 6).offset(x: 4, y: -4)
                }
            NavigationLink {
                LibrarySearch(repository: repository)
            } label: {
                Label("请输入姓名/公司/职位搜索", systemImage: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("library-search")
            Image(systemName: "plus.circle").font(.title2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 7)
    }

    private var shortcuts: some View {
        HStack(spacing: 12) {
            shortcut("新的人脉", icon: "person.crop.circle.fill", color: CardPalette.blue)
            NavigationLink {
                LibraryGroups(repository: repository)
            } label: {
                shortcut("分组管理", icon: "folder.fill.badge.plus", color: .orange)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("library-groups")
            shortcut("人脉地图", icon: "map.fill", color: .green)
            shortcut("人脉分析", icon: "chart.bar.fill", color: CardPalette.blue)
        }
        .padding(.horizontal, 16)
    }

    private func shortcut(_ title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(title).font(.footnote)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 84)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
    }

    private var cardPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                (Text("名片").bold() + Text(" (\(cards.count)张)").foregroundColor(.secondary))
                    .accessibilityIdentifier("card-count")
                Spacer()
                Button { managing = true } label: {
                    Label("管理", systemImage: "square.3.layers.3d").font(.footnote)
                }
                .buttonStyle(.plain)
                .navigationDestination(isPresented: $managing) {
                    ManagedCards(repository: repository)
                }
            }

            if repository.loadFailed {
                Text("无法读取名片")
                Button("重试", action: repository.reload)
            } else if cards.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.title2)
                        .foregroundStyle(CardPalette.blue)
                        .frame(width: 100, height: 60)
                        .background(CardPalette.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("30秒快速认识CC").font(.headline)
                        Text("体验智能的名片识别、人脉管理")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            } else {
                ForEach(cards) { card in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(card.createdAt, format: .iso8601.year().month().day().dateSeparator(.dash))
                            .font(.footnote).foregroundStyle(.secondary)
                        NavigationLink {
                            CardDetailView(id: card.id, repository: repository)
                        } label: {
                            LibraryCardRow(card: card, image: repository.image(card.correctedImagePath))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("card-\(card.id.uuidString)")
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 5))
    }

    private var bottomBar: some View {
        HStack {
            tab("首页", icon: "house")
            tab("名片夹", icon: "person.text.rectangle.fill", selected: true)
            Button {
                showsScanner = true
            } label: {
                Image(systemName: "camera.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(CardPalette.blue, in: Circle())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("扫描")
            .accessibilityIdentifier("open-scanner")
            tab("企业", icon: "building.2")
            tab("登录注册", icon: "person")
        }
        .padding(.vertical, 5)
        .background(Color(white: 0.98).ignoresSafeArea(edges: .bottom))
    }

    private func tab(_ title: String, icon: String, selected: Bool = false) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption2)
        }
        .foregroundStyle(selected ? CardPalette.blue : .secondary)
        .frame(maxWidth: .infinity)
    }

    private func saveScan(_ scan: ScanResult, fields: ContactFields) throws {
        let now = Date()
        let card = BusinessCard(id: UUID(), fields: fields, recognition: scan.recognition,
                                createdAt: now, updatedAt: now)
        try repository.save(card, original: scan.original, corrected: scan.corrected)
        savedCard = card.id
    }
}

struct LibraryCardRow: View {
    let card: BusinessCard
    let image: CGImage?
    var highlight = ""

    var body: some View {
        HStack(spacing: 10) {
            if let cardImage = image {
                Image(decorative: cardImage, scale: 1)
                    .resizable().scaledToFit()
                    .frame(width: 100, height: 60)
                    .accessibilityHidden(true)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.fields.name ?? "未命名名片").font(.system(size: 9, weight: .bold))
                    Text(card.fields.company ?? "").font(.system(size: 7))
                    Spacer(minLength: 0)
                    Image(systemName: "square.on.square").foregroundStyle(CardPalette.navy)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(8)
                .frame(width: 100, height: 60)
                .background(.white)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(marked(card.fields.name ?? "未命名名片")).font(.headline)
                Text(marked(card.fields.jobTitle ?? "")).font(.footnote).foregroundStyle(.secondary)
                Text(marked(card.fields.company ?? "")).font(.footnote).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 2)
            Image(systemName: "ellipsis").foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private func marked(_ value: String) -> AttributedString {
        var result = AttributedString(value)
        if !highlight.isEmpty,
           let match = value.range(of: highlight, options: .caseInsensitive),
           let range = Range(match, in: result) {
            result[range].foregroundColor = CardPalette.blue
        }
        return result
    }
}

private struct LibrarySearch: View {
    let repository: CardRepository
    @State private var query = ""
    @State private var tab = "综合"

    var body: some View {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = repository.cards.filter { $0.matches(term) }
        VStack(spacing: 0) {
            groupSearch("请输入姓名/公司/职位搜索", text: $query, id: "search-query")
                .padding(12).background(.white)
            HStack {
                ForEach(["综合", "名片"], id: \.self) { title in
                    Button { tab = title } label: {
                        VStack(spacing: 8) {
                            Text(title).foregroundStyle(tab == title ? CardPalette.blue : .primary)
                            Capsule().fill(tab == title ? CardPalette.blue : .clear).frame(width: 24, height: 3)
                        }.frame(maxWidth: .infinity)
                    }.buttonStyle(.plain)
                }
            }.padding(.top, 6).background(.white)
            if !term.isEmpty {
                if matches.isEmpty {
                    ContentUnavailableView("未找到「\(term)」", systemImage: "magnifyingglass",
                                           description: Text("请检查输入或更换搜索词"))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("名片夹名片 (\(matches.count))").font(.subheadline).foregroundStyle(.secondary).padding(16)
                            ForEach(matches) { card in
                                groupCardLink(card, repository: repository, highlight: term)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .background(CardPalette.background)
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
