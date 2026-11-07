import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

@main
struct CheckAcceptanceModels {
    @MainActor
    static func main() throws {
        let first = ContactFields(name: "林小舟")
        let second = ContactFields(name: "林晓舟")
        let third = ContactFields(name: "李晓洲")
        var draft = first
        var details = CardName(name: first.name)
        details.nickname = "舟舟"
        details.phoneticSurname = ""
        draft.nameDetails = details
        let edited: Set<WritableKeyPath<CardName, String>> = [\.nickname, \.phoneticSurname]
        draft.refreshUnedited(from: first, with: second, preservingNameParts: edited)
        precondition(draft.name == "林晓舟")
        precondition(draft.nameDetails?.givenName == "晓舟")
        precondition(draft.nameDetails?.nickname == "舟舟")
        precondition(draft.nameDetails?.phoneticSurname == "")

        draft.nameDetails?.givenName = "晓洲"
        draft.name = draft.nameDetails?.displayName
        let protected = edited.union([\.givenName])
        draft.refreshUnedited(from: second, with: third, preservingNameParts: protected)
        precondition(draft.name == "李晓洲")
        draft.refreshUnedited(from: third, with: ContactFields(name: "李小舟"), preservingNameParts: protected)
        precondition(draft.name == "李晓洲")
        precondition(draft.nameDetails?.phoneticSurname == "")
        print("PASS: updated untouched name parts and retained explicit edits across two OCR passes")

        let payload = "CamCard synthetic QR"
        let generator = CIFilter.qrCodeGenerator()
        generator.message = Data(payload.utf8)
        let image = generator.outputImage!.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let imageWithMargin = image.composited(over: CIImage(color: .white))
            .cropped(to: image.extent.insetBy(dx: -40, dy: -40))
        let png = CIContext().pngRepresentation(of: imageWithMargin, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())!
        let decoded = try ScanProcessor.qrPayload(in: png)
        precondition(decoded == payload)
        print("PASS: decoded a synthetic QR payload on device")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = CardRepository(directory: directory)
        let card = BusinessCard(id: UUID(), fields: draft, note: "legacy note", createdAt: .now, updatedAt: .now)
        try repository.save(card)
        precondition(CardRepository(directory: directory).card(id: card.id)?.notes.first?.text == "legacy note")

        let attachment = CardNote.Attachment(kind: .photo)
        let note = CardNote(id: UUID(), text: "Meeting", date: .now,
                            visit: .init(method: .phone, outcome: "Agreed to follow up", followUp: .now),
                            attachments: [attachment])
        try repository.saveNotes([note], assets: [attachment.id: png], for: card.id)
        let reopened = CardRepository(directory: directory)
        precondition(reopened.card(id: card.id)?.notes == [note])
        precondition(reopened.noteAsset(attachment.id) == png)
        try reopened.saveNotes([], for: card.id)
        precondition(reopened.noteAsset(attachment.id) == nil)
        precondition(CardRepository(directory: directory).card(id: card.id)?.notes.isEmpty == true)
        print("PASS: legacy note, visit metadata, attachment persistence, and attachment cleanup")
    }
}
