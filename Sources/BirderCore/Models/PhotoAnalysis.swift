import Foundation

public struct QualityScores: Sendable, Hashable, Codable {
    public var overall: Double
    public var sharpness: Double
    public var exposure: Double
    public var eyeSharpness: Double?
    public var composition: Double?
    public var sessionPercentile: Double

    public init(
        overall: Double,
        sharpness: Double,
        exposure: Double,
        eyeSharpness: Double? = nil,
        composition: Double? = nil,
        sessionPercentile: Double
    ) {
        self.overall = overall
        self.sharpness = sharpness
        self.exposure = exposure
        self.eyeSharpness = eyeSharpness
        self.composition = composition
        self.sessionPercentile = sessionPercentile
    }
}

public struct PhotoAnalysis: Identifiable, Sendable, Hashable, Codable {
    public var id: UUID { photoID }
    public var photoID: UUID
    public var quality: QualityScores
    public var featurePrint: Data
    public var sceneID: UUID?
    public var isSceneBest: Bool
    public var analyzedVersion: Int

    public init(
        photoID: UUID,
        quality: QualityScores,
        featurePrint: Data,
        sceneID: UUID? = nil,
        isSceneBest: Bool = false,
        analyzedVersion: Int = 1
    ) {
        self.photoID = photoID
        self.quality = quality
        self.featurePrint = featurePrint
        self.sceneID = sceneID
        self.isSceneBest = isSceneBest
        self.analyzedVersion = analyzedVersion
    }
}
