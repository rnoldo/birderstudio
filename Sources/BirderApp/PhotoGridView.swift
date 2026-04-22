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

    /// Scene-grouped, display-ordered view of `photos`.
    /// - Photos with a `sceneID` are grouped; groups sort by earliest capture.
    /// - Photos without analysis or without a `sceneID` land in a leading
    ///   "Unassigned" group so they remain visible during import/analysis.
    /// - Within each group photos sort by `quality.overall` descending, so the
    ///   AI-best is always first.
    private var groups: [SceneGroup] { SceneGroup.build(photos: photos, analysis: analysis) }

    /// Flattened order that ← → navigation follows.
    private var orderedPhotoIDs: [UUID] {
        groups.flatMap { $0.photos.map(\.id) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Spacing.lg, pinnedViews: [.sectionHeaders]) {
                    ForEach(groups) { group in
                        Section {
                            LazyVGrid(columns: columns, spacing: Spacing.lg) {
                                ForEach(group.photos) { photo in
                                    PhotoThumbnailCell(
                                        photo: photo,
                                        thumbnailURL: storage.thumbnailURL(for: photo.id),
                                        isSelected: selectedPhotoID == photo.id,
                                        rating: rating(photo.id),
                                        analysis: analysis(photo.id)
                                    )
                                    .id(photo.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedPhotoID = photo.id }
                                }
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.bottom, Spacing.sm)
                        } header: {
                            SceneSectionHeader(group: group)
                        }
                    }
                }
                .padding(.vertical, Spacing.md)
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
            .onKeyPress(.leftArrow) { moveWithinOrder(-1); return .handled }
            .onKeyPress(.rightArrow) { moveWithinOrder(+1); return .handled }
            .onKeyPress(.upArrow) { jumpScene(-1); return .handled }
            .onKeyPress(.downArrow) { jumpScene(+1); return .handled }
            .onKeyPress { press in
                guard let ch = press.characters.first else { return .ignored }
                return onKey(ch) ? .handled : .ignored
            }
        }
    }

    private func moveWithinOrder(_ offset: Int) {
        let order = orderedPhotoIDs
        guard !order.isEmpty else { return }
        guard let current = selectedPhotoID,
              let idx = order.firstIndex(of: current) else {
            selectedPhotoID = order.first
            return
        }
        let newIdx = min(max(idx + offset, 0), order.count - 1)
        if newIdx != idx { selectedPhotoID = order[newIdx] }
    }

    private func jumpScene(_ offset: Int) {
        let gs = groups
        guard !gs.isEmpty else { return }
        let currentIdx: Int
        if let selected = selectedPhotoID,
           let gi = gs.firstIndex(where: { $0.photos.contains(where: { $0.id == selected }) }) {
            currentIdx = gi
        } else {
            currentIdx = 0
        }
        let newIdx = min(max(currentIdx + offset, 0), gs.count - 1)
        if let best = gs[newIdx].photos.first?.id {
            selectedPhotoID = best
        }
    }
}

// MARK: - Scene grouping

struct SceneGroup: Identifiable {
    /// `nil` for the synthetic "Unassigned" bucket (photos not yet analyzed
    /// or without a scene ID). Otherwise the scene's UUID.
    let sceneID: UUID?
    let index: Int
    let photos: [Photo]
    let earliest: Date
    let latest: Date

    var id: String { sceneID?.uuidString ?? "__unassigned__" }

    var displayTitle: String {
        sceneID == nil ? "Unassigned" : "Scene \(index)"
    }

    var timeRange: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        let start = f.string(from: earliest)
        let end = f.string(from: latest)
        return start == end ? start : "\(start)–\(end)"
    }

    var countLabel: String {
        photos.count == 1 ? "1 photo" : "\(photos.count) photos"
    }

    static func build(
        photos: [Photo],
        analysis: (UUID) -> PhotoAnalysis?
    ) -> [SceneGroup] {
        var buckets: [UUID?: [Photo]] = [:]
        for photo in photos {
            let sid = analysis(photo.id)?.sceneID
            buckets[sid, default: []].append(photo)
        }

        let scored: [(UUID?, [Photo])] = buckets.map { key, ps in
            let sorted = ps.sorted { a, b in
                let aq = analysis(a.id)?.quality.overall ?? -1
                let bq = analysis(b.id)?.quality.overall ?? -1
                if aq != bq { return aq > bq }
                return a.captured < b.captured
            }
            return (key, sorted)
        }

        let ordered = scored.sorted { lhs, rhs in
            // Unassigned bucket first; real scenes then by earliest capture.
            switch (lhs.0, rhs.0) {
            case (nil, nil): return false
            case (nil, _): return true
            case (_, nil): return false
            default:
                let le = lhs.1.map(\.captured).min() ?? .distantFuture
                let re = rhs.1.map(\.captured).min() ?? .distantFuture
                return le < re
            }
        }

        var index = 0
        return ordered.map { sid, ps in
            if sid != nil { index += 1 }
            let times = ps.map(\.captured)
            return SceneGroup(
                sceneID: sid,
                index: index,
                photos: ps,
                earliest: times.min() ?? .distantPast,
                latest: times.max() ?? .distantPast
            )
        }
    }
}

@MainActor
private struct SceneSectionHeader: View {
    let group: SceneGroup
    @Environment(\.paletteSurface) private var palette

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(group.displayTitle)
                .font(.system(size: 12, weight: .semibold))
                .kerning(0.4)
                .foregroundStyle(palette.textPrimary)
            Text("·").foregroundStyle(palette.textTertiary)
            Text(group.timeRange)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(palette.textSecondary)
            Text("·").foregroundStyle(palette.textTertiary)
            Text(group.countLabel)
                .font(.system(size: 11))
                .foregroundStyle(palette.textSecondary)
            if group.sceneID != nil, let best = group.photos.first {
                Text("·").foregroundStyle(palette.textTertiary)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.Accent.amber)
                    Text("AI pick: \(best.fileURLCached.lastPathComponent)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(palette.surfaceRaised.opacity(0.75))
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.border.opacity(0.4)).frame(height: 0.5)
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
            if let analysis {
                starsBadge(count: AIStar.stars(for: analysis))
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
