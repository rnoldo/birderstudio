import SwiftUI

public enum Palette {
    public enum Dark {
        public static let canvasBackground = Color(hex: 0x0A0C10)
        public static let surfaceElevated = Color(hex: 0x15181E)
        public static let surfaceRaised = Color(hex: 0x1D2026)
        public static let border = Color(hex: 0x23272E).opacity(0.5)
        public static let borderStrong = Color(hex: 0x2E333C)
        public static let textPrimary = Color(hex: 0xE8EBEF)
        public static let textSecondary = Color(hex: 0x8A9099)
        public static let textTertiary = Color(hex: 0x5A6069)
    }

    public enum Light {
        public static let canvasBackground = Color(hex: 0xFBFBFC)
        public static let surfaceElevated = Color(hex: 0xFFFFFF)
        public static let surfaceRaised = Color(hex: 0xF3F4F6)
        public static let border = Color(hex: 0xE2E4E8)
        public static let borderStrong = Color(hex: 0xC8CBD1)
        public static let textPrimary = Color(hex: 0x14161A)
        public static let textSecondary = Color(hex: 0x5A6069)
        public static let textTertiary = Color(hex: 0x8A9099)
    }

    public enum Accent {
        public static let amber = Color(hex: 0xF5A623)
        public static let amberMuted = Color(hex: 0xA67A1F)
        public static let amberSoft = Color(hex: 0xF5A623).opacity(0.15)
    }

    public enum Semantic {
        public static let accept = Color(hex: 0x4ADE80)
        public static let acceptMuted = Color(hex: 0x2E8B57)
        public static let reject = Color(hex: 0xFB7185)
        public static let rejectMuted = Color(hex: 0xBE4B5A)
        public static let warning = Color(hex: 0xFBBF24)
        public static let info = Color(hex: 0x60A5FA)
        public static let star = Color(hex: 0xFBBF24)
    }
}

public struct PaletteSurface: Sendable {
    public let canvasBackground: Color
    public let surfaceElevated: Color
    public let surfaceRaised: Color
    public let border: Color
    public let borderStrong: Color
    public let textPrimary: Color
    public let textSecondary: Color
    public let textTertiary: Color

    public static let dark = PaletteSurface(
        canvasBackground: Palette.Dark.canvasBackground,
        surfaceElevated: Palette.Dark.surfaceElevated,
        surfaceRaised: Palette.Dark.surfaceRaised,
        border: Palette.Dark.border,
        borderStrong: Palette.Dark.borderStrong,
        textPrimary: Palette.Dark.textPrimary,
        textSecondary: Palette.Dark.textSecondary,
        textTertiary: Palette.Dark.textTertiary
    )

    public static let light = PaletteSurface(
        canvasBackground: Palette.Light.canvasBackground,
        surfaceElevated: Palette.Light.surfaceElevated,
        surfaceRaised: Palette.Light.surfaceRaised,
        border: Palette.Light.border,
        borderStrong: Palette.Light.borderStrong,
        textPrimary: Palette.Light.textPrimary,
        textSecondary: Palette.Light.textSecondary,
        textTertiary: Palette.Light.textTertiary
    )
}
