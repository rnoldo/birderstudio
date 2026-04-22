import SwiftUI
import AppKit
import BirderCore
import BirderUI

@MainActor
struct PhotoPreviewPane: View {
    let photo: Photo
    let previewURL: URL
    let rating: PhotoRating?
    let analysis: PhotoAnalysis?
    let detections: [BirdDetection]
    let onClose: () -> Void
    let onPrev: () -> Void
    let onNext: () -> Void
    let onPrevScene: () -> Void
    let onNextScene: () -> Void
    let onKey: (Character) -> Bool
    let onOpenSearch: () -> Void

    @Environment(\.paletteSurface) private var palette
    @State private var image: NSImage?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.3)
            HStack(spacing: 0) {
                imageArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider().opacity(0.3)
                metadataPanel
                    .frame(width: 260)
            }
        }
        .background(palette.canvasBackground)
        .focusable()
        .focused($focused)
        .onAppear { focused = true }
        .task(id: photo.id) {
            image = await ThumbnailCache.shared.image(at: previewURL)
        }
        .onKeyPress(.escape) { onClose(); return .handled }
        .onKeyPress(.leftArrow) { onPrev(); return .handled }
        .onKeyPress(.rightArrow) { onNext(); return .handled }
        .onKeyPress(.upArrow) { onPrevScene(); return .handled }
        .onKeyPress(.downArrow) { onNextScene(); return .handled }
        .onKeyPress { press in
            if press.modifiers.contains(.command), press.key == KeyEquivalent("k") {
                onOpenSearch()
                return .handled
            }
            guard let ch = press.characters.first else { return .ignored }
            return onKey(ch) ? .handled : .ignored
        }
    }

    private var toolbar: some View {
        HStack(spacing: Spacing.sm) {
            Text(photo.fileURLCached.lastPathComponent)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            ratingStrip
            Divider().frame(height: 14).opacity(0.3)
            Button(action: onPrev) {
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Previous (←)")
            Button(action: onNext) {
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Next (→)")
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Close viewer (Esc)")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private var ratingStrip: some View {
        HStack(spacing: Spacing.xs) {
            decisionChip(systemIcon: "checkmark", label: "P", color: Palette.Semantic.accept,
                         active: rating?.decision == .accepted, onTap: { _ = onKey("p") })
                .help("Accept (P)")
            decisionChip(systemIcon: "xmark", label: "X", color: Palette.Semantic.reject,
                         active: rating?.decision == .rejected, onTap: { _ = onKey("x") })
                .help("Reject (X)")
            decisionChip(systemIcon: "circle.dashed", label: "U", color: palette.textSecondary,
                         active: rating?.decision == .unrated || rating == nil, onTap: { _ = onKey("u") })
                .help("Unrate (U)")
            if let stars = analysis.map(AIStar.stars(for:)) {
                Divider().frame(height: 14).opacity(0.3)
                aiStars(stars)
                    .help("AI ranking within session")
            }
        }
    }

    private func aiStars(_ count: Int) -> some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { n in
                Image(systemName: n <= count ? "star.fill" : "star")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(n <= count ? Palette.Accent.amber : palette.textTertiary)
            }
        }
    }

    private func decisionChip(
        systemIcon: String,
        label: String,
        color: Color,
        active: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 3) {
                Image(systemName: systemIcon).font(.system(size: 9, weight: .bold))
                Text(label).font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(active ? color.opacity(0.25) : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(active ? color : color.opacity(0.35), lineWidth: active ? 1.2 : 0.8)
            )
            .foregroundStyle(active ? color : color.opacity(0.65))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Image area with bbox overlay

    private var imageArea: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.95)
                if let nsImg = image {
                    let pad = Spacing.md
                    let natW = nsImg.size.width
                    let natH = nsImg.size.height
                    let availW = geo.size.width - 2 * pad
                    let availH = geo.size.height - 2 * pad
                    let scale: CGFloat = (natW > 0 && natH > 0)
                        ? min(availW / natW, availH / natH)
                        : 1
                    let dispW = natW * scale
                    let dispH = natH * scale
                    let originX = pad + (availW - dispW) / 2
                    let originY = pad + (availH - dispH) / 2

                    Image(nsImage: nsImg)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(pad)

                    // Bbox overlays — NormalizedRect uses top-left origin, y-down.
                    // When the bbox ML pipeline is added, Vision coords (bottom-left
                    // origin) must be flipped before persisting: y_tl = 1 - y_bl - height.
                    ForEach(detections) { det in
                        let b = det.bbox
                        let bx = originX + CGFloat(b.x) * dispW
                        let by = originY + CGFloat(b.y) * dispH
                        let bw = CGFloat(b.width)  * dispW
                        let bh = CGFloat(b.height) * dispH
                        BboxOverlay(detection: det)
                            .frame(width: max(bw, 2), height: max(bh, 2))
                            .position(x: bx + bw / 2, y: by + bh / 2)
                    }
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .opacity(0.6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    // MARK: - Metadata panel

    private var metadataPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if let analysis {
                    section("Quality") {
                        row("Overall", String(format: "%.2f", analysis.quality.overall))
                        row("Sharpness", String(format: "%.2f", analysis.quality.sharpness))
                        row("Exposure", String(format: "%.2f", analysis.quality.exposure))
                        row("Percentile", String(format: "%.0f%%", analysis.quality.sessionPercentile * 100))
                        if analysis.isSceneBest {
                            row("Scene", "Best of scene")
                        }
                    }
                }
                if !detections.isEmpty {
                    section("Detections") {
                        ForEach(Array(detections.enumerated()), id: \.element.id) { idx, det in
                            row("Bird \(idx + 1)", String(format: "%.0f%%", det.confidence * 100))
                            if let sp = det.speciesID {
                                row("Species", sp)
                            }
                        }
                    }
                }
                section("Capture") {
                    row("Date", photo.captured.formatted(date: .long, time: .shortened))
                    if let camera = cameraDisplay {
                        row("Camera", camera)
                    }
                    if let lens = photo.exif.lens {
                        row("Lens", lens)
                    }
                    if let focal = photo.exif.focalLength {
                        row("Focal", String(format: "%.0f mm", focal))
                    }
                }
                section("Exposure") {
                    if let iso = photo.exif.iso {
                        row("ISO", "\(iso)")
                    }
                    if let shutter = photo.exif.shutter {
                        row("Shutter", shutter.displayString)
                    }
                    if let aperture = photo.exif.aperture {
                        row("Aperture", String(format: "f/%.1f", aperture))
                    }
                }
                section("File") {
                    row("Format", photo.format.rawValue.uppercased())
                    row("Size", "\(photo.pixelSize.width) × \(photo.pixelSize.height)")
                    row("Bytes", fileSizeString)
                    row("Imported", photo.importedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cameraDisplay: String? {
        let parts = [photo.exif.camera.make, photo.exif.camera.model].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private var fileSizeString: String {
        let bcf = ByteCountFormatter()
        bcf.countStyle = .file
        return bcf.string(fromByteCount: photo.fileSize)
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .kerning(0.8)
                .textCase(.uppercase)
                .foregroundStyle(palette.textTertiary)
            content()
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(palette.textSecondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.textPrimary)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Single bbox overlay view

private struct BboxOverlay: View {
    let detection: BirdDetection

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .strokeBorder(Palette.Accent.amber.opacity(0.9), lineWidth: 1.5)
                .background(Rectangle().fill(Palette.Accent.amber.opacity(0.06)))

            if let label {
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Palette.Accent.amber)
                    .offset(y: -18)
            }
        }
    }

    private var label: String? {
        let conf = String(format: "%.0f%%", detection.confidence * 100)
        if let sp = detection.speciesID { return "\(sp) \(conf)" }
        return conf
    }
}
