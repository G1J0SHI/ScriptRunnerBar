import XCTest
@testable import ScriptRunnerBarCore

final class ScriptTests: XCTestCase {
    private var fixture: ScriptFixture!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try ScriptFixture()
    }

    override func tearDown() {
        fixture = nil
        super.tearDown()
    }

    func testMakeExecutableAddsTheBitsAndKeepsTheRest() throws {
        let url = try fixture.makeFile("later.sh", executable: false)

        try Script(url: url, isExecutable: false).makeExecutable()

        let mode = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        XCTAssertEqual(mode, 0o755)
    }

    func testMovingToTheTrashRemovesTheScriptAndIsRecoverable() throws {
        let script = try fixture.makeScript("disposable.sh", "#!/bin/zsh")

        let trashed = try XCTUnwrap(try script.moveToTrash())
        defer { try? FileManager.default.removeItem(at: trashed) }

        XCTAssertFalse(FileManager.default.fileExists(atPath: script.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: trashed.path), "it's in the Trash, not gone")
    }

    func testMovingAMissingFileToTheTrashThrows() {
        let ghost = Script(url: fixture.directory.appendingPathComponent("ghost.sh"))
        XCTAssertThrowsError(try ghost.moveToTrash())
    }

    // MARK: - Filter

    private func script(_ name: String, metadata: ScriptMetadata = .empty, group: String? = nil) -> Script {
        Script(url: URL(fileURLWithPath: "/tmp/\(name)"), metadata: metadata, group: group)
    }

    func testEmptyFilterMatchesEverything() {
        XCTAssertTrue(script("anything.sh").matches(filter: ""))
        XCTAssertTrue(script("anything.sh").matches(filter: "   "))
    }

    func testMatchesTheFilenameCaseInsensitively() {
        XCTAssertTrue(script("Deploy-Prod.sh").matches(filter: "prod"))
    }

    func testMatchesTheFriendlyNameAndStillTheFilename() {
        // The user may search for the file they remember, not the pretty title.
        let subject = script("backup_db.sh", metadata: ScriptMetadata(name: "Nightly Backup"))

        XCTAssertTrue(subject.matches(filter: "nightly"))
        XCTAssertTrue(subject.matches(filter: "backup_db"))
    }

    func testMatchesTheDescription() {
        XCTAssertTrue(script("x.sh", metadata: ScriptMetadata(description: "talks to staging")).matches(filter: "staging"))
    }

    func testMatchesTheGroupEvenWhenTheFilenameDoesNot() {
        XCTAssertTrue(script("go.sh", group: "deploy").matches(filter: "deploy"))
    }

    func testMatchingIgnoresAccents() {
        // Nobody types the accent when filtering a list.
        XCTAssertTrue(script("x.sh", metadata: ScriptMetadata(name: "Café Backup")).matches(filter: "cafe"))
    }

    func testRejectsNonMatches() {
        XCTAssertFalse(script("deploy.sh").matches(filter: "zzz"))
    }
}
