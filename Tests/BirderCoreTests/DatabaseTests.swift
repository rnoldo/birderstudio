import Foundation
import Testing
@testable import BirderCore

@Suite("Database + Migration")
struct DatabaseTests {
    @Test func inMemoryDatabaseOpensAndMigrates() throws {
        let db = try BirderDatabase(location: .inMemory)
        _ = db
    }

    @Test func migrationCreatesAllExpectedTables() async throws {
        let db = try BirderDatabase(location: .inMemory)
        let tables: [String] = try await db.read { grdb in
            try String.fetchAll(
                grdb,
                sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
            )
        }
        let expected: Set<String> = [
            "sessions", "photos", "photo_analyses", "bird_detections",
            "species", "photo_ratings", "edits", "projects", "project_photos"
        ]
        for table in expected {
            #expect(tables.contains(table), "missing table \(table); got \(tables)")
        }
    }

    @Test func ftsVirtualTableIsQueryable() async throws {
        let db = try BirderDatabase(location: .inMemory)
        let count: Int = try await db.read { grdb in
            try Int.fetchOne(grdb, sql: "SELECT COUNT(*) FROM species_fts") ?? -1
        }
        #expect(count == 0)
    }
}
