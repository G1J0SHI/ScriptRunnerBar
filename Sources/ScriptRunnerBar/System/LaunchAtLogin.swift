import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLogin {
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func toggle() throws {
        let service = SMAppService.mainApp
        if service.status == .enabled {
            try service.unregister()
        } else {
            try service.register()
        }
    }
}
