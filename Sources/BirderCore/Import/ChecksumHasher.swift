import Foundation
import CryptoKit

public enum ChecksumError: Error, Sendable {
    case cannotOpen(path: String)
    case readFailed(path: String)
}

public enum ChecksumHasher {
    public static let defaultPrefixBytes: Int = 1_048_576

    /// Computes a content-addressable checksum as
    /// `<sha256(first-N-bytes)>-<file-size>`. This is the dedup key Birder
    /// uses — full bytes is wasteful for 25MB RAWs, yet first-1MB of a CR3
    /// already covers header + embedded JPEG preview and has per-capture
    /// entropy (timestamp, sensor readout).
    public static func compute(
        url: URL,
        prefixBytes: Int = defaultPrefixBytes
    ) throws -> String {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw ChecksumError.cannotOpen(path: url.path)
        }
        defer { try? handle.close() }

        let size = try handle.seekToEnd()
        try handle.seek(toOffset: 0)
        let readSize = UInt64(prefixBytes)
        let chunk = try handle.read(upToCount: Int(min(readSize, size))) ?? Data()
        let digest = SHA256.hash(data: chunk)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "\(hex)-\(size)"
    }
}
