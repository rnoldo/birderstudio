import Foundation

public enum FileFormat: String, Sendable, Codable, CaseIterable {
    case cr2, cr3, nef, arw, dng, raf, orf, rw2
    case jpeg, heic, heif, tiff, png

    public var isRaw: Bool {
        switch self {
        case .cr2, .cr3, .nef, .arw, .dng, .raf, .orf, .rw2: true
        case .jpeg, .heic, .heif, .tiff, .png: false
        }
    }

    public static func from(pathExtension: String) -> FileFormat? {
        FileFormat(rawValue: pathExtension.lowercased())
    }
}

public struct CameraInfo: Sendable, Hashable, Codable {
    public var make: String?
    public var model: String?

    public init(make: String? = nil, model: String? = nil) {
        self.make = make
        self.model = model
    }

    public var isEmpty: Bool { make == nil && model == nil }
}

public struct Coordinate: Sendable, Hashable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct ShutterSpeed: Sendable, Hashable, Codable {
    public var denominator: Int

    public init(denominator: Int) {
        self.denominator = denominator
    }

    public var displayString: String { "1/\(denominator)" }
}

public struct EXIF: Sendable, Hashable, Codable {
    public var camera: CameraInfo
    public var lens: String?
    public var focalLength: Double?
    public var iso: Int?
    public var shutter: ShutterSpeed?
    public var aperture: Double?
    public var gps: Coordinate?

    public init(
        camera: CameraInfo = CameraInfo(),
        lens: String? = nil,
        focalLength: Double? = nil,
        iso: Int? = nil,
        shutter: ShutterSpeed? = nil,
        aperture: Double? = nil,
        gps: Coordinate? = nil
    ) {
        self.camera = camera
        self.lens = lens
        self.focalLength = focalLength
        self.iso = iso
        self.shutter = shutter
        self.aperture = aperture
        self.gps = gps
    }
}

public struct PixelSize: Sendable, Hashable, Codable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public var aspectRatio: Double { Double(width) / Double(height) }
    public var megapixels: Double { Double(width * height) / 1_000_000 }
}

public struct NormalizedRect: Sendable, Hashable, Codable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public static let zero = NormalizedRect(x: 0, y: 0, width: 0, height: 0)
}
