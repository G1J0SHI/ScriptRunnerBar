import XCTest
@testable import ScriptRunnerBarCore

@MainActor
final class ScriptRunTests: XCTestCase {
    private var fixture: ScriptFixture!
    private var directory: URL { fixture.directory }

    override func setUp() async throws {
        try await super.setUp()
        fixture = try ScriptFixture()
    }

    override func tearDown() async throws {
        fixture = nil
        try await super.tearDown()
    }

    /// Runs to completion and returns the collected output plus the outcome.
    private func execute(
        _ script: Script,
        arguments: String = "",
        timeout: TimeInterval = 10,
        configure: ((ScriptRun) -> Void)? = nil
    ) throws -> (output: String, outcome: RunOutcome) {
        let run = ScriptRun(script: script, arguments: arguments)
        let finished = expectation(description: "run finished")

        var output = ""
        var outcome: RunOutcome?

        run.onOutput = { output += $0.plainText }
        run.onFinish = {
            outcome = $0
            finished.fulfill()
        }

        try run.start()
        configure?(run)
        wait(for: [finished], timeout: timeout)

        return (output, try XCTUnwrap(outcome))
    }

    func testCapturesStandardOutput() throws {
        let script = try fixture.makeScript("echo.sh", "#!/bin/zsh\necho hello world")
        let result = try execute(script)

        XCTAssertTrue(result.output.contains("hello world"))
        XCTAssertEqual(result.outcome, .success)
    }

    func testCapturesStandardError() throws {
        let script = try fixture.makeScript("err.sh", "#!/bin/zsh\necho oops >&2")
        XCTAssertTrue(try execute(script).output.contains("oops"))
    }

    /// The interpreter a language's shebang names, found the way the app finds it: through a login shell.
    private func isInstalled(_ language: ScriptLanguage) -> Bool {
        let words = language.shebang.dropFirst(2).split(separator: " ").map(String.init)
        guard let first = words.first else { return false }
        let name = first.hasSuffix("/env") ? (words.dropFirst().first ?? "") : first
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/bin/zsh")
        probe.arguments = ["-l", "-c", "command -v \(ShellCommand.quote(name))"]
        probe.standardOutput = FileHandle.nullDevice
        probe.standardError = FileHandle.nullDevice
        return (try? probe.run()) != nil && { probe.waitUntilExit(); return probe.terminationStatus == 0 }()
    }

    func testEveryTemplateRunsAndReceivesArguments() throws {
        for language in ScriptLanguage.allCases where isInstalled(language) {
            let url = try ScriptCreator.createScript(named: "Hello", language: language, in: directory)
            let script = try XCTUnwrap(ScriptDiscovery.discoverScripts(in: directory).first { $0.filename == url.lastPathComponent })
            let result = try execute(script, arguments: "one 'two words'", timeout: 90)

            XCTAssertEqual(result.outcome, .success, "\(language): \(result.output)")
            XCTAssertTrue(result.output.contains("Hello! Arguments: one two words"), "\(language): \(result.output)")
        }
    }

    func testRunsAnExecutableFileWithoutAShebangAsAPlainShellScript() throws {
        // No shebang: zsh hands the file to sh, so zsh-only syntax isn't available.
        let script = try fixture.makeScript("bare", "printf 'one\\ntwo\\n'\nprint zsh-only-builtin")
        let result = try execute(script)

        XCTAssertTrue(result.output.contains("one\ntwo"), result.output)
        XCTAssertEqual(result.outcome, .failure(exitCode: 127), "print is a zsh builtin, not an sh command")
    }

    func testDeliversColoursAsStyledRuns() throws {
        // Raw escapes, plus tput, which needs TERM (a GUI app has none of its own).
        let script = try fixture.makeScript("colour.sh", """
        #!/bin/zsh
        printf '\\033[1;31mred\\033[0m plain\\n'
        tput setaf 2; echo green; tput sgr0
        """)
        var runs: [StyledText] = []
        _ = try execute(script) { run in
            let collect = run.onOutput
            run.onOutput = { runs += $0; collect?($0) }
        }

        let red = try XCTUnwrap(runs.first { $0.text == "red" })
        XCTAssertEqual(red.style.foreground, .palette(1))
        XCTAssertTrue(red.style.isBold)
        XCTAssertEqual(runs.first { $0.text.contains("green") }?.style.foreground, .palette(2))
        XCTAssertFalse(runs.plainText.contains("\u{1B}"), "no raw escape reaches the output")
    }

