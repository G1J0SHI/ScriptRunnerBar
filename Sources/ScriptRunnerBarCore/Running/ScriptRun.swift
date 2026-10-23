import Foundation

/// One live execution of a script. Output arrives on the main actor, in
/// order, and `onFinish` fires exactly once.
@MainActor
public final class ScriptRun {
    public let script: Script
    let startedAt = Date()

    var onOutput: (@MainActor ([StyledText]) -> Void)?
    var onFinish: (@MainActor (RunOutcome) -> Void)?

    private let process = Process()
    private let pipe = Pipe()
    private var decoder = UTF8StreamDecoder()
    private var ansi = ANSIParser()
    private var didFinish = false
    private var wasKilled = false

    init(script: Script, arguments: String) {
        self.script = script

        let command = ShellCommand.command(forScriptAt: script.url.path, arguments: arguments)
        process.executableURL = URL(fileURLWithPath: ShellCommand.shellPath)
        process.arguments = ShellCommand.arguments(for: command)
        process.environment = ShellCommand.environment(from: ProcessInfo.processInfo.environment)
        process.currentDirectoryURL = script.url.deletingLastPathComponent()
        // One pipe for both streams keeps output and errors in the order printed.
        process.standardOutput = pipe
        process.standardError = pipe
    }

    func start() throws {
        // DispatchQueue.main (serial) rather than a Task: chunk order must be kept.
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.deliver(data) }
            }
        }
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.complete(status: status) }
            }
        }
        try process.run()
    }

    /// The outcome still arrives through `onFinish`, as `.killed`.
    public func stop() {
        guard process.isRunning else { return }
        wasKilled = true
        process.terminate()
    }

    private func complete(status: Int32) {
        guard !didFinish else { return }
        didFinish = true

        pipe.fileHandleForReading.readabilityHandler = nil
        // Drain what arrived after the last read, or a fast script loses its tail.
        if let remainder = try? pipe.fileHandleForReading.readToEnd() {
            deliver(remainder)
        }
        emit(decoder.finish())

        let outcome: RunOutcome = if wasKilled {
            .killed
        } else if status == 0 {
            .success
        } else {
            .failure(exitCode: status)
        }
        onFinish?(outcome)
    }

    private func deliver(_ data: Data) {
        emit(decoder.decode(data))
    }

    private func emit(_ text: String) {
        let runs = ansi.parse(text)
        guard !runs.isEmpty else { return }
        onOutput?(runs)
    }
}
