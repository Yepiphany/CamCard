import Foundation

enum ContactExtraction {
    static func fields(from rawText: String) -> ContactFields {
        var fields = ContactFields()
        var unclassified: [String] = []
        let lines = rawText.split(whereSeparator: \.isNewline)
        for line in lines {
            let value = line.trimmingCharacters(in: .whitespaces)
            let lower = value.lowercased()
            let emailText = value.replacingOccurrences(of: #"\s*@\s*"#, with: "@", options: .regularExpression)
            let emails = matches(#"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, in: emailText)
            if !emails.isEmpty {
                for email in emails where !fields.email.contains(where: { $0.caseInsensitiveCompare(email) == .orderedSame }) {
                    fields.email.append(email)
                }
            } else if let number = match(#"\+?\d[\d() .-]{5,}\d"#, in: value) {
                if match(#"^(?:mobile\b|cell\b|手机|手機)"#, in: value) != nil {
                    append(number, to: &fields.mobile)
                } else if match(#"^(?:office\b|tel\b|telephone\b|办公电话|電話|电话)"#, in: value) != nil {
                    append(number, to: &fields.officePhone)
                } else if match(#"^(?:fax\b|传真|傳真)"#, in: value) != nil {
                    append(number, to: &fields.fax)
                } else if isAddress(value) {
                    fields.address = fields.address ?? value
                }
            } else if !value.contains("@"), let website = match(#"(?:https?://|www\.)[^\s,，;；]+|\b[a-z0-9-]+(?:\.[a-z0-9-]+)*\.(?:example|com|org|net|cn)\b"#, in: value) {
                fields.website = fields.website ?? website
            } else if let company = labeledValue(#"^(?:company|公司)\s*[:：]\s*(.+)$"#, in: value) {
                fields.company = company
            } else if let title = labeledValue(#"^(?:title|position|职位|職位)\s*[:：]\s*(.+)$"#, in: value) {
                fields.jobTitle = title
            } else if let name = labeledValue(#"^(?:name|姓名)\s*[:：]\s*(.+)$"#, in: value) {
                fields.name = name
            } else if isAddress(value) {
                fields.address = fields.address ?? value
            } else if match(#"\b(?:director|manager|engineer|designer|lead|consultant|illustrator|photographer|planner|analyst|editor|writer|ceo)\b|总监|總監|经理|經理|工程师|工程師|设计师|設計師|顾问|顧問|编辑|編輯"#, in: value) != nil {
                fields.jobTitle = fields.jobTitle ?? value
            } else if match(#"\b(?:studio|ltd|inc|labs|consulting|fabrication|press|atelier|robotics|foundry)\b|公司|集团|集團|工作室|工坊|工房|设计$|設計$"#, in: value) != nil {
                fields.company = fields.company ?? value
            } else if !lower.hasPrefix("product:") {
                unclassified.append(value)
            }
        }
        if let first = unclassified.first,
           first == lines.first?.trimmingCharacters(in: .whitespaces),
           lines.count > 1,
           match(#"^(?:\p{Han}{2,4}|[A-Z][a-z]+(?: [A-Z][a-z]+){1,2})$"#, in: first) != nil {
            fields.name = fields.name ?? first
        }
        // Use an unlabeled organization line only with a clear name and another contact signal.
        if fields.company == nil, let name = fields.name, unclassified.count == 2,
           unclassified[0] == name,
           fields.jobTitle != nil || !fields.email.isEmpty {
            let organizationPattern = match(#"^\p{Han}+$"#, in: name) == nil
                ? #"^[A-Z][a-z]+(?: [A-Z][a-z]+){1,3}$"#
                : #"^\p{Han}{4,}$"#
            if match(organizationPattern, in: unclassified[1]) != nil {
                fields.company = unclassified[1]
            }
        }
        return fields
    }

    private static func isAddress(_ text: String) -> Bool {
        match(#"^(?:地址|address\b)|^\d+\s+.+\b(?:lane|street|road|avenue|drive|way|ln|st|rd|ave)\b|[路街道]\s*\d+\s*[号號]"#, in: text) != nil
    }

    private static func append(_ number: String, to values: inout [String]) {
        let digits = number.filter(\.isNumber)
        if !values.contains(where: { $0.filter(\.isNumber) == digits }) {
            values.append(number)
        }
    }

    private static func labeledValue(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }

    private static func match(_ pattern: String, in text: String) -> String? {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]).map { String(text[$0]) }
    }
}
