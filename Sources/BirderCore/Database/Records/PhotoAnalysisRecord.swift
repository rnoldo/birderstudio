import Foundation
import GRDB

struct PhotoAnalysisRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "photo_analyses"

    var photoId: String
    var qualityOverall: Double
    var qualitySharpness: Double
    var qualityExposure: Double
    var qualityEyeSharp: Double?
    var qualityComposition: Double?
    var qualityPercentile: Double

    var featurePrint: Data
    var sceneId: String?
    var isSceneBest: Int
    var analyzedVersion: Int

    enum CodingKeys: String, CodingKey {
        case photoId = "photo_id"
        case qualityOverall = "quality_overall"
        case qualitySharpness = "quality_sharpness"
        case qualityExposure = "quality_exposure"
        case qualityEyeSharp = "quality_eye_sharp"
        case qualityComposition = "quality_composition"
        case qualityPercentile = "quality_percentile"
        case featurePrint = "feature_print"
        case sceneId = "scene_id"
        case isSceneBest = "is_scene_best"
        case analyzedVersion = "analyzed_version"
    }
}

extension PhotoAnalysisRecord {
    init(from domain: PhotoAnalysis) {
        self.photoId = domain.photoID.uuidString
        self.qualityOverall = domain.quality.overall
        self.qualitySharpness = domain.quality.sharpness
        self.qualityExposure = domain.quality.exposure
        self.qualityEyeSharp = domain.quality.eyeSharpness
        self.qualityComposition = domain.quality.composition
        self.qualityPercentile = domain.quality.sessionPercentile
        self.featurePrint = domain.featurePrint
        self.sceneId = domain.sceneID?.uuidString
        self.isSceneBest = domain.isSceneBest ? 1 : 0
        self.analyzedVersion = domain.analyzedVersion
    }

    func toDomain() throws -> PhotoAnalysis {
        guard let photoUUID = UUID(uuidString: photoId) else {
            throw BirderDatabaseError.invalidEncoding(field: "photo_analyses.photo_id", underlying: photoId)
        }
        let sceneUUID: UUID? = {
            guard let id = sceneId else { return nil }
            return UUID(uuidString: id)
        }()
        let quality = QualityScores(
            overall: qualityOverall,
            sharpness: qualitySharpness,
            exposure: qualityExposure,
            eyeSharpness: qualityEyeSharp,
            composition: qualityComposition,
            sessionPercentile: qualityPercentile
        )
        return PhotoAnalysis(
            photoID: photoUUID,
            quality: quality,
            featurePrint: featurePrint,
            sceneID: sceneUUID,
            isSceneBest: isSceneBest != 0,
            analyzedVersion: analyzedVersion
        )
    }
}
