import SwiftUI

/// Window identifiers, shared by the scene and everything that finds or closes it.
enum WindowID {
    static let main = "main"
}

@main
struct ScriptRunnerBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        let model = appDelegate.model

        Window("ScriptRunnerBar", id: WindowID.main) {
            MainView().environment(model)
        }
        .defaultSize(width: 700, height: 600)
        .windowResizability(.contentMinSize)
        .commands { AppCommands(model: model) }

        Settings {
            SettingsView().environment(model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
        statusItem = StatusItemController(model: model)
    }

    /// Closing the window leaves the app, and any running script, alive.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// No script outlives the app.
    func applicationWillTerminate(_ notification: Notification) {
        model.stopAll()
    }
}
