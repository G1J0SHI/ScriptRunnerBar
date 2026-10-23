import XCTest
@testable import ScriptRunnerBarCore

final class ANSIParserTests: XCTestCase {
    private let esc = "\u{1B}"

    private func parse(_ chunks: String...) -> [StyledText] {
        var parser = ANSIParser()
        return chunks.flatMap { parser.parse($0) }
    }

    private func style(_ configure: (inout ANSIStyle) -> Void) -> ANSIStyle {
        var style = ANSIStyle.plain
        configure(&style)
        return style
    }

    // MARK: - Text survives, escapes don't

    func testPlainTextIsOneRun() {
        XCTAssertEqual(parse("[INFO] array[0] = 1\n"), [StyledText("[INFO] array[0] = 1\n")])
    }

    func testEmptyInputGivesNoRuns() {
        XCTAssertEqual(parse(""), [])
    }

    func testCursorAndEraseSequencesAreDropped() {
        XCTAssertEqual(parse("\(esc)[2K\(esc)[1Gprogress").plainText, "progress")
    }

    func testPrivateModeSequencesAreDropped() {
        XCTAssertEqual(parse("\(esc)[?25lhidden cursor\(esc)[?25h"), [StyledText("hidden cursor")])
    }

    func testTitlesAndHyperlinksAreDropped() {
        let output = parse("\(esc)]0;My Title\u{07}before \(esc)]8;;https://example.com\(esc)\\link\(esc)]8;;\(esc)\\ after")
        XCTAssertEqual(output.plainText, "before link after")
    }

    func testCharacterSetSelectionIsDropped() {
        XCTAssertEqual(parse("\(esc)(Bplain").plainText, "plain")
    }

    // MARK: - Styles

    func testColourAppliesUntilReset() {
        XCTAssertEqual(parse("\(esc)[32mOK\(esc)[0m done"), [
            StyledText("OK", style: style { $0.foreground = .palette(2) }),
            StyledText(" done"),
        ])
    }

    func testCompoundCodesCombine() {
        let output = parse("\(esc)[1;31;44mfail\(esc)[m")
        XCTAssertEqual(output, [StyledText("fail", style: style {
            $0.isBold = true
            $0.foreground = .palette(1)
            $0.background = .palette(4)
        })])
    }

    func testBrightColours() {
        XCTAssertEqual(parse("\(esc)[91;102mx").first?.style, style {
            $0.foreground = .palette(9)
            $0.background = .palette(10)
        })
    }

    func test256AndTrueColour() {
        XCTAssertEqual(parse("\(esc)[38;5;208mx").first?.style.foreground, .palette(208))
        XCTAssertEqual(parse("\(esc)[48;2;10;20;30mx").first?.style.background, .rgb(red: 10, green: 20, blue: 30))
        XCTAssertEqual(parse("\(esc)[38:5:99mx").first?.style.foreground, .palette(99), "colon separators")
    }

    func testExtendedColourDoesNotSwallowFollowingCodes() {
        XCTAssertEqual(parse("\(esc)[38;5;1;1mx").first?.style, style {
            $0.foreground = .palette(1)
            $0.isBold = true
        })
    }

    func testIndividualResets() {
        let output = parse("\(esc)[1;3;4;7;9;31;41ma\(esc)[22;23;24;27;29;39;49mb")
        XCTAssertEqual(output.last, StyledText("b"))
    }

    func testDimAndItalic() {
        XCTAssertEqual(parse("\(esc)[2;3mx").first?.style, style {
            $0.isDim = true
            $0.isItalic = true
        })
    }

    func testUnknownCodesAreIgnored() {
        XCTAssertEqual(parse("\(esc)[5;31mblink").first?.style, style { $0.foreground = .palette(1) })
    }

    func testStyleChangesWithoutTextAddNoEmptyRuns() {
        XCTAssertEqual(parse("\(esc)[31m\(esc)[0m\(esc)[32mgo"), [StyledText("go", style: style { $0.foreground = .palette(2) })])
    }

    // MARK: - Across chunks

    func testStyleCarriesIntoTheNextChunk() {
        XCTAssertEqual(parse("\(esc)[33m", "warning"), [StyledText("warning", style: style { $0.foreground = .palette(3) })])
    }

    func testSequenceSplitAcrossChunksIsReassembled() {
        let output = parse("ok \(esc)[3", "1mred")
        XCTAssertEqual(output, [StyledText("ok "), StyledText("red", style: style { $0.foreground = .palette(1) })])
    }

    func testLoneEscapeAtChunkEndWaitsForMore() {
        XCTAssertEqual(parse("a\(esc)", "[1mb").plainText, "ab")
    }

    func testUnterminatedSequenceDoesNotSwallowOutputForever() {
        let output = parse("\(esc)]" + String(repeating: "x", count: 300) + "\nstill here").plainText
        XCTAssertTrue(output.hasSuffix("still here"))
    }
}
