import SwiftUI

struct MainView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismissWindow) private var dismissWindow
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        @Bindable var model = model

        VSplitView {
            ScriptListView()
                .frame(minHeight: 140, idealHeight: 340)
            OutputPaneView()
                .frame(minHeight: 120, idealHeight: 220)
        }
        .frame(minWidth: 560, minHeight: 440)
        .navigationTitle(model.scriptsDirectory.lastPathComponent)
        .navigationSubtitle((model.scriptsDirectory.path as NSString).abbreviatingWithTildeInPath)
        .searchable(text: $model.filter, placement: .toolbar, prompt: "Filter")
        .searchFocused($isSearchFocused)
        // Return runs the selection: the first match while filtering.
        .onSubmit(of: .search) { model.runSelected() }
        // Esc clears the filter, then hides the window. A cancel-action key
        // equivalent, because onExitCommand never fires in the toolbar search field.
        .background {
            Button("Clear Filter or Hide Window") {
                if model.filter.isEmpty { dismissWindow(id: WindowID.main) } else { model.filter = "" }
            }
            .keyboardShortcut(.cancelAction)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
        .onAppear {
            isSearchFocused = true
            model.isMainWindowOpen = true
        }
        .onDisappear { model.isMainWindowOpen = false }
        .toolbar { toolbarContent }
        .onChange(of: model.searchFocusRequest) { isSearchFocused = true }
        .scriptsFolderPicker(isPresented: $model.isChoosingFolder, model: model)
        .sheet(isPresented: $model.isNamingScript) { NewScriptSheet() }
        .confirmationDialog(
            "Move \u{201C}\(model.scriptPendingDeletion?.displayName ?? "")\u{201D} to the Trash?",
            isPresented: Binding(
                get: { model.scriptPendingDeletion != nil },
                set: { if !$0 { model.scriptPendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: model.scriptPendingDeletion
        ) { script in
            Button("Move to Trash", role: .destructive) { model.confirmDelete(script) }
            Button("Cancel", role: .cancel) {}
        } message: { script in
            Text("\(script.filename) can be restored from the Trash.")
        }
        .appAlert(model)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            toolbarButton(.chooseFolder, symbol: "folder")
            toolbarButton(.refresh, symbol: "arrow.clockwise")
            toolbarButton(.newScript, symbol: "plus")
        }

        ToolbarItem {
            Menu {
                ActionButton(action: .revealFolder, model: model)
                Divider()
                ActionButton(action: .stopAll, model: model)
                Divider()
                ActionButton(action: .copyOutput, model: model)
                ActionButton(action: .clearOutput, model: model)
                ActionButton(action: .closeTab, model: model)
                ActionButton(action: .closeFinishedTabs, model: model)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .help("More Actions")
        }
    }

    private func toolbarButton(_ action: AppAction, symbol: String) -> some View {
        Button { action.perform(in: model) } label: {
            Label(action.title, systemImage: symbol)
        }
        .help(action.tooltip)
    }
}
