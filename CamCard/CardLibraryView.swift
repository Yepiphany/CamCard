import SwiftUI

enum CardPalette {
    static let blue = Color(red: 0.10, green: 0.65, blue: 0.95)
    static let navy = Color(red: 0.08, green: 0.21, blue: 0.39)
    static let background = Color(white: 0.94)
}

struct CardLibraryView: View {
    let repository: CardRepository
    private var cards: [BusinessCard] { repository.cards }
    private enum Entry: String, Identifiable {
        case scanner, album, manual
        var id: Self { self }
    }
    @State private var entry: Entry?
    @State private var pendingEntry: Entry?
    @State private var adding = false
    @State private var showsAddMenu = false
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
            .overlay(alignment: .topTrailing) {
                if showsAddMenu { addMenu }
            }
            .navigationDestination(isPresented: $adding) {
                addOptions
            }
            .onChange(of: adding) { _, shown in
                if !shown, let pendingEntry {
                    self.pendingEntry = nil
                    entry = pendingEntry
                }
            }
            .fullScreenCover(item: $entry, onDismiss: {
                showSavedDetail = savedCard != nil
            }) { destination in
                switch destination {
                case .scanner, .album:
                    ScannerView(opensAlbum: destination == .album, onSave: saveScan)
                case .manual:
                    ContactFieldsEditor(fields: ContactFields(), isNew: true, save: saveManual)
                }
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
            Button { showsAddMenu.toggle() } label: {
                Image(systemName: "plus.circle").font(.title2)
                    .frame(width: 26, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("添加")
            .accessibilityIdentifier("library-add")
        }
        .padding(.horizontal, 16)
        .padding(.top, 7)
    }

    private var addMenu: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear.contentShape(Rectangle()).onTapGesture { showsAddMenu = false }
            VStack(spacing: 0) {
                addOption("扫一扫", icon: "viewfinder") {
                    showsAddMenu = false
                    entry = .scanner
                }
                addOption("添加名片", icon: "person.text.rectangle") {
                    showsAddMenu = false
                    adding = true
                }
                addOption("备份手机通讯录", icon: "person.crop.rectangle.stack") {}
                    .disabled(true)
                addOption("导入联系人", icon: "square.and.arrow.down") {}
                    .disabled(true)
            }
            .frame(width: 174)
            .background(.white, in: RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
            .padding(.top, 54).padding(.trailing, 16)
        }
    }

