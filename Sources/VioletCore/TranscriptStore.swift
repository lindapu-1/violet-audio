import Foundation
public enum TranscriptStore {
    public static func save(text: String, duration: Double, directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let date = Date(); let iso = ISO8601DateFormatter().string(from: date)
        let name = iso.replacingOccurrences(of: ":", with: "-") + "-" + UUID().uuidString.prefix(8) + ".md"
        let url = directory.appendingPathComponent(name)
        let markdown = "# 语音转写\n\n- 时间：\(iso)\n- 片段时长：\(String(format: "%.1f", duration)) 秒\n\n\(text)\n"
        try Data(markdown.utf8).write(to: url, options: .atomic)
        try Data(markdown.utf8).write(to: directory.appendingPathComponent("latest.md"), options: .atomic)
        return url
    }
}
