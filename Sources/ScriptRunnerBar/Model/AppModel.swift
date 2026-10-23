import Foundation
import ScriptRunnerBarCore

struct AlertContent: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    var offersLoginItems = false
}

extension AlertContent {
    /// "Couldn\u{2019}t <action>", with the error's description underneath.
    init(couldnt action: String, error: Error) {
        self.init(title: "Couldn\u{2019}t \(action)", message: error.localizedDescription)
    }
}

struct NewScriptDraft {
    var language = ScriptLanguage.shell
    var name = ""
    var description = ""

    /// nil until the name has a letter or a digit.
    var filename: String? { ScriptCreator.filename(for: name, language: language) }
}

/// The single owner of UI state and the only entry point for actions. Runs
/// themselves live in `RunCoordinator`; this mirrors which scripts are running.
@MainActor @Observable
final class AppModel {
    @ObservationIgnored private let preferences: PreferenceStore
    @ObservationIgnored private let notifier = RunNotifier()
    @ObservationIgnored private let runs = RunCoordinator()
    @ObservationIgnored private var folderWatcher: FolderWatcher?

    private(set) var scriptsDirectory: URL
    private(set) var scripts: [Script] = []
    private(set) var runningIDs: Set<String> = []
    private(set) var arguments: [String: String] = [:]
    private(set) var tabs: [OutputTab] = []
    private(set) var launchAtLogin = LaunchAtLogin.isEnabled
    /// A counter, not a flag, so two requests in a row both register.
    private(set) var searchFocusRequest = 0

    var selection: Script.ID?
    var selectedTabID: OutputTab.ID?
    var filter = "" {
        didSet { if filter != oldValue { selectFirstMatchIfNeeded() } }
    }

    var alert: AlertContent?
    /// Set by the window itself. Commands that act on it are disabled while it's closed.
    var isMainWindowOpen = false
    var isChoosingFolder = false
    var isNamingScript = false
    var newScript = NewScriptDraft()
    var scriptPendingDeletion: Script?

    init(preferences: PreferenceStore = PreferenceStore()) {
        self.preferences = preferences
        scriptsDirectory = preferences.scriptsDirectory
    }

    func start() {
        runs.onRunStateChange = { [weak self] in self?.syncRunState() }
        notifier.requestAuthorization()
        watchScriptsFolder()
        reloadScripts()
    }

    // MARK: - Derived state

    var runningCount: Int { runningIDs.count }
    var hasRunningScripts: Bool { !runningIDs.isEmpty }
    var hasFinishedTabs: Bool { tabs.contains(where: \.isFinished) }
    var selectedTab: OutputTab? { tabs.first { $0.id == selectedTabID } ?? tabs.last }
    var visibleScripts: [Script] { scripts.filter { $0.matches(filter: filter) } }
    var sections: [ScriptSection] { ScriptSection.sections(of: visibleScripts) }

    func script(id: Script.ID) -> Script? { scripts.first { $0.id == id } }
    func isRunning(_ script: Script) -> Bool { runningIDs.contains(script.id) }
    func arguments(for script: Script) -> String { arguments[script.id] ?? "" }

    // MARK: - Scripts folder

    func setScriptsDirectory(_ url: URL) {
        preferences.scriptsDirectory = url
        scriptsDirectory = url
        watchScriptsFolder()
        reloadScripts()
    }

    func refresh() {
        reloadScripts()
    }

    private func watchScriptsFolder() {
        folderWatcher = FolderWatcher(url: scriptsDirectory) { [weak self] in self?.reloadIfChanged() }
    }

    private func reloadScripts(_ discovered: [Script]? = nil) {
        scripts = discovered ?? ScriptDiscovery.discoverScripts(in: scriptsDirectory)
        for script in scripts where arguments[script.id] == nil {
            arguments[script.id] = preferences.arguments(for: script.id)
        }
        if let selection, script(id: selection) == nil {
            self.selection = nil
        }
        selectFirstMatchIfNeeded()
    }

    /// FSEvents fires for any change; only rebuild when the scripts differ.
    private func reloadIfChanged() {
        let discovered = ScriptDiscovery.discoverScripts(in: scriptsDirectory)
        if discovered != scripts { reloadScripts(discovered) }
    }

    // MARK: - Filter and selection

    func focusSearch() {
        searchFocusRequest += 1
    }

    /// While filtering, keep a visible row selected so Return has a target.
    private func selectFirstMatchIfNeeded() {
        guard !filter.isEmpty else { return }
        let visible = visibleScripts
        if let selection, visible.contains(where: { $0.id == selection }) { return }
        selection = visible.first?.id
    }

    func runSelected() {
        guard let selection, let script = script(id: selection) else {
            SystemActions.beep()
            return
        }
        toggleRun(script)
    }

    /// Saved on every keystroke, so arguments survive a refresh or relaunch.
    func setArguments(_ value: String, for script: Script) {
        arguments[script.id] = value
        preferences.setArguments(value, for: script.id)
    }

    // MARK: - Running

