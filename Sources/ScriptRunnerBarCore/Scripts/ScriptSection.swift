import Foundation

/// Consecutive scripts from one folder, in discovery order: a section of the list.
public struct ScriptSection: Identifiable, Equatable, Sendable {
    public let title: String?
    public let scripts: [Script]
    public var id: String { title ?? "" }

    public static func sections(of scripts: [Script]) -> [ScriptSection] {
        var result: [ScriptSection] = []
        for script in scripts {
            if let last = result.last, last.title == script.group {
                result[result.count - 1] = ScriptSection(title: last.title, scripts: last.scripts + [script])
            } else {
                result.append(ScriptSection(title: script.group, scripts: [script]))
            }
        }
        return result
    }
}
