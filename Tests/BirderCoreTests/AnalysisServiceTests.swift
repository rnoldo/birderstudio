import Foundation
import Testing
@testable import BirderCore

@Suite("Analysis service")
struct AnalysisServiceTests {
    private func makeDB() throws -> BirderDatabase {
        try BirderDatabase(location: .inMemory)
    }

    private func makeStorage() throws -> StorageLocations {
        let root = URL(fileURLWithPath: "/tmp/birder-analysis-\(UUID().uuidString)", isDirectory: true)
        let loc = StorageLocations(root: root)
        try loc.ensureDirectoriesExist()
        return loc
    }

    private func seedImportedSession(db: BirderDatabase, storage: StorageLocations) async throws -> (UUID, Int) {
        let repo = SessionRepository(database: db)
        let session = Session(
            name: "Analysis Test",
            dateStart: Date(),
            dateEnd: Date(),
            createdAt: Date(timeIntervalSince1970: 1_713_000_000)
        )
        try await repo.save(session)

        let importer = ImportService(
            database: db,
            storage: storage,
            bookmarks: BookmarkStore(mode: .minimal),
            maxConcurrency: 3
        )
        let urls = Array(Samples.cr3Files.prefix(3))
        var imported = 0
        for await event in importer.imports(urls: urls, sessionID: session.id) {
            if case .imported = event { imported += 1 }
        }
        return (session.id, imported)
    }

    @Test func analyzesImportedSessionAndPersists() async throws {
        guard Samples.isAvailable, Samples.cr3Files.count >= 3 else { return }
        let db = try makeDB()
        let storage = try makeStorage()
        defer { try? FileManager.default.removeItem(at: storage.root) }

        let (sessionID, importedCount) = try await seedImportedSession(db: db, storage: storage)
        #expect(importedCount == 3)

        let service = AnalysisService(
            pipeline: SimpleAnalysisPipeline(),
            database: db,
            maxConcurrency: 2
        )

        var analyzed = 0
        var failed = 0
        var startedTotal: Int?
        var completedPair: (Int, Int)?
        for await event in service.analyze(sessionID: sessionID) {
            switch event {
            case .started(let total): startedTotal = total
            case .analyzed: analyzed += 1
            case .failed(_, let msg):
                Issue.record("analyze failed: \(msg)")
                failed += 1
            case .completed(let a, let f): completedPair = (a, f)
            }
        }
        #expect(startedTotal == 3)
        #expect(analyzed == 3)
        #expect(failed == 0)
        #expect(completedPair?.0 == 3)

        let analysisRepo = AnalysisRepository(database: db)
        let stored = try await analysisRepo.fetchBySession(sessionID)
        #expect(stored.count == 3)
        for a in stored {
            #expect(a.quality.overall >= 0.0 && a.quality.overall <= 1.0)
            #expect(a.featurePrint.count > 1000)
        }

        // Session percentiles must cover distinct values across 3 photos.
        let pcts = Set(stored.map { Int(($0.quality.sessionPercentile * 1000).rounded()) })
        #expect(pcts.count >= 2, "percentiles should vary across photos")

        // Photo status should be marked .analyzed with analyzedAt set.
        let photoRepo = PhotoRepository(database: db)
        let photos = try await photoRepo.fetchBySession(sessionID)
        for p in photos {
            #expect(p.status == .analyzed)
            #expect(p.analyzedAt != nil)
        }
    }

    @Test func reAnalyzeSkipsAlreadyAnalyzed() async throws {
        guard Samples.isAvailable, Samples.cr3Files.count >= 2 else { return }
        let db = try makeDB()
        let storage = try makeStorage()
        defer { try? FileManager.default.removeItem(at: storage.root) }

        let (sessionID, _) = try await seedImportedSession(db: db, storage: storage)
        let service = AnalysisService(
            pipeline: SimpleAnalysisPipeline(),
            database: db,
            maxConcurrency: 2
        )
        for await _ in service.analyze(sessionID: sessionID) {}

        var secondRunAnalyzed = 0
        var secondStartedTotal: Int?
        for await event in service.analyze(sessionID: sessionID) {
            switch event {
            case .started(let n): secondStartedTotal = n
            case .analyzed: secondRunAnalyzed += 1
            default: break
            }
        }
        #expect(secondStartedTotal == 0)
        #expect(secondRunAnalyzed == 0)
    }
}
