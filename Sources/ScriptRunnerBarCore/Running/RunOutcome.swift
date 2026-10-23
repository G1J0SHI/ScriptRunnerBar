import Foundation

public enum RunOutcome: Equatable, Sendable {
    case success
    case failure(exitCode: Int32)
    case killed

    public var statusDescription: String {
        switch self {
        case .success: "Succeeded"
        case .failure(let code): "Failed (exit \(code))"
        case .killed: "Stopped"
        }
    }

    public func summaryLine(duration: TimeInterval) -> String {
        let elapsed = RunDuration.string(from: duration)
        return switch self {
        case .success: "[ finished successfully in \(elapsed) ]"
        case .failure(let code): "[ exited with code \(code) after \(elapsed) ]"
        case .killed: "[ stopped after \(elapsed) ]"
        }
    }
}

public enum RunDuration {
    public static func string(from interval: TimeInterval) -> String {
        let interval = max(0, interval)
        // 9.95, not 10: "%.1f" would render 9.97 as "10.0s".
        if interval < 9.95 { return String(format: "%.1fs", interval) }

        let totalSeconds = Int(interval.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 { return String(format: "%dh %02dm", hours, minutes) }
        if minutes > 0 { return String(format: "%dm %02ds", minutes, seconds) }
        return "\(seconds)s"
    }
}
