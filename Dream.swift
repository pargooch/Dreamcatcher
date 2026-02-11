import Foundation

struct Dream: Identifiable, Codable {
    let id: UUID
    var originalText: String
    var rewrittenText: String?
    var tone: String?
    var date: Date
    var generatedImages: [GeneratedDreamImage]?
    var imageStyle: String?

    init(originalText: String) {
        self.id = UUID()
        self.originalText = originalText
        self.rewrittenText = nil
        self.tone = nil
        self.date = Date()
        self.generatedImages = nil
        self.imageStyle = nil
    }

    var hasImages: Bool {
        guard let images = generatedImages else { return false }
        return !images.isEmpty
    }

    var sortedImages: [GeneratedDreamImage] {
        (generatedImages ?? []).sorted { $0.sequenceIndex < $1.sequenceIndex }
    }
}