    func testReportsNonZeroExitCode() throws {
        let script = try fixture.makeScript("fail.sh", "#!/bin/zsh\nexit 3")
        XCTAssertEqual(try execute(script).outcome, .failure(exitCode: 3))
    }

    func testPassesArgumentsThrough() throws {
        let script = try fixture.makeScript("args.sh", "#!/bin/zsh\necho \"got:$1\"")
        XCTAssertTrue(try execute(script, arguments: "banana").output.contains("got:banana"))
    }

    func testHandlesPathsContainingSpacesAndQuotes() throws {
        let script = try fixture.makeScript("it's a script.sh", "#!/bin/zsh\necho quoted-ok")
        let result = try execute(script)

        XCTAssertTrue(result.output.contains("quoted-ok"))
        XCTAssertEqual(result.outcome, .success)
    }

    func testCapturesFinalOutputOfAFastScript() throws {
        // Guards the drain-on-exit path: without it the last write is lost.
        let script = try fixture.makeScript("quick.sh", "#!/bin/zsh\nprintf 'last line'")
        XCTAssertTrue(try execute(script).output.contains("last line"))
    }

    func testKeepsACharacterSplitAcrossTwoReads() throws {
        // "é" is two bytes (C3 A9). The pause makes the pipe deliver them as
        // separate reads; decoding each read on its own drops both halves.
        let script = try fixture.makeScript(
            "split.sh",
            "#!/bin/zsh\nprintf 'caf\\xc3'\nsleep 0.3\nprintf '\\xa9 ok\\n'"
        )
        XCTAssertEqual(try execute(script).output, "café ok\n")
    }

    func testKeepsOutputContainingInvalidUTF8() throws {
        // One bad byte must not silently swallow the whole line around it.
        let script = try fixture.makeScript("latin1.sh", "#!/bin/zsh\nprintf 'before \\xff after\\n'")
        let output = try execute(script).output

        XCTAssertTrue(output.contains("before"), "got: \(output)")
        XCTAssertTrue(output.contains("after"), "got: \(output)")
    }

    func testScriptsCanFindHomebrewTools() throws {
        // A Finder-launched app inherits a bare PATH, so `brew`, `jq`, `node`
        // all fail with "command not found" unless the run adds these.
        let script = try fixture.makeScript("path.sh", "#!/bin/zsh\necho \"$PATH\"")
        let output = try execute(script).output

        XCTAssertTrue(output.contains("/opt/homebrew/bin"), "PATH was: \(output)")
    }

    func testRunsFromTheScriptsOwnDirectory() throws {
        let script = try fixture.makeScript("pwd.sh", "#!/bin/zsh\npwd")
        let output = try execute(script).output

        // Resolve both sides: /tmp is a symlink to /private/tmp on macOS.
        let expected = directory.resolvingSymlinksInPath().path
        XCTAssertTrue(output.contains(expected), "Expected \(expected) in: \(output)")
    }

    func testStopMarksTheRunAsKilled() throws {
        let script = try fixture.makeScript("sleep.sh", "#!/bin/zsh\nsleep 30")
        let result = try execute(script) { run in
            // Give the process a beat to actually start before terminating.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { run.stop() }
        }

        XCTAssertEqual(result.outcome, .killed)
    }

    func testFinishFiresExactlyOnce() throws {
        let script = try fixture.makeScript("once.sh", "#!/bin/zsh\necho done")
        let run = ScriptRun(script: script, arguments: "")

        let finished = expectation(description: "finished")
        finished.assertForOverFulfill = true

        var count = 0
        run.onFinish = { _ in
            count += 1
            finished.fulfill()
        }

        try run.start()
        wait(for: [finished], timeout: 10)

        // Let any stray duplicate callback land before asserting.
        let settle = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { settle.fulfill() }
        wait(for: [settle], timeout: 2)

        XCTAssertEqual(count, 1)
    }
}
