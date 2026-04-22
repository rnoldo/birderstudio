import SwiftUI
import UniformTypeIdentifiers
import BirderCore
import BirderUI

@MainActor
struct SessionDetailView: View {
    let session: Session
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.paletteSurface) private var palette
    @Environment(\.undoManager) private var undoManager
    @StateObject private var importer = ImportCoordinator()
    @StateObject private var cull = CullCoordinator()
    @State private var isDropTargeted = false
    @State private var photos: [Photo] = []
    @State private var selectedPhotoID: UUID?
    @State private var filter: CullFilter = .all
    @State private var selectedPhotoDetections: [BirdDetection] = []
    @State private var showSearch = false

    private var filteredPhotos: [Photo] {
        photos.filter { filter.includes(photo: $0, rating: cull.rating(for: $0.id), analysis: cull.analysis(for: $0.id)) }
    }

    private var filterCounts: [CullFilter: Int] {
        var result: [CullFilter: Int] = [:]
        for f in CullFilter.allCases {
            result[f] = photos.reduce(0) {
                $0 + (f.includes(photo: $1, rating: cull.rating(for: $1.id), analysis: cull.analysis(for: $1.id)) ? 1 : 0)
            }
        }
        return result
    }

    // MARK: - Session stats

    private var acceptedCount: Int {
        photos.filter { cull.rating(for: $0.id)?.decision == .accepted }.count
    }
    private var rejectedCount: Int {
        photos.filter { cull.rating(for: $0.id)?.decision == .rejected }.count
    }
    private var analyzedCount: Int {
        photos.filter { cull.analysis(for: $0.id) != nil }.count
    }
    private var sceneCount: Int {
        Set(photos.compactMap { cull.analysis(for: $0.id)?.sceneID }).count
    }
    private var avgQuality: Double? {
        let scores = photos.compactMap { cull.analysis(for: $0.id)?.quality.overall }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.3)
            contentArea
        }
        .task(id: session.id) {
            let handler = WindowDropHandler.shared
            handler.onDrop = { urls in
                handleDropURLs(urls)
                return true
            }
            handler.onTargeted = { targeted in
                isDropTargeted = targeted
            }
        }
        .task(id: session.id) {
            await observePhotos()
        }
        .task(id: session.id) {
            await cull.loadSession(session.id, ratingRepo: env.ratingRepo, analysisRepo: env.analysisRepo)
        }
        .task(id: importer.isAnalyzing) {
            if !importer.isAnalyzing {
                await cull.loadSession(session.id, ratingRepo: env.ratingRepo, analysisRepo: env.analysisRepo)
            }
        }
        .task(id: selectedPhotoID) {
            guard let id = selectedPhotoID, let repo = env.detectionRepo else {
                selectedPhotoDetections = []
                return
            }
            selectedPhotoDetections = (try? await repo.fetchByPhoto(id)) ?? []
        }
        .overlay {
            if showSearch {
                SearchPanel(
                    isPresented: $showSearch,
                    sessions: env.sessions,
                    photos: photos,
                    onSelectSession: { env.selectedSessionID = $0 },
                    onSelectPhoto: { selectedPhotoID = $0 }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeOut(duration: 0.12), value: showSearch)
        // Hidden button so Cmd+K works even when focus is on the VStack
        .background {
            Button("") { showSearch = true }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
        }
    }

    // MARK: - Cull key handler

    fileprivate func handleCullKey(_ character: Character) -> Bool {
        guard let id = selectedPhotoID, let shortcut = CullShortcut.from(character: character) else {
            return false
        }
        let previous = cull.rating(for: id)?.decision ?? .unrated
        let next: RatingDecision
        switch shortcut {
        case .accept: next = .accepted
        case .reject: next = .rejected
        case .unrate: next = .unrated
        }
        guard next != previous else { return true }
        cull.setDecision(photoID: id, decision: next, repo: env.ratingRepo)
        let repo = env.ratingRepo
        undoManager?.registerUndo(withTarget: cull) { coordinator in
            MainActor.assumeIsolated {
                coordinator.setDecision(photoID: id, decision: previous, repo: repo)
            }
        }
        undoManager?.setActionName("Rate Photo")
        return true
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.system(size: 22, weight: .semibold))
                HStack(spacing: Spacing.sm) {
                    Text(session.dateStart.formatted(date: .long, time: .shortened))
                    Text("·")
                    Text(photoCountText)
                }
                .font(.system(size: 12))
                .foregroundStyle(palette.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    @ViewBuilder
    private var contentArea: some View {
        if importer.isImporting {
            importProgress
        } else if photos.isEmpty {
            largeDropZone
        } else {
            populatedBody
        }
    }

    private var photoCountText: String {
        switch photos.count {
        case 0: "No photos"
        case 1: "1 photo"
        default: "\(photos.count) photos"
        }
    }

    // MARK: - Empty drop zone

    private var largeDropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .strokeBorder(
                    isDropTargeted ? Palette.Accent.amber : palette.border,
                    style: StrokeStyle(lineWidth: BorderWidth.thin, dash: [6, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(isDropTargeted ? Palette.Accent.amberSoft : Color.clear)
                )
                .animation(.easeOut(duration: 0.15), value: isDropTargeted)
            VStack(spacing: Spacing.md) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(palette.textSecondary)
                Text("Drop RAW files here")
                    .font(.system(size: 16, weight: .medium))
                Text("Supports CR3, CR2, NEF, ARW, DNG, RAF, ORF, RW2, plus JPEG/HEIC/TIFF")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.xl)
        }
        .padding(Spacing.xl)
    }

    // MARK: - Import progress

    private var importProgress: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            VStack(spacing: Spacing.sm) {
                Text("Importing \(importer.processedCount) / \(importer.total)")
                    .font(.system(size: 13, weight: .medium))
                ProgressView(value: importer.progress)
                    .progressViewStyle(.linear)
                    .tint(Palette.Accent.amber)
                    .frame(maxWidth: 360)
                HStack(spacing: Spacing.lg) {
                    counter("Imported", importer.importedCount, Palette.Semantic.accept)
                    counter("Skipped", importer.skippedCount, palette.textSecondary)
                    counter("Failed", importer.failedCount, Palette.Semantic.reject)
                }
            }
            if !importer.recentErrors.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(importer.recentErrors.enumerated()), id: \.offset) { _, message in
                        Text(message)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Palette.Semantic.rejectMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: 480)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
    }

    private var analyzeProgressStrip: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView().controlSize(.small)
            Text("Analyzing \(importer.analyzedCount + importer.analyzeFailedCount) / \(importer.analyzeTotal)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.textSecondary)
            ProgressView(value: importer.analyzeProgress)
                .progressViewStyle(.linear)
                .tint(Palette.Accent.amber)
                .frame(maxWidth: 220)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
        .background(palette.surfaceRaised.opacity(0.3))
    }

    private func counter(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .kerning(0.6)
                .textCase(.uppercase)
                .foregroundStyle(palette.textTertiary)
        }
    }

    // MARK: - Populated body

    @ViewBuilder
    private var populatedBody: some View {
        if let storage = env.storage {
            VStack(spacing: 0) {
                if importer.isAnalyzing {
                    analyzeProgressStrip
                    Divider().opacity(0.3)
                }
                CullFilterBar(selected: $filter, counts: filterCounts)
                Divider().opacity(0.3)
                SessionStatsBar(
                    total: photos.count,
                    accepted: acceptedCount,
                    rejected: rejectedCount,
                    scenes: sceneCount,
                    analyzed: analyzedCount,
                    avgQuality: avgQuality
                )
                Divider().opacity(0.3)
                if let selected = selectedPhoto {
                    HSplitView {
                        PhotoPreviewPane(
                            photo: selected,
                            previewURL: storage.previewURL(for: selected.id),
                            rating: cull.rating(for: selected.id),
                            analysis: cull.analysis(for: selected.id),
                            detections: selectedPhotoDetections,
                            onClose: { selectedPhotoID = nil },
                            onPrev: { navigatePhoto(offset: -1) },
                            onNext: { navigatePhoto(offset: +1) },
                            onPrevScene: { navigateScene(offset: -1) },
                            onNextScene: { navigateScene(offset: +1) },
                            onKey: handleCullKey,
                            onOpenSearch: { showSearch = true }
                        )
                        .frame(minWidth: 480)
                        PhotoGridView(
                            photos: filteredPhotos,
                            storage: storage,
                            selectedPhotoID: $selectedPhotoID,
                            rating: { cull.rating(for: $0) },
                            analysis: { cull.analysis(for: $0) },
                            onKey: handleCullKey
                        )
                        .frame(minWidth: 280, idealWidth: 360, maxWidth: 560)
                    }
                } else {
                    PhotoGridView(
                        photos: filteredPhotos,
                        storage: storage,
                        selectedPhotoID: $selectedPhotoID,
                        rating: { cull.rating(for: $0) },
                        analysis: { cull.analysis(for: $0) },
                        onKey: handleCullKey
                    )
                }
            }
            .overlay(alignment: .top) {
                if isDropTargeted {
                    Rectangle()
                        .fill(Palette.Accent.amber)
                        .frame(height: 2)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: isDropTargeted)
        } else {
            Color.clear
        }
    }

    private var selectedPhoto: Photo? {
        guard let id = selectedPhotoID else { return nil }
        return photos.first { $0.id == id }
    }

    private var sceneGroups: [SceneGroup] {
        SceneGroup.build(photos: filteredPhotos) { cull.analysis(for: $0) }
    }

    private func navigatePhoto(offset: Int) {
        let order = sceneGroups.flatMap { $0.photos.map(\.id) }
        guard !order.isEmpty else { return }
        guard let id = selectedPhotoID,
              let idx = order.firstIndex(of: id) else {
            selectedPhotoID = order.first
            return
        }
        let newIdx = min(max(idx + offset, 0), order.count - 1)
        guard newIdx != idx else { return }
        selectedPhotoID = order[newIdx]
    }

    private func navigateScene(offset: Int) {
        let groups = sceneGroups
        guard !groups.isEmpty else { return }
        let currentIdx: Int
        if let id = selectedPhotoID,
           let gi = groups.firstIndex(where: { $0.photos.contains(where: { $0.id == id }) }) {
            currentIdx = gi
        } else {
            currentIdx = 0
        }
        let newIdx = min(max(currentIdx + offset, 0), groups.count - 1)
        if let best = groups[newIdx].photos.first?.id {
            selectedPhotoID = best
        }
    }

    private func handleDropURLs(_ urls: [URL]) {
        let supported = urls.filter { FileFormat.from(pathExtension: $0.pathExtension) != nil }
        guard !supported.isEmpty, let service = env.importService else { return }
        Task { @MainActor in
            await importer.run(
                urls: supported,
                sessionID: session.id,
                importer: service,
                analyzer: env.analysisService
            )
        }
    }

    private func observePhotos() async {
        guard let repo = env.photoRepo else { return }
        do {
            for try await ps in repo.observeBySession(session.id) {
                self.photos = ps
            }
        } catch {
            // Observation ended; ignore.
        }
    }
}
