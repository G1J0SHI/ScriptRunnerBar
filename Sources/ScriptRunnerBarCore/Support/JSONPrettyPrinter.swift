import Foundation

/// Pretty-prints output lines that are a complete JSON object or array.
/// Anything else is returned untouched.
public enum JSONPrettyPrinter {
    public static func prettify(chunk: String) -> String {
        guard chunk.contains("{") || chunk.contains("[") else { return chunk }

        let processed = chunk.components(separatedBy: "\n").map(prettify(line:)).joined(separator: "\n")
        // Keep the trailing newline, or the next chunk welds onto this line.
        return chunk.hasSuffix("\n") && !processed.hasSuffix("\n") ? processed + "\n" : processed
    }

    /// Keys are sorted so repeated runs produce the same output.
    static func prettify(line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let isContainer = (trimmed.hasPrefix("{") && trimmed.hasSuffix("}"))
            || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
        guard trimmed.count >= 2, isContainer,
              let data = trimmed.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: parsed, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: pretty, encoding: .utf8)
        else { return line }
        return result
    }
}
