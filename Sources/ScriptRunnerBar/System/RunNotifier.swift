import Foundation
import ScriptRunnerBarCore
import UserNotifications

@MainActor
final class RunNotifier {
    private var isAvailable = false

    func requestAuthorization() {
        // The framework throws outside an app bundle (e.g. `swift run`).
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in self?.isAvailable = granted }
        }
    }

    func notifyFinished(scriptName: String, outcome: RunOutcome) {
        let body: String
        switch outcome {
        case .success: body = "Finished successfully"
        case .failure(let code): body = "Failed with exit code \(code)"
        case .killed: return  // the user stopped it; no need to tell them
        }
        guard isAvailable else { return }

        let content = UNMutableNotificationContent()
        content.title = scriptName
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }
}
