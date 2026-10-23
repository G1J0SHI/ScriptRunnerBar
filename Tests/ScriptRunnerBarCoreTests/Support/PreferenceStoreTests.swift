import XCTest
@testable import ScriptRunnerBarCore

final class PreferenceStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: PreferenceStore!

    override func setUp() {
        super.setUp()
        // An isolated suite so tests never touch the real user's settings.
        suiteName = "srb-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = PreferenceStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaultsToHomeScriptsFolder() {
        XCTAssertEqual(store.scriptsDirectory, PreferenceStore.defaultScriptsDirectory)
    }

    func testPersistsChosenDirectory() {
        let chosen = URL(fileURLWithPath: "/tmp/custom-scripts", isDirectory: true)
        store.scriptsDirectory = chosen

        // A fresh instance proves it round-tripped through storage.
        let reloaded = PreferenceStore(defaults: defaults)
        XCTAssertEqual(reloaded.scriptsDirectory.path, chosen.path)
    }

    func testArgumentsDefaultToEmpty() {
        XCTAssertEqual(store.arguments(for: "/tmp/a.sh"), "")
    }

    func testPersistsArgumentsPerScriptPath() {
        store.setArguments("--verbose", for: "/tmp/a.sh")
        store.setArguments("--quiet", for: "/tmp/b.sh")

        let reloaded = PreferenceStore(defaults: defaults)
        XCTAssertEqual(reloaded.arguments(for: "/tmp/a.sh"), "--verbose")
        XCTAssertEqual(reloaded.arguments(for: "/tmp/b.sh"), "--quiet")
    }

    func testClearingArgumentsRemovesTheKeyEntirely() {
        store.setArguments("--verbose", for: "/tmp/a.sh")
        store.setArguments("", for: "/tmp/a.sh")

        XCTAssertEqual(store.arguments(for: "/tmp/a.sh"), "")
        XCTAssertNil(defaults.object(forKey: PreferenceStore.argumentsKey(for: "/tmp/a.sh")))
    }
}
