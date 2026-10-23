import Foundation

/// Decodes UTF-8 arriving in arbitrary chunks. A pipe read can split a
/// multi-byte character; the incomplete tail is held until the rest arrives.
/// Invalid bytes become U+FFFD instead of dropping the whole chunk.
struct UTF8StreamDecoder {
    private var pending: [UInt8] = []

    mutating func decode(_ chunk: Data) -> String {
        pending.append(contentsOf: chunk)
        let completeCount = Self.lengthOfCompletePrefix(pending)
        let text = String(decoding: pending[..<completeCount], as: UTF8.self)
        pending.removeFirst(completeCount)
        return text
    }

    mutating func finish() -> String {
        defer { pending.removeAll() }
        return String(decoding: pending, as: UTF8.self)
    }

    /// `bytes.count` minus an incomplete sequence at the end (at most 3 bytes).
    private static func lengthOfCompletePrefix(_ bytes: [UInt8]) -> Int {
        var continuationBytes = 0
        for index in bytes.indices.reversed() {
            let byte = bytes[index]
            if byte & 0b1100_0000 == 0b1000_0000 {
                continuationBytes += 1
                // More than 3 can't be one character's tail: invalid, let decoding flag it.
                if continuationBytes > 3 { return bytes.count }
                continue
            }
            let isIncomplete = continuationBytes + 1 < sequenceLength(leadByte: byte)
            return isIncomplete ? index : bytes.count
        }
        return bytes.count
    }

    private static func sequenceLength(leadByte: UInt8) -> Int {
        switch leadByte {
        case 0xC0...0xDF: 2
        case 0xE0...0xEF: 3
        case 0xF0...0xF7: 4
        default: 1
        }
    }
}