    /// Stops a running script, makes a non-executable one executable, otherwise
    /// starts it.
    func toggleRun(_ script: Script) {
        if !script.isExecutable {
            makeExecutable(script)
        } else if let run = runs.activeRun(for: script) {
            run.stop()
        } else {
            startRun(script)
        }
    }

    func stopAll() {
        runs.stopAll()
    }

    private func makeExecutable(_ script: Script) {
        do {
            try script.makeExecutable()
            reloadIfChanged()
        } catch {
            alert = AlertContent(couldnt: "make \(script.filename) executable", error: error)
        }
    }

    /// Always a new tab, so a repeat run never overwrites output being compared.
    private func startRun(_ script: Script) {
        let arguments = arguments(for: script)
        let tab = OutputTab(script: script, arguments: arguments)
        tabs.append(tab)
        selectedTabID = tab.id

        do {
            tab.run = try runs.start(
                script,
                arguments: arguments,
                onOutput: { [weak tab] runs in tab?.append(runs) },
                onFinish: { [weak self, weak tab] outcome, duration in
                    tab?.finish(outcome, duration: duration)
                    self?.notifier.notifyFinished(scriptName: script.displayName, outcome: outcome)
                }
            )
        } catch {
            tab.append("Failed to start: \(error.localizedDescription)\n")
            tab.finish(.failure(exitCode: -1), duration: 0)
        }
    }

    private func syncRunState() {
        runningIDs = Set(runs.activeRuns.map(\.script.id))
    }

    // MARK: - Output tabs

    func select(_ tab: OutputTab) {
        selectedTabID = tab.id
    }

    /// Closing a tab stops its run: a hidden run could never be stopped.
    func close(_ tab: OutputTab) {
        tab.run?.stop()
        let index = tabs.firstIndex { $0.id == tab.id }
        tabs.removeAll { $0.id == tab.id }
        if selectedTabID == tab.id {
            selectedTabID = index.flatMap { tabs.indices.contains($0) ? tabs[$0].id : tabs.last?.id }
        }
    }

    func closeSelectedTab() {
        if let tab = selectedTab { close(tab) }
    }

    func closeFinishedTabs() {
        tabs.filter(\.isFinished).forEach(close)
    }

    func selectNextTab() { cycleTab(by: 1) }
    func selectPreviousTab() { cycleTab(by: -1) }

    private func cycleTab(by step: Int) {
        guard tabs.count > 1, let current = selectedTab,
              let index = tabs.firstIndex(where: { $0.id == current.id }) else { return }
        selectedTabID = tabs[(index + step + tabs.count) % tabs.count].id
    }

    func copySelectedTabOutput() {
        if let tab = selectedTab { SystemActions.copyToClipboard(tab.text) }
    }

    func clearSelectedTabOutput() {
        selectedTab?.clear()
    }

    // MARK: - Script files

    /// Keeps the language from last time: people tend to create several in a row.
    func promptForNewScript() {
        newScript.name = ""
        newScript.description = ""
        isNamingScript = true
    }

    var newScriptFileExists: Bool {
        guard let filename = newScript.filename else { return false }
        return FileManager.default.fileExists(atPath: scriptsDirectory.appendingPathComponent(filename).path)
    }

    var canCreateScript: Bool { newScript.filename != nil && !newScriptFileExists }

    func createScript() {
        guard canCreateScript else { return }
        isNamingScript = false
        do {
            let url = try ScriptCreator.createScript(
                named: newScript.name,
                description: newScript.description,
                language: newScript.language,
                in: scriptsDirectory
            )
            reloadScripts()
            SystemActions.open(url)
        } catch {
            alert = AlertContent(couldnt: "create the script", error: error)
        }
    }

    func canDelete(_ script: Script) -> Bool { !isRunning(script) }

    func requestDelete(_ script: Script) {
        if canDelete(script) { scriptPendingDeletion = script }
    }

    func confirmDelete(_ script: Script) {
        scriptPendingDeletion = nil
        do {
            try script.moveToTrash()
            setArguments("", for: script)
            reloadScripts()
        } catch {
            alert = AlertContent(couldnt: "move \(script.filename) to the Trash", error: error)
        }
    }

    func revealScriptsFolder() { SystemActions.open(scriptsDirectory) }
    func edit(_ script: Script) { SystemActions.open(script.url) }
    func reveal(_ script: Script) { SystemActions.reveal(script.url) }
    func copyPath(of script: Script) { SystemActions.copyToClipboard(script.url.path) }

    // MARK: - Launch at login

    func toggleLaunchAtLogin() {
        do {
            try LaunchAtLogin.toggle()
        } catch {
            alert = AlertContent(
                title: "Couldn\u{2019}t change the login item",
                message: """
                \(error.localizedDescription)

                This usually means the app isn\u{2019}t in /Applications or ~/Applications yet. \
                You can also set it in System Settings \u{203A} General \u{203A} Login Items.
                """,
                offersLoginItems: true
            )
        }
        launchAtLogin = LaunchAtLogin.isEnabled
    }
}
