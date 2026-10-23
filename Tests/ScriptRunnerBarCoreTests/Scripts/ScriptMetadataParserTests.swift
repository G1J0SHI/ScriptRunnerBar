import XCTest
@testable import ScriptRunnerBarCore

final class ScriptMetadataParserTests: XCTestCase {
    func testParsesNameAndDescriptionFromHashComments() {
        let source = """
        #!/bin/zsh
        # @name: Check Order Status
        # @description: Hits staging and prints the state
        echo hi
        """

        let metadata = ScriptMetadataParser.parse(source)
        XCTAssertEqual(metadata.name, "Check Order Status")
        XCTAssertEqual(metadata.description, "Hits staging and prints the state")
    }

    func testParsesSlashComments() {
        let metadata = ScriptMetadataParser.parse("// @name: Swifty\n// @description: Uses slashes")
        XCTAssertEqual(metadata.name, "Swifty")
        XCTAssertEqual(metadata.description, "Uses slashes")
    }

    func testParsesDashComments() {
        let metadata = ScriptMetadataParser.parse("#!/usr/bin/osascript\n-- @name: Apple\n-- @description: Uses dashes")
        XCTAssertEqual(metadata.name, "Apple")
        XCTAssertEqual(metadata.description, "Uses dashes")
    }

    func testDirectivesAreCaseInsensitive() {
        let metadata = ScriptMetadataParser.parse("# @NAME: Shouty\n# @Description: Mixed case")
        XCTAssertEqual(metadata.name, "Shouty")
        XCTAssertEqual(metadata.description, "Mixed case")
    }

    func testEachFieldIsIndependentlyOptional() {
        let nameOnly = ScriptMetadataParser.parse("# @name: Solo")
        XCTAssertEqual(nameOnly.name, "Solo")
        XCTAssertNil(nameOnly.description)

        let descriptionOnly = ScriptMetadataParser.parse("# @description: Just a blurb")
        XCTAssertNil(descriptionOnly.name)
        XCTAssertEqual(descriptionOnly.description, "Just a blurb")
    }

    func testScriptWithoutDirectivesIsEmpty() {
        let metadata = ScriptMetadataParser.parse("#!/bin/zsh\necho 'no metadata here'")
        XCTAssertEqual(metadata, .empty)
    }

    func testBlankValueIsTreatedAsAbsent() {
        // "# @name:" with nothing after it should not yield an empty title.
        let metadata = ScriptMetadataParser.parse("# @name:\n# @description:   ")
        XCTAssertNil(metadata.name)
        XCTAssertNil(metadata.description)
    }

    func testBlankLinesDoNotTerminateTheHeader() {
        let source = """
        #!/bin/zsh

        # @name: Spaced Out

        # @description: Survives the gaps
        """

        let metadata = ScriptMetadataParser.parse(source)
        XCTAssertEqual(metadata.name, "Spaced Out")
        XCTAssertEqual(metadata.description, "Survives the gaps")
    }

    func testStopsScanningAtFirstRealCodeLine() {
        // The directive sits below actual code, so it is not a header.
        let source = """
        #!/bin/zsh
        echo "starting"
        # @name: Too Late
        """

        XCTAssertNil(ScriptMetadataParser.parse(source).name)
    }

    func testIgnoresDirectivesBeyondTheLineLimit() {
        let padding = String(repeating: "# filler\n", count: 25)
        let metadata = ScriptMetadataParser.parse(padding + "# @name: Way Down There")
        XCTAssertNil(metadata.name)
    }

    func testFirstDeclarationWins() {
        let metadata = ScriptMetadataParser.parse("# @name: First\n# @name: Second")
        XCTAssertEqual(metadata.name, "First")
    }

    func testHandlesEmptyInput() {
        XCTAssertEqual(ScriptMetadataParser.parse(""), .empty)
    }

    // MARK: - Shebang

    func testReadsTheShebangInterpreter() {
        XCTAssertEqual(ScriptMetadataParser.shebang(in: "#!/bin/zsh\necho hi"), "/bin/zsh")
        XCTAssertEqual(ScriptMetadataParser.shebang(in: "#!  /usr/bin/env python3  \nprint(1)"), "/usr/bin/env python3")
        XCTAssertEqual(ScriptMetadataParser.shebang(in: "#!/usr/bin/env -S dart run\r\n"), "/usr/bin/env -S dart run")
    }

    func testNoShebangWhenTheFirstLineIsSomethingElse() {
        XCTAssertNil(ScriptMetadataParser.shebang(in: "curl example.com"))
        XCTAssertNil(ScriptMetadataParser.shebang(in: "\n#!/bin/zsh"), "only the very first line counts")
        XCTAssertNil(ScriptMetadataParser.shebang(in: "# !/bin/zsh"))
        XCTAssertNil(ScriptMetadataParser.shebang(in: "#!"))
        XCTAssertNil(ScriptMetadataParser.shebang(in: ""))
    }
}
