import Foundation
import GRDB

public struct SessionRepository: Sendable {
    private let db: BirderDatabase

    public init(database: BirderDatabase) {
        self.db = database
    }

    public func save(_ session: Session) async throws {
        try await db.write { db in
            try SessionRecord(from: session).upsert(db)
        }
    }

    public func fetch(id: UUID) async throws -> Session? {
        try await db.read { db in
            try SessionRecord
                .filter(key: id.uuidString)
                .fetchOne(db)?
                .toDomain()
        }
    }

    public func all() async throws -> [Session] {
        try await db.read { db in
            try SessionRecord
                .order(Column("date_start").desc)
                .fetchAll(db)
                .map { try $0.toDomain() }
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await db.write { db in
            try SessionRecord.deleteOne(db, key: id.uuidString)
        }
    }

    public func observeAll() -> AsyncValueObservation<[Session]> {
        ValueObservation
            .tracking { db -> [Session] in
                try SessionRecord
                    .order(Column("date_start").desc)
                    .fetchAll(db)
                    .map { try $0.toDomain() }
            }
            .values(in: db.reader)
    }
}
