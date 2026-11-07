import SwiftUI

struct LibraryGroups: View {
    let repository: CardRepository
    @State private var name = ""
    @State private var search = ""
    @State private var editing = false
    @State private var naming = false
    @State private var groupToRename: CardGroup?
    @State private var groupToDelete: CardGroup?
    @State private var error: String?
    @State private var sortedByName = false

    var body: some View {
        let groups = sortedByName ? repository.groups.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        } : repository.groups
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !editing {
                    groupSearch("请输入分组名称", text: $search).padding(.horizontal, 16).padding(.vertical, 8).background(.white)
                    Button { groupToRename = nil; name = ""; naming = true } label: {
                        Label("新建分组", systemImage: "plus").frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain).padding(16).background(.white)
                }
                HStack {
                    Text("我的分组")
                    Spacer()
                    if !editing {
                        Menu("排序", systemImage: "line.3.horizontal.decrease") {
                            Button("自定义顺序") { sortedByName = false }
                            Button("按名称") { sortedByName = true }
                        }
                    }
                }.font(.subheadline).foregroundStyle(.secondary).padding(16)
                ForEach(groups.filter { editing || search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { group in
                    let title = "\(group.name) (\(repository.cards.filter { $0.groupIDs.contains(group.id) }.count))"
                    if editing {
                        HStack {
                            Button { groupToDelete = group } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                            }.accessibilityLabel("删除分组 \(group.name)")
                            Button {
                                groupToRename = group
                                name = group.name
                                naming = true
                            } label: {
                                HStack {
                                    Text(title)
                                    Image(systemName: "pencil").foregroundStyle(.secondary)
                                }
                            }.buttonStyle(.plain)
                            Spacer()
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.tertiary)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                                .draggable(group.id.uuidString)
                                .accessibilityLabel("调整分组顺序")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).frame(minHeight: 54)
                        .background(.white)
                        .dropDestination(for: String.self) { values, _ in
                            guard let value = values.first, let id = UUID(uuidString: value), id != group.id else {
                                return false
                            }
                            do {
                                try repository.moveGroup(id: id, to: group.id)
                                sortedByName = false
                                return true
                            } catch {
                                self.error = "无法调整分组顺序。"
                                return false
                            }
                        }
                    } else {
                        groupLink(title) { GroupCards(repository: repository, group: group) }
                    }
                }
                Text("智能分组").font(.subheadline).foregroundStyle(.secondary).padding(16)
                groupLink("近 30 天看过的名片 (\(repository.cards.filter(\.recentlyViewed).count))") {
                    GroupCards(repository: repository, smart: .viewed)
                }
                groupLink("最近新增名片 (\(repository.cards.filter(\.recentlyCreated).count))") {
                    GroupCards(repository: repository, smart: .recent)
                }
                groupLink("未分组 (\(repository.cards.filter { $0.groupIDs.isEmpty }.count))") {
                    GroupCards(repository: repository, smart: .ungrouped)
                }
            }
        }
        .background(CardPalette.background)
        .navigationTitle(editing ? "编辑分组" : "分组")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(editing ? "完成" : "编辑") {
                    editing.toggle()
                    if editing { sortedByName = false }
                }.tint(CardPalette.blue)
            }
        }
        .alert(groupToRename == nil ? "新建分组" : "编辑分组", isPresented: $naming) {
            TextField("分组名称", text: $name)
            Button("取消", role: .cancel) {}
            Button("好") {
                do {
                    try createGroup(name, replacing: groupToRename, repository: repository)
                } catch { self.error = "无法保存分组，请检查名称是否重复。" }
            }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .alert("删除分组", isPresented: Binding(get: { groupToDelete != nil }, set: { if !$0 { groupToDelete = nil } }), presenting: groupToDelete) { group in
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                do { try repository.delete(group) } catch { self.error = "无法删除分组。" }
            }
        } message: { _ in
            Text("该分组中的名片仍会保留。")
        }
        .managementError($error)
    }

    @ViewBuilder
    private func groupLink<Destination: View>(_ title: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }.padding(16).background(.white)
        }.buttonStyle(.plain)
        Divider().padding(.leading, 16)
    }
}

private struct GroupCards: View {
    enum SmartGroup { case viewed, recent, ungrouped }
    let repository: CardRepository
    var group: CardGroup? = nil
    var smart: SmartGroup? = nil
    @State private var query = ""
    @State private var more = false
    @State private var picker = false
    @State private var scanner = false
    @State private var savedCardID: UUID?
    @State private var showingSavedCard = false
    @Environment(\.dismiss) private var dismiss
    @State private var selecting = false
    @State private var selected: Set<UUID> = []
    @State private var error: String?

    private var members: [BusinessCard] {
        repository.cards.filter { card in
            if let group { return card.groupIDs.contains(group.id) }
            switch smart {
            case .viewed: return card.recentlyViewed
            case .recent: return card.recentlyCreated
            default: return card.groupIDs.isEmpty
            }
        }
    }

