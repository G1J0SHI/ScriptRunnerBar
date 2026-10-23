import ScriptRunnerBarCore
import SwiftUI

struct ScriptListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        List(selection: $model.selection) {
            ForEach(model.sections) { section in
                Section {
                    ForEach(section.scripts) { script in
                        ScriptRow(script: script)
                    }
                } header: {
                    if let title = section.title { Text(title) }
                }
            }
        }
        .listStyle(.inset)
        .accessibilityLabel("Scripts")
        .onDeleteCommand {
            if let script = model.selection.flatMap(model.script(id:)) { model.requestDelete(script) }
        }
        // Return and double-click both arrive as the primary action.
        .contextMenu(forSelectionType: Script.ID.self) { ids in
            if let script = ids.first.flatMap(model.script(id:)) {
                ScriptContextMenu(script: script)
            }
        } primaryAction: { ids in
            if let script = ids.first.flatMap(model.script(id:)) { model.toggleRun(script) }
        }
        .overlay { EmptyListView() }
    }
}

/// Stateless: run state is read from the model, never stored here.
private struct ScriptRow: View {
    let script: Script
    @Environment(AppModel.self) private var model

    var body: some View {
        let running = model.isRunning(script)

        HStack(spacing: 10) {
            Image(nsImage: SystemActions.icon(for: script.url))
                .resizable()
                .frame(width: 28, height: 28)
                .opacity(script.isExecutable ? 1 : 0.5)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(script.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                if let subtitle = script.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(subtitle)
                }
            }
            .opacity(script.isExecutable ? 1 : 0.5)

            Spacer(minLength: 8)

            TextField("Arguments", text: argumentsBinding)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 150)
                .onSubmit { model.toggleRun(script) }
                .accessibilityLabel("Arguments for \(script.displayName)")

            Button { model.edit(script) } label: {
                Label("Edit \(script.displayName)", systemImage: "square.and.pencil")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("Open \(script.filename) in your editor")

            Button { model.requestDelete(script) } label: {
                Label("Move \(script.displayName) to Trash", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .disabled(!model.canDelete(script))
            .help(model.canDelete(script) ? "Move \(script.filename) to the Trash" : "Stop \(script.filename) before deleting it")

            runButton(running: running)

            // A fixed slot, so the row doesn't shift when a run starts or stops.
            Group {
                if running { ProgressView().controlSize(.small) } else { Color.clear }
            }
            .frame(width: 16, height: 16)
        }
        .padding(.vertical, 4)
    }

    private var argumentsBinding: Binding<String> {
        Binding(
            get: { model.arguments(for: script) },
            set: { model.setArguments($0, for: script) }
        )
    }

    private func runButton(running: Bool) -> some View {
        let symbol: String
        let label: String
        let help: String

        if !script.isExecutable {
            symbol = "lock.fill"
            label = "Make \(script.displayName) executable"
            help = "\(script.filename) isn\u{2019}t executable. Click to make it executable."
        } else {
            symbol = running ? "stop.fill" : "play.fill"
            label = "\(running ? "Stop" : "Run") \(script.displayName)"
            help = label
        }

        return Button { model.toggleRun(script) } label: {
            Label(label, systemImage: symbol)
                .labelStyle(.iconOnly)
                .frame(width: 24, height: 22)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

private struct ScriptContextMenu: View {
    let script: Script
    @Environment(AppModel.self) private var model

    var body: some View {
        let running = model.isRunning(script)

        Button(!script.isExecutable ? "Make Executable" : (running ? "Stop" : "Run")) {
            model.toggleRun(script)
        }
        Divider()
        Button("Open in Editor") { model.edit(script) }
        Button("Show in Finder") { model.reveal(script) }
        Button("Copy Path") { model.copyPath(of: script) }
        Divider()
        Button("Move to Trash\u{2026}", role: .destructive) { model.requestDelete(script) }
            .disabled(!model.canDelete(script))
    }
}

/// An empty folder, or a filter with no matches.
private struct EmptyListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.scripts.isEmpty {
            ContentUnavailableView {
                Label("No scripts found", systemImage: "terminal")
            } description: {
                Text("in \((model.scriptsDirectory.path as NSString).abbreviatingWithTildeInPath)")
            } actions: {
                HStack {
                    Button("Choose Folder\u{2026}") { AppAction.chooseFolder.perform(in: model) }
                    Button("New Script\u{2026}") { AppAction.newScript.perform(in: model) }
                }
            }
        } else if model.visibleScripts.isEmpty {
            ContentUnavailableView.search(text: model.filter)
        }
    }
}
