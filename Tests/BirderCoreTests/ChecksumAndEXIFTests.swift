import Foundation
import Testing
@testable import BirderCore

@Suite("Checksum and EXIF")
struct ChecksumAndEXIFTests {
    @Test func checksumStableForSameBytes() throws {
        let tmp = URL(fileURLWithPath: "/tmp/birder-cksum-\(UUID().uuidString).bin")
        try Data(repeating: 0xAB, count: 2_500_000).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let a = try ChecksumHasher.compute(url: tmp)
        let b = try ChecksumHasher.compute(url: tmp)
        #expect(a == b)
        #expect(a.hasSuffix("-2500000"))
    }

    @Test func checksumChangesWithBytes() throws {
        let urlA = URL(fileURLWithPath: "/tmp/birder-cksum-a-\(UUID().uuidString).bin")
        let urlB = URL(fileURLWithPath: "/tmp/birder-cksum-b-\(UUID().uuidString).bin")
        try Data(repeating: 0x01, count: 100_000).write(to: urlA)
        try Data(repeating: 0x02, count: 100_000).write(to: urlB)
        defer {
            try? FileManager.default.removeItem(at: urlA)
            try? FileManager.default.removeItem(at: urlB)
        }
        let a = try ChecksumHasher.compute(url: urlA)
        let b = try ChecksumHasher.compute(url: urlB)
        #expect(a != b)
    }

    @Test func checksumHandlesFilesSmallerThanPrefix() throws {
        let tmp = URL(fileURLWithPath: "/tmp/birder-cksum-small-\(UUID().uuidString).bin")
        try Data(repeating: 0x42, count: 128).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let h = try ChecksumHasher.compute(url: tmp, prefixBytes: 1_048_576)
        #expect(h.hasSuffix("-128"))
    }

    @Test func exifExtractsFromCR3() throws {
        guard Samples.isAvailable, let url = Samples.cr3Files.first else {
            return
        }
        let meta = try EXIFExtractor.extract(from: url)
        #expect(meta.pixelSize.width > 3000)
        #expect(meta.pixelSize.height > 2000)
        #expect(meta.exif.camera.make?.lowercased().contains("canon") == true)
        #expect(meta.exif.aperture != nil)
        #expect(meta.exif.shutter != nil)
        #expect(meta.exif.focalLength != nil)
        #expect(meta.captured != nil)
        #expect(meta.uti == "com.canon.cr3-raw-image")
    }

    @Test func exifChecksumStableAcrossSamples() throws {
        guard Samples.isAvailable else { return }
        for url in Samples.cr3Files.prefix(5) {
            let a = try ChecksumHasher.compute(url: url)
            let b = try ChecksumHasher.compute(url: url)
            #expect(a == b, "checksum not stable for \(url.lastPathComponent)")
        }
    }

    @Test func exifChecksumDistinctAcrossDifferentPhotos() throws {
        guard Samples.isAvailable else { return }
        let urls = Samples.cr3Files.prefix(3)
        let hashes = try urls.map { try ChecksumHasher.compute(url: $0) }
        #expect(Set(hashes).count == hashes.count, "expected unique checksums across distinct CR3s")
    }
}
