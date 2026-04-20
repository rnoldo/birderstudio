import SwiftUI
import BirderCore
import BirderUI

@main
struct BirderStudioApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup("Birder Studio") {
            RootView()
                .environmentObject(env)
                .environment(\.paletteSurface, .dark)
                .frame(minWidth: 960, minHeight: 600)
                .task { await env.bootstrap() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1440, height: 900)
    }
}
