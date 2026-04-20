import SwiftUI
import AppKit
import BirderCore
import BirderUI

@MainActor
struct PhotoGridView: View {
    let photos: [Photo]
    let storage: StorageLocations
    @Binding var selectedPhotoID: UUID?

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 280), spacing: Spacing.md)
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: Spacing.lg) {
                    ForEach(photos) { photo in
                        PhotoThumbnailCell(
                            photo: photo,
                            thumbnailURL: storage.thumbnailURL(for: photo.id),
                            isSelected: selectedPhotoID == photo.id
                        )
                        .id(photo.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPhotoID = photo.id
                        }
                    }
                }
                .padding(Spacing.lg)
            }
            .onChange(of: selectedPhotoID) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

@MainActor
private struct PhotoThumbnailCell: View {
    let photo: Photo
    let thumbnailURL: URL
    let isSelected: Bool

    @Environment(\.paletteSurface) private var palette
    @State private var image: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            thumbnailArea
            captionRow
            exifRow
        }
        .task(id: photo.id) {
            image = await ThumbnailCache.shared.image(at: thumbnailURL)
        }
    }

    private var thumbnailArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(Color.black.opacity(0.9))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            } else {
                ProgressView()
                    .controlSize(.small)
                    .opacity(0.5)
            }
            if photo.format.isRaw {
                Text("RAW")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .kerning(0.6)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.black.opacity(0.55))
                    )
                    .foregroundStyle(Palette.Accent.amber)
                    .padding(Spacing.xs)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .aspectRatio(3.0 / 2.0, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .strokeBorder(
                    isSelected ? Palette.Accent.amber : Color.white.opacity(0.04),
                    lineWidth: isSelected ? 2 : BorderWidth.hair
                )
        )
        .shadow(
            color: isSelected ? Palette.Accent.amber.opacity(0.35) : .clear,
            radius: isSelected ? 8 : 0
        )
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    private var captionRow: some View {
        HStack(spacing: Spacing.sm) {
            Text(photo.captured.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 10))
                .foregroundStyle(palette.textSecondary)
            Spacer(minLength: 0)
            Text(photo.format.rawValue.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(palette.textTertiary)
        }
    }

    @ViewBuilder
    private var exifRow: some View {
        HStack(spacing: Spacing.xs) {
            if let iso = photo.exif.iso {
                tag("ISO \(iso)")
            }
            if let shutter = photo.exif.shutter {
                tag(shutter.displayString)
            }
            if let aperture = photo.exif.aperture {
                tag(String(format: "f/%.1f", aperture))
            }
            Spacer(minLength: 0)
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(palette.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.xs)
                    .fill(palette.surfaceRaised.opacity(0.6))
            )
    }
}
