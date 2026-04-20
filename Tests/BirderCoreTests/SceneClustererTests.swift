import Foundation
import Testing
@testable import BirderCore

@Suite("Scene clusterer")
struct SceneClustererTests {
    private func inputAt(_ seconds: TimeInterval, quality: Double, print: Data) -> SceneClusterer.Input {
        SceneClusterer.Input(
            photoID: UUID(),
            captured: Date(timeIntervalSinceReferenceDate: seconds),
            quality: quality,
            featurePrint: print
        )
    }

    @Test func splitsOnLongTimeGap() throws {
        guard Samples.isAvailable, Samples.cr3Files.count >= 2 else { return }
        let pipeline = SimpleAnalysisPipeline()
        let a = try pipeline.analyze(photoID: UUID(), imageURL: Samples.cr3Files[0])
        let b = try pipeline.analyze(photoID: UUID(), imageURL: Samples.cr3Files[1])

        // Two pairs, each within 1s, gap of 600s between pairs → 2 scenes.
        let inputs: [SceneClusterer.Input] = [
            inputAt(0, quality: 0.3, print: a.featurePrint),
            inputAt(0.5, quality: 0.7, print: a.featurePrint),
            inputAt(600, quality: 0.6, print: b.featurePrint),
            inputAt(600.5, quality: 0.4, print: b.featurePrint),
        ]
        let clusterer = SceneClusterer(timeGapSeconds: 10, maxFeatureDistance: 1.0)
        let result = clusterer.cluster(inputs)
        #expect(result.count == 4)

        let uniqueScenes = Set(result.map(\.sceneID))
        #expect(uniqueScenes.count == 2, "expected 2 scenes, got \(uniqueScenes.count)")

        let bestCount = result.filter(\.isBest).count
        #expect(bestCount == 2, "one best per scene")
    }

    @Test func emptyInputReturnsEmpty() {
        let result = SceneClusterer().cluster([])
        #expect(result.isEmpty)
    }

    @Test func serviceWritesSceneGroupingForImportedPhotos() async throws {
        guard Samples.isAvailable, Samples.cr3Files.count >= 3 else { return }
        let db = try BirderDatabase(location: .inMemory)
        let storageRoot = URL(fileURLWithPath: "/tmp/birder-scene-\(UUID().uuidString)", isDirectory: true)
        let storage = StorageLocations(root: storageRoot)
        try storage.ensureDirectoriesExist()
        defer { try? FileManager.default.removeItem(at: storageRoot) }

        let sessionRepo = SessionRepository(database: db)
        let session = Session(
            name: "Scene Test",
            dateStart: Date(),
            dateEnd: Date(),
            createdAt: Date(timeIntervalSince1970: 1_713_000_000)
        )
        try await sessionRepo.save(session)

        let importer = ImportService(
            database: db, storage: storage,
            bookmarks: BookmarkStore(mode: .minimal),
            maxConcurrency: 3
        )
        for await _ in importer.imports(urls: Array(Samples.cr3Files.prefix(3)), sessionID: session.id) {}

        let service = AnalysisService(
            pipeline: SimpleAnalysisPipeline(),
            database: db,
            maxConcurrency: 2
        )
        for await _ in service.analyze(sessionID: session.id) {}

        let analysisRepo = AnalysisRepository(database: db)
        let stored = try await analysisRepo.fetchBySession(session.id)
        #expect(stored.count == 3)
        #expect(stored.allSatisfy { $0.sceneID != nil }, "scene IDs must be assigned")
        let bestCount = stored.filter(\.isSceneBest).count
        let sceneCount = Set(stored.compactMap(\.sceneID)).count
        #expect(bestCount == sceneCount, "one best per scene")
    }
}
