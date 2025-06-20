import Foundation

struct Video: Identifiable, Hashable { // Added Hashable for potential use in lists/diffing
    let id: UUID
    var url: URL
    var date: Date
    var thumbnailURL: URL? // Optional: for a separately generated thumbnail image

    // Conformance to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // Conformance to Equatable (implied by Hashable, but good to be explicit if needed elsewhere)
    static func == (lhs: Video, rhs: Video) -> Bool {
        lhs.id == rhs.id
    }

    // Initializer
    init(id: UUID = UUID(), url: URL, date: Date, thumbnailURL: URL? = nil) {
        self.id = id
        self.url = url
        self.date = date
        self.thumbnailURL = thumbnailURL
    }
}
