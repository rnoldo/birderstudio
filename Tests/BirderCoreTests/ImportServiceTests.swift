import Foundation
import Testing
@testable import BirderCore

@Suite("ImportService")
struct ImportServiceTests {
    private func makeDB() throws -> BirderDatabase {
        try BirderDatabase(location: .inMemory)
    }

    private func makeStorage() throws -> StorageLocations {
        let root = URL(fileURLWithPath: "/tmp/birder-import-\(UUID().uuidString)", isDirectory: true)
        let loc = StorageLocations(root: root)
        try loc.ensureDirectoriesExist()
        return loc
    }

    private func seedSession(_ db: BirderDatabase) async throws -> UUID {
        let repo = SessionRepository(database: db)
        let session = Session(
            name: "Import Test",
            dateStart: Date(),
            dateEnd: Date()
        )
        try await repo.save(session)
        return session.id
    }

    @Test func importsThreeCR3PhotosEndToEnd() async throws {
        guard Samples.isAvailable else { return }
        let urls = Array(Samples.cr3Files.prefix(3))
        let db = try makeDB()
        let storage = try makeStorage()
        defer { try? FileManager.default.removeItem(at: storage.root) }

        let sessionID = try await seedSession(db)
        let service = ImportService(
            database: db,
            storage: storage,
            bookmarks: BookmarkStore(mode: .minimal),
            maxConcurrency: 3
        )

        var imported = 0
        var skipped = 0
        var failed = 0
        var completedTotal: (Int, Int, Int)?

        for await event in service.imports(urls: urls, sessionID: sessionID) {
            switch event {
            case .imported: imported += 1
            case .duplicateSkipped: skipped += 1
            case .failed(_, let message):
                Issue.record("import failed: \(message)")
                failed += 1
            case .started(let total):
                #expect(total == urls.count)
            case .completed(let i, let s, let f):
                completedTotal = (i, s, f)
            }
        }

        #expect(imported == urls.count)
        #expect(skipped == 0)
        #expect(failed == 0)
        #expect(completedTotal?.0 == urls.count)

        let photoRepo = PhotoRepository(database: db)
        let stored = try await photoRepo.fetchBySession(sessionID)
        #expect(stored.count == urls.count)

        for photo in stored {
            let thumb = storage.thumbnailURL(for: photo.id)
            let preview = storage.previewURL(for: photo.id)
            #expect(FileManager.default.fileExists(atPath: thumb.path), "missing thumb for \(photo.id)")
            #expect(FileManager.default.fileExists(atPath: preview.path), "missing preview for \(photo.id)")
            #expect(photo.exif.camera.make?.lowercased().contains("canon") == true)
            #expect(photo.pixelSize.width > 3000)
            #expect(photo.format == .cr3)
            #expect(!photo.checksum.isEmpty)
            #expect(photo.fileBookmark.count > 0)
        }
    }

    @Test func dedupesOnSecondImportOfSameFile() async throws {
        guard Samples.isAvailable, let url = Samples.cr3Files.first else { return }
        let db = try makeDB()
        let storage = try makeStorage()
        defer { try? FileManager.default.removeItem(at: storage.root) }

        let sessionID = try await seedSession(db)
        let service = ImportService(
            database: db,
            storage: storage,
            bookmarks: BookmarkStore(mode: .minimal),
            maxConcurrency: 2
        )

        // first run imports 1 photo
        for await event in service.imports(urls: [url], sessionID: sessionID) {
            if case .failed(_, let message) = event {
                Issue.record("first import failed: \(message)")
            }
        }

        // second run with same URL must skip
        var skipped = 0
        var imported = 0
        for await event in service.imports(urls: [url], sessionID: sessionID) {
            switch event {
            case .imported: imported += 1
            case .duplicateSkipped: skipped += 1
            default: break
            }
        }
        #expect(imported == 0)
        #expect(skipped == 1)

        let photoRepo = PhotoRepository(database: db)
        #expect(try await photoRepo.countBySession(sessionID) == 1)
    }

    @Test func reportsUnsupportedFormat() async throws {
        let db = try makeDB()
        let storage = try makeStorage()
        defer { try? FileManager.default.removeItem(at: storage.root) }

        let bogus = URL(fileURLWithPath: "/tmp/not-a-photo-\(UUID().uuidString).xyz")
        try Data("hello".utf8).write(to: bogus)
        defer { try? FileManager.default.removeItem(at: bogus) }

        let sessionID = try await seedSession(db)
        let service = ImportService(
            database: db,
            storage: storage,
            bookmarks: BookmarkStore(mode: .minimal)
        )

        var failed = 0
        for await event in service.imports(urls: [bogus], sessionID: sessionID) {
            if case .failed = event { failed += 1 }
        }
        #expect(failed == 1)
    }

    @Test func benchmark23CR3Photos() async throws {
        guard Samples.isAvailable else { return }
        let urls = Samples.cr3Files
        guard urls.count >= 10 else { return }

        let db = try makeDB()
        let storage = try makeStorage()
        defer { try? FileManager.default.removeItem(at: storage.root) }

        let sessionID = try await seedSession(db)
        let service = ImportService(
            database: db,
            storage: storage,
            bookmarks: BookmarkStore(mode: .minimal)
        )

        let start = Date()
        var imported = 0
        for await event in service.imports(urls: urls, sessionID: sessionID) {
            if case .imported = event { imported += 1 }
        }
        let elapsed = Date().timeIntervalSince(start)
        let perPhoto = elapsed / Double(urls.count) * 1000

        #expect(imported == urls.count)
        print("[BENCH] imported \(urls.count) CR3s in \(String(format: "%.2f", elapsed))s (\(String(format: "%.0f", perPhoto))ms/photo)")
        #expect(elapsed < 15.0, "import should finish under 15s for \(urls.count) CR3s, got \(elapsed)s")
    }
}
