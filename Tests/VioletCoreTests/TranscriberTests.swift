import XCTest
@testable import VioletCore
final class TranscriberTests: XCTestCase {
    func testElevenRequestUsesBatchModelAndChinese() throws {
        let request = try Transcriber.makeRequest(wav: Data([1,2,3]), configuration: .init(endpoint: "https://api.elevenlabs.io/v1/speech-to-text", model: "scribe_v2", key: "test-key"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "xi-api-key"), "test-key")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let body = String(decoding: request.httpBody!, as: UTF8.self)
        XCTAssertTrue(body.contains("name=\"model_id\"\r\n\r\nscribe_v2"))
        XCTAssertTrue(body.contains("name=\"language_code\"\r\n\r\nzho"))
        XCTAssertTrue(body.contains("filename=\"selection.wav\""))
    }
    func testGeminiEmbedsExactAudioAndDoesNotPutKeyInURL() throws {
        let request = try Transcriber.makeRequest(wav: Data([1,2,3]), configuration: .init(endpoint: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions", model: "gemini-3.8-flash", key: "test-key"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertFalse(request.url!.absoluteString.contains("test-key"))
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        let content = try XCTUnwrap(messages[0]["content"] as? [[String: Any]])
        let audio = try XCTUnwrap(content[1]["input_audio"] as? [String: String])
        XCTAssertEqual(Data(base64Encoded: audio["data"]!), Data([1,2,3]))
        XCTAssertEqual(audio["format"], "wav")
    }
    func testRejectsTruncatedAndEmptyOutput() throws {
        XCTAssertThrowsError(try Transcriber.decode(Data(#"{"text":"   "}"#.utf8), gemini: false))
        XCTAssertThrowsError(try Transcriber.decode(Data(#"{"choices":[{"message":{"content":"未完整"},"finish_reason":"length"}]}"#.utf8), gemini: true))
        XCTAssertEqual(try Transcriber.decode(Data(#"{"choices":[{"message":{"content":"中文。"},"finish_reason":"stop"}]}"#.utf8), gemini: true), "中文。")
    }
    func testRejectsInsecureEndpointBeforeSendingKey() {
        XCTAssertThrowsError(try Transcriber.makeRequest(wav: Data(), configuration: .init(endpoint: "http://example.com", model: "whisper", key: "secret")))
    }
}
