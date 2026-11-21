import SwiftUI
import AppKit

@main
struct PlaylistGrabApp: App {
    @StateObject private var state = AppState()
    @StateObject private var tools = ToolManager.shared

    init() {
        UserDefaults.standard.register(defaults: AppDefaults.registered)

        // Stop any running downloads when the app quits.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { _ in
            RunnerRegistry.shared.cancelAll()
        }
    }

    var body: some Scene {
        WindowGroup("PlaylistGrab") {
            ContentView()
                .environmentObject(state)
                .environmentObject(tools)
                .frame(minWidth: 780, minHeight: 540)
                .task {
                    await tools.prepareOnLaunch()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    state.openSettings(tab: .general)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(tools)
        }
    }
}
