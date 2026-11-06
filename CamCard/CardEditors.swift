import SwiftUI

struct CardImages: View {
    let original: CGImage?
    let corrected: CGImage?
    @State private var selection = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                photo(original, title: "原图").tag(0)
                photo(corrected, title: "校正图").tag(1)
            }.tabViewStyle(.page(indexDisplayMode: .never))
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        pageButton("原图", index: 0)
                        pageButton("校正图", index: 1)
                    }
                    .padding(.bottom, 6)
                }
                .background(.black)
                .navigationTitle("名片图片")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
                }
        }
    }

    private func pageButton(_ title: String, index: Int) -> some View {
        Button { selection = index } label: {
            Circle().fill(selection == index ? CardPalette.blue : .gray)
                .frame(width: 8, height: 8).frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("card-image-page-\(index)")
    }

    private func photo(_ image: CGImage?, title: String) -> some View {
        VStack {
            Text(title).foregroundStyle(.white)
            if let image {
                Image(decorative: image, scale: 1).resizable().scaledToFit()
                    .accessibilityLabel(title)
            } else {
                ContentUnavailableView("无法读取图片", systemImage: "photo")
            }
        }.padding(16)
    }
}

struct ContactFieldsEditor: View {
    @State var fields: ContactFields
    let save: (ContactFields) throws -> Void
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    row("姓名", text: optional(\.name))
                    values("手机", list: $fields.mobile)
                    values("办公电话", list: $fields.officePhone)
                    values("工作邮箱", list: $fields.email)
                    VStack(spacing: 0) {
                        row("公司", text: optional(\.company))
                        Divider().padding(.horizontal, 16)
                        row("职位", text: optional(\.jobTitle))
                    }
                    row("首页", text: optional(\.website))
                    row("公司地址", text: optional(\.address))
                    values("传真", list: $fields.fax)
                }
            }
            .background(CardPalette.background)
            .navigationTitle("编辑名片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do { try save(fields.cleaned); dismiss() }
                        catch { self.error = "无法保存名片。" }
                    }
                }
            }
            .managementError($error)
        }
    }

    private func row(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary).frame(width: 82, alignment: .leading)
            TextField(label, text: text, prompt: Text(""), axis: .vertical)
                .autocorrectionDisabled()
                .accessibilityIdentifier("edit-\(label)")
        }.padding(.horizontal, 16).frame(minHeight: 50).background(.white)
    }

    private func optional(_ key: WritableKeyPath<ContactFields, String?>) -> Binding<String> {
        Binding(get: { fields[keyPath: key] ?? "" }, set: { fields[keyPath: key] = $0 })
    }

    private func values(_ title: String, list: Binding<[String]>) -> some View {
        VStack(spacing: 1) {
            ForEach(list.wrappedValue.indices, id: \.self) { index in
                row(title, text: list[index])
            }
            Button("添加\(title)", systemImage: "plus") { list.wrappedValue.append("") }
                .font(.subheadline).frame(maxWidth: .infinity, minHeight: 42).background(.white)
        }
    }
}

struct CardGroupsPicker: View {
    let repository: CardRepository
    let cardID: UUID
    @State private var query = ""
    @State private var newName = ""
    @State private var adding = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    groupSearch("请输入分组名称", text: $query).padding(12).background(.white)
                    Button { newName = ""; adding = true } label: {
                        Label("新建分组", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16).background(.white)
                    }.buttonStyle(.plain)
                    ForEach(repository.groups.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { group in
                        Button {
                            guard var card = repository.card(id: cardID) else { return }
                            if card.groupIDs.contains(group.id) { card.groupIDs.remove(group.id) }
                            else { card.groupIDs.insert(group.id) }
                            card.updatedAt = .now
                            do { try repository.save(card) } catch { self.error = "无法更新分组。" }
                        } label: {
                            HStack {
                                Text(group.name)
                                Spacer()
                                if repository.card(id: cardID)?.groupIDs.contains(group.id) == true {
                                    Image(systemName: "checkmark").foregroundStyle(CardPalette.blue)
                                }
                            }.padding(16).background(.white).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }
            }.background(CardPalette.background)
                .navigationTitle("添加到分组")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
                }
                .alert("新建分组", isPresented: $adding) {
                    TextField("分组名称", text: $newName)
                    Button("取消", role: .cancel) {}
                    Button("好") {
                        do { try createGroup(newName, repository: repository) }
                        catch { self.error = "无法创建分组。" }
                    }.disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .managementError($error)
        }
    }
}
