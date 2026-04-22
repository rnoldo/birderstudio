import Foundation
import BirderCore

@MainActor
final class CullCoordinator: ObservableObject {
    @Published private(set) var ratings: [UUID: PhotoRating] = [:]
    @Published private(set) var analyses: [UUID: PhotoAnalysis] = [:]

    func loadSession(_ sessionID: UUID, ratingRepo: RatingRepository?, analysisRepo: AnalysisRepository?) async {
        guard let ratingRepo, let analysisRepo else { return }
        do {
            let ratingsMap = try await ratingRepo.fetchBySession(sessionID)
            let analysesList = try await analysisRepo.fetchBySession(sessionID)
            self.ratings = ratingsMap
            self.analyses = Dictionary(uniqueKeysWithValues: analysesList.map { ($0.photoID, $0) })
        } catch {
            // Keep stale state; user can retry.
        }
    }

    func setDecision(photoID: UUID, decision: RatingDecision, repo: RatingRepository?) {
        guard let repo else { return }
        var current = ratings[photoID] ?? PhotoRating(photoID: photoID)
        current.decision = decision
        current.ratedAt = Date()
        ratings[photoID] = current
        Task { try? await repo.setDecision(photoID: photoID, decision: decision) }
    }

    func rating(for id: UUID) -> PhotoRating? { ratings[id] }
    func analysis(for id: UUID) -> PhotoAnalysis? { analyses[id] }
}

/// AI-assigned 1-5 star ranking based on the photo's session percentile.
/// Unlike the Q quality bar (absolute sharpness/exposure signal), stars
/// represent the photo's relative rank within the current session — so
/// every session has its top tier, regardless of absolute quality.
enum AIStar {
    static func stars(for analysis: PhotoAnalysis) -> Int {
        let p = analysis.quality.sessionPercentile
        switch p {
        case 0.90...: return 5
        case 0.70..<0.90: return 4
        case 0.40..<0.70: return 3
        case 0.15..<0.40: return 2
        default: return 1
        }
    }
}

/// User-driven cull shortcut. Stars are AI-assigned (see `AIStar`), not
/// user-editable, so there are only three manual decisions: pick / reject / unrate.
enum CullShortcut {
    case accept
    case reject
    case unrate

    static func from(character: Character) -> CullShortcut? {
        switch character {
        case "p", "P": return .accept
        case "x", "X": return .reject
        case "u", "U": return .unrate
        default: return nil
        }
    }
}
