import Foundation

/// The `@name` / `@description` a script may declare in its leading comments.
struct ScriptMetadata: Equatable, Sendable {
    var name: String?
    var description: String?

    static let empty = ScriptMetadata()
}

enum ScriptMetadataParser {
    private static let maxLinesScanned = 20

    static func shebang(in contents: String) -> String? {
        let firstLine = contents.prefix { !$0.isNewline }
        guard firstLine.hasPrefix("#!") else { return nil }
        let interpreter = firstLine.dropFirst(2).trimmingCharacters(in: .whitespaces)
        return interpreter.isEmpty ? nil : interpreter
    }

    /// Reads `#`, `//` or `--` (AppleScript) comments up to the first line of
    /// code. Blank lines and the shebang are skipped; the first declaration of
    /// each key wins.
    static func parse(_ contents: String) -> ScriptMetadata {
        var metadata = ScriptMetadata()

        for rawLine in contents.components(separatedBy: .newlines).prefix(maxLinesScanned) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#!") { continue }
            guard let body = commentBody(of: line) else { break }

            if let value = directiveValue(in: body, key: "@name:") {
                metadata.name = metadata.name ?? value
            } else if let value = directiveValue(in: body, key: "@description:") {
                metadata.description = metadata.description ?? value
            }
        }
        return metadata
    }

    private static func commentBody(of line: String) -> String? {
        guard let marker = ["//", "--", "#"].first(where: line.hasPrefix) else { return nil }
        return String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
    }

    /// Case-insensitive; an empty value counts as no value.
    private static func directiveValue(in body: String, key: String) -> String? {
        guard body.lowercased().hasPrefix(key.lowercased()) else { return nil }
        let value = String(body.dropFirst(key.count)).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
}
