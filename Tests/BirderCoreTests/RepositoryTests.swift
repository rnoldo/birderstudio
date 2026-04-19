import Foundation
import Testing
@testable import BirderCore

@Suite("Repository CRUD")
struct RepositoryTests {
    private func freshDB() throws -> BirderDatabase {
        try BirderDatabase(location: .inMemory)
    }

    private func makeSession() -> Session {
        Session(
            name: "Bolsa Chica 2026-04",
            locationName: "Bolsa Chica Ecological Reserve",
            locationCoordinate: Coordinate(latitude: 33.69, longitude: -118.04),
            dateStart: Date(timeIntervalSince1970: 1_712_000_000),
            dateEnd: Date(timeIntervalSince1970: 1_712_020_000)
        )
    }

    private func makePhoto(sessionID: UUID) -> Photo {
        Photo(
            sessionID: sessionID,
            fileBookmark: Data([0x01]),
            fileURLCached: URL(fileURLWithPath: "/tmp/a.cr3"),
            checksum: UUID().uuidString,
            fileSize: 20_000_000,
            format: .cr3,
            captured: Date(timeIntervalSince1970: 1_712_010_000),
            exif: EXIF(
                camera: CameraInfo(make: "Sony", model: "A1"),
                iso: 800,
                shutter: ShutterSpeed(denominator: 2000),
                aperture: 5.6
            ),
            pixelSize: PixelSize(width: 9504, height: 6336)
        )
    }

    @Test func sessionCrudRoundtrip() async throws {
        let db = try freshDB()
        let repo = SessionRepository(database: db)
        let original = makeSession()

        try await repo.save(original)
        let fetched = try await repo.fetch(id: original.id)
        #expect(fetched == original)

        let all = try await repo.all()
        #expect(all.count == 1)

        try await repo.delete(id: original.id)
        let afterDelete = try await repo.fetch(id: original.id)
        #expect(afterDelete == nil)
    }

    @Test func photoCrudAndSessionRelation() async throws {
        let db = try freshDB()
        let sessionRepo = SessionRepository(database: db)
        let photoRepo = PhotoRepository(database: db)

        let session = makeSession()
        try await sessionRepo.save(session)

        let photos = (0..<3).map { _ in makePhoto(sessionID: session.id) }
        try await photoRepo.saveBatch(photos)

        let bySession = try await photoRepo.fetchBySession(session.id)
        #expect(bySession.count == 3)

        let sample = photos[0]
        let fetched = try await photoRepo.fetch(id: sample.id)
        #expect(fetched == sample)

        let count = try await photoRepo.countBySession(session.id)
        #expect(count == 3)
    }

    @Test func photoCascadesOnSessionDelete() async throws {
        let db = try freshDB()
        let sessionRepo = SessionRepository(database: db)
        let photoRepo = PhotoRepository(database: db)

        let session = makeSession()
        try await sessionRepo.save(session)
        let photo = makePhoto(sessionID: session.id)
        try await photoRepo.save(photo)

        try await sessionRepo.delete(id: session.id)

        let after = try await photoRepo.fetch(id: photo.id)
        #expect(after == nil)
    }

    @Test func findByChecksum() async throws {
        let db = try freshDB()
        let sessionRepo = SessionRepository(database: db)
        let photoRepo = PhotoRepository(database: db)

        let session = makeSession()
        try await sessionRepo.save(session)
        let photo = makePhoto(sessionID: session.id)
        try await photoRepo.save(photo)

        let found = try await photoRepo.findByChecksum(photo.checksum)
        #expect(found?.id == photo.id)

        let notFound = try await photoRepo.findByChecksum("does-not-exist")
        #expect(notFound == nil)
    }

    @Test func analysisCrudAndSceneGrouping() async throws {
        let db = try freshDB()
        let sessionRepo = SessionRepository(database: db)
        let photoRepo = PhotoRepository(database: db)
        let analysisRepo = AnalysisRepository(database: db)

        let session = makeSession()
        try await sessionRepo.save(session)
        let photos = (0..<3).map { _ in makePhoto(sessionID: session.id) }
        try await photoRepo.saveBatch(photos)

        let sceneID = UUID()
        let analyses = photos.enumerated().map { index, photo in
            PhotoAnalysis(
                photoID: photo.id,
                quality: QualityScores(
                    overall: Double(index + 1) * 0.3,
                    sharpness: 0.8,
                    exposure: 0.7,
                    sessionPercentile: Double(index) / 2.0
                ),
                featurePrint: Data(repeating: UInt8(index), count: 32),
                sceneID: sceneID,
                isSceneBest: index == 2
            )
        }
        try await analysisRepo.saveBatch(analyses)

        let bySession = try await analysisRepo.fetchBySession(session.id)
        #expect(bySession.count == 3)

        let best = bySession.filter { $0.isSceneBest }
        #expect(best.count == 1)
        #expect(best.first?.photoID == photos[2].id)
    }

