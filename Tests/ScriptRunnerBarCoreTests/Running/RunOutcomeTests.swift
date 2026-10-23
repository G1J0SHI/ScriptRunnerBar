import XCTest
@testable import ScriptRunnerBarCore

final class RunOutcomeTests: XCTestCase {
    func testDurationKeepsTenthsUnderTenSeconds() {
        XCTAssertEqual(RunDuration.string(from: 0), "0.0s")
        XCTAssertEqual(RunDuration.string(from: 0.42), "0.4s")
        XCTAssertEqual(RunDuration.string(from: 9.94), "9.9s")
    }

    func testDurationNeverShowsTenPointZero() {
        // %.1f rounds 9.97 up; it must read as whole seconds instead.
        XCTAssertEqual(RunDuration.string(from: 9.97), "10s")
    }

    func testDurationUsesWholeSecondsUnderAMinute() {
        XCTAssertEqual(RunDuration.string(from: 42.4), "42s")
    }

    func testDurationUsesMinutesAndPaddedSeconds() {
        XCTAssertEqual(RunDuration.string(from: 187), "3m 07s")
        XCTAssertEqual(RunDuration.string(from: 59.6), "1m 00s")
    }

    func testDurationUsesHoursAndPaddedMinutes() {
        XCTAssertEqual(RunDuration.string(from: 3720), "1h 02m")
    }

    func testDurationClampsNegativeClockSkewToZero() {
        XCTAssertEqual(RunDuration.string(from: -3), "0.0s")
    }

    func testStatusDescriptions() {
        XCTAssertEqual(RunOutcome.success.statusDescription, "Succeeded")
        XCTAssertEqual(RunOutcome.failure(exitCode: 3).statusDescription, "Failed (exit 3)")
        XCTAssertEqual(RunOutcome.killed.statusDescription, "Stopped")
    }

    func testSummaryLinesIncludeTheDuration() {
        XCTAssertEqual(RunOutcome.success.summaryLine(duration: 2.4), "[ finished successfully in 2.4s ]")
        XCTAssertEqual(
            RunOutcome.failure(exitCode: 1).summaryLine(duration: 75),
            "[ exited with code 1 after 1m 15s ]"
        )
        XCTAssertEqual(RunOutcome.killed.summaryLine(duration: 0.5), "[ stopped after 0.5s ]")
    }
}
