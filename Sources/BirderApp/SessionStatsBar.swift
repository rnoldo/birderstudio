import SwiftUI
import BirderUI

@MainActor
struct SessionStatsBar: View {
    let total: Int
    let accepted: Int
    let rejected: Int
    let scenes: Int
    let analyzed: Int
    let avgQuality: Double?

    @Environment(\.paletteSurface) private var palette

    var body: some View {
        HStack(spacing: 0) {
            stat(label: "Picks", value: "\(accepted)", color: Palette.Semantic.accept)
            divider
            stat(label: "Rejects", value: "\(rejected)", color: Palette.Semantic.reject)
            divider
            stat(label: "Scenes", value: "\(scenes)", color: palette.textSecondary)
            if let q = avgQuality {
                divider
                stat(label: "Avg Q", value: String(format: "%.0f", q * 100), color: palette.textSecondary)
            }
            divider
            analyzedStat
            Spacer()
        }
        .font(.system(size: 10))
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
        .background(palette.canvasBackground.opacity(0.6))
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.border)
            .frame(width: 1, height: 10)
            .padding(.horizontal, Spacing.sm)
    }

    private var analyzedStat: some View {
        HStack(spacing: 3) {
            if analyzed < total {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.7)
            }
            Text(analyzed < total ? "Analyzed \(analyzed)/\(total)" : "Analyzed \(analyzed)")
                .foregroundStyle(analyzed < total ? Palette.Accent.amber : palette.textTertiary)
        }
    }

    private func stat(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .foregroundStyle(palette.textTertiary)
                .kerning(0.4)
            Text(value)
                .foregroundStyle(color)
                .fontWeight(.semibold)
                .fontDesign(.monospaced)
        }
    }
}
