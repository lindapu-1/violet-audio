import XCTest
@testable import VioletCore
final class TranscriptStoreTests: XCTestCase {
    func testHistoryPreservedAndLatestUpdated() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try TranscriptStore.save(text: "你好，这是第一段。", duration: 2.5, directory: directory)
        let second = try TranscriptStore.save(text: "这是最新上下文。", duration: 4, directory: directory)
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(try String(contentsOf: first, encoding: .utf8).contains("你好，这是第一段。"))
        XCTAssertEqual(try Data(contentsOf: second), try Data(contentsOf: directory.appendingPathComponent("latest.md")))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 3)
    }
}
