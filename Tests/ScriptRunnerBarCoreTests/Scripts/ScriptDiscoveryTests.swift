import XCTest
@testable import ScriptRunnerBarCore

final class ScriptDiscoveryTests: XCTestCase {
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

    func testSkipsNonExecutableFiles() throws {
        try fixture.makeFile("runnable.sh")
        try fixture.makeFile("notes.txt", contents: "just notes", executable: false)

        XCTAssertEqual(ScriptDiscovery.discoverScripts(in: directory).map(\.filename), ["runnable.sh"])
    }

    func testListsNonExecutableFilesThatStartWithAShebang() throws {
        // A downloaded script without chmod +x: hiding it makes the app look broken.
        // The shebang is what marks it, whatever its language or extension.
        try fixture.makeFile("ready.sh")
        try fixture.makeFile("downloaded.sh", executable: false)
        try fixture.makeFile("tool.dart", contents: "#!/usr/bin/env dart\nvoid main() {}", executable: false)
        try fixture.makeFile("deploy", executable: false)

        let scripts = ScriptDiscovery.discoverScripts(in: directory)

        XCTAssertEqual(scripts.map(\.filename), ["deploy", "downloaded.sh", "ready.sh", "tool.dart"])
        XCTAssertEqual(scripts.map(\.isExecutable), [false, false, true, false])
    }

    func testSkipsNonExecutableFilesWithoutAShebangWhateverTheirExtension() throws {
        try fixture.makeFile("plain.sh", contents: "curl example.com", executable: false)
        try fixture.makeFile("Package.swift", contents: "// swift-tools-version: 6.0", executable: false)
        try fixture.makeFile("Sources/App.swift", contents: "print(1)", executable: false)
        try fixture.makeFile("binary.dat", contents: String(repeating: "\u{0}\u{1}", count: 100), executable: false)

        XCTAssertEqual(ScriptDiscovery.discoverScripts(in: directory), [])
    }

    func testAnExecutableFileWithoutAShebangIsStillListed() throws {
        // zsh runs it itself, as it would typed into Terminal.
        try fixture.makeFile("bare", contents: "curl example.com")

        let script = try XCTUnwrap(ScriptDiscovery.discoverScripts(in: directory).first)
        XCTAssertTrue(script.isExecutable)
        XCTAssertNil(script.shebang)
    }

    func testRecordsTheShebang() throws {
        try fixture.makeFile("a.py", contents: "#!/usr/bin/env python3\nprint(1)")
        try fixture.makeFile("b.sh", contents: "#!/bin/zsh\necho hi")

        XCTAssertEqual(ScriptDiscovery.discoverScripts(in: directory).map(\.shebang), ["/usr/bin/env python3", "/bin/zsh"])
    }

    func testSkipsHiddenFiles() throws {
        try fixture.makeFile("visible.sh")
        try fixture.makeFile(".secret.sh")

        XCTAssertEqual(ScriptDiscovery.discoverScripts(in: directory).map(\.filename), ["visible.sh"])
    }

    func testSkipsExcludedExtensions() throws {
        try fixture.makeFile("keep.sh")
        try fixture.makeFile("Info.plist")

        XCTAssertEqual(ScriptDiscovery.discoverScripts(in: directory).map(\.filename), ["keep.sh"])
    }

    func testSkipsDirectoriesEvenThoughTheyAreExecutable() throws {
        try fixture.makeFile("real.sh")
        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent("subfolder"),
            withIntermediateDirectories: true
        )

