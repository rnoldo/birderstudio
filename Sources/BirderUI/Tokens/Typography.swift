import SwiftUI

public enum Typography {
    public enum Family: String {
        case interDisplay = "InterDisplay"
        case inter = "Inter"
        case newYork = "NewYork"
        case jetbrainsMono = "JetBrainsMono"
    }

    public static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(Family.inter.rawValue, size: size).weight(weight)
    }

    public static func interDisplay(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom(Family.interDisplay.rawValue, size: size).weight(weight)
    }

    public static func newYork(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .custom(Family.newYork.rawValue, size: size).weight(weight)
    }

    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(Family.jetbrainsMono.rawValue, size: size).weight(weight)
    }

    public static let display = interDisplay(28, weight: .semibold)
    public static let title = interDisplay(20, weight: .semibold)
    public static let subtitle = inter(16, weight: .medium)
    public static let body = inter(14, weight: .regular)
    public static let bodyStrong = inter(14, weight: .medium)
    public static let caption = inter(12, weight: .regular)
    public static let captionStrong = inter(12, weight: .medium)
    public static let micro = inter(10, weight: .medium)
    public static let species = newYork(16, weight: .medium)
    public static let speciesLarge = newYork(22, weight: .semibold)
    public static let exifValue = mono(12, weight: .regular)
    public static let exifLabel = inter(10, weight: .medium)
}
