import Foundation
import Testing
@testable import BirderCore

@Suite("Thumbnail generation")
struct ThumbnailTests {
    @Test func thumbnailFromCR3Embedded() throws {
        guard Samples.isAvailable, let src = Samples.cr3Files.first else { return }
        let out = URL(fileURLWithPath: "/tmp/birder-thumb-\(UUID().uuidString).heic")
        defer { try? FileManager.default.removeItem(at: out) }

        let result = try ThumbnailGenerator.generate(
            source: src,
            output: out,
            options: .thumbnail
        )
        #expect(result.pixelSize.width <= 256)
        #expect(result.pixelSize.height <= 256)
        #expect(result.pixelSize.width > 0 && result.pixelSize.height > 0)
        #expect(result.bytesWritten > 500)
        #expect(FileManager.default.fileExists(atPath: out.path))
    }

    @Test func previewFromCR3Embedded() throws {
        guard Samples.isAvailable, let src = Samples.cr3Files.first else { return }
        let out = URL(fileURLWithPath: "/tmp/birder-preview-\(UUID().uuidString).heic")
        defer { try? FileManager.default.removeItem(at: out) }

        let result = try ThumbnailGenerator.generate(
            source: src,
            output: out,
            options: .preview
        )
        #expect(result.pixelSize.width <= 1200)
        #expect(result.pixelSize.height <= 1200)
        #expect(result.pixelSize.width > 500)
        #expect(result.bytesWritten > 5000)
    }

    @Test func thumbnailFailsGracefullyOnMissingFile() {
        let bogus = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).cr3")
        let out = URL(fileURLWithPath: "/tmp/out-\(UUID().uuidString).heic")
        #expect(throws: (any Error).self) {
            _ = try ThumbnailGenerator.generate(source: bogus, output: out, options: .thumbnail)
        }
    }
}
