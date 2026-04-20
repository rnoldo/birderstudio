import SwiftUI
import UniformTypeIdentifiers
import BirderCore
import BirderUI

@MainActor
struct SessionDetailView: View {
    let session: Session
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.paletteSurface) private var palette
    @StateObject private var importer = ImportCoordinator()
    @StateObject private var cull = CullCoordinator()
    @State private var isDropTargeted = false
    @State private var photos: [Photo] = []
    @State private var selectedPhotoID: UUID?
    @State private var filter: CullFilter = .all

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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.3)
            contentArea
        }
        .task(id: session.id) {
            await observePhotos()
        }
        .task(id: session.id) {
            await cull.loadSession(session.id, ratingRepo: env.ratingRepo, analysisRepo: env.analysisRepo)
        }
        .task(id: importer.isAnalyzing) {
            // When a batch of analysis completes, reload the ratings/analyses cache.
            if !importer.isAnalyzing {
                await cull.loadSession(session.id, ratingRepo: env.ratingRepo, analysisRepo: env.analysisRepo)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    fileprivate func handleCullKey(_ character: Character) -> Bool {
        guard let id = selectedPhotoID, let shortcut = CullShortcut.from(character: character) else {
            return false
        }
        switch shortcut {
        case .accept: cull.setDecision(photoID: id, decision: .accepted, repo: env.ratingRepo)
        case .reject: cull.setDecision(photoID: id, decision: .rejected, repo: env.ratingRepo)
        case .unrate: cull.setDecision(photoID: id, decision: .unrated, repo: env.ratingRepo)
        case .star(let n): cull.setStar(photoID: id, star: n, repo: env.ratingRepo)
        }
        return true
    }

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
                if let selected = selectedPhoto {
                    HSplitView {
                        PhotoPreviewPane(
                            photo: selected,
                            previewURL: storage.previewURL(for: selected.id),
                            rating: cull.rating(for: selected.id),
                            analysis: cull.analysis(for: selected.id),
                            onClose: { selectedPhotoID = nil },
                            onPrev: { navigatePhoto(offset: -1) },
                            onNext: { navigatePhoto(offset: +1) },
                            onKey: handleCullKey
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

    private func navigatePhoto(offset: Int) {
        guard let id = selectedPhotoID,
              let idx = photos.firstIndex(where: { $0.id == id }) else { return }
        let newIdx = min(max(idx + offset, 0), photos.count - 1)
        guard newIdx != idx else { return }
        selectedPhotoID = photos[newIdx].id
    }

    private func handleDrop(providers: [NSItemProvider]) {
        Task { @MainActor in
            let urls = await Self.loadURLs(from: providers)
            let supported = urls.filter { FileFormat.from(pathExtension: $0.pathExtension) != nil }
            guard !supported.isEmpty, let service = env.importService else { return }
            await importer.run(
                urls: supported,
                sessionID: session.id,
                importer: service,
                analyzer: env.analysisService
            )
        }
    }

    private static func loadURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers {
            if let url = await loadURL(from: provider) {
                urls.append(url)
            }
        }
        return urls
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
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
