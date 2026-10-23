import XCTest
@testable import ScriptRunnerBarCore

@MainActor
final class RunCoordinatorTests: XCTestCase {
    private var fixture: ScriptFixture!
    private var coordinator: RunCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        fixture = try ScriptFixture()
        coordinator = RunCoordinator()
    }

    override func tearDown() async throws {
        coordinator.stopAll()
        coordinator = nil
        fixture = nil
        try await super.tearDown()
    }

    /// Starts `script` without keeping the returned run, then waits for it.
    private func startAndWait(
        _ script: Script,
        timeout: TimeInterval = 10,
        whileRunning: (() -> Void)? = nil
    ) throws -> (output: String, outcome: RunOutcome, duration: TimeInterval) {
        let finished = expectation(description: "finished")
        var output = ""
        var result: (RunOutcome, TimeInterval)?

        try coordinator.start(
            script,
            arguments: "",
            onOutput: { output += $0.plainText },
            onFinish: { outcome, duration in
                result = (outcome, duration)
                finished.fulfill()
            }
        )
        whileRunning?()
        wait(for: [finished], timeout: timeout)

        let (outcome, duration) = try XCTUnwrap(result)
        return (output, outcome, duration)
    }

    func testARunNobodyHoldsStillFinishesAndDeliversOutput() throws {
        // Regression: a run referenced only by a local variable was freed on
        // return, losing its output and leaving the process unstoppable.
        let script = try fixture.makeScript("slow.sh", "#!/bin/zsh\nsleep 0.3\necho survived")
        let result = try startAndWait(script)

        XCTAssertEqual(result.output, "survived\n")
        XCTAssertEqual(result.outcome, .success)
    }

    func testTracksTheRunOnlyWhileItIsAlive() throws {
        let script = try fixture.makeScript("tracked.sh", "#!/bin/zsh\nsleep 0.3")

        _ = try startAndWait(script) {
            XCTAssertNotNil(self.coordinator.activeRun(for: script))
            XCTAssertFalse(self.coordinator.activeRuns.isEmpty)
        }

        XCTAssertNil(coordinator.activeRun(for: script))
        XCTAssertTrue(coordinator.activeRuns.isEmpty)
    }

    func testOnFinishAlreadySeesTheRunRemoved() throws {
        let script = try fixture.makeScript("quick.sh", "#!/bin/zsh\ntrue")
        let finished = expectation(description: "finished")

        try coordinator.start(script, arguments: "", onOutput: { _ in }, onFinish: { _, _ in
            XCTAssertNil(self.coordinator.activeRun(for: script))
            finished.fulfill()
        })
        wait(for: [finished], timeout: 10)
    }

    func testRefusesToStartTheSameScriptTwice() throws {
        let script = try fixture.makeScript("once.sh", "#!/bin/zsh\nsleep 30")
        try coordinator.start(script, arguments: "", onOutput: { _ in }, onFinish: { _, _ in })

        XCTAssertThrowsError(
            try coordinator.start(script, arguments: "", onOutput: { _ in }, onFinish: { _, _ in })
        ) { error in
            XCTAssertEqual(error as? RunCoordinator.StartError, .alreadyRunning)
        }
        XCTAssertEqual(coordinator.activeRuns.count, 1)
    }

    func testStopAllStopsEveryRun() throws {
        let first = try fixture.makeScript("a.sh", "#!/bin/zsh\nsleep 30")
        let second = try fixture.makeScript("b.sh", "#!/bin/zsh\nsleep 30")

        var outcomes: [RunOutcome] = []
        let bothFinished = expectation(description: "both finished")
        bothFinished.expectedFulfillmentCount = 2
        let record: @MainActor (RunOutcome, TimeInterval) -> Void = { outcome, _ in
            outcomes.append(outcome)
            bothFinished.fulfill()
        }

        try coordinator.start(first, arguments: "", onOutput: { _ in }, onFinish: record)
        try coordinator.start(second, arguments: "", onOutput: { _ in }, onFinish: record)
        coordinator.stopAll()

        wait(for: [bothFinished], timeout: 10)
        XCTAssertEqual(outcomes, [.killed, .killed])
        XCTAssertTrue(coordinator.activeRuns.isEmpty)
    }

    func testAnnouncesStateChangesOnStartAndFinish() throws {
        let script = try fixture.makeScript("notify.sh", "#!/bin/zsh\ntrue")
        var changes = 0
        coordinator.onRunStateChange = { changes += 1 }

        _ = try startAndWait(script)

        XCTAssertEqual(changes, 2, "one for the start, one for the finish")
    }

    func testReportsHowLongTheRunTook() throws {
        let script = try fixture.makeScript("timed.sh", "#!/bin/zsh\nsleep 0.4")
        let duration = try startAndWait(script).duration

        XCTAssertGreaterThanOrEqual(duration, 0.4)
        XCTAssertLessThan(duration, 5)
    }

    func testAFailedLaunchThrowsAndLeavesNothingBehind() throws {
        // A script whose folder vanished between discovery and launch: the
        // working directory is gone, so Process refuses to launch at all.
        let script = try fixture.makeScript("gone.sh", "#!/bin/zsh\ntrue")
        try FileManager.default.removeItem(at: fixture.directory)

        var stateChanges = 0
        coordinator.onRunStateChange = { stateChanges += 1 }

        XCTAssertThrowsError(
            try coordinator.start(script, arguments: "", onOutput: { _ in }, onFinish: { _, _ in
                XCTFail("a run that never launched must not report finishing")
            })
        )
        XCTAssertTrue(coordinator.activeRuns.isEmpty)
        XCTAssertEqual(stateChanges, 0, "nothing started, so nothing to announce")
    }
}
