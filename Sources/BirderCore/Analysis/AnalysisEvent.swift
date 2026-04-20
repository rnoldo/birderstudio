import Foundation

public enum AnalysisEvent: Sendable {
    case started(totalCount: Int)
    case analyzed(photoID: UUID, quality: QualityScores)
    case failed(photoID: UUID, message: String)
    case completed(analyzed: Int, failed: Int)
}
