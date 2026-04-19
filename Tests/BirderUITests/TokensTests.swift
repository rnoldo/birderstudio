import Testing
@testable import BirderUI

@Suite("Design System Tokens")
struct TokensTests {
    @Test func spacingScaleIsMonotonic() {
        let values = [Spacing.hair, Spacing.xs, Spacing.sm, Spacing.md,
                      Spacing.lg, Spacing.xl, Spacing.xxl, Spacing.xxxl]
        #expect(values == values.sorted())
    }

    @Test func paletteSurfacesAreDistinct() {
        #expect(PaletteSurface.dark.canvasBackground != PaletteSurface.light.canvasBackground)
        #expect(PaletteSurface.dark.textPrimary != PaletteSurface.light.textPrimary)
    }

    @Test func motionDurationsAreSensible() {
        #expect(Duration.instant < Duration.snap)
        #expect(Duration.snap < Duration.smooth)
        #expect(Duration.smooth < Duration.gentle)
    }
}
