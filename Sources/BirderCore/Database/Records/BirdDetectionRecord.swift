import Foundation
import GRDB

struct BirdDetectionRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "bird_detections"

    var id: String
    var photoId: String
    var bboxX: Double
    var bboxY: Double
    var bboxW: Double
    var bboxH: Double
    var confidence: Double
    var speciesId: String?
    var speciesConfidence: Double?
    var speciesSource: String

    enum CodingKeys: String, CodingKey {
        case id
        case photoId = "photo_id"
        case bboxX = "bbox_x"
        case bboxY = "bbox_y"
        case bboxW = "bbox_w"
        case bboxH = "bbox_h"
        case confidence
        case speciesId = "species_id"
        case speciesConfidence = "species_confidence"
        case speciesSource = "species_source"
    }
}

extension BirdDetectionRecord {
    init(from domain: BirdDetection) {
        self.id = domain.id.uuidString
        self.photoId = domain.photoID.uuidString
        self.bboxX = domain.bbox.x
        self.bboxY = domain.bbox.y
        self.bboxW = domain.bbox.width
        self.bboxH = domain.bbox.height
        self.confidence = domain.confidence
        self.speciesId = domain.speciesID
        self.speciesConfidence = domain.speciesConfidence
        self.speciesSource = domain.speciesSource.rawValue
    }

    func toDomain() throws -> BirdDetection {
        guard let uuid = UUID(uuidString: id) else {
            throw BirderDatabaseError.invalidEncoding(field: "bird_detections.id", underlying: id)
        }
        guard let photoUUID = UUID(uuidString: photoId) else {
            throw BirderDatabaseError.invalidEncoding(field: "bird_detections.photo_id", underlying: photoId)
        }
        let source = SpeciesSource(rawValue: speciesSource) ?? .unknown
        return BirdDetection(
            id: uuid,
            photoID: photoUUID,
            bbox: NormalizedRect(x: bboxX, y: bboxY, width: bboxW, height: bboxH),
            confidence: confidence,
            speciesID: speciesId,
            speciesConfidence: speciesConfidence,
            speciesSource: source
        )
    }
}
