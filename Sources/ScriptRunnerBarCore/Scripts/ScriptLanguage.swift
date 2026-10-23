import Foundation

/// What New Script offers: a shebang, an extension and a template per language.
/// Running never depends on this; a script runs through its own shebang.
public enum ScriptLanguage: CaseIterable, Sendable {
    case shell, bash, python, ruby, perl, javascript, swift, appleScript

    public var displayName: String {
        switch self {
        case .shell: "Shell (zsh)"
        case .bash: "Bash"
        case .python: "Python"
        case .ruby: "Ruby"
        case .perl: "Perl"
        case .javascript: "JavaScript (Node)"
        case .swift: "Swift"
        case .appleScript: "AppleScript"
        }
    }

    public var primaryExtension: String {
        switch self {
        case .shell: "sh"
        case .bash: "bash"
        case .python: "py"
        case .ruby: "rb"
        case .perl: "pl"
        case .javascript: "js"
        case .swift: "swift"
        case .appleScript: "applescript"
        }
    }

    var shebang: String {
        switch self {
        case .shell: "#!/bin/zsh"
        case .bash: "#!/usr/bin/env bash"
        case .python: "#!/usr/bin/env python3"
        case .ruby: "#!/usr/bin/env ruby"
        case .perl: "#!/usr/bin/env perl"
        case .javascript: "#!/usr/bin/env node"
        case .swift: "#!/usr/bin/env swift"
        case .appleScript: "#!/usr/bin/osascript"
        }
    }

    /// Name and description go into comments, so they're flattened to one
    /// line: a newline would end the comment and leave the rest as code.
    func template(name: String, description: String = "") -> String {
        var header = "\(comment) @name: \(Self.oneLine(name))"
        let description = Self.oneLine(description)
        if !description.isEmpty { header += "\n\(comment) @description: \(description)" }
        return "\(shebang)\n\(header)\n\n\(body)\n"
    }

    private static func oneLine(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var comment: String {
        switch self {
        case .javascript, .swift: "//"
        case .appleScript: "--"
        default: "#"
        }
    }

    private var body: String {
        switch self {
        case .shell, .bash:
            """
            set -euo pipefail

            # Your script goes here. Arguments typed into the app arrive as "$@".
            echo "Hello! Arguments: $*"
            """
        case .python:
            """
            import sys

            # Your script goes here. Arguments typed into the app arrive in sys.argv[1:].
            print("Hello! Arguments:", " ".join(sys.argv[1:]))
            """
        case .ruby:
            """
            # Your script goes here. Arguments typed into the app arrive in ARGV.
            puts "Hello! Arguments: #{ARGV.join(' ')}"
            """
        case .perl:
            """
            use strict;
            use warnings;

            # Your script goes here. Arguments typed into the app arrive in @ARGV.
            print "Hello! Arguments: @ARGV\\n";
            """
        case .javascript:
            """
            // Your script goes here. Arguments typed into the app arrive in process.argv.slice(2).
            console.log("Hello! Arguments:", process.argv.slice(2).join(" "));
            """
        case .swift:
            """
            // Your script goes here. Arguments typed into the app arrive in CommandLine.arguments.dropFirst().
            print("Hello! Arguments:", CommandLine.arguments.dropFirst().joined(separator: " "))
            """
        case .appleScript:
            """
            on run argv
            \t-- Your script goes here. Arguments typed into the app arrive in argv.
            \tset AppleScript's text item delimiters to " "
            \treturn "Hello! Arguments: " & (argv as text)
            end run
            """
        }
    }
}
