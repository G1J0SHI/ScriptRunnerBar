import SwiftUI

struct ActionButton: View {
    let action: AppAction
    let model: AppModel

    var body: some View {
        Button(action.title) { action.perform(in: model) }
            .keyboardShortcut(action.shortcut)
            .disabled(!action.isEnabled(in: model))
    }
}

/// The menu bar menus; they also make the shortcuts work.
struct AppCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            ActionButton(action: .newScript, model: model)
            ActionButton(action: .chooseFolder, model: model)
            ActionButton(action: .revealFolder, model: model)
            Divider()
            ActionButton(action: .refresh, model: model)
        }

        CommandGroup(after: .textEditing) {
            ActionButton(action: .find, model: model)
        }

        CommandGroup(replacing: .help) {}

        CommandMenu("Run") {
            ActionButton(action: .stopAll, model: model)
            Divider()
            ActionButton(action: .copyOutput, model: model)
            ActionButton(action: .clearOutput, model: model)
            Divider()
            ActionButton(action: .nextTab, model: model)
            ActionButton(action: .previousTab, model: model)
            ActionButton(action: .closeTab, model: model)
            ActionButton(action: .closeFinishedTabs, model: model)
        }
    }
}
