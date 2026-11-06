import Foundation

enum ContactExtraction {
    static func fields(from rawText: String) -> ContactFields {
        var fields = ContactFields()
        var unclassified: [String] = []
        let lines = rawText.split(whereSeparator: \.isNewline)
        for line in lines {
            let value = line.trimmingCharacters(in: .whitespaces)
            let lower = value.lowercased()
            if let email = match(#"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, in: value) {
                if !fields.email.contains(email) { fields.email.append(email) }
            } else if let number = match(#"\+?\d[\d() .-]{5,}\d"#, in: value),
                      lower.hasPrefix("mobile") || lower.hasPrefix("手机") {
                if !fields.mobile.contains(number) { fields.mobile.append(number) }
            } else if let number = match(#"\+?\d[\d() .-]{5,}\d"#, in: value),
                      ["office", "tel", "电话"].contains(where: lower.hasPrefix) {
                if !fields.officePhone.contains(number) { fields.officePhone.append(number) }
            } else if let number = match(#"\+?\d[\d() .-]{5,}\d"#, in: value),
                      lower.hasPrefix("fax") || lower.hasPrefix("传真") {
                if !fields.fax.contains(number) { fields.fax.append(number) }
            } else if let website = match(#"(?:https?://|www\.)\S+|\b[a-z0-9-]+\.(?:example|com|org|net|cn)\b"#, in: value) {
                fields.website = fields.website ?? website
            } else if ["studio", " ltd", " inc", "公司", "集团", "工作室"].contains(where: lower.contains) {
                fields.company = fields.company ?? value
            } else if ["director", "manager", "engineer", "designer", "总监", "经理", "工程师", "设计师"].contains(where: lower.contains) {
                fields.jobTitle = fields.jobTitle ?? value
            } else if lower.hasPrefix("地址") || match(#"^\d+\s+.+\b(?:lane|street|road|avenue)\b"#, in: value) != nil {
                fields.address = fields.address ?? value
            } else {
                unclassified.append(value)
            }
        }
        if fields.company != nil || fields.jobTitle != nil,
           let first = unclassified.first, first == lines.first.map(String.init),
           match(#"^(?:\p{Han}{2,4}|[A-Z][a-z]+(?: [A-Z][a-z]+){1,2})$"#, in: first) != nil {
            fields.name = first
        }
        return fields
    }

    private static func match(_ pattern: String, in text: String) -> String? {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]).map { String(text[$0]) }
    }
}
