import Contacts
import SwiftUI

struct CardDetailView: View {
    let id: UUID
    let repository: CardRepository

    private enum Page: String, Identifiable {
        case image, edit, groups, notes, contacts
        var id: Self { self }
    }

    @State private var page: Page?
    @State private var more = false
    @State private var confirmDelete = false
    @State private var contactsDenied = false
    @State private var exportFile: ContactExportFile?
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let card = repository.card(id: id) {
            detail(card)
                .onAppear {
                    var updated = card
                    updated.lastViewedAt = .now
                    try? repository.save(updated)
                }
        }
    }

    private func detail(_ card: BusinessCard) -> some View {
        let fields = card.fields
        return VStack(spacing: 0) {
            ZStack {
                Text("名片详情").font(.headline)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("返回")
                    .accessibilityIdentifier("detail-back")
                    Spacer()
                    Image(systemName: "star").frame(width: 36)
                    Button { more = true } label: {
                        Image(systemName: "ellipsis").frame(width: 38, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("更多")
                    .accessibilityIdentifier("detail-more")
                }.padding(.trailing, 4)
            }
            .frame(height: 46)
            .foregroundStyle(.white)
            .background {
                ZStack {
                    CardPalette.navy
                    if let image = repository.image(card.correctedImagePath) {
                        GeometryReader { geometry in
                            Image(decorative: image, scale: 1)
                                .resizable().scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                                .clipped().opacity(0.12)
                        }
                    }
                }.ignoresSafeArea(edges: .top)
            }

            ScrollView {
                VStack(spacing: 10) {
                    summary(fields)
                        .onTapGesture {
                            if card.originalImagePath != nil { page = .image }
                        }
                    HStack {
                        Button { call((fields.mobile + fields.officePhone).first) } label: {
                            action("电话", icon: "phone.fill", color: Color(red: 0.29, green: 0.55, blue: 0.97))
                        }.disabled((fields.mobile + fields.officePhone).isEmpty)
                        Button { map(fields.address) } label: {
                            action("地址", icon: "mappin", color: Color(red: 0.98, green: 0.71, blue: 0.05))
                        }.disabled(fields.address == nil)
                        Button { page = .notes } label: { action("备注", icon: "note.text", color: Color(red: 0.59, green: 0.75, blue: 0.12)) }
                        Button { page = .edit } label: { action("编辑", icon: "pencil", color: .teal) }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 10)
                    .background(.white)

                    VStack(spacing: 0) {
                        let names = repository.groups.filter { card.groupIDs.contains($0.id) }.map(\.name)
                        detailLink(names.isEmpty ? "未分组" : "分组: " + names.joined(separator: "、"),
                                   icon: "person.2.fill", id: "detail-groups") { page = .groups }
                        detailLink(card.notes.first.map { "备注: " + $0.text } ?? "备注",
                                   icon: "note.text", id: "detail-notes") { page = .notes }
                    }
                    .background(.white)

                    VStack(spacing: 0) {
                        rows("手机", icon: "phone.fill", values: fields.mobile, onTap: call)
                        rows("办公电话", icon: "phone.fill", values: fields.officePhone, onTap: call)
                        rows("工作邮箱", icon: "envelope.fill", values: fields.email, identifier: "email", onTap: email)
                        if let address = fields.address {
                            Button { map(address) } label: { field(address, label: "公司地址", icon: "mappin") }
                                .buttonStyle(.plain)
                        }
                        if let company = fields.company {
                            field(company, label: "公司", icon: "building.2.fill")
                        }
                        if let company = fields.alternateCompany {
                            field(company, label: fields.alternateJobTitle ?? "公司", icon: "building.2.fill")
                        }
                        if let website = fields.website {
                            Button {
                                if let url = ContactExport.website(website) { openURL(url) }
                            } label: { field(website, label: "主页", icon: "globe") }.buttonStyle(.plain)
                        }
                        rows("传真", icon: "printer.fill", values: fields.fax)
                    }
                    .background(.white)
                }
            }
            .background(CardPalette.background)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 10) {
                Button { page = .contacts } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "person.crop.rectangle").font(.title3)
                        Text(card.contactIdentifier == nil ? "存入通讯录" : "已存").font(.caption2)
                    }
                }.accessibilityIdentifier("detail-contacts")
                Text("向对方递名片").frame(maxWidth: .infinity)
                    .padding(.vertical, 8).overlay(Capsule().strokeBorder(CardPalette.blue))
                Button { prepareExport(card) } label: {
                    Text("分享名片").frame(maxWidth: .infinity)
                        .padding(.vertical, 8).foregroundStyle(.white)
                        .background(.green, in: Capsule())
                }
            }
            .font(.footnote)
            .foregroundStyle(CardPalette.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white)
        }
        .overlay {
            if more { morePanel(card) }
        }
        .fullScreenCover(item: $page) { selection in
            switch selection {
            case .image:
                CardImages(original: repository.image(card.originalImagePath), corrected: repository.image(card.correctedImagePath))
            case .edit:
                ContactFieldsEditor(fields: card.fields, original: repository.image(card.originalImagePath),
                                    corrected: repository.image(card.correctedImagePath), recognition: card.recognition) { fields, _ in
                    try update { $0.fields = fields }
                }
            case .groups:
                CardGroupsPicker(repository: repository, cardID: id)
            case .notes:
                CardNotes(repository: repository, cardID: id)
            case .contacts:
                ContactsDestination { try await saveToContacts() }
            }
        }
        .alert("提示", isPresented: $confirmDelete) {
            Button("取消", role: .cancel) {}
            Button("删除名片", role: .destructive) {
                do {
                    try repository.delete(card)
                    dismiss()
                } catch { self.error = "无法删除名片。" }
            }
        } message: { Text("删除未同步名片将无法恢复，请确认是否要删除？") }
        .alert("无法保存名片到通讯录", isPresented: $contactsDenied) {
            Button("取消", role: .cancel) {}
            Button("前往设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        } message: { Text("请在设置中允许访问通讯录。") }
        .sheet(item: $exportFile) { file in
            ContactExportConfirmation(file: file)
        }
        .managementError($error)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func detailLink(_ title: String, icon: String, id: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 0) {
                field(title, label: nil, icon: icon)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
                    .padding(.trailing, 16)
            }.frame(minHeight: 54).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(id)
    }

    private func morePanel(_ card: BusinessCard) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 4) {
                    panelItem(card.contactIdentifier == nil ? "存入通讯录" : "更新到通讯录", icon: "person.crop.rectangle.fill", color: .green) {
                        page = .contacts
                    }
                    panelItem("编辑", icon: "pencil", color: CardPalette.blue) { page = .edit }
                    panelItem("邀请使用名片全能王", icon: "person.badge.plus", color: CardPalette.blue)
                    panelItem("导出 VCF", icon: "square.and.arrow.up", color: CardPalette.blue) { prepareExport(card) }
                }.padding(16)
                Divider().padding(.horizontal, 16)
                HStack(alignment: .top, spacing: 4) {
                    panelItem("分组", icon: "person.2.fill") { page = .groups }
                    panelItem("备注", icon: "note.text") { page = .notes }
                    panelItem("提醒", icon: "alarm.fill")
                    panelItem("删除", icon: "trash.fill") { confirmDelete = true }
                }.padding(16)
                Button("取消") { more = false }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 50).background(.white)
            }
            .background(CardPalette.background)
        }
        .background {
            Color.black.opacity(0.48).ignoresSafeArea()
                .onTapGesture { more = false }
                .accessibilityHidden(true)
        }
    }

    private func panelItem(_ title: String, icon: String, color: Color = .secondary,
                           perform: (() -> Void)? = nil) -> some View {
        Button {
            more = false
            perform?()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 26)).foregroundStyle(color)
                    .frame(width: 58, height: 58).background(.white, in: RoundedRectangle(cornerRadius: 8))
                Text(title).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity)
        }.buttonStyle(.plain).disabled(perform == nil)
    }

    private func update(_ edit: (inout BusinessCard) -> Void) throws {
        guard var card = repository.card(id: id) else { throw CocoaError(.fileNoSuchFile) }
        edit(&card)
        card.updatedAt = .now
        try repository.save(card)
    }

    private func saveToContacts() async throws {
        guard let card = repository.card(id: id) else { return }
        let store = CNContactStore()
        do {
            guard try await store.requestAccess(for: .contacts) else {
                page = nil
                contactsDenied = true
                return
            }
            let contact = try ContactExport.save(card, in: store)
            try update { $0.contactIdentifier = contact }
            page = nil
        } catch let error as CNError where error.code == .authorizationDenied {
            page = nil
            contactsDenied = true
        }
    }

    private func prepareExport(_ card: BusinessCard) {
        do {
            exportFile = try ContactExportFile(fields: card.fields)
        } catch { self.error = "无法生成 VCF。" }
    }

    private func call(_ number: String?) {
        guard let number else { return }
        let digits = number.filter { $0.isNumber || $0 == "+" }
        if let url = URL(string: "tel:" + digits), !digits.isEmpty { openURL(url) }
    }

    private func email(_ address: String) {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        if let url = components.url { openURL(url) }
    }

    private func map(_ address: String?) {
        guard let address else { return }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: address)]
        if let url = components?.url { openURL(url) }
    }

    private func summary(_ fields: ContactFields) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 12) {
                Text(fields.name?.first.map(String.init) ?? "名")
                    .foregroundStyle(.secondary)
                    .frame(width: 58, height: 58)
                    .background(CardPalette.background, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(fields.name ?? "未命名名片").font(.headline)
                        .accessibilityIdentifier("detail-name")
                    if let jobTitle = fields.jobTitle { Text(jobTitle).foregroundStyle(.secondary) }
                    if let company = fields.company { Text(company).foregroundStyle(.secondary) }
                }
            }
            .padding(.bottom, 12)
            if let number = fields.mobile.first {
                Label(number, systemImage: "phone.fill").foregroundStyle(.secondary)
            }
            if let address = fields.address {
                Label(address, systemImage: "mappin").foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 3)
        .padding(.horizontal, 10)
        .padding(.top, 7)
        .background(alignment: .top) { CardPalette.navy.frame(height: 80) }
    }

    private func action(_ title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: Circle())
            Text(title).font(.caption)
        }
        .frame(maxWidth: .infinity)
    }

    private func field(_ value: String, label: String?, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                if let label {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func rows(_ label: String, icon: String, values: [String], identifier: String? = nil,
                      onTap: ((String) -> Void)? = nil) -> some View {
        ForEach(values.indices, id: \.self) { index in
            let value = values[index]
            Group {
                if let onTap {
                    Button { onTap(value) } label: { field(value, label: label, icon: icon) }
                        .buttonStyle(.plain)
                } else {
                    field(value, label: label, icon: icon)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityIdentifier("\(identifier ?? label)-\(index)")
        }
    }
}
