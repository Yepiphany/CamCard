import Contacts
import SwiftUI

enum ContactExport {
    static func website(_ value: String) -> URL? {
        let address = value.contains("://") ? value : "https://" + value
        guard let url = URL(string: address), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme), url.host != nil else { return nil }
        return url
    }

    static func vCard(_ fields: ContactFields) throws -> Data {
        let contact = CNMutableContact()
        apply(fields, to: contact)
        return try CNContactVCardSerialization.data(with: [contact])
    }

    static func save(_ card: BusinessCard, in store: CNContactStore) throws -> String {
        let request = CNSaveRequest()
        if let id = card.contactIdentifier {
            do {
                let existing = try store.unifiedContact(withIdentifier: id, keysToFetch: keys)
                guard let mutable = existing.mutableCopy() as? CNMutableContact else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                apply(card.fields, to: mutable)
                request.update(mutable)
                try store.execute(request)
                return mutable.identifier
            } catch let error as CNError where error.code == .recordDoesNotExist {
                // A contact removed outside CamCard can be created again.
            }
        }
        let contact = CNMutableContact()
        apply(card.fields, to: contact)
        request.add(contact, toContainerWithIdentifier: nil)
        try store.execute(request)
        return contact.identifier
    }

    private static var keys: [CNKeyDescriptor] {
        [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactMiddleNameKey, CNContactNamePrefixKey,
         CNContactNameSuffixKey, CNContactNicknameKey, CNContactPhoneticGivenNameKey, CNContactPhoneticFamilyNameKey,
         CNContactOrganizationNameKey, CNContactJobTitleKey, CNContactDepartmentNameKey,
         CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactUrlAddressesKey,
         CNContactPostalAddressesKey].map { $0 as CNKeyDescriptor }
    }

    private static func apply(_ fields: ContactFields, to contact: CNMutableContact) {
        contact.givenName = fields.nameDetails?.givenName ?? fields.name ?? ""
        contact.familyName = fields.nameDetails?.surname ?? ""
        contact.middleName = fields.nameDetails?.middleName ?? ""
        contact.namePrefix = fields.nameDetails?.prefix ?? ""
        contact.nameSuffix = fields.nameDetails?.suffix ?? ""
        contact.nickname = fields.nameDetails?.nickname ?? ""
        contact.phoneticGivenName = fields.nameDetails?.phoneticGivenName ?? ""
        contact.phoneticFamilyName = fields.nameDetails?.phoneticSurname ?? ""
        contact.departmentName = fields.department ?? ""
        contact.organizationName = fields.company ?? ""
        contact.jobTitle = fields.jobTitle ?? ""
        contact.phoneNumbers = phones(fields.mobile, label: CNLabelPhoneNumberMobile)
            + phones(fields.officePhone, label: CNLabelWork)
            + phones(fields.fax, label: CNLabelPhoneNumberWorkFax)
        contact.emailAddresses = fields.email.map { CNLabeledValue(label: CNLabelWork, value: $0 as NSString) }
        contact.urlAddresses = fields.website.flatMap(website).map {
            [CNLabeledValue(label: CNLabelURLAddressHomePage, value: $0.absoluteString as NSString)]
        } ?? []
        contact.postalAddresses = fields.address.map {
            let address = CNMutablePostalAddress()
            address.street = $0
            return [CNLabeledValue(label: CNLabelWork, value: address)]
        } ?? []
    }

    private static func phones(_ numbers: [String], label: String) -> [CNLabeledValue<CNPhoneNumber>] {
        numbers.map { CNLabeledValue(label: label, value: CNPhoneNumber(stringValue: $0)) }
    }
}

struct ContactExportFile: Identifiable {
    let url: URL
    var id: URL { url }

    init(fields: ContactFields) throws {
        let data = try ContactExport.vCard(fields)
        let directory = URL.documentsDirectory.appendingPathComponent("VCF", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suffix = UUID().uuidString.prefix(8)
        url = directory.appendingPathComponent("名片-\(suffix).vcf")
        try data.write(to: url, options: .atomic)
    }
}

struct ContactExportConfirmation: View {
    let file: ContactExportFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Label("已导出 VCF", systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(CardPalette.blue)
            Text(file.url.lastPathComponent).font(.subheadline)
            Text("文件 → 我的 iPhone → CamCard → VCF")
                .font(.footnote).foregroundStyle(.secondary)
            ShareLink(item: file.url) {
                Label("分享 VCF", systemImage: "square.and.arrow.up")
            }.buttonStyle(.borderedProminent)
            Button("完成") { dismiss() }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .presentationDetents([.medium])
    }
}

struct ContactsDestination: View {
    let save: () async throws -> Void
    @State private var working = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Label("iPhone", systemImage: "checkmark.circle.fill").foregroundStyle(CardPalette.blue)
            }
            .navigationTitle("保存到通讯录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(working) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        working = true
                        Task {
                            defer { working = false }
                            do { try await save() } catch { self.error = "无法保存名片到通讯录。" }
                        }
                    }.disabled(working)
                }
            }
            .managementError($error)
        }.presentationDetents([.medium]).interactiveDismissDisabled(working)
    }
}
