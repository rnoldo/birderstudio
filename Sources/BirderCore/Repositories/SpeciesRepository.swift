import Foundation
import GRDB

public struct SpeciesRepository: Sendable {
    private let db: BirderDatabase

    public init(database: BirderDatabase) {
        self.db = database
    }

    public func save(_ species: Species) async throws {
        try await db.write { db in
            try SpeciesRecord(from: species).upsert(db)
        }
    }

    public func saveBatch(_ species: [Species]) async throws {
        try await db.write { db in
            for s in species {
                try SpeciesRecord(from: s).upsert(db)
            }
        }
    }

    public func fetch(id: String) async throws -> Species? {
        try await db.read { db in
            try SpeciesRecord
                .filter(key: id)
                .fetchOne(db)?
                .toDomain()
        }
    }

    public func search(query: String, limit: Int = 20) async throws -> [Species] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return try await db.read { db in
            let pattern = FTS5Pattern(matchingAnyTokenIn: trimmed)
            guard let p = pattern else { return [] }
            let sql = """
                SELECT species.* FROM species
                JOIN species_fts ON species_fts.rowid = species.rowid
                WHERE species_fts MATCH ?
                ORDER BY rank
                LIMIT ?
                """
            return try SpeciesRecord
                .fetchAll(db, sql: sql, arguments: [p, limit])
                .map { $0.toDomain() }
        }
    }

    public func count() async throws -> Int {
        try await db.read { db in
            try SpeciesRecord.fetchCount(db)
        }
    }
}
