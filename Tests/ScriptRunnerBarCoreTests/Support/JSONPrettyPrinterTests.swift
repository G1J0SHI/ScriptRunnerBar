import XCTest
@testable import ScriptRunnerBarCore

final class JSONPrettyPrinterTests: XCTestCase {
    func testPrettyPrintsAJSONObject() {
        let result = JSONPrettyPrinter.prettify(line: #"{"b":2,"a":1}"#)
        XCTAssertEqual(result, "{\n  \"a\" : 1,\n  \"b\" : 2\n}")
    }

    func testPrettyPrintsAJSONArray() {
        let result = JSONPrettyPrinter.prettify(line: "[1,2]")
        XCTAssertTrue(result.contains("\n"), "Expected multi-line output, got: \(result)")
    }

    func testLeavesPlainLogLinesAlone() {
        let line = "2026-09-11 12:00:00 INFO starting up"
        XCTAssertEqual(JSONPrettyPrinter.prettify(line: line), line)
    }

    func testLeavesLinesThatMerelyContainBracesAlone() {
        let line = "Deploying to {region} now"
        XCTAssertEqual(JSONPrettyPrinter.prettify(line: line), line)
    }

    func testLeavesMalformedJSONUntouched() {
        let line = #"{"a": }"#
        XCTAssertEqual(JSONPrettyPrinter.prettify(line: line), line)
    }

    func testIgnoresBareScalars() {
        // Valid JSON, but reformatting it would be pointless noise.
        XCTAssertEqual(JSONPrettyPrinter.prettify(line: "42"), "42")
    }

    func testPreservesTrailingNewlineInChunks() {
        let chunk = "hello\n"
        XCTAssertEqual(JSONPrettyPrinter.prettify(chunk: chunk), "hello\n")
    }

    func testProcessesOnlyTheJSONLineWithinAMixedChunk() {
        let chunk = "before\n{\"a\":1}\nafter\n"
        let result = JSONPrettyPrinter.prettify(chunk: chunk)

        XCTAssertTrue(result.hasPrefix("before\n"))
        XCTAssertTrue(result.hasSuffix("after\n"))
        XCTAssertTrue(result.contains("\"a\" : 1"))
    }

    func testChunkWithoutBracesIsReturnedUnchanged() {
        let chunk = "line one\nline two\n"
        XCTAssertEqual(JSONPrettyPrinter.prettify(chunk: chunk), chunk)
    }
}
