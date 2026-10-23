import Foundation

/// Owns every live run, so a run never dies with the view that launched it.
@MainActor
public final class RunCoordinator {
    enum StartError: Error, Equatable {
        case alreadyRunning
    }

    public private(set) var activeRuns: [ScriptRun] = []

    public var onRunStateChange: (@MainActor () -> Void)?

    public init() {}

    public func activeRun(for script: Script) -> ScriptRun? {
        activeRuns.first { $0.script.id == script.id }
    }

    /// Starts `script` and keeps the run alive until it ends. `onFinish` sees
    /// the run already removed from `activeRuns`.
    @discardableResult
    public func start(
        _ script: Script,
        arguments: String,
        onOutput: @escaping @MainActor ([StyledText]) -> Void,
        onFinish: @escaping @MainActor (RunOutcome, TimeInterval) -> Void
    ) throws -> ScriptRun {
        guard activeRun(for: script) == nil else { throw StartError.alreadyRunning }

        let run = ScriptRun(script: script, arguments: arguments)
        let startedAt = run.startedAt
        run.onOutput = onOutput
        // Weak `run`: it owns this closure.
        run.onFinish = { [weak self, weak run] outcome in
            self?.activeRuns.removeAll { $0 === run }
            onFinish(outcome, Date().timeIntervalSince(startedAt))
            self?.onRunStateChange?()
        }

        try run.start()
        activeRuns.append(run)
        onRunStateChange?()
        return run
    }

    public func stopAll() {
        activeRuns.forEach { $0.stop() }
    }
}
