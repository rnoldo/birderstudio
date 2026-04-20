import Foundation
import BirderCore

@MainActor
final class ImportCoordinator: ObservableObject {
    @Published private(set) var isImporting = false
    @Published private(set) var isAnalyzing = false
    @Published private(set) var total = 0
    @Published private(set) var importedCount = 0
    @Published private(set) var skippedCount = 0
    @Published private(set) var failedCount = 0
    @Published private(set) var analyzedCount = 0
    @Published private(set) var analyzeTotal = 0
    @Published private(set) var analyzeFailedCount = 0
    @Published private(set) var recentErrors: [String] = []

    var processedCount: Int { importedCount + skippedCount + failedCount }

    var progress: Double {
        guard total > 0 else { return 0 }
        return min(1.0, Double(processedCount) / Double(total))
    }

    var analyzeProgress: Double {
        guard analyzeTotal > 0 else { return 0 }
        return min(1.0, Double(analyzedCount + analyzeFailedCount) / Double(analyzeTotal))
    }

    func run(
        urls: [URL],
        sessionID: UUID,
        importer: ImportService,
        analyzer: AnalysisService?
    ) async {
        guard !isImporting, !urls.isEmpty else { return }
        isImporting = true
        total = urls.count
        importedCount = 0
        skippedCount = 0
        failedCount = 0
        analyzedCount = 0
        analyzeTotal = 0
        analyzeFailedCount = 0
        recentErrors = []

        for await event in importer.imports(urls: urls, sessionID: sessionID) {
            switch event {
            case .started(let count):
                total = count
            case .imported:
                importedCount += 1
            case .duplicateSkipped:
                skippedCount += 1
            case .failed(_, let message):
                failedCount += 1
                recentErrors.append(message)
                if recentErrors.count > 3 { recentErrors.removeFirst() }
            case .completed:
                break
            }
        }
        isImporting = false

        guard let analyzer, importedCount > 0 else { return }
        isAnalyzing = true
        for await event in analyzer.analyze(sessionID: sessionID) {
            switch event {
            case .started(let n):
                analyzeTotal = n
            case .analyzed:
                analyzedCount += 1
            case .failed(_, let message):
                analyzeFailedCount += 1
                recentErrors.append("analyze: \(message)")
                if recentErrors.count > 3 { recentErrors.removeFirst() }
            case .completed:
                break
            }
        }
        isAnalyzing = false
    }
}
