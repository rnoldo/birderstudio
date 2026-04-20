import Foundation
import BirderCore

@MainActor
final class ImportCoordinator: ObservableObject {
    @Published private(set) var isImporting = false
    @Published private(set) var total = 0
    @Published private(set) var importedCount = 0
    @Published private(set) var skippedCount = 0
    @Published private(set) var failedCount = 0
    @Published private(set) var recentErrors: [String] = []

    var processedCount: Int { importedCount + skippedCount + failedCount }

    var progress: Double {
        guard total > 0 else { return 0 }
        return min(1.0, Double(processedCount) / Double(total))
    }

    func run(urls: [URL], sessionID: UUID, service: ImportService) async {
        guard !isImporting, !urls.isEmpty else { return }
        isImporting = true
        total = urls.count
        importedCount = 0
        skippedCount = 0
        failedCount = 0
        recentErrors = []

        for await event in service.imports(urls: urls, sessionID: sessionID) {
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
    }
}
