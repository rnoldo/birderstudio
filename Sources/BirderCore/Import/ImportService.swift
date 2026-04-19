import Foundation

public final class ImportService: Sendable {
    private let storage: StorageLocations
    private let bookmarks: BookmarkStore
    private let photoRepo: PhotoRepository
    private let maxConcurrency: Int

    public init(
        database: BirderDatabase,
        storage: StorageLocations,
        bookmarks: BookmarkStore = BookmarkStore(mode: .securityScoped),
        maxConcurrency: Int? = nil
    ) {
        self.storage = storage
        self.bookmarks = bookmarks
        self.photoRepo = PhotoRepository(database: database)
        self.maxConcurrency = maxConcurrency ?? max(4, ProcessInfo.processInfo.activeProcessorCount)
    }

    /// Imports a batch of photo URLs into the given session. Events stream as
    /// each photo finishes. The stream finishes after `.completed`.
    public func imports(urls: [URL], sessionID: UUID) -> AsyncStream<ImportEvent> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let task = Task {
                await self.run(urls: urls, sessionID: sessionID, continuation: continuation)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(
        urls: [URL],
        sessionID: UUID,
        continuation: AsyncStream<ImportEvent>.Continuation
    ) async {
        try? storage.ensureDirectoriesExist()
        continuation.yield(.started(totalCount: urls.count))

        var imported = 0
        var skipped = 0
        var failed = 0

        await withTaskGroup(of: ImportResult.self) { group in
            let initial = min(urls.count, maxConcurrency)
            for i in 0..<initial {
                let url = urls[i]
                group.addTask { [self] in
                    await self.importOne(url: url, sessionID: sessionID)
                }
            }
            var next = initial
            while let result = await group.next() {
                handle(result, continuation: continuation, imported: &imported, skipped: &skipped, failed: &failed)
                if next < urls.count {
                    let url = urls[next]
                    next += 1
                    group.addTask { [self] in
                        await self.importOne(url: url, sessionID: sessionID)
                    }
                }
            }
        }

        continuation.yield(.completed(imported: imported, skipped: skipped, failed: failed))
    }

    private func importOne(url: URL, sessionID: UUID) async -> ImportResult {
        guard let format = FileFormat.from(pathExtension: url.pathExtension) else {
            return .failed(url: url, message: "unsupported format: .\(url.pathExtension)")
        }

        let checksum: String
        do {
            checksum = try ChecksumHasher.compute(url: url)
        } catch {
            return .failed(url: url, message: "checksum failed: \(error)")
        }

        do {
            if let existing = try await photoRepo.findByChecksum(checksum) {
                return .duplicate(url: url, existingPhotoID: existing.id)
            }
        } catch {
            return .failed(url: url, message: "dedup lookup failed: \(error)")
        }

        let bookmark: Data
        do {
            bookmark = try bookmarks.createBookmark(for: url)
        } catch {
            return .failed(url: url, message: "bookmark failed: \(error)")
        }

        let fileSize: Int64
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            if let n = attrs[.size] as? Int64 {
                fileSize = n
            } else if let n = attrs[.size] as? Int {
                fileSize = Int64(n)
            } else if let n = attrs[.size] as? NSNumber {
                fileSize = n.int64Value
            } else {
                return .failed(url: url, message: "stat returned no size")
            }
        } catch {
            return .failed(url: url, message: "stat failed: \(error)")
        }

        let meta: ExtractedMetadata
        do {
            meta = try EXIFExtractor.extract(from: url)
        } catch {
            return .failed(url: url, message: "exif failed: \(error)")
        }

        let photoID = UUID()
        let thumbURL = storage.thumbnailURL(for: photoID)
        let previewURL = storage.previewURL(for: photoID)

        do {
            _ = try ThumbnailGenerator.generate(source: url, output: thumbURL, options: .thumbnail)
        } catch {
            return .failed(url: url, message: "thumbnail failed: \(error)")
        }
        do {
            _ = try ThumbnailGenerator.generate(source: url, output: previewURL, options: .preview)
        } catch {
            try? FileManager.default.removeItem(at: thumbURL)
            return .failed(url: url, message: "preview failed: \(error)")
        }

        let photo = Photo(
            id: photoID,
            sessionID: sessionID,
            fileBookmark: bookmark,
            fileURLCached: url,
            checksum: checksum,
            fileSize: fileSize,
            format: format,
            captured: meta.captured ?? Date(),
            exif: meta.exif,
            pixelSize: meta.pixelSize,
            status: .imported,
            importedAt: Date()
        )

        do {
            try await photoRepo.save(photo)
        } catch {
            try? FileManager.default.removeItem(at: thumbURL)
            try? FileManager.default.removeItem(at: previewURL)
            return .failed(url: url, message: "db save failed: \(error)")
        }

        return .imported(photoID: photoID, url: url)
    }

    private func handle(
        _ result: ImportResult,
        continuation: AsyncStream<ImportEvent>.Continuation,
        imported: inout Int,
        skipped: inout Int,
        failed: inout Int
    ) {
        switch result {
        case .imported(let id, let url):
            imported += 1
            continuation.yield(.imported(photoID: id, url: url))
        case .duplicate(let url, let existing):
            skipped += 1
            continuation.yield(.duplicateSkipped(url: url, existingPhotoID: existing))
        case .failed(let url, let message):
            failed += 1
            continuation.yield(.failed(url: url, message: message))
        }
    }
}

private enum ImportResult: Sendable {
    case imported(photoID: UUID, url: URL)
    case duplicate(url: URL, existingPhotoID: UUID)
    case failed(url: URL, message: String)
}
