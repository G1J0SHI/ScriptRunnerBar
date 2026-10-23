import XCTest
@testable import ScriptRunnerBarCore

/// Real FSEvents against a real temp folder. Generous timeouts: event
/// delivery is fast locally but can lag on a loaded machine.
@MainActor
final class FolderWatcherTests: XCTestCase {
    private var fixture: ScriptFixture!

    override func setUp() async throws {
        try await super.setUp()
        fixture = try ScriptFixture()
    }

    override func tearDown() async throws {
        fixture = nil
        try await super.tearDown()
    }

    /// Starts watching, performs `change` once the stream is live, and
    /// fails unless a callback arrives *after* the change. Earlier callbacks
    /// are ignored: FSEvents may still deliver the test's own setup work
    /// (creating folders, writing files) after the stream starts.
    private func assertNoticesChange(_ change: @escaping () throws -> Void) throws {
        let noticed = expectation(description: "change noticed")
        noticed.assertForOverFulfill = false
        var changeMade = false

        let watcher = try XCTUnwrap(FolderWatcher(url: fixture.directory, latency: 0.1) {
            if changeMade { noticed.fulfill() }
        })

        // Let the stream arm and any setup events drain before changing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                try change()
                changeMade = true
            } catch {
                XCTFail("change failed: \(error)")
            }
        }

        wait(for: [noticed], timeout: 5)
        withExtendedLifetime(watcher) {}
    }

    func testNoticesANewScript() throws {
        try assertNoticesChange {
            try self.fixture.makeScript("new.sh", "#!/bin/zsh\necho hi")
        }
    }

    func testNoticesAScriptInANestedSubfolder() throws {
        let nested = fixture.directory.appendingPathComponent("deploy/prod")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        try assertNoticesChange {
            try "echo hi".write(to: nested.appendingPathComponent("ship.sh"), atomically: true, encoding: .utf8)
        }
    }

    func testNoticesAFileBecomingExecutable() throws {
        // chmod +x changes no directory listing, but it's what turns a file
        // into a script.
        let url = fixture.directory.appendingPathComponent("later.sh")
        try "echo hi".write(to: url, atomically: true, encoding: .utf8)

        try assertNoticesChange {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }

    func testStaysQuietAfterBeingReleased() throws {
        var calls = 0
        var watcher = FolderWatcher(url: fixture.directory, latency: 0.1) { calls += 1 }
        XCTAssertNotNil(watcher)
        watcher = nil

        try fixture.makeScript("after.sh", "echo hi")
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))

        XCTAssertEqual(calls, 0)
    }
}
