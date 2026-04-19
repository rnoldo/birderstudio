import Foundation

public enum RatingDecision: Int, Sendable, Codable, CaseIterable {
    case rejected = -1
    case unrated = 0
    case accepted = 1
}

public struct PhotoRating: Identifiable, Sendable, Hashable, Codable {
    public var id: UUID { photoID }
    public var photoID: UUID
    public var decision: RatingDecision
    public var star: Int
    public var colorLabel: Int
    public var note: String?
    public var ratedAt: Date

    public init(
        photoID: UUID,
        decision: RatingDecision = .unrated,
        star: Int = 0,
        colorLabel: Int = 0,
        note: String? = nil,
        ratedAt: Date = Date()
    ) {
        self.photoID = photoID
        self.decision = decision
        self.star = min(max(star, 0), 5)
        self.colorLabel = min(max(colorLabel, 0), 7)
        self.note = note
        self.ratedAt = ratedAt
    }
}
