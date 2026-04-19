import Foundation
import GRDB

public struct RatingRepository: Sendable {
    private let db: BirderDatabase

    public init(database: BirderDatabase) {
        self.db = database
    }

    public func save(_ rating: PhotoRating) async throws {
        try await db.write { db in
            try PhotoRatingRecord(from: rating).upsert(db)
        }
    }

    public func fetch(photoID: UUID) async throws -> PhotoRating? {
        try await db.read { db in
            try PhotoRatingRecord
                .filter(key: photoID.uuidString)
                .fetchOne(db)?
                .toDomain()
        }
    }

    public func setDecision(photoID: UUID, decision: RatingDecision) async throws {
        let existing = try await fetch(photoID: photoID) ?? PhotoRating(photoID: photoID)
        var updated = existing
        updated.decision = decision
        updated.ratedAt = Date()
        try await save(updated)
    }

    public func setStar(photoID: UUID, star: Int) async throws {
        let existing = try await fetch(photoID: photoID) ?? PhotoRating(photoID: photoID)
        var updated = existing
        updated.star = min(max(star, 0), 5)
        updated.ratedAt = Date()
        try await save(updated)
    }

    public func delete(photoID: UUID) async throws {
        _ = try await db.write { db in
            try PhotoRatingRecord.deleteOne(db, key: photoID.uuidString)
        }
    }

    public func fetchBySession(_ sessionID: UUID) async throws -> [UUID: PhotoRating] {
        try await db.read { db in
            let sql = """
                SELECT r.* FROM photo_ratings r
                JOIN photos p ON p.id = r.photo_id
                WHERE p.session_id = ?
                """
            let records = try PhotoRatingRecord
                .fetchAll(db, sql: sql, arguments: [sessionID.uuidString])
            var map: [UUID: PhotoRating] = [:]
            for record in records {
                let rating = try record.toDomain()
                map[rating.photoID] = rating
            }
            return map
        }
    }
}
