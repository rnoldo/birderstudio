import SwiftUI
import BirderCore
import BirderUI

enum CullFilter: String, CaseIterable, Identifiable {
    case all
    case picks
    case rejects
    case unrated
    case sceneBest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .picks: "Picks"
        case .rejects: "Rejects"
        case .unrated: "Unrated"
        case .sceneBest: "Scene Best"
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.grid.2x2"
        case .picks: "checkmark.circle"
        case .rejects: "xmark.circle"
        case .unrated: "circle.dashed"
        case .sceneBest: "star"
        }
    }

    func includes(photo: Photo, rating: PhotoRating?, analysis: PhotoAnalysis?) -> Bool {
        switch self {
        case .all: return true
        case .picks: return rating?.decision == .accepted
        case .rejects: return rating?.decision == .rejected
        case .unrated: return rating?.decision == nil || rating?.decision == .unrated
        case .sceneBest: return analysis?.isSceneBest == true
        }
    }
}

@MainActor
struct CullFilterBar: View {
    @Binding var selected: CullFilter
    let counts: [CullFilter: Int]

    @Environment(\.paletteSurface) private var palette

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(CullFilter.allCases) { filter in
                filterChip(filter)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(palette.surfaceRaised.opacity(0.5))
    }

    private func filterChip(_ filter: CullFilter) -> some View {
        let isActive = selected == filter
        let count = counts[filter] ?? 0
        return Button {
            withAnimation(.easeOut(duration: 0.12)) { selected = filter }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: filter.symbol).font(.system(size: 10, weight: .medium))
                Text(filter.title).font(.system(size: 11, weight: .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(palette.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(palette.surfaceRaised.opacity(isActive ? 0.3 : 0.6))
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(isActive ? Palette.Accent.amberSoft : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(
                    isActive ? Palette.Accent.amber : palette.border.opacity(0.4),
                    lineWidth: isActive ? 1 : 0.6
                )
            )
            .foregroundStyle(isActive ? Palette.Accent.amber : palette.textSecondary)
        }
        .buttonStyle(.plain)
        .help(filter.title)
    }
}
