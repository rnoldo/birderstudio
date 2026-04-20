import SwiftUI
import BirderCore
import BirderUI

@MainActor
struct SessionSidebar: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.paletteSurface) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.4)
            if env.sessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
        .background(palette.surfaceElevated)
    }

    private var header: some View {
        HStack {
            Text("Sessions")
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.8)
                .textCase(.uppercase)
                .foregroundStyle(palette.textSecondary)
            Spacer()
            Button {
                Task { await env.createSession() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("New session")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private var sessionList: some View {
        List(selection: $env.selectedSessionID) {
            ForEach(env.sessions) { session in
                SessionRow(session: session)
                    .tag(session.id as Session.ID?)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            Task { await env.deleteSession(session.id) }
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Spacer()
            Text("No sessions")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.textSecondary)
            Text("Click  +  to create one")
                .font(.system(size: 11))
                .foregroundStyle(palette.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SessionRow: View {
    let session: Session
    @Environment(\.paletteSurface) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Text(session.dateStart.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 11))
                .foregroundStyle(palette.textTertiary)
        }
        .padding(.vertical, 2)
    }
}