        XCTAssertEqual(ScriptDiscovery.discoverScripts(in: directory).map(\.filename), ["real.sh"])
    }

    func testSortsCaseInsensitivelyByFilename() throws {
        try fixture.makeFile("banana.sh")
        try fixture.makeFile("Apple.sh")
        try fixture.makeFile("cherry.sh")

        XCTAssertEqual(
            ScriptDiscovery.discoverScripts(in: directory).map(\.filename),
            ["Apple.sh", "banana.sh", "cherry.sh"]
        )
    }

    func testAttachesParsedMetadata() throws {
        try fixture.makeFile(
            "meta.sh",
            contents: "#!/bin/zsh\n# @name: Pretty Name\n# @description: Does things\n"
        )

        let script = try XCTUnwrap(ScriptDiscovery.discoverScripts(in: directory).first)
        XCTAssertEqual(script.displayName, "Pretty Name")
        XCTAssertEqual(script.subtitle, "Does things")
    }

    func testFallsBackToFilenameWithoutMetadata() throws {
        try fixture.makeFile("plain.sh", contents: "#!/bin/zsh\necho hi")

        let script = try XCTUnwrap(ScriptDiscovery.discoverScripts(in: directory).first)
        XCTAssertEqual(script.displayName, "plain.sh")
        XCTAssertNil(script.subtitle)
    }

    func testMissingDirectoryYieldsEmptyListRatherThanThrowing() {
        let ghost = directory.appendingPathComponent("does-not-exist")
        XCTAssertTrue(ScriptDiscovery.discoverScripts(in: ghost).isEmpty)
    }

    // MARK: - Recursive subfolders

    func testFindsScriptsInASubfolder() throws {
        try fixture.makeFile("deploy/go.sh")

        let script = try XCTUnwrap(ScriptDiscovery.discoverScripts(in: directory).first)
        XCTAssertEqual(script.filename, "go.sh")
        XCTAssertEqual(script.group, "deploy")
    }

    func testRootLevelScriptsHaveNoGroup() throws {
        try fixture.makeFile("top.sh")

        let script = try XCTUnwrap(ScriptDiscovery.discoverScripts(in: directory).first)
        XCTAssertNil(script.group)
    }

    func testNestedSubfoldersJoinIntoOneGroupPath() throws {
        try fixture.makeFile("deploy/prod/go.sh")

        let script = try XCTUnwrap(ScriptDiscovery.discoverScripts(in: directory).first)
        XCTAssertEqual(script.group, "deploy/prod")
    }

    func testSkipsHiddenSubfolderEntirely() throws {
        try fixture.makeFile(".git/hooks/pre-commit.sh")
        try fixture.makeFile("visible.sh")

        XCTAssertEqual(ScriptDiscovery.discoverScripts(in: directory).map(\.filename), ["visible.sh"])
    }

    func testRootScriptsSortBeforeGroupedScripts() throws {
        try fixture.makeFile("deploy/inner.sh")
        try fixture.makeFile("outer.sh")

        let scripts = ScriptDiscovery.discoverScripts(in: directory)
        XCTAssertEqual(scripts.map(\.filename), ["outer.sh", "inner.sh"])
    }

    func testGroupsSortAlphabeticallyAndFilenamesSortWithinAGroup() throws {
        try fixture.makeFile("zebra/one.sh")
        try fixture.makeFile("alpha/b.sh")
        try fixture.makeFile("alpha/a.sh")

        let scripts = ScriptDiscovery.discoverScripts(in: directory)
        XCTAssertEqual(
            scripts.map { "\($0.group ?? "")/\($0.filename)" },
            ["alpha/a.sh", "alpha/b.sh", "zebra/one.sh"]
        )
    }

    func testDoesNotFollowSymlinkedDirectories() throws {
        try fixture.makeFile("real.sh")
        try fixture.makeFile("a/thing.sh")

        // A symlink back at the root, sitting inside a real subfolder. Without
        // loop protection this recurses forever; with it, the symlink is
        // simply never descended into.
        try FileManager.default.createSymbolicLink(
            at: directory.appendingPathComponent("a/loop"),
            withDestinationURL: directory
        )

        let scripts = ScriptDiscovery.discoverScripts(in: directory)
        XCTAssertEqual(scripts.map(\.filename).sorted(), ["real.sh", "thing.sh"])
    }
}
