import XCTest
@testable import ScriptRunnerBarCore

/// A throwaway folder for tests that touch the real filesystem or spawn real
/// processes: executable bits, FSEvents and `Process` are what can break, and
/// a mock would verify none of it.
final class ScriptFixture {
    let directory: URL

    init() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("srb-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    @discardableResult
    func makeFile(_ name: String, contents: String = "#!/bin/zsh\necho hi", executable: Bool = true) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: executable ? 0o755 : 0o644], ofItemAtPath: url.path)
        return url
    }

    @discardableResult
    func makeScript(_ name: String, _ body: String) throws -> Script {
        Script(url: try makeFile(name, contents: body))
    }
}

extension [StyledText] {
    var plainText: String { map(\.text).joined() }
}
