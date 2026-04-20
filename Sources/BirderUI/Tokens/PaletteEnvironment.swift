import SwiftUI

private struct PaletteSurfaceKey: EnvironmentKey {
    static let defaultValue: PaletteSurface = .dark
}

public extension EnvironmentValues {
    var paletteSurface: PaletteSurface {
        get { self[PaletteSurfaceKey.self] }
        set { self[PaletteSurfaceKey.self] = newValue }
    }
}
