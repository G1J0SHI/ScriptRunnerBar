import Foundation

public enum ANSIColor: Equatable, Sendable {
    /// 0-7 standard, 8-15 bright, 16-255 the xterm 256-colour palette.
    case palette(UInt8)
    case rgb(red: UInt8, green: UInt8, blue: UInt8)
}

public struct ANSIStyle: Equatable, Sendable {
    public var foreground: ANSIColor?
    public var background: ANSIColor?
    public var isBold = false
    public var isDim = false
    public var isItalic = false
    public var isUnderlined = false
    public var isInverse = false
    public var isStrikethrough = false

    public static let plain = ANSIStyle()
}

public struct StyledText: Equatable, Sendable {
    public var text: String
    public var style: ANSIStyle

    public init(_ text: String, style: ANSIStyle = .plain) {
        self.text = text
        self.style = style
    }
}

/// Splits terminal output into styled runs. SGR sequences (colours, bold...)
/// set the style; every other escape sequence (cursor moves, titles, links)
/// is dropped. The style, and a sequence cut off at the end of a chunk, carry
/// over to the next chunk.
struct ANSIParser {
    private static let escape: Unicode.Scalar = "\u{1B}"
    /// An unterminated sequence longer than this is garbage, not a split read.
    private static let maxPendingLength = 256

    private var style = ANSIStyle.plain
    private var pending = ""

    mutating func parse(_ chunk: String) -> [StyledText] {
        let input = pending + chunk
        pending = ""
        guard input.unicodeScalars.contains(Self.escape) else {
            return input.isEmpty ? [] : [StyledText(input, style: style)]
        }

        var runs: [StyledText] = []
        var text = String.UnicodeScalarView()
        let scalars = input.unicodeScalars
        var index = scalars.startIndex

        func flush() {
            guard !text.isEmpty else { return }
            if let last = runs.last, last.style == style {
                runs[runs.count - 1].text += String(text)
            } else {
                runs.append(StyledText(String(text), style: style))
            }
            text = String.UnicodeScalarView()
        }

        while index < scalars.endIndex {
            guard scalars[index] == Self.escape else {
                text.append(scalars[index])
                index = scalars.index(after: index)
                continue
            }
            guard let sequence = Self.sequence(in: scalars, at: index) else {
                let rest = String(scalars[index...])
                if rest.unicodeScalars.count <= Self.maxPendingLength {
                    pending = rest
                    break
                }
                index = scalars.index(after: index)  // drop the lone ESC, keep the text
                continue
            }
            if let codes = sequence.sgrCodes {
                flush()
                style.apply(codes)
            }
            index = sequence.end
        }
        flush()
        return runs
    }

    private struct Sequence {
        let end: String.UnicodeScalarView.Index
        let sgrCodes: [Int]?
    }

    private static func sequence(in scalars: String.UnicodeScalarView, at start: String.UnicodeScalarView.Index) -> Sequence? {
        let introducer = scalars.index(after: start)
        guard introducer < scalars.endIndex else { return nil }
        let body = scalars.index(after: introducer)

        switch scalars[introducer] {
        case "[":
            return controlSequence(in: scalars, from: body)
        case "]", "P", "X", "^", "_":
            return stringSequence(in: scalars, from: body)
        case "(", ")", "*", "+":
            // Character-set selection: one more scalar.
            guard body < scalars.endIndex else { return nil }
            return Sequence(end: scalars.index(after: body), sgrCodes: nil)
        default:
            return Sequence(end: body, sgrCodes: nil)
        }
    }

    /// CSI: parameter bytes, intermediate bytes, then one final byte. Only a
    /// final "m" with plain numeric parameters is SGR.
    private static func controlSequence(in scalars: String.UnicodeScalarView, from body: String.UnicodeScalarView.Index) -> Sequence? {
        var index = body
        var parameters = ""
        while index < scalars.endIndex {
            let value = scalars[index].value
            switch value {
            case 0x30...0x3F, 0x20...0x2F:
                parameters.unicodeScalars.append(scalars[index])
                index = scalars.index(after: index)
            case 0x40...0x7E:
                let end = scalars.index(after: index)
                let isSGR = value == 0x6D && parameters.allSatisfy { $0.isNumber || $0 == ";" || $0 == ":" }
                guard isSGR else { return Sequence(end: end, sgrCodes: nil) }
                let codes = parameters
                    .split(omittingEmptySubsequences: false) { $0 == ";" || $0 == ":" }
                    .map { Int($0) ?? 0 }
                return Sequence(end: end, sgrCodes: codes)
            default:
                // Malformed: drop what was read and resume at this scalar.
                return Sequence(end: index, sgrCodes: nil)
            }
        }
        return nil
    }

    /// OSC and friends: everything up to BEL or ESC \.
    private static func stringSequence(in scalars: String.UnicodeScalarView, from body: String.UnicodeScalarView.Index) -> Sequence? {
        var index = body
        while index < scalars.endIndex {
            if scalars[index] == "\u{07}" { return Sequence(end: scalars.index(after: index), sgrCodes: nil) }
            if scalars[index] == escape {
                let next = scalars.index(after: index)
                guard next < scalars.endIndex else { return nil }
                if scalars[next] == "\\" { return Sequence(end: scalars.index(after: next), sgrCodes: nil) }
            }
            index = scalars.index(after: index)
        }
        return nil
    }
}

private extension ANSIStyle {
    mutating func apply(_ codes: [Int]) {
        var index = codes.startIndex
        while index < codes.endIndex {
            let code = codes[index]
            index += 1
            switch code {
            case 0: self = .plain
            case 1: isBold = true
            case 2: isDim = true
            case 3: isItalic = true
            case 4: isUnderlined = true
            case 7: isInverse = true
            case 9: isStrikethrough = true
            case 22: isBold = false; isDim = false
            case 23: isItalic = false
            case 24: isUnderlined = false
            case 27: isInverse = false
            case 29: isStrikethrough = false
            case 30...37: foreground = .palette(UInt8(code - 30))
            case 39: foreground = nil
            case 40...47: background = .palette(UInt8(code - 40))
            case 49: background = nil
            case 90...97: foreground = .palette(UInt8(code - 90 + 8))
            case 100...107: background = .palette(UInt8(code - 100 + 8))
            case 38, 48:
                let (color, consumed) = Self.extendedColor(codes[index...])
                index += consumed
                if code == 38 { foreground = color ?? foreground } else { background = color ?? background }
            default: break
            }
        }
    }

    /// `5;n` (256-colour) or `2;r;g;b` (true colour) after a 38 or 48.
    static func extendedColor(_ codes: ArraySlice<Int>) -> (ANSIColor?, consumed: Int) {
        let values = Array(codes)
        func byte(_ position: Int) -> UInt8? {
            values.indices.contains(position) ? UInt8(exactly: values[position]) : nil
        }
        switch values.first {
        case 5:
            return (byte(1).map(ANSIColor.palette), min(2, values.count))
        case 2:
            guard let red = byte(1), let green = byte(2), let blue = byte(3) else { return (nil, values.count) }
            return (.rgb(red: red, green: green, blue: blue), 4)
        default:
            return (nil, 0)
        }
    }
}
