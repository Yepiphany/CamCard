import SwiftUI

struct CardDetailView: View {
    let card: BusinessCard

    var body: some View {
        let fields = card.fields
        List {
            Section {
                Text(fields.name ?? "未命名名片")
                    .font(.title2.bold())
                    .accessibilityIdentifier("detail-name")
                if let jobTitle = fields.jobTitle { Text(jobTitle) }
                if let company = fields.company { Text(company) }
            }

            Section("联系方式") {
                rows("手机", values: fields.mobile)
                rows("办公电话", values: fields.officePhone)
                rows("邮箱", values: fields.email, identifier: "email")
                rows("传真", values: fields.fax)
                if let website = fields.website {
                    LabeledContent("主页", value: website)
                }
                if let address = fields.address {
                    LabeledContent("工作地址", value: address)
                }
            }
        }
        .navigationTitle("名片详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rows(_ label: String, values: [String], identifier: String? = nil) -> some View {
        ForEach(values.indices, id: \.self) { index in
            LabeledContent(label, value: values[index])
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityValue(values[index])
                .accessibilityIdentifier("\(identifier ?? label)-\(index)")
        }
    }
}
