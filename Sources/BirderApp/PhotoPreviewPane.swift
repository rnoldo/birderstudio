import SwiftUI
import AppKit
import BirderCore
import BirderUI

@MainActor
struct PhotoPreviewPane: View {
    let photo: Photo
    let previewURL: URL
    let onClose: () -> Void
    let onPrev: () -> Void
    let onNext: () -> Void

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
                    .frame(width: 240)
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
    }

    private var toolbar: some View {
        HStack(spacing: Spacing.sm) {
            Text(photo.fileURLCached.lastPathComponent)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
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

    private var imageArea: some View {
        ZStack {
            Color.black.opacity(0.95)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(Spacing.md)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .opacity(0.6)
            }
        }
    }

    private var metadataPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
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
