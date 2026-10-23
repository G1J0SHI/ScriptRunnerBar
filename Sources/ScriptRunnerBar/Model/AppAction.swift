import SwiftUI

/// Every action with a keyboard shortcut, defined once. Feeds the menu bar
/// commands, the toolbar's More menu and toolbar tooltips, so their titles,
/// shortcuts and enabled states can't disagree.
enum AppAction: CaseIterable {
    case newScript, chooseFolder, revealFolder, refresh, find, stopAll
    case copyOutput, clearOutput, nextTab, previousTab, closeTab, closeFinishedTabs

    var title: String {
        switch self {
        case .newScript: "New Script\u{2026}"
        case .chooseFolder: "Choose Scripts Folder\u{2026}"
        case .revealFolder: "Show Scripts Folder in Finder"
        case .refresh: "Refresh"
        case .find: "Filter Scripts"
        case .stopAll: "Stop All Running Scripts"
        case .copyOutput: "Copy Tab Output"
        case .clearOutput: "Clear Tab Output"
        case .nextTab: "Show Next Tab"
        case .previousTab: "Show Previous Tab"
        case .closeTab: "Close Tab"
        case .closeFinishedTabs: "Close Finished Tabs"
        }
    }

    private var key: KeyEquivalent {
        switch self {
        case .newScript: "n"
        case .find: "f"
        case .chooseFolder: "o"
        case .revealFolder, .refresh: "r"
        case .stopAll: "."
        case .copyOutput: "c"
        case .clearOutput: "k"
        case .nextTab: "]"
        case .previousTab: "["
        case .closeTab, .closeFinishedTabs: "w"
        }
    }

    private var modifiers: EventModifiers {
        switch self {
        case .newScript, .refresh, .find, .stopAll, .clearOutput: .command
        case .chooseFolder, .revealFolder, .copyOutput, .nextTab, .previousTab, .closeTab: [.command, .shift]
        case .closeFinishedTabs: [.command, .option, .shift]
        }
    }

    var shortcut: KeyboardShortcut {
        KeyboardShortcut(key, modifiers: modifiers)
    }

    /// e.g. "Refresh (\u{2318}R)", modifiers in Apple's canonical order.
    var tooltip: String {
        let symbols: [(EventModifiers, String)] = [
            (.control, "\u{2303}"), (.option, "\u{2325}"), (.shift, "\u{21E7}"), (.command, "\u{2318}"),
        ]
        let shortcutText = symbols.filter { modifiers.contains($0.0) }.map(\.1).joined()
            + String(key.character).uppercased()
        let name = title.hasSuffix("\u{2026}") ? String(title.dropLast()) : title
        return "\(name) (\(shortcutText))"
    }

    @MainActor
    func isEnabled(in model: AppModel) -> Bool {
        switch self {
        case .stopAll: model.hasRunningScripts
        case .copyOutput, .clearOutput, .closeTab: model.selectedTab != nil
        case .nextTab, .previousTab: model.tabs.count > 1
        case .closeFinishedTabs: model.hasFinishedTabs
        case .newScript, .chooseFolder, .find: model.isMainWindowOpen
        case .revealFolder, .refresh: true
        }
    }

    @MainActor
    func perform(in model: AppModel) {
        switch self {
        case .newScript: model.promptForNewScript()
        case .chooseFolder: model.isChoosingFolder = true
        case .revealFolder: model.revealScriptsFolder()
        case .refresh: model.refresh()
        case .find: model.focusSearch()
        case .stopAll: model.stopAll()
        case .copyOutput: model.copySelectedTabOutput()
        case .clearOutput: model.clearSelectedTabOutput()
        case .nextTab: model.selectNextTab()
        case .previousTab: model.selectPreviousTab()
        case .closeTab: model.closeSelectedTab()
        case .closeFinishedTabs: model.closeFinishedTabs()
        }
    }
}
