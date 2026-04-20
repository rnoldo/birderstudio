import Foundation

public enum AnalysisError: Error, Sendable, Equatable {
    case imageLoadFailed(URL)
    case contextCreationFailed
    case featurePrintFailed(String)
}

/// Analyzes a single photo to produce quality signals + a feature print for
/// similarity clustering. Implementations must be callable from a background
/// thread — the service layer wraps calls in `Task.detached`.
///
/// Current simple implementation scores sharpness + exposure globally. The
/// future bird-aware implementation will fill in `eyeSharpness` / `composition`
/// without changing this protocol or any caller (see `docs/QUALITY_SCORING_DESIGN.md`).
public protocol AnalysisPipeline: Sendable {
    func analyze(photoID: UUID, imageURL: URL) throws -> PhotoAnalysis
}
