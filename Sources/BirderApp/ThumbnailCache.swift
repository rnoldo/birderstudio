import AppKit
import Foundation

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache: NSCache<NSString, NSImage>

    private init() {
        cache = NSCache<NSString, NSImage>()
        cache.countLimit = 500
    }

    func image(at url: URL) async -> NSImage? {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let data = await Self.readData(at: url)
        guard let data, let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    private static func readData(at url: URL) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            try? Data(contentsOf: url)
        }.value
    }
}
