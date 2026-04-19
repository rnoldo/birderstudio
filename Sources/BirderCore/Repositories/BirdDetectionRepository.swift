import Foundation
import GRDB

public struct BirdDetectionRepository: Sendable {
    private let db: BirderDatabase

    public init(database: BirderDatabase) {
        self.db = database
    }

    public func save(_ detection: BirdDetection) async throws {
        try await db.write { db in
            try BirdDetectionRecord(from: detection).upsert(db)
        }
    }

    public func saveBatch(_ detections: [BirdDetection]) async throws {
        try await db.write { db in
            for d in detections {
                try BirdDetectionRecord(from: d).upsert(db)
            }
        }
    }

    public func fetchByPhoto(_ photoID: UUID) async throws -> [BirdDetection] {
        try await db.read { db in
            try BirdDetectionRecord
                .filter(Column("photo_id") == photoID.uuidString)
                .fetchAll(db)
                .map { try $0.toDomain() }
        }
    }

    public func setSpecies(
        detectionID: UUID,
        speciesID: String?,
        confidence: Double?,
        source: SpeciesSource
    ) async throws {
        try await db.write { db in
            try db.execute(
                sql: """
                    UPDATE bird_detections
                    SET species_id = ?, species_confidence = ?, species_source = ?
                    WHERE id = ?
                    """,
                arguments: [speciesID, confidence, source.rawValue, detectionID.uuidString]
            )
        }
    }

    public func deleteAllForPhoto(_ photoID: UUID) async throws {
        _ = try await db.write { db in
            try BirdDetectionRecord
                .filter(Column("photo_id") == photoID.uuidString)
                .deleteAll(db)
        }
    }
}
