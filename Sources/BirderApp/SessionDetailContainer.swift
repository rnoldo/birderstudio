import SwiftUI
import BirderCore
import BirderUI

@MainActor
struct SessionDetailContainer: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.paletteSurface) private var palette

    var body: some View {
        Group {
            if let id = env.selectedSessionID,
               let session = env.sessions.first(where: { $0.id == id }) {
                SessionDetailView(session: session)
                    .id(session.id)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.canvasBackground)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Text("Birder Studio")
                .font(.system(size: 28, weight: .semibold, design: .serif))
            Text("Pick a session, or create one from the sidebar.")
                .font(.system(size: 13))
                .foregroundStyle(palette.textSecondary)
        }
    }
}