    var body: some View {
        let title = group?.name ?? (smart == .viewed ? "近 30 天看过的名片" : smart == .recent ? "最近新增名片" : "未分组")
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").frame(width: 28, height: 44).contentShape(Rectangle())
                }.accessibilityLabel("返回").accessibilityIdentifier("group-back")
                groupSearch("\(title) (\(members.count))", text: $query)
                if group != nil {
                    Button {
                        if selecting { selecting = false; selected = [] }
                        else { more = true }
                    } label: {
                        if selecting { Text("取消") } else { Image(systemName: "ellipsis").frame(width: 28, height: 44).contentShape(Rectangle()) }
                    }.accessibilityLabel(selecting ? "取消" : "更多").accessibilityIdentifier("group-more")
                }
            }.buttonStyle(.plain).padding(.horizontal, 12).background(.white)
            ScrollView {
                ForEach(members.filter { query.isEmpty || $0.matches(query) }) { card in
                    if selecting {
                        selectionRow(card, selected: $selected)
                    } else {
                        Text(card.createdAt, format: .iso8601.year().month().day().dateSeparator(.dash))
                            .font(.footnote).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                        groupCardLink(card, repository: repository)
                    }
                }
            }
            if selecting, let group {
                Button("移出分组") {
                    do {
                        try repository.save(members.filter { selected.contains($0.id) }.map {
                            var card = $0
                            card.groupIDs.remove(group.id)
                            return card
                        })
                        selected = []
                        selecting = false
                    } catch { self.error = "无法更新分组。" }
                }.disabled(selected.isEmpty).padding()
            }
        }
        .background(CardPalette.background)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showingSavedCard) {
            if let savedCardID { CardDetailView(id: savedCardID, repository: repository) }
        }
        .onChange(of: showingSavedCard) { _, shown in
            if !shown { savedCardID = nil }
        }
        .confirmationDialog("", isPresented: $more) {
            Button("多选") { selecting = true }
            Button("拍名片") { scanner = true }
            Button("从名片夹中添加") { picker = true }
            Button("取消", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $picker) {
            if let group {
                GroupMemberPicker(repository: repository, group: group)
            }
        }
        .fullScreenCover(isPresented: $scanner, onDismiss: { showingSavedCard = savedCardID != nil }) {
            if let group {
                ScannerView { scan, fields in
                    let card = BusinessCard(id: UUID(), fields: fields, recognition: scan.recognition,
                                            groupIDs: [group.id], createdAt: .now, updatedAt: .now)
                    try repository.save(card, original: scan.original, corrected: scan.corrected)
                    savedCardID = card.id
                }
            }
        }
        .managementError($error)
    }
}

private struct GroupMemberPicker: View {
    let repository: CardRepository
    let group: CardGroup
    @State private var selected: Set<UUID> = []
    @State private var query = ""
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                groupSearch("请输入姓名/公司/职位搜索", text: $query).padding(12).background(.white)
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(repository.cards.filter { !$0.groupIDs.contains(group.id) && (query.isEmpty || $0.matches(query)) }) { card in
                            selectionRow(card, selected: $selected)
                        }
                    }
                }
            }
            .background(CardPalette.background)
            .navigationTitle("从名片夹中添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        do {
                            try repository.save(repository.cards.filter { selected.contains($0.id) }.map {
                                var card = $0
                                card.groupIDs.insert(group.id)
                                return card
                            })
                            dismiss()
                        } catch { self.error = "无法添加名片。" }
                    }.disabled(selected.isEmpty)
                }
            }
            .managementError($error)
        }
    }
}

struct ManagedCards: View {
    let repository: CardRepository
    @State private var selected: Set<UUID> = []
    @State private var confirm = false
    @State private var error: String?

    var body: some View {
        List(repository.cards) { card in
            selectionRow(card, selected: $selected)
        }
        .listStyle(.plain)
        .navigationTitle("管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("删除", role: .destructive) { confirm = true }.disabled(selected.isEmpty)
            }
        }
        .alert("提示", isPresented: $confirm) {
            Button("取消", role: .cancel) {}
            Button("删除名片", role: .destructive) {
                do {
                    try repository.deleteCards(repository.cards.filter { selected.contains($0.id) })
                    selected = []
                } catch { self.error = "无法删除名片。" }
            }
        } message: { Text("删除未同步名片将无法恢复，请确认是否要删除？") }
        .managementError($error)
    }
}

private func selectionRow(_ card: BusinessCard, selected: Binding<Set<UUID>>) -> some View {
    Button {
        if selected.wrappedValue.contains(card.id) { selected.wrappedValue.remove(card.id) }
        else { selected.wrappedValue.insert(card.id) }
    } label: {
        HStack(spacing: 12) {
            Image(systemName: selected.wrappedValue.contains(card.id) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(CardPalette.blue)
            Text(card.fields.name ?? "未命名名片")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
        .background(.white)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("select-card-\(card.id.uuidString)")
}

@MainActor
func groupCardLink(_ card: BusinessCard, repository: CardRepository, highlight: String = "") -> some View {
    LibraryCardEntry(card: card, repository: repository, identifier: "linked-card-\(card.id.uuidString)", highlight: highlight)
        .padding(.horizontal, 16).padding(.vertical, 10).background(.white)
}

func groupSearch(_ placeholder: String, text: Binding<String>, id: String? = nil) -> some View {
    HStack(spacing: 8) {
        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
        TextField(placeholder, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier(id ?? placeholder)
    }.padding(.horizontal, 12).frame(height: 36).background(CardPalette.background, in: Capsule())
}

@MainActor
func createGroup(_ name: String, replacing previous: CardGroup? = nil, repository: CardRepository) throws {
    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty, !repository.groups.contains(where: {
        $0.id != previous?.id && $0.name.localizedCaseInsensitiveCompare(title) == .orderedSame
    }) else { throw CocoaError(.validationMissingMandatoryProperty) }
    try repository.save(CardGroup(id: previous?.id ?? UUID(), name: title, createdAt: previous?.createdAt ?? .now))
}

extension View {
    func managementError(_ message: Binding<String?>) -> some View {
        alert("提示", isPresented: Binding(get: { message.wrappedValue != nil }, set: {
            if !$0 { message.wrappedValue = nil }
        })) {
            Button("好", role: .cancel) {}
        } message: { Text(message.wrappedValue ?? "") }
    }
}
