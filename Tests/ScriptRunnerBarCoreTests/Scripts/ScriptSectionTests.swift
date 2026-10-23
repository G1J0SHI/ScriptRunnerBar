import XCTest
@testable import ScriptRunnerBarCore

final class ScriptSectionTests: XCTestCase {
    private func script(_ name: String, in group: String? = nil) -> Script {
        Script(url: URL(fileURLWithPath: "/scripts/\(group.map { $0 + "/" } ?? "")\(name)"), group: group)
    }

    func testNoScriptsGiveNoSections() {
        XCTAssertEqual(ScriptSection.sections(of: []), [])
    }

    func testOneSectionPerFolderInDiscoveryOrder() {
        let sections = ScriptSection.sections(of: [
            script("top.sh"),
            script("ship.sh", in: "deploy"),
            script("rollback.sh", in: "deploy"),
            script("go.sh", in: "deploy/prod"),
        ])

        XCTAssertEqual(sections.map(\.title), [nil, "deploy", "deploy/prod"])
        XCTAssertEqual(sections[1].scripts.map(\.filename), ["ship.sh", "rollback.sh"])
        XCTAssertEqual(sections.map(\.id), ["", "deploy", "deploy/prod"], "ids are unique per section")
    }
}
