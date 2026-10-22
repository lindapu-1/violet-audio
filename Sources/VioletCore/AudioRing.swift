import Foundation

/// Bounded mono PCM storage. Snapshot coordinates are absolute sample positions,
/// so recording may continue without moving the user's selected interval.
public final class AudioRing: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Float]
    private var position: Int64 = 0
    public let sampleRate: Int
    public init(sampleRate: Int = 16000, seconds: Int = 1800) {
        precondition(sampleRate > 0 && seconds > 0)
        self.sampleRate = sampleRate
        storage = Array(repeating: 0, count: sampleRate * seconds)
    }
    public func append(_ samples: [Float]) {
        lock.lock(); defer { lock.unlock() }
        let retained = min(samples.count, storage.count)
        let skip = samples.count - retained
        position += Int64(skip)
        let offset = Int(position % Int64(storage.count))
        let firstCount = min(retained, storage.count - offset)
        storage.replaceSubrange(offset..<(offset + firstCount), with: samples[skip..<(skip + firstCount)])
        if firstCount < retained { storage.replaceSubrange(0..<(retained-firstCount), with: samples[(skip+firstCount)...]) }
        position += Int64(retained)
    }
    public func snapshot() -> AudioSnapshot {
        lock.lock(); defer { lock.unlock() }
        let first = max(0, position - Int64(storage.count))
        let count = Int(position - first)
        let offset = Int(first % Int64(storage.count))
        let firstCount = min(count, storage.count - offset)
        var samples = Array(storage[offset..<(offset+firstCount)])
        if firstCount < count { samples.append(contentsOf: storage[0..<(count-firstCount)]) }
        return AudioSnapshot(samples: samples, sampleRate: sampleRate, startFrame: first)
    }
}

public struct AudioSnapshot: Sendable {
    public let samples: [Float]
    public let sampleRate: Int
    public let startFrame: Int64
    public var duration: Double { Double(samples.count) / Double(sampleRate) }
    public func selected(start: Double, end: Double) throws -> AudioSnapshot {
        guard start.isFinite, end.isFinite, start >= 0, end <= duration, end > start else { throw AudioError.invalidRange }
        let a = Int((start * Double(sampleRate)).rounded(.down))
        let b = min(samples.count, Int((end * Double(sampleRate)).rounded(.up)))
        return AudioSnapshot(samples: Array(samples[a..<b]), sampleRate: sampleRate, startFrame: startFrame + Int64(a))
    }
    public func peaks(bins: Int) -> [Float] {
        guard bins > 0 else { return [] }
        return (0..<bins).map { i in
            let a = i * samples.count / bins, b = (i + 1) * samples.count / bins
            return samples[a..<b].reduce(Float(0)) { max($0, abs($1)) }
        }
    }
    public func wav() -> Data {
        var result = Data()
        func ascii(_ value: String) { result.append(contentsOf: value.utf8) }
        func u16(_ value: UInt16) { var v = value.littleEndian; withUnsafeBytes(of: &v) { result.append(contentsOf: $0) } }
        func u32(_ value: UInt32) { var v = value.littleEndian; withUnsafeBytes(of: &v) { result.append(contentsOf: $0) } }
        ascii("RIFF"); u32(UInt32(36 + samples.count * 2)); ascii("WAVEfmt "); u32(16); u16(1); u16(1)
        u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16); ascii("data"); u32(UInt32(samples.count * 2))
        for sample in samples { let safe = sample.isFinite ? max(-1, min(1, sample)) : 0; u16(UInt16(bitPattern: Int16(safe * 32767))) }
        return result
    }
}
public enum AudioError: Error { case invalidRange }
