import Foundation
import Testing
@testable import BirderCore

@Suite("Storage and Bookmarks")
struct StorageAndBookmarkTests {
    @Test func storageLocationsResolvesPaths() {
        let root = URL(fileURLWithPath: "/tmp/birder-test-\(UUID().uuidString)", isDirectory: true)
        let loc = StorageLocations(root: root)
        let id = UUID()

        #expect(loc.databaseURL.lastPathComponent == "db.sqlite")
        #expect(loc.thumbnailsDir.lastPathComponent == "thumbs")
        #expect(loc.previewsDir.lastPathComponent == "previews")
        #expect(loc.thumbnailURL(for: id).pathExtension == "heic")
        #expect(loc.previewURL(for: id).pathExtension == "heic")
        #expect(loc.thumbnailURL(for: id).lastPathComponent.hasPrefix(id.uuidString))
    }

    @Test func storageLocationsCreatesDirectories() throws {
        let root = URL(fileURLWithPath: "/tmp/birder-test-\(UUID().uuidString)", isDirectory: true)
        let loc = StorageLocations(root: root)
        try loc.ensureDirectoriesExist()
        defer { try? FileManager.default.removeItem(at: root) }

        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: loc.thumbnailsDir.path, isDirectory: &isDir))
        #expect(isDir.boolValue)
        #expect(FileManager.default.fileExists(atPath: loc.previewsDir.path, isDirectory: &isDir))
        #expect(isDir.boolValue)
    }

    @Test func bookmarkRoundtripMinimal() throws {
        let tmp = try writeSampleFile()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let store = BookmarkStore(mode: .minimal)
        let data = try store.createBookmark(for: tmp)
        #expect(!data.isEmpty)

        let (resolved, isStale) = try store.resolve(data)
        #expect(resolved.standardizedFileURL == tmp.standardizedFileURL)
        #expect(!isStale)

        let contents = try store.withScopedAccess(to: data) { url in
            try Data(contentsOf: url)
        }
        #expect(contents == Data("hi".utf8))
    }

    private func writeSampleFile() throws -> URL {
        let url = URL(fileURLWithPath: "/tmp/birder-bookmark-\(UUID().uuidString).txt")
        try Data("hi".utf8).write(to: url)
        return url
    }
}
