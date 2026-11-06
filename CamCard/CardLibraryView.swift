import SwiftUI

enum CardPalette {
    static let blue = Color(red: 0.10, green: 0.65, blue: 0.95)
    static let navy = Color(red: 0.08, green: 0.21, blue: 0.39)
    static let background = Color(white: 0.94)
}

struct CardLibraryView: View {
    let repository: any CardRepository
    @State private var cards: [BusinessCard] = []
    @State private var loadFailed = false
    @State private var showsScanner = false
    @State private var savedCard: BusinessCard?
    @State private var showSavedDetail = false
    @State private var scans: [UUID: ScanResult] = [:]
    private var images: [UUID: CGImage] { scans.mapValues(\.original) }
    @State private var groups: [CardGroup] = []

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
                loadCards()
                showSavedDetail = savedCard != nil
            }) {
                ScannerView(onSave: saveScan)
            }
            .navigationDestination(isPresented: $showSavedDetail) {
                if let savedCard {
                    CardDetailView(card: savedCard, cardImage: images[savedCard.id])
                }
            }
            .onChange(of: showSavedDetail) { _, shown in
                if !shown { savedCard = nil }
            }
            .onAppear(perform: loadCards)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "ellipsis.message").font(.title2)
                .overlay(alignment: .topTrailing) {
                    Circle().fill(.red).frame(width: 6, height: 6).offset(x: 4, y: -4)
                }
            NavigationLink {
                LibrarySearch(cards: cards, images: images)
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
                LibraryGroups(cards: cards, groups: $groups, images: images, onSave: updateCard)
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
                Label("管理", systemImage: "square.3.layers.3d").font(.footnote)
            }

            if loadFailed {
                Text("无法读取名片")
                Button("重试", action: loadCards)
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
                            CardDetailView(card: card, cardImage: images[card.id])
                        } label: {
                            cardRow(card)
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

    private func cardRow(_ card: BusinessCard) -> some View {
        HStack(spacing: 10) {
            if let cardImage = scans[card.id]?.corrected {
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
                Text(card.fields.name ?? "未命名名片").font(.headline)
                Text(card.fields.jobTitle ?? "").font(.footnote).foregroundStyle(.secondary)
                Text(card.fields.company ?? "").font(.footnote).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 2)
            Image(systemName: "ellipsis").foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
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
        try repository.save(card)
        scans[card.id] = scan
        savedCard = card
    }

    private func updateCard(_ card: BusinessCard) throws {
        try repository.save(card)
        loadCards()
    }

    private func loadCards() {
        do {
            cards = try repository.listCards()
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }
}

private struct LibrarySearch: View {
    let cards: [BusinessCard]
    let images: [UUID: CGImage]
    @State private var query = ""

    private var matches: [BusinessCard] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        return cards.filter { card in
            let fields = card.fields
            let text = [fields.name, fields.company, fields.jobTitle].compactMap { $0 }
            let digits = term.filter(\.isNumber)
            let phoneMatch = !digits.isEmpty
                && term.allSatisfy { $0.isNumber || "+- ()".contains($0) }
                && (fields.mobile + fields.officePhone).contains { $0.filter(\.isNumber).contains(digits) }
            return phoneMatch || (text + fields.email).contains { $0.localizedCaseInsensitiveContains(term) }
        }
    }

    var body: some View {
        List {
            TextField("请输入姓名/公司/职位搜索", text: $query)
                .accessibilityIdentifier("search-query")
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if matches.isEmpty {
                    ContentUnavailableView("暂无相关名片", systemImage: "magnifyingglass")
                }
                ForEach(matches) { card in
                    NavigationLink(card.fields.name ?? "未命名名片") {
                        CardDetailView(card: card, cardImage: images[card.id])
                    }
                }
            }
        }
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct LibraryGroups: View {
    let cards: [BusinessCard]
    @Binding var groups: [CardGroup]
    let images: [UUID: CGImage]
    let onSave: (BusinessCard) throws -> Void
    @State private var name = ""
    @State private var search = ""
    @State private var adding = false

    var body: some View {
        List {
            TextField("请输入分组名称", text: $search)
            Button("新建分组", systemImage: "plus") { adding = true }
            Section("我的分组") {
                ForEach(groups.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { group in
                    NavigationLink("\(group.name) (\(cards.filter { $0.groupIDs.contains(group.id) }.count))") {
                        GroupCards(group: group, cards: cards, images: images, onSave: onSave)
                    }
                }
            }
            Section("智能分组") {
                NavigationLink("未分组 (\(cards.filter { $0.groupIDs.isEmpty }.count))") {
                    List(cards.filter { $0.groupIDs.isEmpty }) { card in
                        NavigationLink(card.fields.name ?? "未命名名片") {
                            CardDetailView(card: card, cardImage: images[card.id])
                        }
                    }
                    .navigationTitle("未分组")
                    .toolbar(.visible, for: .navigationBar)
                }
            }
        }
        .navigationTitle("分组")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .alert("新建分组", isPresented: $adding) {
            TextField("分组名称", text: $name)
            Button("取消", role: .cancel) { name = "" }
            Button("好") {
                let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty, !groups.contains(where: { $0.name == title }) {
                    groups.append(CardGroup(id: UUID(), name: title, createdAt: .now))
                }
                name = ""
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

private struct GroupCards: View {
    let group: CardGroup
    let cards: [BusinessCard]
    let images: [UUID: CGImage]
    let onSave: (BusinessCard) throws -> Void
    @State private var added: Set<UUID> = []
    @State private var showingPicker = false
    @State private var failed = false

    private var members: [BusinessCard] {
        cards.compactMap { card in
            if card.groupIDs.contains(group.id) { return card }
            guard added.contains(card.id) else { return nil }
            var updated = card
            updated.groupIDs.insert(group.id)
            return updated
        }
    }

    var body: some View {
        List {
            Button("从名片夹中添加", systemImage: "plus") { showingPicker = true }
            ForEach(members) { card in
                NavigationLink(card.fields.name ?? "未命名名片") {
                    CardDetailView(card: card, cardImage: images[card.id])
                }
            }
        }
        .navigationTitle("\(group.name) (\(members.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .confirmationDialog("从名片夹中添加", isPresented: $showingPicker, titleVisibility: .visible) {
            ForEach(cards.filter { card in !members.contains(where: { $0.id == card.id }) }) { card in
                Button(card.fields.name ?? "未命名名片") {
                    var updated = card
                    updated.groupIDs.insert(group.id)
                    do {
                        try onSave(updated)
                        added.insert(card.id)
                    } catch {
                        failed = true
                    }
                }
            }
        }
        .alert("无法添加名片", isPresented: $failed) {
            Button("好", role: .cancel) {}
        }
    }
}
