import Foundation

public struct StorageLocations: Sendable, Equatable {
    public let root: URL
    public let databaseURL: URL
    public let thumbnailsDir: URL
    public let previewsDir: URL

    public init(root: URL) {
        self.root = root
        self.databaseURL = root.appendingPathComponent("db.sqlite", isDirectory: false)
        self.thumbnailsDir = root.appendingPathComponent("thumbs", isDirectory: true)
        self.previewsDir = root.appendingPathComponent("previews", isDirectory: true)
    }

    public static func userDefault(fileManager: FileManager = .default) throws -> StorageLocations {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = appSupport.appendingPathComponent("BirderStudio", isDirectory: true)
        return StorageLocations(root: root)
    }

    public func thumbnailURL(for photoID: UUID) -> URL {
        thumbnailsDir.appendingPathComponent(photoID.uuidString + ".heic", isDirectory: false)
    }

    public func previewURL(for photoID: UUID) -> URL {
        previewsDir.appendingPathComponent(photoID.uuidString + ".heic", isDirectory: false)
    }

    public func ensureDirectoriesExist(fileManager: FileManager = .default) throws {
        for url in [root, thumbnailsDir, previewsDir] {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
