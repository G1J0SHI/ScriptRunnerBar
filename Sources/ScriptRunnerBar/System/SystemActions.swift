import AppKit

/// The macOS services SwiftUI has no API for.
@MainActor
enum SystemActions {
    private static var iconCache: [String: NSImage] = [:]

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Finder's icon for the file, cached because lists redraw often.
    static func icon(for url: URL) -> NSImage {
        if let cached = iconCache[url.path] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        iconCache[url.path] = icon
        return icon
    }

    static func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    /// Fires the app menu's Settings item (found by its Command-comma key), which
    /// SwiftUI's Settings scene provides; there is no public call to open it.
    static func showSettings() {
        NSApp.activate()
        let item = NSApp.mainMenu?.items.first?.submenu?.items.first { $0.keyEquivalent == "," }
        if let item, let action = item.action { NSApp.sendAction(action, to: item.target, from: item) }
    }

    /// Reopening the app is what a Dock click does, and macOS always honours it;
    /// `NSApp.activate()` is refused while another app is active. The window follows
    /// you to the current desktop, but from a full-screen app macOS still switches Space.
    static func showMainWindow() {
        NSApp.windows.first { $0.identifier?.rawValue == WindowID.main }?.collectionBehavior.insert(.moveToActiveSpace)
        NSWorkspace.shared.open(Bundle.main.bundleURL)
    }

    static func beep() {
        NSSound.beep()
    }
}
