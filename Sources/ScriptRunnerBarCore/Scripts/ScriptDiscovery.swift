import Foundation

public enum ScriptDiscovery {
    /// Never scripts, even when executable.
    private static let excludedExtensions: Set<String> = ["plist"]
    /// A safety cap against runaway scans, not a design target.
    private static let maxDepth = 10

    private static let resourceKeys: [URLResourceKey] = [
        .isRegularFileKey, .isExecutableKey, .isHiddenKey, .isDirectoryKey, .isSymbolicLinkKey,
    ]

    /// Root scripts first, then each folder; alphabetical, case-insensitive.
    public static func discoverScripts(in directory: URL) -> [Script] {
        var results: [Script] = []
        scan(directory: directory, relativePath: [], depth: 0, into: &results)
        return results.sorted { lhs, rhs in
            let lhsGroup = lhs.group ?? "", rhsGroup = rhs.group ?? ""
            if lhsGroup != rhsGroup {
                return lhsGroup.localizedCaseInsensitiveCompare(rhsGroup) == .orderedAscending
            }
            return lhs.filename.localizedCaseInsensitiveCompare(rhs.filename) == .orderedAscending
        }
    }

    private static func scan(directory: URL, relativePath: [String], depth: Int, into results: inout [Script]) {
        guard depth <= maxDepth,
              let entries = try? FileManager.default.contentsOfDirectory(
                  at: directory, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles]
              )
        else { return }

        for url in entries {
            let name = url.lastPathComponent
            // `.skipsHiddenFiles` misses dotfiles on some volumes.
            guard !name.hasPrefix("."),
                  let values = try? url.resourceValues(forKeys: Set(resourceKeys))
            else { continue }

            if values.isDirectory == true {
                // A symlinked folder could point back at an ancestor: skip it.
                guard values.isSymbolicLink != true else { continue }
                scan(directory: url, relativePath: relativePath + [name], depth: depth + 1, into: &results)
                continue
            }

            guard values.isRegularFile == true, values.isHidden != true,
                  !excludedExtensions.contains(url.pathExtension.lowercased())
            else { continue }

            // Executable files are scripts. Others only if they start with a
            // shebang, and are then listed locked (they need `chmod +x`).
            let header = readHeader(at: url)
            let isExecutable = values.isExecutable == true
            guard isExecutable || header.shebang != nil else { continue }
            results.append(Script(
                url: url,
                metadata: header.metadata,
                shebang: header.shebang,
                group: relativePath.isEmpty ? nil : relativePath.joined(separator: "/"),
                isExecutable: isExecutable
            ))
        }
    }

    /// Reads only the first 8 KB: the shebang and the `@name` header are all
    /// that matters. Decoding is lenient, so a binary file just has neither.
    private static func readHeader(at url: URL) -> (shebang: String?, metadata: ScriptMetadata) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return (nil, .empty) }
        defer { try? handle.close() }
        guard let chunk = try? handle.read(upToCount: 8192) else { return (nil, .empty) }
        let text = String(decoding: chunk, as: UTF8.self)
        return (ScriptMetadataParser.shebang(in: text), ScriptMetadataParser.parse(text))
    }
}
