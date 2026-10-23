import ScriptRunnerBarCore
import SwiftUI

/// One run's output. Each run gets its own tab, so concurrent runs never interleave.
@MainActor @Observable
final class OutputTab: Identifiable {
    /// `Text` re-lays-out its whole string per append, so only the newest
    /// characters are kept for display. `text` keeps everything for copying.
    static let renderLimit = 200_000

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    let id = UUID()
    let title: String
    let command: String
    let shebang: String?
    let startedAt: Date
    /// Everything printed, without styling: what Copy Tab Output copies.
    private(set) var text = ""
    /// The styled tail that's drawn.
    private(set) var styledText = AttributedString()
    private var styledCount = 0
    private var omittedCount = 0
    /// nil while running.
    private(set) var outcome: RunOutcome?
    private(set) var duration: TimeInterval?

    /// The run printing into this tab, so closing the tab stops exactly it.
    @ObservationIgnored weak var run: ScriptRun?

    init(script: Script, arguments: String) {
        let path = (script.url.path as NSString).abbreviatingWithTildeInPath
        let trimmedArguments = arguments.trimmingCharacters(in: .whitespaces)
        command = trimmedArguments.isEmpty ? path : "\(path) \(trimmedArguments)"
        shebang = script.shebang
        startedAt = Date()
        title = "\(script.displayName) @ \(Self.timeFormatter.string(from: startedAt))"
    }

    var detailLine: String {
        [shebang.map { "#!\($0)" }, "Started \(Self.timeFormatter.string(from: startedAt))"]
            .compactMap { $0 }.joined(separator: " \u{00B7} ")
    }

    var isFinished: Bool { outcome != nil }

    var displayText: AttributedString {
        guard omittedCount > 0 else { return styledText }
        return AttributedString("[ \(omittedCount) earlier characters not shown; Copy Tab Output copies everything ]\n")
            + styledText
    }

    func append(_ runs: [StyledText]) {
        for run in runs {
            let piece = JSONPrettyPrinter.prettify(chunk: run.text)
            text += piece
            styledText += AttributedString(piece, attributes: ANSIPalette.attributes(for: run.style))
            styledCount += piece.count
        }
        trimToRenderLimit()
    }

    func append(_ plain: String) {
        append([StyledText(plain)])
    }

    func clear() {
        text = ""
        styledText = AttributedString()
        styledCount = 0
        omittedCount = 0
    }

    func finish(_ outcome: RunOutcome, duration: TimeInterval) {
        self.outcome = outcome
        self.duration = duration
        append("\n\(outcome.summaryLine(duration: duration))\n")
    }

    /// Trims in batches (at 125% of the limit) so it isn't paid on every append.
    private func trimToRenderLimit() {
        guard styledCount > Self.renderLimit + Self.renderLimit / 4 else { return }
        let excess = styledCount - Self.renderLimit
        let cut = styledText.characters.index(styledText.startIndex, offsetBy: excess)
        styledText.removeSubrange(styledText.startIndex..<cut)
        styledCount -= excess
        omittedCount += excess
    }

    // MARK: - Status presentation (shape and colour, never colour alone)

    var statusSymbol: String {
        switch outcome {
        case nil: "circle.dashed"
        case .success: "checkmark.circle.fill"
        case .failure: "xmark.octagon.fill"
        case .killed: "stop.circle.fill"
        }
    }

    var statusColor: Color {
        switch outcome {
        case nil: .accentColor
        case .success: .green
        case .failure: .red
        case .killed: .orange
        }
    }

    var statusDescription: String {
        guard let outcome, let duration else { return "Running" }
        return "\(outcome.statusDescription) after \(RunDuration.string(from: duration))"
    }

    var accessibilityTitle: String {
        "Output for \(title), \(statusDescription)"
    }
}
