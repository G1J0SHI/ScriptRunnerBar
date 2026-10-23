import SwiftUI

/// The Settings window (Command-comma).
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var isChoosingFolder = false

    var body: some View {
        Form {
            LabeledContent("Scripts folder") {
                HStack {
                    Text((model.scriptsDirectory.path as NSString).abbreviatingWithTildeInPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Choose\u{2026}") { isChoosingFolder = true }
                        .accessibilityLabel("Choose scripts folder")
                }
            }
            Toggle("Launch at Login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { _ in model.toggleLaunchAtLogin() }
            ))
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .scriptsFolderPicker(isPresented: $isChoosingFolder, model: model)
        .appAlert(model)
    }
}
