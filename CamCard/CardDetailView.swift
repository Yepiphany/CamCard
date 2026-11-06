import SwiftUI

struct CardDetailView: View {
    let card: BusinessCard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let fields = card.fields
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("返回")
                .accessibilityIdentifier("detail-back")
                Spacer()
                Text("名片详情").font(.headline)
                Spacer()
                Image(systemName: "star")
                Image(systemName: "ellipsis").frame(width: 32)
            }
            .foregroundStyle(.white)
            .background(CardPalette.navy.ignoresSafeArea(edges: .top))

            ScrollView {
                VStack(spacing: 10) {
                    summary(fields)
                    HStack {
                        action("电话", icon: "phone.fill", color: .blue)
                        action("地址", icon: "mappin.circle.fill", color: .orange)
                        action("备注", icon: "note.text", color: .green)
                        action("编辑", icon: "pencil", color: .teal)
                    }
                    .padding(.vertical, 10)
                    .background(.white)

                    VStack(spacing: 0) {
                        field(card.groupIDs.isEmpty ? "未分组" : "分组", label: nil, icon: "person.2.fill")
                        field(card.note ?? "备注", label: nil, icon: "note.text")
                    }
                    .background(.white)

                    VStack(spacing: 0) {
                        rows("手机", icon: "phone.fill", values: fields.mobile)
                        rows("办公电话", icon: "phone.fill", values: fields.officePhone)
                        rows("工作邮箱", icon: "envelope.fill", values: fields.email, identifier: "email")
                        if let address = fields.address {
                            field(address, label: "公司地址", icon: "mappin")
                        }
                        if let company = fields.company {
                            field(company, label: "公司", icon: "building.2.fill")
                        }
                        if let website = fields.website {
                            field(website, label: "主页", icon: "globe")
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
                Label("存入通讯录", systemImage: "person.crop.rectangle").font(.caption2)
                Text("向对方递名片").frame(maxWidth: .infinity)
                    .padding(.vertical, 8).overlay(Capsule().strokeBorder(CardPalette.blue))
                Text("分享名片").frame(maxWidth: .infinity)
                    .padding(.vertical, 8).foregroundStyle(.white)
                    .background(.green, in: Capsule())
            }
            .font(.footnote)
            .foregroundStyle(CardPalette.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white)
        }
        .toolbar(.hidden, for: .navigationBar)
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

    private func rows(_ label: String, icon: String, values: [String], identifier: String? = nil) -> some View {
        ForEach(values.indices, id: \.self) { index in
            field(values[index], label: label, icon: icon)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityValue(values[index])
                .accessibilityIdentifier("\(identifier ?? label)-\(index)")
        }
    }
}
