import Foundation
import GRDB

struct PhotoRatingRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "photo_ratings"

    var photoId: String
    var decision: Int
    var star: Int
    var colorLabel: Int
    var note: String?
    var ratedAt: Double

    enum CodingKeys: String, CodingKey {
        case photoId = "photo_id"
        case decision
        case star
        case colorLabel = "color_label"
        case note
        case ratedAt = "rated_at"
    }
}

extension PhotoRatingRecord {
    init(from domain: PhotoRating) {
        self.photoId = domain.photoID.uuidString
        self.decision = domain.decision.rawValue
        self.star = domain.star
        self.colorLabel = domain.colorLabel
        self.note = domain.note
        self.ratedAt = domain.ratedAt.timeIntervalSinceReferenceDate
    }

    func toDomain() throws -> PhotoRating {
        guard let photoUUID = UUID(uuidString: photoId) else {
            throw BirderDatabaseError.invalidEncoding(field: "photo_ratings.photo_id", underlying: photoId)
        }
        let decision = RatingDecision(rawValue: decision) ?? .unrated
        return PhotoRating(
            photoID: photoUUID,
            decision: decision,
            star: star,
            colorLabel: colorLabel,
            note: note,
            ratedAt: Date(timeIntervalSinceReferenceDate: ratedAt)
        )
    }
}
