import CoreServices
import Foundation

/// Calls back on the main actor when anything under a folder changes.
/// FSEvents rather than a vnode source because discovery is recursive.
@MainActor
public final class FolderWatcher {
    /// Written once in `init`, read only in the nonisolated `deinit`.
    private nonisolated(unsafe) var stream: FSEventStreamRef?
    private let onChange: @MainActor () -> Void

    /// nil if the stream can't be created; manual refresh still works.
    public init?(url: URL, latency: TimeInterval = 0.4, onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange

        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            // Scheduled on the main queue below.
            MainActor.assumeIsolated {
                Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue().onChange()
            }
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            // FSEvents reports real paths, so symlinked roots like /tmp must be resolved.
            [url.resolvingSymlinksInPath().path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            // File-level events: a `chmod +x` changes no directory listing.
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
        ) else { return nil }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
    }

    deinit {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }
}
