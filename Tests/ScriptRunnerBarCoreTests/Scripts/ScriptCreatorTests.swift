import XCTest
@testable import ScriptRunnerBarCore

final class ScriptCreatorTests: XCTestCase {
    private var fixture: ScriptFixture!
    private var directory: URL { fixture.directory }

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try ScriptFixture()
    }

    override func tearDown() {
        fixture = nil
        super.tearDown()
    }

    @discardableResult
    private func create(_ name: String, _ language: ScriptLanguage = .shell) throws -> URL {
        try ScriptCreator.createScript(named: name, language: language, in: directory)
    }

    func testFilenameIsTheSlugPlusTheLanguagesExtension() {
        XCTAssertEqual(ScriptCreator.filename(for: "Check Order Status", language: .shell), "check-order-status.sh")
        XCTAssertEqual(ScriptCreator.filename(for: "Weekly Report", language: .python), "weekly-report.py")
        XCTAssertEqual(ScriptCreator.filename(for: "Say Hi", language: .appleScript), "say-hi.applescript")
    }

    func testSlugRules() {
        let cases = [
            "a   b___c!!!d": "a-b-c-d.sh",
            "  !!Hello World!!  ": "hello-world.sh",
            "Café Run 2": "café-run-2.sh",
            "notes.txt": "notes-txt.sh",
        ]
        for (name, expected) in cases {
            XCTAssertEqual(ScriptCreator.filename(for: name, language: .shell), expected, name)
        }
    }

    func testCreatedScriptIsExecutableAndImmediatelyDiscoverableWithItsHeader() throws {
        let url = try ScriptCreator.createScript(
            named: "Nightly Backup",
            description: "Copies the important folders",
            language: .ruby,
            in: directory
        )

        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: url.path))
        let found = try XCTUnwrap(ScriptDiscovery.discoverScripts(in: directory).first)
        XCTAssertEqual(found.displayName, "Nightly Backup")
        XCTAssertEqual(found.subtitle, "Copies the important folders")
        XCTAssertEqual(found.shebang, "/usr/bin/env ruby")
        XCTAssertTrue(found.isExecutable)
    }

    func testRefusesToOverwriteAndLeavesTheExistingFileIntact() throws {
        let url = try create("Precious")
        try "DO NOT CLOBBER".write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try create("Precious")) { error in
            guard case ScriptCreator.CreationError.alreadyExists = error else {
                return XCTFail("Expected .alreadyExists, got \(error)")
            }
        }
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "DO NOT CLOBBER")
    }

    func testRejectsAnUnusableName() {
        for name in ["!!!", "   ", ""] {
            XCTAssertThrowsError(try create(name), name) { error in
                XCTAssertEqual(error as? ScriptCreator.CreationError, .invalidName)
            }
        }
    }
}
