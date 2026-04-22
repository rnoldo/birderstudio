import SwiftUI
import BirderCore
import BirderUI

@MainActor
struct SearchPanel: View {
    @Binding var isPresented: Bool
    let sessions: [Session]
    let photos: [Photo]
    let onSelectSession: (UUID) -> Void
    let onSelectPhoto: (UUID) -> Void

    @State private var query = ""
    @State private var highlightedIndex = 0
    @FocusState private var fieldFocused: Bool

    @Environment(\.paletteSurface) private var palette

    private var results: [SearchResult] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        var out: [SearchResult] = []
        if q.isEmpty {
            // Show recent sessions when query is blank
            out += sessions.prefix(5).map { .session($0) }
        } else {
            out += sessions.filter {
                $0.name.lowercased().contains(q)
            }.map { .session($0) }
            out += photos.filter {
                $0.fileURLCached.lastPathComponent.lowercased().contains(q) ||
                $0.captured.formatted(date: .abbreviated, time: .omitted).lowercased().contains(q) ||
                ($0.exif.camera.model ?? "").lowercased().contains(q)
            }.prefix(10).map { .photo($0) }
        }
        return Array(out.prefix(12))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                searchField
                if !results.isEmpty {
                    Divider().opacity(0.3)
                    resultsList
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(palette.surfaceRaised)
                    .shadow(color: .black.opacity(0.4), radius: 24, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .strokeBorder(palette.border, lineWidth: BorderWidth.thin)
            )
            .frame(width: 520)
            .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { fieldFocused = true }
        .onKeyPress(.escape) { isPresented = false; return .handled }
        .onKeyPress(.upArrow) {
            if highlightedIndex > 0 { highlightedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if highlightedIndex < results.count - 1 { highlightedIndex += 1 }
            return .handled
        }
        .onKeyPress(.return) {
            if results.indices.contains(highlightedIndex) {
                activate(results[highlightedIndex])
            }
            return .handled
        }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.textSecondary)
            TextField("Search sessions, photos…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(palette.textPrimary)
                .focused($fieldFocused)
                .onChange(of: query) { highlightedIndex = 0 }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(palette.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { idx, result in
                    resultRow(result, highlighted: idx == highlightedIndex)
                        .onTapGesture { activate(result) }
                        .onHover { if $0 { highlightedIndex = idx } }
                }
            }
            .padding(.vertical, Spacing.xs)
        }
        .frame(maxHeight: 320)
    }

    private func resultRow(_ result: SearchResult, highlighted: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: result.icon)
                .font(.system(size: 13))
                .foregroundStyle(highlighted ? Palette.Accent.amber : palette.textSecondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                if let sub = result.subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if highlighted {
                Text("↵")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(palette.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            highlighted
                ? RoundedRectangle(cornerRadius: CornerRadius.xs).fill(Palette.Accent.amberSoft)
                : RoundedRectangle(cornerRadius: CornerRadius.xs).fill(Color.clear)
        )
        .padding(.horizontal, Spacing.xs)
        .contentShape(Rectangle())
    }

    private func activate(_ result: SearchResult) {
        switch result {
        case .session(let s): onSelectSession(s.id)
        case .photo(let p):   onSelectPhoto(p.id)
        }
        isPresented = false
    }
}

private enum SearchResult: Identifiable {
    case session(Session)
    case photo(Photo)

    var id: String {
        switch self {
        case .session(let s): "s-\(s.id)"
        case .photo(let p):   "p-\(p.id)"
        }
    }
    var icon: String {
        switch self {
        case .session: "calendar"
        case .photo:   "photo"
        }
    }
    var title: String {
        switch self {
        case .session(let s): s.name
        case .photo(let p):   p.fileURLCached.lastPathComponent
        }
    }
    var subtitle: String? {
        switch self {
        case .session(let s):
            return s.dateStart.formatted(date: .long, time: .omitted)
        case .photo(let p):
            let parts = [
                p.captured.formatted(date: .abbreviated, time: .shortened),
                p.exif.camera.model
            ].compactMap { $0 }
            return parts.joined(separator: " · ")
        }
    }
}
