import Foundation

public enum SpeciesSource: String, Sendable, Codable, CaseIterable {
    case ml
    case user
    case unknown
}

public struct BirdDetection: Identifiable, Sendable, Hashable, Codable {
    public var id: UUID
    public var photoID: UUID
    public var bbox: NormalizedRect
    public var confidence: Double
    public var speciesID: String?
    public var speciesConfidence: Double?
    public var speciesSource: SpeciesSource

    public init(
        id: UUID = UUID(),
        photoID: UUID,
        bbox: NormalizedRect,
        confidence: Double,
        speciesID: String? = nil,
        speciesConfidence: Double? = nil,
        speciesSource: SpeciesSource = .unknown
    ) {
        self.id = id
        self.photoID = photoID
        self.bbox = bbox
        self.confidence = confidence
        self.speciesID = speciesID
        self.speciesConfidence = speciesConfidence
        self.speciesSource = speciesSource
    }
}
