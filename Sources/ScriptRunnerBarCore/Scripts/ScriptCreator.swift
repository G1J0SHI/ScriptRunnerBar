import Foundation

public enum ScriptCreator {
    enum CreationError: LocalizedError, Equatable {
        case invalidName
        case alreadyExists(URL)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidName:
                "Please enter a name containing at least one letter or number."
            case .alreadyExists(let url):
                "\u{201C}\(url.lastPathComponent)\u{201D} already exists in this folder."
            case .writeFailed(let reason):
                "Could not create the script: \(reason)"
            }
        }
    }

    public static func filename(for name: String, language: ScriptLanguage) -> String? {
        // Every run of non-alphanumerics (any script) becomes one hyphen.
        let slug = String(name.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" })
            .split(separator: "-")
            .joined(separator: "-")
        return slug.isEmpty ? nil : "\(slug).\(language.primaryExtension)"
    }

    @discardableResult
    public static func createScript(
        named rawName: String,
        description: String = "",
        language: ScriptLanguage,
        in directory: URL
    ) throws -> URL {
        let name = rawName.trimmingCharacters(in: .whitespaces)
        guard let filename = filename(for: name, language: language) else { throw CreationError.invalidName }

        let destination = directory.appendingPathComponent(filename)
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw CreationError.alreadyExists(destination)
        }

        let body = language.template(name: name, description: description)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try body.write(to: destination, atomically: true, encoding: .utf8)
            // Executable, or discovery wouldn't list it as runnable.
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
        } catch {
            throw CreationError.writeFailed(error.localizedDescription)
        }
        return destination
    }
}
