import SwiftUI
import BirderCore
import BirderUI

struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.paletteSurface) private var palette

    var body: some View {
        ZStack {
            palette.canvasBackground.ignoresSafeArea()
            content
        }
        .foregroundStyle(palette.textPrimary)
        .background(
            WindowAccessor { window in
                WindowDropHandler.shared.install(in: window)
            }
        )
    }

    @ViewBuilder private var content: some View {
        if let error = env.bootstrapError {
            ErrorView(message: error)
        } else if env.database == nil {
            LoadingView()
        } else {
            MainShell()
        }
    }
}

private struct LoadingView: View {
    @Environment(\.paletteSurface) private var palette

    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView().controlSize(.small)
            Text("Opening library…")
                .font(.system(size: 13))
                .foregroundStyle(palette.textSecondary)
        }
    }
}

private struct ErrorView: View {
    let message: String
    @Environment(\.paletteSurface) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Can't start Birder Studio")
                .font(.system(size: 16, weight: .semibold))
            Text(message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(palette.textSecondary)
                .textSelection(.enabled)
        }
        .padding(Spacing.lg)
    }
}

private struct MainShell: View {
    @Environment(\.paletteSurface) private var palette

    var body: some View {
        NavigationSplitView {
            SessionSidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            SessionDetailContainer()
        }
        .navigationSplitViewStyle(.balanced)
    }
}
