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
    var original: CGImage? = nil
    var corrected: CGImage? = nil
    var recognition: RecognitionRecord? = nil
    var isNew = false
    var save: (ContactFields, CGImage?) throws -> Void
    @State private var error: String?
    @State private var showsName = false
    @State private var imagePage = 0
    @State private var addsCompany = false
    @State private var addsSecondCompany = false
    @State private var addsMore = false
    @State private var showsAlbum = false
    @State private var manualImage: CGImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("编辑名片")
                HStack {
                    Button("取消") { dismiss() }.foregroundStyle(.primary)
                    Spacer()
                    Button("保存") {
                        do { try save(fields.cleaned, manualImage); dismiss() }
                        catch { self.error = "无法保存名片。" }
                    }
                    .disabled(isNew && fields.cleaned == ContactFields())
                }.padding(.horizontal, 16)
            }.frame(height: 48)
            ScrollView {
                VStack(spacing: 10) {
                    if let image = corrected ?? original ?? manualImage { preview(image) }
                    if isNew { manualImageButton }
                    Button { showsName = true } label: {
                        HStack(spacing: 12) {
                            fieldLabel("姓名")
                            Text(fields.name ?? "").foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16).frame(minHeight: 50).background(.white)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("edit-name")
                    VStack(spacing: 0) {
                        values("手机", list: $fields.mobile)
                        values("办公电话", list: $fields.officePhone)
                        Menu {
                            Button("手机") { fields.mobile.append("") }
                            Button("办公电话") { fields.officePhone.append("") }
                            Button("传真") { fields.fax.append(""); addsMore = true }
                        } label: { addLabel("添加电话") }
                    }
                    VStack(spacing: 0) {
                        values("工作邮箱", list: $fields.email)
                        Button { fields.email.append("") } label: { addLabel("添加邮箱") }
                            .buttonStyle(.plain)
                    }
                    VStack(spacing: 0) {
                        if addsCompany || addsSecondCompany || fields.company != nil || fields.jobTitle != nil
                            || fields.department != nil || fields.alternateCompany != nil || fields.alternateJobTitle != nil {
                            row("公司", text: optional(\.company))
                            row("部门", text: optional(\.department))
                            row("职位", text: optional(\.jobTitle))
                            if addsSecondCompany || fields.alternateCompany != nil || fields.alternateJobTitle != nil {
                                row("公司", text: optional(\.alternateCompany), id: "edit-alternate-company")
                                row("职位", text: optional(\.alternateJobTitle), id: "edit-alternate-title")
                            }
                        }
                        Button {
                            if addsCompany || fields.company != nil || fields.jobTitle != nil || fields.department != nil {
                                addsSecondCompany = true
                            } else {
                                addsCompany = true
                            }
                        } label: { addLabel("添加公司信息") }
                        .buttonStyle(.plain)
                    }
                    VStack(spacing: 0) {
                        if addsMore || fields.website != nil || fields.address != nil || !fields.fax.isEmpty {
                            row("主页", text: optional(\.website), blue: true)
                            row("公司地址", text: optional(\.address), blue: true)
                            values("传真", list: $fields.fax)
                        }
                        if !addsMore {
                            Button { addsMore = true } label: { addLabel("添加更多信息") }
                                .buttonStyle(.plain)
                        }
                    }
                    if isNew {
                        Toggle("名片自动保存到通讯录", isOn: .constant(false))
                            .font(.subheadline).padding(.horizontal, 16).frame(minHeight: 50)
                            .background(.white).disabled(true)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(CardPalette.background.ignoresSafeArea())
        .tint(CardPalette.blue)
        .fullScreenCover(isPresented: $showsName) {
            CardNameEditor(
                details: fields.nameDetails ?? CardName(name: fields.name),
                preview: NameImagePreview(image: corrected, recognition: recognition)
            ) { details in
                fields.name = details.displayName
                fields.nameDetails = details
            }
        }
        .fullScreenCover(isPresented: $showsAlbum) {
            ScanAlbum { images in
                guard let data = images.first else { return }
                do { manualImage = try ScanProcessor.decode(data) }
                catch { self.error = "无法读取这张照片。" }
                showsAlbum = false
            }
        }
        .managementError($error)
    }

    private var manualImageButton: some View {
        Button { showsAlbum = true } label: {
            VStack(spacing: 10) {
                Image(systemName: "plus").font(.title3)
                    .frame(width: 50, height: 50)
                    .background(.white, in: RoundedRectangle(cornerRadius: 4))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(.gray.opacity(0.5), style: StrokeStyle(dash: [2, 2]))
                    }
                Text(manualImage == nil ? "添加名片图像" : "更换名片图像").font(.subheadline)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: manualImage == nil ? 156 : 90)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func preview(_ image: CGImage) -> some View {
        TabView(selection: $imagePage) {
            RecognizedCardImage(image: image, regions: corrected == nil ? [] : recognition?.regions ?? [])
                .scaledToFit().tag(0)
            if let original, corrected != nil {
                Image(decorative: original, scale: 1).resizable().scaledToFit().tag(1)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .aspectRatio(max(CGFloat(image.width) / CGFloat(image.height), 1.05), contentMode: .fit)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .clipShape(.rect(cornerRadius: 8))
        .overlay(alignment: .bottom) {
            if original != nil, corrected != nil {
                HStack(spacing: 10) {
                    ForEach(0..<2) { page in
                        Button { imagePage = page } label: {
                            Circle().fill(page == imagePage ? CardPalette.blue : .gray.opacity(0.6))
                                .frame(width: 8, height: 8)
                                .frame(width: 22, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(page == 0 ? "校正图" : "原图")
                    }
                }.padding(.bottom, 2)
            }
        }
        .padding(.horizontal, 16).padding(.top, 10)
        .accessibilityIdentifier("edit-card-preview")
    }

    private func fieldLabel(_ label: String, blue: Bool = false) -> some View {
        Text(label).font(.subheadline)
            .foregroundStyle(blue ? CardPalette.blue : .secondary)
            .frame(width: 78, alignment: .leading)
    }

    private func row(_ label: String, text: Binding<String>, blue: Bool = false, id: String? = nil) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                fieldLabel(label, blue: blue)
                TextField(label, text: text, prompt: Text(""), axis: .vertical)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier(id ?? "edit-\(label)")
            }.padding(.horizontal, 16).frame(minHeight: 50)
            Divider().padding(.horizontal, 16)
        }.background(.white)
    }

    private func addLabel(_ title: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "plus.circle.fill").foregroundStyle(CardPalette.blue)
            Text(title).foregroundStyle(.secondary)
            Spacer()
        }
        .font(.subheadline).padding(.horizontal, 18).frame(minHeight: 50)
        .background(.white).contentShape(Rectangle())
    }

    private func optional(_ key: WritableKeyPath<ContactFields, String?>) -> Binding<String> {
        Binding(get: { fields[keyPath: key] ?? "" }, set: { fields[keyPath: key] = $0 })
    }

    private func values(_ title: String, list: Binding<[String]>) -> some View {
        ForEach(list.wrappedValue.indices, id: \.self) { index in
            row(title, text: list[index], blue: true)
        }
    }
}

struct RecognizedCardImage: View {
    let image: CGImage
    let regions: [RecognitionRecord.TextRegion]

    var body: some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .overlay {
                GeometryReader { proxy in
                    ForEach(Array(regions.enumerated()), id: \.offset) { _, region in
                        Rectangle().fill(.orange.opacity(0.20))
                            .frame(width: region.width * proxy.size.width, height: region.height * proxy.size.height)
                            .position(x: (region.x + region.width / 2) * proxy.size.width,
                                      y: (region.y + region.height / 2) * proxy.size.height)
                    }
                }.accessibilityHidden(true)
            }
    }
}

struct NameImagePreview: View {
    let image: CGImage?
    let recognition: RecognitionRecord?

    var body: some View {
        if let image {
            if let region = recognition?.regions.first(where: {
                !$0.text.isEmpty && $0.text == recognition?.candidates.name
            }), let crop = image.cropping(to: CGRect(x: region.x * Double(image.width),
                                                     y: region.y * Double(image.height),
                                                     width: region.width * Double(image.width),
                                                     height: region.height * Double(image.height)).integral) {
                Image(decorative: crop, scale: 1).resizable().scaledToFit()
                    .background(.pink.opacity(0.15))
            } else {
                RecognizedCardImage(image: image, regions: recognition?.regions ?? [])
                    .scaledToFill()
            }
        }
    }
}

struct CardNameEditor<Preview: View>: View {
    @State var details: CardName
    let preview: Preview
    let onBack: (CardName) -> Void
    @State private var showsHidden = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    onBack(details)
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")
                .accessibilityIdentifier("scan-name-back")
                Spacer()
            }.background(.white)
            ScrollView {
                VStack(spacing: 10) {
                    preview.frame(maxWidth: .infinity).frame(height: 100)
                        .background(.white).clipped().accessibilityHidden(true)
                    VStack(spacing: 0) {
                        row("姓", value: $details.surname, id: "field-surname")
                        row("名字", value: $details.givenName, id: "field-given-name")
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("拼音").font(.footnote).foregroundStyle(.secondary)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                        row("姓", value: $details.phoneticSurname, id: "name-phonetic-surname")
                        row("名字", value: $details.phoneticGivenName, id: "name-phonetic-given")
                    }
                    if showsHidden {
                        VStack(spacing: 0) {
                            row("名称前缀", value: $details.prefix, id: "name-prefix")
                            row("中间名", value: $details.middleName, id: "name-middle")
                            row("名称后缀", value: $details.suffix, id: "name-suffix")
                            row("昵称", value: $details.nickname, id: "name-nickname")
                        }
                    } else {
                        Button("显示隐藏项") { showsHidden = true }
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44).background(.white)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(CardPalette.background.ignoresSafeArea())
    }

    private func row(_ title: String, value: Binding<String>, id: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .leading)
                TextField(title, text: value, prompt: Text(""))
                    .autocorrectionDisabled()
                    .accessibilityIdentifier(id)
            }.padding(.horizontal, 16).frame(minHeight: 50)
            Divider().padding(.horizontal, 16)
        }.background(.white)
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
