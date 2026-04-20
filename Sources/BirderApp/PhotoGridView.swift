import SwiftUI
import AppKit
import BirderCore
import BirderUI

@MainActor
struct PhotoGridView: View {
    let photos: [Photo]
    let storage: StorageLocations
    @Binding var selectedPhotoID: UUID?
    var rating: (UUID) -> PhotoRating? = { _ in nil }
    var analysis: (UUID) -> PhotoAnalysis? = { _ in nil }
    var onKey: (Character) -> Bool = { _ in false }

    @FocusState private var focused: Bool

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
                            isSelected: selectedPhotoID == photo.id,
                            rating: rating(photo.id),
                            analysis: analysis(photo.id)
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
            .focusable()
            .focused($focused)
            .onAppear { focused = true }
            .onKeyPress(.leftArrow) { moveSelection(-1); return .handled }
            .onKeyPress(.rightArrow) { moveSelection(+1); return .handled }
            .onKeyPress { press in
                guard let ch = press.characters.first else { return .ignored }
                return onKey(ch) ? .handled : .ignored
            }
        }
    }

    private func moveSelection(_ offset: Int) {
        guard !photos.isEmpty else { return }
        guard let current = selectedPhotoID,
              let idx = photos.firstIndex(where: { $0.id == current }) else {
            selectedPhotoID = photos.first?.id
            return
        }
        let newIdx = min(max(idx + offset, 0), photos.count - 1)
        if newIdx != idx {
            selectedPhotoID = photos[newIdx].id
        }
    }
}

@MainActor
private struct PhotoThumbnailCell: View {
    let photo: Photo
    let thumbnailURL: URL
    let isSelected: Bool
    let rating: PhotoRating?
    let analysis: PhotoAnalysis?

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
        .opacity(rating?.decision == .rejected ? 0.5 : 1.0)
    }

    private var borderColor: Color {
        if isSelected { return Palette.Accent.amber }
        switch rating?.decision {
        case .accepted: return Palette.Semantic.accept
        case .rejected: return Palette.Semantic.reject
        default: return Color.white.opacity(0.04)
        }
    }

    private var borderWidth: CGFloat {
        if isSelected { return 2 }
        return rating?.decision != nil && rating?.decision != .unrated ? 1.5 : BorderWidth.hair
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
            topLeftBadges
            topRightBadges
            bottomBar
        }
        .aspectRatio(3.0 / 2.0, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
        .shadow(
            color: isSelected ? Palette.Accent.amber.opacity(0.35) : .clear,
            radius: isSelected ? 8 : 0
        )
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.15), value: rating?.decision)
    }

    @ViewBuilder
    private var topLeftBadges: some View {
        VStack(alignment: .leading, spacing: 3) {
            if analysis?.isSceneBest == true {
                badge(icon: "star.fill", text: "BEST", color: Palette.Accent.amber)
            }
            if let decision = rating?.decision, decision != .unrated {
                switch decision {
                case .accepted:
                    badge(icon: "checkmark", text: "PICK", color: Palette.Semantic.accept)
                case .rejected:
                    badge(icon: "xmark", text: "REJ", color: Palette.Semantic.reject)
                case .unrated:
                    EmptyView()
                }
            }
        }
        .padding(Spacing.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var topRightBadges: some View {
        VStack(alignment: .trailing, spacing: 3) {
            if photo.format.isRaw {
                Text("RAW")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .kerning(0.6)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .foregroundStyle(Palette.Accent.amber)
            }
            if let stars = rating?.star, stars > 0 {
                starsBadge(count: stars)
            }
        }
        .padding(Spacing.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if let overall = analysis?.quality.overall {
            VStack {
                Spacer()
                HStack(spacing: 3) {
                    Text("Q")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule()
                                .fill(qualityColor(overall))
                                .frame(width: geo.size.width * overall)
                        }
                    }
                    .frame(height: 3)
                    Text("\(Int(overall * 100))")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 18, alignment: .trailing)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }
        }
    }

    private func qualityColor(_ score: Double) -> Color {
        if score >= 0.7 { return Palette.Semantic.accept }
        if score >= 0.45 { return Palette.Accent.amber }
        return Palette.Semantic.reject
    }

    private func badge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8, weight: .bold))
            Text(text).font(.system(size: 9, weight: .bold, design: .monospaced)).kerning(0.6)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.black.opacity(0.55)))
        .foregroundStyle(color)
    }

    private func starsBadge(count: Int) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<count, id: \.self) { _ in
                Image(systemName: "star.fill").font(.system(size: 8))
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.black.opacity(0.55)))
        .foregroundStyle(Palette.Accent.amber)
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
