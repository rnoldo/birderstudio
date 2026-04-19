import SwiftUI

public enum Motion {
    public static let snap = Animation.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.18)
    public static let smooth = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.3)
    public static let gentle = Animation.timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.5)
    public static let bounce = Animation.spring(response: 0.4, dampingFraction: 0.7)
    public static let heroEntrance = Animation.spring(response: 0.55, dampingFraction: 0.82)

    public static let keyboardNav = snap
    public static let sidebarToggle = smooth
    public static let photoEnter = gentle
    public static let cardAccept = bounce
    public static let cardReject = bounce
    public static let inspectorSlide = smooth
    public static let modalPresent = heroEntrance
    public static let sceneBestReveal = bounce
}

public enum Duration {
    public static let instant: TimeInterval = 0.10
    public static let snap: TimeInterval = 0.18
    public static let smooth: TimeInterval = 0.30
    public static let gentle: TimeInterval = 0.50
}