    private var addOptions: some View {
        VStack(spacing: 10) {
            VStack(spacing: 0) {
                addOption("从相册导入", icon: "photo") { beginEntry(.album) }
                addOption("手动输入名片", icon: "square.and.pencil") { beginEntry(.manual) }
                addOption("识别邮件签名", icon: "envelope.badge") {}
                    .disabled(true)
            }.background(.white)
            addOption("导入系统联系人", icon: "person.crop.circle.badge.plus") {}
                .disabled(true).background(.white)
            addOption("雷达交换", icon: "scope") {}
                .disabled(true).background(.white)
            Spacer()
        }
        .padding(.top, 10)
        .background(CardPalette.background.ignoresSafeArea())
        .navigationTitle("添加名片")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func addOption(_ title: String, icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: icon).foregroundStyle(CardPalette.blue).frame(width: 22)
                    Text(title).foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16).frame(minHeight: 46)
                Divider().padding(.horizontal, 16)
            }
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func beginEntry(_ destination: Entry) {
        pendingEntry = destination
        adding = false
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
                        LibraryCardEntry(card: card, repository: repository, identifier: "card-\(card.id.uuidString)")
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
                entry = .scanner
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

    private func saveManual(_ fields: ContactFields, image: CGImage?) throws {
        let card = BusinessCard(id: UUID(), fields: fields, createdAt: .now, updatedAt: .now)
        if let image {
            try repository.save(card, original: image, corrected: image)
        } else {
            try repository.save(card)
        }
        savedCard = card.id
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

struct LibraryCardEntry: View {
    let card: BusinessCard
    let repository: CardRepository
    let identifier: String
    var highlight = ""

    private enum Destination: String, Identifiable {
        case groups, notes
        var id: Self { self }
    }

    @State private var more = false
    @State private var pending: Destination?
    @State private var pendingExport = false
    @State private var destination: Destination?
    @State private var exportFile: ContactExportFile?
    @State private var error: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 0) {
            NavigationLink {
                CardDetailView(id: card.id, repository: repository)
            } label: {
                LibraryCardRow(card: card, image: repository.image(card.correctedImagePath), highlight: highlight)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(card.fields.name ?? "未命名名片")
            .accessibilityIdentifier(identifier)
            Button { more = true } label: {
                Image(systemName: "ellipsis").foregroundStyle(.tertiary)
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("更多操作")
            .accessibilityIdentifier("card-more-\(card.id.uuidString)")
        }
        .fullScreenCover(isPresented: $more, onDismiss: {
            if pendingExport {
                pendingExport = false
                do { exportFile = try ContactExportFile(fields: card.fields) }
                catch { self.error = "无法生成 VCF。" }
            } else {
                destination = pending
                pending = nil
            }
        }) {
            VStack(spacing: 0) {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { more = false }
                    .accessibilityHidden(true)
                quickActions
            }
            .background { Color.black.opacity(0.50).ignoresSafeArea() }
            .presentationBackground(.clear)
        }
        .fullScreenCover(item: $destination) { page in
            switch page {
            case .groups: CardGroupsPicker(repository: repository, cardID: card.id)
            case .notes: CardNotes(repository: repository, cardID: card.id)
            }
        }
        .sheet(item: $exportFile) { file in
            ContactExportConfirmation(file: file)
        }
        .managementError($error)
    }

    private var quickActions: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("更多操作").font(.headline)
                HStack {
                    Button { more = false } label: {
                        Image(systemName: "xmark").foregroundStyle(.secondary).frame(width: 48, height: 50)
                    }.buttonStyle(.plain).accessibilityLabel("关闭")
                    Spacer()
                }
            }
            Divider()
            action("打电话", icon: "phone") {
                if let number = (card.fields.mobile + card.fields.officePhone).first {
                    let digits = number.filter { $0.isNumber || $0 == "+" }
                    if !digits.isEmpty, let url = URL(string: "tel:" + digits) { openURL(url) }
                }
                more = false
            }.disabled((card.fields.mobile + card.fields.officePhone).isEmpty)
            action("管理分组", icon: "list.bullet") { pending = .groups; more = false }
            action("添加备注/拜访日志", icon: "square.and.pencil") { pending = .notes; more = false }
            action("分享TA的名片", icon: "square.and.arrow.up") {
                pendingExport = true
                more = false
            }
            Color.clear.frame(height: 12)
        }
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
                .fill(.white)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func action(_ title: String, icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 0) {
                HStack(spacing: 15) {
                    Image(systemName: icon).font(.system(size: 20)).frame(width: 24)
                    Text(title)
                    Spacer()
                }
                .padding(.horizontal, 16).frame(height: 54)
                Divider().padding(.horizontal, 16)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

private struct LibrarySearch: View {
    let repository: CardRepository
    @State private var query = ""
    @State private var tab = "综合"
    @AppStorage("card-search-history") private var historyData = Data()
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    private var term: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var history: [String] { (try? JSONDecoder().decode([String].self, from: historyData)) ?? [] }

    var body: some View {
        let matches = repository.cards.filter { $0.matches(term) }
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    remember()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left").frame(width: 22, height: 42)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("返回").accessibilityIdentifier("search-back")
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("不仅能搜名片，还能搜企业和人脉", text: $query)
                        .focused($focused).submitLabel(.search)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("search-query")
                        .onSubmit { remember(); focused = false }
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }.buttonStyle(.plain).accessibilityLabel("清空搜索")
                    }
                }.padding(.horizontal, 12).frame(height: 34).background(.white, in: Capsule())
            }.padding(.horizontal, 16).padding(.vertical, 4)

            if term.isEmpty {
                if !history.isEmpty { recentSearches }
                networkSearchPanel
            } else {
                HStack {
                    ForEach(["综合", "名片"], id: \.self) { title in
                        Button { tab = title; focused = false } label: {
                            VStack(spacing: 8) {
                                Text(title).foregroundStyle(tab == title ? CardPalette.blue : .primary)
                                Capsule().fill(tab == title ? CardPalette.blue : .clear).frame(width: 24, height: 3)
                            }.frame(maxWidth: .infinity)
                        }.buttonStyle(.plain)
                    }
                }.padding(.top, 10).background(.white)
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
                    }.scrollDismissesKeyboard(.interactively)
                }
            }
            Spacer(minLength: 0)
        }
        .background(CardPalette.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var networkSearchPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Text("搜索公开名片，轻松直达企业连接人")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(CardPalette.blue)
                Spacer()
                Image(systemName: "person.3.sequence.fill")
                    .font(.title3).foregroundStyle(CardPalette.blue.opacity(0.6))
                    .accessibilityHidden(true)
            }
            Toggle("开启人脉搜索", isOn: .constant(false))
                .font(.subheadline.weight(.semibold))
                .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 8))
                .disabled(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("•  开启后，其他人可通过姓名、公司等信息找到你。")
                Text("•  成为好友前，手机号和邮箱等联系方式不可见。")
                Text("•  开启后，可在隐私设置中关闭。")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [CardPalette.blue.opacity(0.09), .white], startPoint: .top, endPoint: .bottom))
        }
        .padding(.horizontal, 5).padding(.top, 10)
    }

    private var recentSearches: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("最近搜索").font(.headline)
                Spacer()
                Button { historyData = Data() } label: {
                    Image(systemName: "trash").foregroundStyle(.secondary)
                }.buttonStyle(.plain).accessibilityLabel("清空最近搜索")
            }
            ScrollView(.horizontal) {
                HStack {
                    ForEach(history, id: \.self) { value in
                        Button {
                            query = value
                            remember()
                            focused = false
                        } label: {
                            Text(value).padding(.horizontal, 12).padding(.vertical, 5)
                                .background(CardPalette.background, in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }
            }.scrollIndicators(.hidden)
        }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 5))
            .padding(.horizontal, 5)
    }

    private func remember() {
        guard !term.isEmpty else { return }
        let updated = [term] + history.filter { $0.caseInsensitiveCompare(term) != .orderedSame }
        historyData = (try? JSONEncoder().encode(Array(updated.prefix(10)))) ?? Data()
    }
}
