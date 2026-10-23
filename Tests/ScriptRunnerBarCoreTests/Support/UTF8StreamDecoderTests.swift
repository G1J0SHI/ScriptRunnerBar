import XCTest
@testable import ScriptRunnerBarCore

final class UTF8StreamDecoderTests: XCTestCase {
    private func decodeAll(_ chunks: [[UInt8]]) -> String {
        var decoder = UTF8StreamDecoder()
        let body = chunks.map { decoder.decode(Data($0)) }.joined()
        return body + decoder.finish()
    }

    func testPassesPlainASCIIStraightThrough() {
        var decoder = UTF8StreamDecoder()
        XCTAssertEqual(decoder.decode(Data("hello\n".utf8)), "hello\n")
    }

    func testReassemblesATwoByteCharacterSplitInHalf() {
        // "é" = C3 A9
        XCTAssertEqual(decodeAll([[0x63, 0x61, 0x66, 0xC3], [0xA9]]), "café")
    }

    func testHoldsBackTheIncompletePartUntilItArrives() {
        var decoder = UTF8StreamDecoder()
        XCTAssertEqual(decoder.decode(Data([0x61, 0xE2, 0x80])), "a")   // "…" = E2 80 A6
        XCTAssertEqual(decoder.decode(Data([0xA6, 0x62])), "…b")
    }

    func testReassemblesAFourByteCharacterSplitAtEveryPoint() {
        // Written as an escape so no editor or tooling can mangle the literal.
        let dog = "\u{1F436}"
        let bytes = Array(dog.utf8)   // F0 9F 90 B6
        XCTAssertEqual(bytes.count, 4)

        for cut in 1..<bytes.count {
            let chunks = [Array(bytes[..<cut]), Array(bytes[cut...])]
            XCTAssertEqual(decodeAll(chunks), dog, "split at byte \(cut)")
        }
    }

    func testReassemblesACharacterDeliveredOneByteAtATime() {
        XCTAssertEqual(decodeAll(Array("日本".utf8).map { [$0] }), "日本")
    }

    func testReplacesInvalidBytesInsteadOfDroppingTheText() {
        XCTAssertEqual(decodeAll([[0x6F, 0x6B, 0x20, 0xFF, 0x21]]), "ok \u{FFFD}!")
    }

    func testFinishFlushesATruncatedFinalCharacterAsReplacement() {
        XCTAssertEqual(decodeAll([[0x61, 0xC3]]), "a\u{FFFD}")
    }

    func testFinishLeavesTheDecoderEmpty() {
        var decoder = UTF8StreamDecoder()
        _ = decoder.decode(Data([0xC3]))
        _ = decoder.finish()
        XCTAssertEqual(decoder.finish(), "")
    }

    func testStrayContinuationBytesAreNeverHeldBackForever() {
        // Four continuation bytes can't be the tail of one character.
        var decoder = UTF8StreamDecoder()
        XCTAssertEqual(decoder.decode(Data([0x80, 0x80, 0x80, 0x80])).count, 4)
    }
}
