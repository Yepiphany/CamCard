import Foundation

@main
struct ScoreRecognition {
    private struct Fixtures: Decodable {
        var samples: [Sample]
    }

    private struct Sample: Decodable {
        var id: String
        var image: String
        var scoreFields: Bool
        var fields: [String: Value?]
    }

    private enum Value: Decodable {
        case text(String)
        case list([String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                self = .text(text)
            } else {
                self = .list(try container.decode([String].self))
            }
        }

        var values: [String] {
            switch self {
            case .text(let value): [value]
            case .list(let values): values
            }
        }
    }

    private struct Score {
        var correct = 0
        var present = 0
        var falsePositive = 0
        var absent = 0
    }

    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw CocoaError(.fileReadInvalidFileName, userInfo: [
                NSLocalizedDescriptionKey: "Usage: ScoreRecognition <business-cards fixture directory>"
            ])
        }
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let fixtures = try JSONDecoder().decode(
            Fixtures.self,
            from: Data(contentsOf: directory.appendingPathComponent("ground-truth.json"))
        )
        let keys = ["name", "company", "jobTitle", "mobile", "officePhone", "email", "website", "address"]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        var scores: [String: Score] = [:]
        for sample in fixtures.samples {
            var fields = ContactFields()
            do {
                let image = try ScanProcessor.decode(Data(contentsOf: directory.appendingPathComponent(sample.image)))
                let result = try ScanProcessor.recognize(original: image, source: image, accurate: false)
                fields = result.recognition.candidates
                print("\(sample.id) | languages=\(result.recognition.languages.joined(separator: ",")) | manualCrop=\(result.needsManualCrop)")
                print(String(decoding: try encoder.encode(result.recognition), as: UTF8.self))
            } catch {
                print("\(sample.id) | error=\(error.localizedDescription)")
            }
            guard sample.scoreFields else { continue }
            let actual: [String: [String]] = [
                "name": [fields.name].compactMap { $0 },
                "company": [fields.company].compactMap { $0 },
                "jobTitle": [fields.jobTitle].compactMap { $0 },
                "mobile": fields.mobile,
                "officePhone": fields.officePhone,
                "email": fields.email,
                "website": [fields.website].compactMap { $0 },
                "address": [fields.address].compactMap { $0 }
            ]
            for key in keys {
                let expected = normalize((sample.fields[key] ?? nil)?.values ?? [], key: key)
                let found = normalize(actual[key, default: []], key: key)
                if expected.isEmpty {
                    scores[key, default: Score()].absent += 1
                    if !found.isEmpty { scores[key, default: Score()].falsePositive += 1 }
                } else {
                    scores[key, default: Score()].present += 1
                    if found == expected { scores[key, default: Score()].correct += 1 }
                }
                if found != expected {
                    print("DIFF \(sample.id) \(key): \(expected.sorted()) → \(found.sorted())")
                }
            }
        }
        for key in keys {
            let score = scores[key, default: Score()]
            print("SCORE \(key) \(score.correct)/\(score.present) \(score.falsePositive)/\(score.absent)")
        }
    }

    private static func normalize(_ values: [String], key: String) -> Set<String> {
        Set(values.map { value in
            if key == "mobile" || key == "officePhone" {
                return value.filter(\.isNumber)
            }
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
                .precomposedStringWithCanonicalMapping
        })
    }
}
