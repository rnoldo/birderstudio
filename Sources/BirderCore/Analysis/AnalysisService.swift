import Foundation

/// Batch analyzer for a session.
///
/// - Runs `AnalysisPipeline` on each photo via `Task.detached` (CPU-bound work
///   off the service actor).
/// - Bounds concurrency to `maxConcurrency` to avoid RAM spikes on large imports.
/// - After the batch completes, recomputes `sessionPercentile` library-relative
///   across all analyses in the session (including pre-existing ones), so rating
///   filters reflect the current library.
public final class AnalysisService: Sendable {
    private let pipeline: any AnalysisPipeline
    private let photoRepo: PhotoRepository
    private let analysisRepo: AnalysisRepository
    private let clusterer: SceneClusterer
    private let maxConcurrency: Int

    public init(
        pipeline: any AnalysisPipeline,
        database: BirderDatabase,
        clusterer: SceneClusterer = SceneClusterer(),
        maxConcurrency: Int? = nil
    ) {
        self.pipeline = pipeline
        self.photoRepo = PhotoRepository(database: database)
        self.analysisRepo = AnalysisRepository(database: database)
        self.clusterer = clusterer
        self.maxConcurrency = maxConcurrency ?? max(2, ProcessInfo.processInfo.activeProcessorCount / 2)
    }

    /// Analyzes every photo in the session that is not yet analyzed (or failed).
    /// Events stream as each photo finishes. The stream finishes after `.completed`.
    public func analyze(sessionID: UUID) -> AsyncStream<AnalysisEvent> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let task = Task {
                await self.run(sessionID: sessionID, continuation: continuation)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(
        sessionID: UUID,
        continuation: AsyncStream<AnalysisEvent>.Continuation
    ) async {
        let allPhotos: [Photo]
        do {
            allPhotos = try await photoRepo.fetchBySession(sessionID)
        } catch {
            continuation.yield(.completed(analyzed: 0, failed: 0))
            return
        }

        let pending = allPhotos.filter { $0.status == .imported || $0.status == .failed }
        continuation.yield(.started(totalCount: pending.count))
        guard !pending.isEmpty else {
            continuation.yield(.completed(analyzed: 0, failed: 0))
            return
        }

        var analyzedCount = 0
        var failedCount = 0

        await withTaskGroup(of: AnalyzeResult.self) { group in
            let initial = min(pending.count, maxConcurrency)
            for i in 0..<initial {
                let photo = pending[i]
                group.addTask { [pipeline] in
                    await Self.analyzeOne(photo: photo, pipeline: pipeline)
                }
            }
            var next = initial
            while let result = await group.next() {
                await handle(result, continuation: continuation,
                             analyzed: &analyzedCount, failed: &failedCount)
                if next < pending.count {
                    let photo = pending[next]
                    next += 1
                    group.addTask { [pipeline] in
                        await Self.analyzeOne(photo: photo, pipeline: pipeline)
                    }
                }
            }
        }

        // Recompute session-relative percentile across ALL analyses in this session,
        // not just the ones we just wrote, so existing photos' rank shifts as the
        // library grows.
        do {
            try await recomputeSessionPercentiles(sessionID: sessionID)
        } catch {
            // percentile is a soft-fail — don't tank the batch
        }

        // Re-cluster scenes. Cheap to redo from scratch since session sizes are
        // bounded by a single shoot.
        do {
            try await recomputeScenes(sessionID: sessionID)
        } catch {
            // scene grouping is a soft-fail
        }

        continuation.yield(.completed(analyzed: analyzedCount, failed: failedCount))
    }

    private static func analyzeOne(
        photo: Photo,
        pipeline: any AnalysisPipeline
    ) async -> AnalyzeResult {
        await Task.detached(priority: .userInitiated) { () -> AnalyzeResult in
            do {
                let analysis = try pipeline.analyze(
                    photoID: photo.id,
                    imageURL: photo.fileURLCached
                )
                return .ok(photo: photo, analysis: analysis)
            } catch {
                return .failed(photoID: photo.id, message: "\(error)")
            }
        }.value
    }

    private func handle(
        _ result: AnalyzeResult,
        continuation: AsyncStream<AnalysisEvent>.Continuation,
        analyzed: inout Int,
        failed: inout Int
    ) async {
        switch result {
        case .ok(let photo, let analysis):
            do {
                try await analysisRepo.save(analysis)
                try await photoRepo.updateStatus(
                    id: photo.id, status: .analyzed, analyzedAt: Date()
                )
                analyzed += 1
                continuation.yield(.analyzed(photoID: photo.id, quality: analysis.quality))
            } catch {
                failed += 1
                continuation.yield(.failed(photoID: photo.id, message: "persist failed: \(error)"))
            }
        case .failed(let photoID, let message):
            failed += 1
            try? await photoRepo.updateStatus(id: photoID, status: .failed)
            continuation.yield(.failed(photoID: photoID, message: message))
        }
    }

    private func recomputeSessionPercentiles(sessionID: UUID) async throws {
        let analyses = try await analysisRepo.fetchBySession(sessionID)
        guard analyses.count > 1 else { return }

        let sorted = analyses.map { $0.quality.overall }.sorted()
        let n = Double(sorted.count)

        var updated: [PhotoAnalysis] = []
        updated.reserveCapacity(analyses.count)
        for a in analyses {
            // Rank = # scores strictly below; ties share midpoint percentile.
            let rank = sorted.firstIndex(where: { $0 >= a.quality.overall }) ?? sorted.count
            let upper = sorted.lastIndex(where: { $0 <= a.quality.overall }).map { $0 + 1 } ?? sorted.count
            let midpoint = Double(rank + upper) / 2.0
            let pct = max(0.0, min(1.0, midpoint / n))

            var q = a.quality
            q.sessionPercentile = pct
            var updatedAnalysis = a
            updatedAnalysis.quality = q
            updated.append(updatedAnalysis)
        }
        try await analysisRepo.saveBatch(updated)
    }

    private func recomputeScenes(sessionID: UUID) async throws {
        let analyses = try await analysisRepo.fetchBySession(sessionID)
        guard !analyses.isEmpty else { return }
        let photos = try await photoRepo.fetchBySession(sessionID)
        let capturedByID = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0.captured) })

        let inputs: [SceneClusterer.Input] = analyses.compactMap { a in
            guard let captured = capturedByID[a.photoID] else { return nil }
            return SceneClusterer.Input(
                photoID: a.photoID,
                captured: captured,
                quality: a.quality.overall,
                featurePrint: a.featurePrint
            )
        }
        let assignments = clusterer.cluster(inputs)
        try await analysisRepo.updateSceneGrouping(sessionID: sessionID, groupings: assignments)
    }
}

private enum AnalyzeResult: Sendable {
    case ok(photo: Photo, analysis: PhotoAnalysis)
    case failed(photoID: UUID, message: String)
}
