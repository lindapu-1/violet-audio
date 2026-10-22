import XCTest
@testable import VioletCore
final class AudioRingTests: XCTestCase {
    func testWrapRetainsNewestAndSnapshotIsStable() throws {
        let ring = AudioRing(sampleRate: 4, seconds: 2)
        ring.append([0,1,2,3,4,5]); let frozen = ring.snapshot()
        ring.append([6,7,8,9]); let current = ring.snapshot()
        XCTAssertEqual(current.samples, [2,3,4,5,6,7,8,9]); XCTAssertEqual(current.startFrame, 2)
        XCTAssertEqual(frozen.samples, [0,1,2,3,4,5])
        XCTAssertEqual(try current.selected(start: 0.5, end: 1.5).samples, [4,5,6,7])
        XCTAssertThrowsError(try current.selected(start: -1, end: 1))
        XCTAssertThrowsError(try current.selected(start: 1, end: 3))
    }
    func testLargeWritesAndManyWrapsMatchReference() {
        let ring = AudioRing(sampleRate: 7, seconds: 3)
        var all: [Float] = []
        for count in [0, 1, 19, 3, 70, 2, 21, 22, 0, 200] {
            let values = (0..<count).map { Float(all.count + $0) }
            all.append(contentsOf: values); ring.append(values)
            XCTAssertEqual(ring.snapshot().samples, Array(all.suffix(21)))
            XCTAssertEqual(ring.snapshot().startFrame, Int64(max(0, all.count - 21)))
        }
    }
    func testPauseDoesNotMakeOldSpeechAppearRecent() {
        let ring = AudioRing(sampleRate: 2, seconds: 4)
        ring.append([1, 2, 3, 4]); ring.appendSilence(seconds: 1.5); ring.append([5])
        XCTAssertEqual(ring.snapshot().samples, [1,2,3,4,0,0,0,5])
        ring.appendSilence(seconds: 3600); ring.append([6])
        XCTAssertEqual(ring.snapshot().samples, [0,0,0,0,0,0,0,6])
        XCTAssertEqual(ring.snapshot().duration, 4)
    }
    func testFullThirtyMinuteCapacityAndExpiry() {
        let ring = AudioRing()
        let second = Array(repeating: Float(0.25), count: 16000)
        for _ in 0..<1801 { ring.append(second) }
        let shot = ring.snapshot()
        XCTAssertEqual(shot.duration, 1800)
        XCTAssertEqual(shot.startFrame, 16000)
        XCTAssertEqual(shot.samples.count, 28_800_000)
        XCTAssertEqual(shot.peaks(bins: 180), Array(repeating: Float(0.25), count: 180))
    }
    func testWavAndPeaks() {
        let ring = AudioRing(sampleRate: 4, seconds: 1); ring.append([0,-0.5,1,0])
        let shot = ring.snapshot(); XCTAssertEqual(shot.peaks(bins: 2), [0.5,1])
        let data = shot.wav(); XCTAssertEqual(data.count, 52)
        XCTAssertEqual(String(data: data.prefix(4), encoding: .utf8), "RIFF")
        XCTAssertEqual(Array(data[44..<52]), [0,0,1,192,255,127,0,0])
    }
}
