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
    @State private var isDropTargeted = false
    @State private var photos: [Photo] = []
    @State private var selectedPhotoID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.3)
            contentArea
        }
        .task(id: session.id) {
            await observePhotos()
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
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
            Group {
                if let selected = selectedPhoto {
                    HSplitView {
                        PhotoPreviewPane(
                            photo: selected,
                            previewURL: storage.previewURL(for: selected.id),
                            onClose: { selectedPhotoID = nil },
                            onPrev: { navigatePhoto(offset: -1) },
                            onNext: { navigatePhoto(offset: +1) }
                        )
                        .frame(minWidth: 480)
                        PhotoGridView(
                            photos: photos,
                            storage: storage,
                            selectedPhotoID: $selectedPhotoID
                        )
                        .frame(minWidth: 280, idealWidth: 360, maxWidth: 560)
                    }
                } else {
                    PhotoGridView(
                        photos: photos,
                        storage: storage,
                        selectedPhotoID: $selectedPhotoID
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
            await importer.run(urls: supported, sessionID: session.id, service: service)
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
