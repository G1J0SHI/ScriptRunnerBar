import Foundation

public struct Script: Equatable, Identifiable, Sendable {
    public let url: URL
    /// False for a script-looking file without the executable bit. It's still
    /// listed, with a one-click `chmod +x`.
    public let isExecutable: Bool
    /// The `#!` interpreter ("/usr/bin/env python3"); nil for an executable
    /// file without one, which zsh runs itself.
    public let shebang: String?
    /// Folder path relative to the scripts root ("deploy/prod"); nil at the root.
    let group: String?
    let metadata: ScriptMetadata

    init(
        url: URL,
        metadata: ScriptMetadata = .empty,
        shebang: String? = nil,
        group: String? = nil,
        isExecutable: Bool = true
    ) {
        self.url = url
        self.metadata = metadata
        self.shebang = shebang
        self.group = group
        self.isExecutable = isExecutable
    }

    public var id: String { url.path }
    public var filename: String { url.lastPathComponent }
    public var displayName: String { metadata.name ?? filename }
    public var subtitle: String? { metadata.description }

    public func makeExecutable() throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let mode = (attributes[.posixPermissions] as? Int) ?? 0o644
        try FileManager.default.setAttributes([.posixPermissions: mode | 0o111], ofItemAtPath: url.path)
    }

    @discardableResult
    public func moveToTrash() throws -> URL? {
        var trashed: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &trashed)
        return trashed as URL?
    }

    /// Finder-style matching (case- and accent-insensitive) on every visible field.
    public func matches(filter: String) -> Bool {
        let needle = filter.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return true }
        return [filename, displayName, subtitle, group]
            .compactMap { $0 }
            .contains { $0.localizedStandardContains(needle) }
    }
}
