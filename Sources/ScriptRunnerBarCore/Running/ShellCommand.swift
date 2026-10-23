import Foundation

/// Scripts run through `zsh -l -c '<path> <arguments>'`, so the kernel honours
/// the script's own shebang. A file without one is handed to `sh` (not zsh) by
/// zsh's exec fallback.
enum ShellCommand {
    static let shellPath = "/bin/zsh"

    /// A login shell reads `~/.zprofile` (where PATH setup belongs). Not `-i`:
    /// `~/.zshrc` prompt themes would print into every run's output.
    static func arguments(for command: String) -> [String] {
        ["-l", "-c", command]
    }

    /// Homebrew on Apple silicon and Intel; a Finder-launched app lacks both.
    private static let extraPathFolders = ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin"]

    /// Adds the Homebrew folders to PATH, and a TERM: a Finder-launched app has
    /// none, and `tput setaf` fails without one.
    static func environment(from base: [String: String]) -> [String: String] {
        var environment = base
        let existing = (base["PATH"] ?? "").split(separator: ":").map(String.init)
        let additions = extraPathFolders.filter { !existing.contains($0) }
        environment["PATH"] = (additions + existing).joined(separator: ":")
        environment["TERM"] = base["TERM"] ?? "xterm-256color"
        return environment
    }

    /// Single quotes expand nothing, so a path like `$(rm -rf ~)` stays inert.
    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// The path is always quoted; the arguments are deliberately left raw, so
    /// `$HOME`, globs and redirects work as the user typed them.
    static func command(forScriptAt path: String, arguments: String) -> String {
        let quotedPath = quote(path)
        let trimmedArguments = arguments.trimmingCharacters(in: .whitespaces)
        return trimmedArguments.isEmpty ? quotedPath : "\(quotedPath) \(trimmedArguments)"
    }
}
