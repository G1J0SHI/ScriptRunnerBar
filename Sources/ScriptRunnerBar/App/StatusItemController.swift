import AppKit

/// The menu bar icon: a click shows the window, a right-click (or Control-click)
/// a small menu. Filled while anything runs.
@MainActor
final class StatusItemController: NSObject {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    init(model: AppModel) {
        self.model = model
        super.init()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(clicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateIcon()
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if wantsMenu { showMenu() } else { SystemActions.showMainWindow() }
    }

    /// Attached only for this click; a permanent menu would also take the left click.
    private func showMenu() {
        statusItem.menu = makeMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(item("Open ScriptRunnerBar", #selector(openWindow)))
        let stop = item(AppAction.stopAll.title, #selector(stopAll))
        stop.isEnabled = AppAction.stopAll.isEnabled(in: model)
        menu.addItem(stop)
        menu.addItem(.separator())
        menu.addItem(item("About ScriptRunnerBar", #selector(about)))
        menu.addItem(item("Settings\u{2026}", #selector(settings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit ScriptRunnerBar", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
        return menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "", target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target ?? self
        return item
    }

    @objc private func openWindow() { SystemActions.showMainWindow() }
    @objc private func stopAll() { AppAction.stopAll.perform(in: model) }
    @objc private func about() { SystemActions.showAbout() }
    @objc private func settings() { SystemActions.showSettings() }

    private func updateIcon() {
        let count = withObservationTracking {
            model.runningCount
        } onChange: { [weak self] in
            Task { @MainActor in self?.updateIcon() }
        }
        let label = count > 0 ? "ScriptRunnerBar, \(count) running" : "ScriptRunnerBar"
        let image = NSImage(systemSymbolName: count > 0 ? "terminal.fill" : "terminal", accessibilityDescription: label)
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = label
    }
}
