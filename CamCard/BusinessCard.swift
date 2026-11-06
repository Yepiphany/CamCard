import Foundation

struct ContactFields: Codable, Equatable {
    var name: String?
    var company: String?
    var jobTitle: String?
    var mobile: [String] = []
    var officePhone: [String] = []
    var email: [String] = []
    var website: String?
    var address: String?
    var fax: [String] = []
}

struct RecognitionRecord: Codable, Equatable {
    struct TextRegion: Codable, Equatable {
        var text: String
        var x: Double
        var y: Double
        var width: Double
        var height: Double
    }

    var languages: [String]
    var rawText: String
    var regions: [TextRegion]
    var candidates: ContactFields
    var recognizedAt: Date
}

struct BusinessCard: Identifiable, Codable, Equatable {
    let id: UUID
    var originalImagePath: String?
    var correctedImagePath: String?
    var fields: ContactFields
    var recognition: RecognitionRecord?
    var groupIDs: Set<UUID> = []
    var note: String?
    let createdAt: Date
    var updatedAt: Date
}

struct CardGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
}
