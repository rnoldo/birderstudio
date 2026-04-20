import Foundation
import BirderCore

@MainActor
final class CullCoordinator: ObservableObject {
    @Published private(set) var ratings: [UUID: PhotoRating] = [:]
    @Published private(set) var analyses: [UUID: PhotoAnalysis] = [:]

    private var refreshTask: Task<Void, Never>?

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

    func setStar(photoID: UUID, star: Int, repo: RatingRepository?) {
        guard let repo else { return }
        let clamped = min(max(star, 0), 5)
        var current = ratings[photoID] ?? PhotoRating(photoID: photoID)
        current.star = clamped
        current.ratedAt = Date()
        ratings[photoID] = current
        Task { try? await repo.setStar(photoID: photoID, star: clamped) }
    }

    func rating(for id: UUID) -> PhotoRating? { ratings[id] }
    func analysis(for id: UUID) -> PhotoAnalysis? { analyses[id] }
}

/// Returns the matching action if the character maps to a cull shortcut.
enum CullShortcut {
    case accept
    case reject
    case unrate
    case star(Int)

    static func from(character: Character) -> CullShortcut? {
        switch character {
        case "p", "P": return .accept
        case "x", "X": return .reject
        case "u", "U": return .unrate
        case "0": return .star(0)
        case "1": return .star(1)
        case "2": return .star(2)
        case "3": return .star(3)
        case "4": return .star(4)
        case "5": return .star(5)
        default: return nil
        }
    }
}
