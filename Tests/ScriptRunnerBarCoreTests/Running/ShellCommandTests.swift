import XCTest
@testable import ScriptRunnerBarCore

final class ShellCommandTests: XCTestCase {
    func testEnvironmentPrependsTheHomebrewFolders() {
        let environment = ShellCommand.environment(from: ["PATH": "/usr/bin:/bin", "HOME": "/Users/x"])

        XCTAssertEqual(
            environment["PATH"],
            "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin"
        )
        XCTAssertEqual(environment["HOME"], "/Users/x", "everything else passes through untouched")
    }

    func testEnvironmentDoesNotDuplicateFoldersAlreadyPresent() {
        let environment = ShellCommand.environment(from: ["PATH": "/usr/local/bin:/usr/bin"])
        XCTAssertEqual(environment["PATH"], "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin")
    }

    func testEnvironmentCopesWithNoPATHAtAll() {
        let environment = ShellCommand.environment(from: [:])
        XCTAssertEqual(environment["PATH"], "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin")
    }

    func testEnvironmentProvidesATerminalTypeWhenMissing() {
        XCTAssertEqual(ShellCommand.environment(from: [:])["TERM"], "xterm-256color")
    }

    func testEnvironmentKeepsAnExistingTerminalType() {
        XCTAssertEqual(ShellCommand.environment(from: ["TERM": "vt100"])["TERM"], "vt100")
    }

    func testRunsAsALoginShellSoProfilePATHIsLoaded() {
        XCTAssertEqual(ShellCommand.arguments(for: "echo hi"), ["-l", "-c", "echo hi"])
    }

    func testQuotesAPlainPath() {
        XCTAssertEqual(ShellCommand.quote("/tmp/a.sh"), "'/tmp/a.sh'")
    }

    func testQuotesPathContainingSpaces() {
        let command = ShellCommand.command(forScriptAt: "/Users/me/My Scripts/go.sh", arguments: "")
        XCTAssertEqual(command, "'/Users/me/My Scripts/go.sh'")
    }

    func testEscapesEmbeddedSingleQuote() {
        // The POSIX close/escape/reopen dance.
        XCTAssertEqual(ShellCommand.quote("it's.sh"), "'it'\\''s.sh'")
    }

    func testShellMetacharactersInPathAreNeutralised() {
        let quoted = ShellCommand.quote("/tmp/$(rm -rf ~)/x.sh")
        XCTAssertEqual(quoted, "'/tmp/$(rm -rf ~)/x.sh'")
    }

    func testAppendsArgumentsUnquoted() {
        // Arguments stay raw so globs, redirects and $VARs keep working.
        let command = ShellCommand.command(forScriptAt: "/tmp/a.sh", arguments: "--flag *.json")
        XCTAssertEqual(command, "'/tmp/a.sh' --flag *.json")
    }

    func testIgnoresWhitespaceOnlyArguments() {
        let command = ShellCommand.command(forScriptAt: "/tmp/a.sh", arguments: "   ")
        XCTAssertEqual(command, "'/tmp/a.sh'")
    }
}
