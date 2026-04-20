import Foundation
import GRDB

public struct PhotoRepository: Sendable {
    private let db: BirderDatabase

    public init(database: BirderDatabase) {
        self.db = database
    }

    public func save(_ photo: Photo) async throws {
        try await db.write { db in
            try PhotoRecord(from: photo).upsert(db)
        }
    }

    public func saveBatch(_ photos: [Photo]) async throws {
        try await db.write { db in
            for photo in photos {
                try PhotoRecord(from: photo).upsert(db)
            }
        }
    }

    public func fetch(id: UUID) async throws -> Photo? {
        try await db.read { db in
            try PhotoRecord
                .filter(key: id.uuidString)
                .fetchOne(db)?
                .toDomain()
        }
    }

    public func fetchBySession(_ sessionID: UUID) async throws -> [Photo] {
        try await db.read { db in
            try PhotoRecord
                .filter(Column("session_id") == sessionID.uuidString)
                .order(Column("captured_at").asc)
                .fetchAll(db)
                .map { try $0.toDomain() }
        }
    }

    public func findByChecksum(_ checksum: String) async throws -> Photo? {
        try await db.read { db in
            try PhotoRecord
                .filter(Column("checksum") == checksum)
                .fetchOne(db)?
                .toDomain()
        }
    }

    public func updateStatus(id: UUID, status: ProcessingStatus, analyzedAt: Date? = nil) async throws {
        try await db.write { db in
            var record = try PhotoRecord.filter(key: id.uuidString).fetchOne(db)
            guard var r = record else { return }
            r.status = status.rawValue
            if let date = analyzedAt {
                r.analyzedAt = date.timeIntervalSinceReferenceDate
            }
            try r.update(db)
            record = r
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await db.write { db in
            try PhotoRecord.deleteOne(db, key: id.uuidString)
        }
    }

    public func countBySession(_ sessionID: UUID) async throws -> Int {
        try await db.read { db in
            try PhotoRecord
                .filter(Column("session_id") == sessionID.uuidString)
                .fetchCount(db)
        }
    }

    public func observeBySession(_ sessionID: UUID) -> AsyncValueObservation<[Photo]> {
        ValueObservation
            .tracking { db -> [Photo] in
                try PhotoRecord
                    .filter(Column("session_id") == sessionID.uuidString)
                    .order(Column("captured_at").asc)
                    .fetchAll(db)
                    .map { try $0.toDomain() }
            }
            .values(in: db.reader)
    }
}
