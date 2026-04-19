import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

public enum ThumbnailError: Error, Sendable {
    case cannotOpenSource(path: String)
    case thumbnailCreationFailed(path: String)
    case destinationCreationFailed(path: String)
    case encodingFailed(path: String)
}

public struct ThumbnailOptions: Sendable, Equatable {
    public var maxPixelSize: Int
    public var compressionQuality: Double
    public var applyTransform: Bool
    public var forceFullDecode: Bool

    public init(
        maxPixelSize: Int,
        compressionQuality: Double = 0.82,
        applyTransform: Bool = true,
        forceFullDecode: Bool = false
    ) {
        self.maxPixelSize = maxPixelSize
        self.compressionQuality = compressionQuality
        self.applyTransform = applyTransform
        self.forceFullDecode = forceFullDecode
    }

    public static let thumbnail = ThumbnailOptions(maxPixelSize: 256)
    public static let preview = ThumbnailOptions(maxPixelSize: 1200)
}

public struct GeneratedThumbnail: Sendable, Equatable {
    public let pixelSize: PixelSize
    public let bytesWritten: Int
}

public enum ThumbnailGenerator {
    /// Decodes an embedded thumbnail or preview from `source` and encodes it as
    /// HEIC at `output`. Must run off the main actor — the ImageIO operations
    /// block while decoding.
    public static func generate(
        source: URL,
        output: URL,
        options: ThumbnailOptions
    ) throws -> GeneratedThumbnail {
        guard let src = CGImageSourceCreateWithURL(source as CFURL, nil) else {
            throw ThumbnailError.cannotOpenSource(path: source.path)
        }

        var imageOpts: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: options.maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: options.applyTransform,
        ]
        if options.forceFullDecode {
            imageOpts[kCGImageSourceCreateThumbnailFromImageAlways] = true
        } else {
            imageOpts[kCGImageSourceCreateThumbnailFromImageIfAbsent] = true
        }

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(src, 0, imageOpts as CFDictionary) else {
            throw ThumbnailError.thumbnailCreationFailed(path: source.path)
        }

        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard let dest = CGImageDestinationCreateWithURL(
            output as CFURL,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            throw ThumbnailError.destinationCreationFailed(path: output.path)
        }

        let destProps: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: options.compressionQuality
        ]
        CGImageDestinationAddImage(dest, cgImage, destProps as CFDictionary)

        guard CGImageDestinationFinalize(dest) else {
            throw ThumbnailError.encodingFailed(path: output.path)
        }

        let size = PixelSize(width: cgImage.width, height: cgImage.height)
        let bytes = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int) ?? 0
        return GeneratedThumbnail(pixelSize: size, bytesWritten: bytes)
    }
}
