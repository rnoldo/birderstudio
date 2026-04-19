import Foundation

public struct CropParams: Sendable, Hashable, Codable {
    public var rect: NormalizedRect
    public var rotation: Double
    public var aspectLocked: Bool

    public init(rect: NormalizedRect, rotation: Double = 0, aspectLocked: Bool = false) {
        self.rect = rect
        self.rotation = rotation
        self.aspectLocked = aspectLocked
    }
}

public struct ExposureParams: Sendable, Hashable, Codable {
    public var ev: Double
    public var highlights: Double
    public var shadows: Double
    public var whites: Double
    public var blacks: Double

    public init(ev: Double = 0, highlights: Double = 0, shadows: Double = 0, whites: Double = 0, blacks: Double = 0) {
        self.ev = ev
        self.highlights = highlights
        self.shadows = shadows
        self.whites = whites
        self.blacks = blacks
    }
}

public struct WhiteBalanceParams: Sendable, Hashable, Codable {
    public var temperature: Double
    public var tint: Double

    public init(temperature: Double = 0, tint: Double = 0) {
        self.temperature = temperature
        self.tint = tint
    }
}

public struct SharpenParams: Sendable, Hashable, Codable {
    public var amount: Double
    public var radius: Double
    public var featherAware: Bool

    public init(amount: Double = 0, radius: Double = 1.0, featherAware: Bool = false) {
        self.amount = amount
        self.radius = radius
        self.featherAware = featherAware
    }
}

public struct DenoiseParams: Sendable, Hashable, Codable {
    public var luminance: Double
    public var color: Double

    public init(luminance: Double = 0, color: Double = 0) {
        self.luminance = luminance
        self.color = color
    }
}

public struct VibranceParams: Sendable, Hashable, Codable {
    public var saturation: Double
    public var vibrance: Double

    public init(saturation: Double = 0, vibrance: Double = 0) {
        self.saturation = saturation
        self.vibrance = vibrance
    }
}

public struct VignetteParams: Sendable, Hashable, Codable {
    public var amount: Double
    public var feather: Double
    public var subjectAware: Bool

    public init(amount: Double = 0, feather: Double = 0.5, subjectAware: Bool = false) {
        self.amount = amount
        self.feather = feather
        self.subjectAware = subjectAware
    }
}

public struct EyeBrightenParams: Sendable, Hashable, Codable {
    public var amount: Double

    public init(amount: Double = 0) {
        self.amount = amount
    }
}

public struct BackgroundBlurParams: Sendable, Hashable, Codable {
    public var amount: Double
    public var subjectMask: Data?

    public init(amount: Double = 0, subjectMask: Data? = nil) {
        self.amount = amount
        self.subjectMask = subjectMask
    }
}

public struct WatermarkParams: Sendable, Hashable, Codable {
    public enum Position: String, Sendable, Codable {
        case topLeft, topRight, bottomLeft, bottomRight, custom
    }
    public var text: String?
    public var imageIdentifier: String?
    public var position: Position
    public var opacity: Double
    public var smartAvoidance: Bool

    public init(
        text: String? = nil,
        imageIdentifier: String? = nil,
        position: Position = .bottomRight,
        opacity: Double = 0.75,
        smartAvoidance: Bool = true
    ) {
        self.text = text
        self.imageIdentifier = imageIdentifier
        self.position = position
        self.opacity = opacity
        self.smartAvoidance = smartAvoidance
    }
}

public struct PresetApplication: Sendable, Hashable, Codable {
    public var presetID: String
    public var strength: Double

    public init(presetID: String, strength: Double = 1.0) {
        self.presetID = presetID
        self.strength = strength
    }
}

public struct OverlayLayer: Sendable, Hashable, Codable {
    public enum Kind: String, Sendable, Codable {
        case speciesLabel, exifBadge, arrow, text, shape
    }
    public var id: UUID
    public var kind: Kind
    public var payload: [String: String]
    public var position: NormalizedRect

    public init(id: UUID = UUID(), kind: Kind, payload: [String: String] = [:], position: NormalizedRect) {
        self.id = id
        self.kind = kind
        self.payload = payload
        self.position = position
    }
}

public struct EditGraph: Sendable, Hashable, Codable {
    public let version: Int
    public var crop: CropParams?
    public var exposure: ExposureParams?
    public var whiteBalance: WhiteBalanceParams?
    public var sharpen: SharpenParams?
    public var denoise: DenoiseParams?
    public var vibrance: VibranceParams?
    public var vignette: VignetteParams?
    public var eyeBrighten: EyeBrightenParams?
    public var backgroundBlur: BackgroundBlurParams?
    public var watermark: WatermarkParams?
    public var preset: PresetApplication?
    public var overlays: [OverlayLayer]

    public init(
        version: Int = 1,
        crop: CropParams? = nil,
        exposure: ExposureParams? = nil,
        whiteBalance: WhiteBalanceParams? = nil,
        sharpen: SharpenParams? = nil,
        denoise: DenoiseParams? = nil,
        vibrance: VibranceParams? = nil,
        vignette: VignetteParams? = nil,
        eyeBrighten: EyeBrightenParams? = nil,
        backgroundBlur: BackgroundBlurParams? = nil,
        watermark: WatermarkParams? = nil,
        preset: PresetApplication? = nil,
        overlays: [OverlayLayer] = []
    ) {
        self.version = version
        self.crop = crop
        self.exposure = exposure
        self.whiteBalance = whiteBalance
        self.sharpen = sharpen
        self.denoise = denoise
        self.vibrance = vibrance
        self.vignette = vignette
        self.eyeBrighten = eyeBrighten
        self.backgroundBlur = backgroundBlur
        self.watermark = watermark
        self.preset = preset
        self.overlays = overlays
    }

    public static let empty = EditGraph()
}
