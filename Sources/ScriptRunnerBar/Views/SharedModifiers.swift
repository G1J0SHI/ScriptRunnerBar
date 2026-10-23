import SwiftUI

extension View {
    /// The folder chooser, shared by the window and Settings.
    func scriptsFolderPicker(isPresented: Binding<Bool>, model: AppModel) -> some View {
        fileImporter(isPresented: isPresented, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { model.setScriptsDirectory(url) }
        }
        .fileDialogDefaultDirectory(model.scriptsDirectory)
        .fileDialogMessage("Choose the folder containing your scripts")
        .fileDialogConfirmationLabel("Choose")
    }

    /// Presents `model.alert`.
    func appAlert(_ model: AppModel) -> some View {
        alert(
            model.alert?.title ?? "",
            isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } }),
            presenting: model.alert
        ) { content in
            if content.offersLoginItems {
                Button("Open Login Items") { SystemActions.open(LaunchAtLogin.settingsURL) }
            }
            Button(content.offersLoginItems ? "Cancel" : "OK", role: .cancel) {}
        } message: { content in
            Text(content.message)
        }
    }
}
