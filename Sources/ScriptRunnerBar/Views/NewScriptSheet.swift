import ScriptRunnerBarCore
import SwiftUI

struct NewScriptSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameIsFocused: Bool

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 14) {
            Text("New Script")
                .font(.headline)

            Form {
                Picker("Language", selection: $model.newScript.language) {
                    ForEach(ScriptLanguage.allCases, id: \.self) { language in
                        Text("\(language.displayName) (.\(language.primaryExtension))").tag(language)
                    }
                }
                TextField("Name", text: $model.newScript.name, prompt: Text("Check Order Status (required)"))
                    .focused($nameIsFocused)
                TextField("Description", text: $model.newScript.description, prompt: Text("Optional"))
            }
            .formStyle(.columns)

            preview

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { model.createScript() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canCreateScript)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear { nameIsFocused = true }
    }

    @ViewBuilder
    private var preview: some View {
        if let filename = model.newScript.filename {
            if model.newScriptFileExists {
                Label("\(filename) already exists in this folder.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            } else {
                Label("Creates \(filename) in \((model.scriptsDirectory.path as NSString).abbreviatingWithTildeInPath)",
                      systemImage: "doc.badge.plus")
                    .foregroundStyle(.secondary)
            }
        } else {
            Label("Give it a name with at least one letter or number.", systemImage: "info.circle")
                .foregroundStyle(.secondary)
        }
    }
}
