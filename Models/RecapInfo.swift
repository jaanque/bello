import Foundation

enum RecapType: String, Codable {
    case weekly
    case monthly
}

struct RecapInfo: Identifiable, Hashable {
    let id: UUID
    var url: URL
    var title: String
    var type: RecapType
    var thumbnailURL: URL? // For future thumbnail display

    init(id: UUID = UUID(), url: URL, title: String, type: RecapType, thumbnailURL: URL? = nil) {
        self.id = id
        self.url = url
        self.title = title
        self.type = type
        self.thumbnailURL = thumbnailURL
    }

    // Conformances for Hashable and Equatable (Identifiable implies Equatable on id)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RecapInfo, rhs: RecapInfo) -> Bool {
        lhs.id == rhs.id
    }
}
