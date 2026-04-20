import Foundation

/// Groups photos into "scenes" — bursts of the same subject taken close in time
/// with similar visual content. Based on Kestrel's hybrid approach:
///
/// 1. Photos sorted by captured time.
/// 2. Single pass: each photo compared to the current scene's anchor.
///    - If time gap > `timeGapSeconds` OR feature distance > `maxFeatureDistance`
///      → start a new scene (photo becomes the new anchor).
///    - Otherwise → join the current scene.
/// 3. Within each scene, photo with highest `quality.overall` is marked as best.
///
/// `timeGapSeconds = 10` is deliberately loose — bursts + quick reframing of the
/// same bird should stay grouped. Feature distance catches "same second, different
/// subject" (e.g., panning quickly between birds).
public struct SceneClusterer: Sendable {
    public var timeGapSeconds: TimeInterval
    public var maxFeatureDistance: Float

    public init(timeGapSeconds: TimeInterval = 10.0, maxFeatureDistance: Float = 0.6) {
        self.timeGapSeconds = timeGapSeconds
        self.maxFeatureDistance = maxFeatureDistance
    }

    public struct Input: Sendable {
        public var photoID: UUID
        public var captured: Date
        public var quality: Double
        public var featurePrint: Data

        public init(photoID: UUID, captured: Date, quality: Double, featurePrint: Data) {
            self.photoID = photoID
            self.captured = captured
            self.quality = quality
            self.featurePrint = featurePrint
        }
    }

    public func cluster(_ inputs: [Input]) -> [SceneAssignment] {
        guard !inputs.isEmpty else { return [] }
        let sorted = inputs.sorted { $0.captured < $1.captured }

        var assignments: [SceneAssignment] = []
        assignments.reserveCapacity(sorted.count)

        var currentSceneID = UUID()
        var anchor = sorted[0]
        var members: [(UUID, Double)] = [(sorted[0].photoID, sorted[0].quality)]

        func flush() {
            guard !members.isEmpty else { return }
            let bestID = members.max(by: { $0.1 < $1.1 })!.0
            for (pid, _) in members {
                assignments.append(SceneAssignment(
                    photoID: pid,
                    sceneID: currentSceneID,
                    isBest: pid == bestID
                ))
            }
        }

        for i in 1..<sorted.count {
            let p = sorted[i]
            let gap = p.captured.timeIntervalSince(anchor.captured)
            var sameScene = gap <= timeGapSeconds
            if sameScene {
                // Only pay the unarchive cost when time gap says it's a candidate.
                let dist = (try? FeaturePrintCompare.distance(anchor.featurePrint, p.featurePrint)) ?? .greatestFiniteMagnitude
                sameScene = dist <= maxFeatureDistance
            }
            if sameScene {
                members.append((p.photoID, p.quality))
            } else {
                flush()
                currentSceneID = UUID()
                anchor = p
                members = [(p.photoID, p.quality)]
            }
        }
        flush()
        return assignments
    }
}