    @Test func birdDetectionLifecycle() async throws {
        let db = try freshDB()
        let sessionRepo = SessionRepository(database: db)
        let photoRepo = PhotoRepository(database: db)
        let detectionRepo = BirdDetectionRepository(database: db)
        let speciesRepo = SpeciesRepository(database: db)

        let session = makeSession()
        try await sessionRepo.save(session)
        let photo = makePhoto(sessionID: session.id)
        try await photoRepo.save(photo)
        try await speciesRepo.save(
            Species(id: "mallar3", commonNameEN: "Mallard",
                    scientificName: "Anas platyrhynchos")
        )

        let detections = (0..<2).map { i in
            BirdDetection(
                photoID: photo.id,
                bbox: NormalizedRect(x: Double(i) * 0.3, y: 0.2, width: 0.2, height: 0.3),
                confidence: 0.9 - Double(i) * 0.1
            )
        }
        try await detectionRepo.saveBatch(detections)

        let fetched = try await detectionRepo.fetchByPhoto(photo.id)
        #expect(fetched.count == 2)

        let firstID = detections[0].id
        try await detectionRepo.setSpecies(
            detectionID: firstID,
            speciesID: "mallar3",
            confidence: 0.88,
            source: .ml
        )
        let updated = try await detectionRepo.fetchByPhoto(photo.id).first { $0.id == firstID }
        #expect(updated?.speciesID == "mallar3")
        #expect(updated?.speciesSource == .ml)
    }

    @Test func speciesSearchFTS() async throws {
        let db = try freshDB()
        let repo = SpeciesRepository(database: db)
        let entries = [
            Species(id: "norcar", commonNameEN: "Northern Cardinal", commonNameZH: "主红雀",
                    scientificName: "Cardinalis cardinalis"),
            Species(id: "mallar3", commonNameEN: "Mallard", commonNameZH: "绿头鸭",
                    scientificName: "Anas platyrhynchos"),
            Species(id: "cangoo", commonNameEN: "Canada Goose", commonNameZH: "加拿大黑雁",
                    scientificName: "Branta canadensis")
        ]
        try await repo.saveBatch(entries)

        let count = try await repo.count()
        #expect(count == 3)

        let cardResults = try await repo.search(query: "cardinal")
        #expect(cardResults.contains { $0.id == "norcar" })

        let chineseResults = try await repo.search(query: "绿头鸭")
        #expect(chineseResults.contains { $0.id == "mallar3" })

        let latinResults = try await repo.search(query: "Branta")
        #expect(latinResults.contains { $0.id == "cangoo" })

        let emptyResults = try await repo.search(query: "")
        #expect(emptyResults.isEmpty)
    }

    @Test func ratingCrudAndDecisionFlow() async throws {
        let db = try freshDB()
        let sessionRepo = SessionRepository(database: db)
        let photoRepo = PhotoRepository(database: db)
        let ratingRepo = RatingRepository(database: db)

        let session = makeSession()
        try await sessionRepo.save(session)
        let photo = makePhoto(sessionID: session.id)
        try await photoRepo.save(photo)

        try await ratingRepo.setDecision(photoID: photo.id, decision: .accepted)
        var fetched = try await ratingRepo.fetch(photoID: photo.id)
        #expect(fetched?.decision == .accepted)

        try await ratingRepo.setStar(photoID: photo.id, star: 4)
        fetched = try await ratingRepo.fetch(photoID: photo.id)
        #expect(fetched?.star == 4)
        #expect(fetched?.decision == .accepted)

        try await ratingRepo.delete(photoID: photo.id)
        fetched = try await ratingRepo.fetch(photoID: photo.id)
        #expect(fetched == nil)
    }
}
