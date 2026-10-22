import XCTest
@testable import VioletCore
final class LiveSpeechTests: XCTestCase {
    func testChineseFileTranscription() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let key = env["VIOLET_TEST_API_KEY"], let path = env["VIOLET_TEST_WAV"] else { throw XCTSkip("Requires an explicitly supplied test key and synthetic audio") }
        let text = try await Transcriber.transcribe(wav: Data(contentsOf: URL(fileURLWithPath: path)), configuration: SpeechConfiguration(endpoint: "https://api.elevenlabs.io/v1/speech-to-text", model: "scribe_v2", key: key))
        XCTAssertTrue(text.contains("紫色") || text.contains("麦克风"), "Synthetic Chinese phrase was not recognized")
        XCTAssertTrue(text.contains("明天") && text.contains("会议"), "Synthetic sentence was not recognized")
        if let output = env["VIOLET_TEST_RESULT"] { try text.write(toFile: output, atomically: true, encoding: .utf8) }
    }
}
