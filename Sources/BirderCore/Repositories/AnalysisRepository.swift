import Foundation
import GRDB

public struct AnalysisRepository: Sendable {
    private let db: BirderDatabase

    public init(database: BirderDatabase) {
        self.db = database
    }

    public func save(_ analysis: PhotoAnalysis) async throws {
        try await db.write { db in
            try PhotoAnalysisRecord(from: analysis).upsert(db)
        }
    }

    public func saveBatch(_ analyses: [PhotoAnalysis]) async throws {
        try await db.write { db in
            for a in analyses {
                try PhotoAnalysisRecord(from: a).upsert(db)
            }
        }
    }

    public func fetch(photoID: UUID) async throws -> PhotoAnalysis? {
        try await db.read { db in
            try PhotoAnalysisRecord
                .filter(key: photoID.uuidString)
                .fetchOne(db)?
                .toDomain()
        }
    }

    public func fetchBySession(_ sessionID: UUID) async throws -> [PhotoAnalysis] {
        try await db.read { db in
            let sql = """
                SELECT pa.* FROM photo_analyses pa
                JOIN photos p ON p.id = pa.photo_id
                WHERE p.session_id = ?
                ORDER BY p.captured_at ASC
                """
            return try PhotoAnalysisRecord
                .fetchAll(db, sql: sql, arguments: [sessionID.uuidString])
                .map { try $0.toDomain() }
        }
    }

    public func updateSceneGrouping(sessionID: UUID, groupings: [SceneAssignment]) async throws {
        try await db.write { db in
            for g in groupings {
                try db.execute(
                    sql: """
                        UPDATE photo_analyses
                        SET scene_id = ?, is_scene_best = ?
                        WHERE photo_id = ?
                        """,
                    arguments: [g.sceneID.uuidString, g.isBest ? 1 : 0, g.photoID.uuidString]
                )
            }
        }
    }
}

public struct SceneAssignment: Sendable, Hashable {
    public var photoID: UUID
    public var sceneID: UUID
    public var isBest: Bool

    public init(photoID: UUID, sceneID: UUID, isBest: Bool) {
        self.photoID = photoID
        self.sceneID = sceneID
        self.isBest = isBest
    }
}
