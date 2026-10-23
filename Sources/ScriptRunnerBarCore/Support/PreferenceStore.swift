import Foundation

public final class PreferenceStore {
    private static let scriptsDirectoryKey = "scriptsDirectory"
    private static let argumentsPrefix = "scriptArguments."

    static var defaultScriptsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Scripts")
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var scriptsDirectory: URL {
        get {
            guard let path = defaults.string(forKey: Self.scriptsDirectoryKey), !path.isEmpty else {
                return Self.defaultScriptsDirectory
            }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        set { defaults.set(newValue.path, forKey: Self.scriptsDirectoryKey) }
    }

    public func arguments(for scriptPath: String) -> String {
        defaults.string(forKey: Self.argumentsKey(for: scriptPath)) ?? ""
    }

    /// Clearing a field removes its key rather than storing "".
    public func setArguments(_ arguments: String, for scriptPath: String) {
        let key = Self.argumentsKey(for: scriptPath)
        if arguments.trimmingCharacters(in: .whitespaces).isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(arguments, forKey: key)
        }
    }

    static func argumentsKey(for scriptPath: String) -> String {
        argumentsPrefix + scriptPath
    }
}
