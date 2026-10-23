import XCTest
@testable import ScriptRunnerBarCore

final class ScriptLanguageTests: XCTestCase {
    func testEveryLanguageHasADistinctExtension() {
        let extensions = ScriptLanguage.allCases.map(\.primaryExtension)
        XCTAssertEqual(extensions.count, Set(extensions).count)
    }

    func testEveryTemplateStartsWithItsShebangAndDiscoveryReadsItBack() {
        for language in ScriptLanguage.allCases {
            let template = language.template(name: "X")
            XCTAssertTrue(template.hasPrefix(language.shebang + "\n"), "\(language)")
            XCTAssertEqual(
                ScriptMetadataParser.shebang(in: template),
                String(language.shebang.dropFirst(2)),
                "\(language)"
            )
        }
    }

    func testEveryTemplateDeclaresNameAndDescriptionInAParsableComment() {
        for language in ScriptLanguage.allCases {
            let metadata = ScriptMetadataParser.parse(
                language.template(name: "It's \"Quoted\"", description: "Does a thing")
            )
            XCTAssertEqual(metadata.name, "It's \"Quoted\"", "\(language)")
            XCTAssertEqual(metadata.description, "Does a thing", "\(language)")
        }
    }

    func testNoDescriptionLineIsWrittenWhenNoneIsGiven() {
        let template = ScriptLanguage.shell.template(name: "My Task")

        XCTAssertTrue(template.contains("# @name: My Task"))
        XCTAssertFalse(template.contains("@description"))
    }

    func testNewlinesInTheFieldsCannotEscapeTheComment() {
        for language in ScriptLanguage.allCases {
            let template = language.template(name: "Evil\nrm -rf ~", description: "line one\nline two\n")

            XCTAssertFalse(template.split(separator: "\n").contains("rm -rf ~"), "\(language)")
            XCTAssertTrue(template.contains("@name: Evil rm -rf ~\n"), "\(language)")
            XCTAssertTrue(template.contains("@description: line one line two\n"), "\(language)")
        }
    }
}
