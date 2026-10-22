import AppKit
import AVFoundation
import VioletCore

@MainActor final class AppModel: ObservableObject {
    let recorder = Recorder()
    let systemRecorder = SystemRecorder()
    @Published var source = "麦克风"
    @Published var peaks: [Float] = []
    @Published var loading = false
    private var refreshID = UUID()
    @Published var snapshot: AudioSnapshot?
    @Published var start = 0.0
    @Published var end = 0.0
    @Published var text = ""
    @Published var savedURL: URL?
    private var resultDuration = 0.0
    @Published var status = "准备就绪"
    @Published var busy = false
    @Published var settings = false
    @Published var configurationError: String?
    @Published var recallMinutes = 5.0
    @Published var endpoint = UserDefaults.standard.string(forKey: "endpoint") ?? "https://api.elevenlabs.io/v1/speech-to-text"
    @Published var model = UserDefaults.standard.string(forKey: "model") ?? "scribe_v2"
    @Published var key = ""
    @Published var directory = UserDefaults.standard.string(forKey: "directory") ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads/Violet").path
    private var player: AVAudioPlayer?
    private var task: Task<Void, Never>?
    @Published var testFixture = false
    init() {
        key = KeyStore.read(); settings = key.isEmpty
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if let path = env["VIOLET_UI_TEST_WAV"], let testKey = env["VIOLET_UI_TEST_KEY"], let output = env["VIOLET_UI_TEST_DIRECTORY"] {
            do {
                let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
                guard file.processingFormat.sampleRate == 16000, file.processingFormat.channelCount == 1,
                      let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { return }
                try file.read(into: buffer)
                if let channel = buffer.floatChannelData?[0] {
                    recorder.ring.append(Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))))
                    key = testKey; directory = output; settings = false; testFixture = true
                    status = "测试模式：合成音频，非麦克风录音"
                }
            } catch { status = "测试音频加载失败" }
        }
        #endif
    }
    func refresh(minutes: Double? = nil) {
        let ring = source == "系统音频" ? systemRecorder.ring : recorder.ring
        let id = UUID(); refreshID = id; loading = true
        Task {
            let result = await Task.detached { let shot = ring.snapshot(); return (shot, shot.peaks(bins: 180)) }.value
            guard refreshID == id else { return }
            snapshot = result.0; peaks = result.1
            end = result.0.duration; start = max(0, end - (minutes ?? recallMinutes) * 60)
            loading = false
        }
    }

    func saveSettings() {
        configurationError = nil
        endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: endpoint), url.scheme == "https", url.host != nil, !model.isEmpty, !key.isEmpty else {
            configurationError = "请填写 HTTPS 接口、模型和 API Key。"; return
        }
        directory = NSString(string: directory).expandingTildeInPath
        guard directory.hasPrefix("/") else { configurationError = "请选择有效的绝对保存路径。"; return }
        do {
            let target = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            let probe = target.appendingPathComponent(".violet-write-test-" + UUID().uuidString)
            try Data().write(to: probe, options: .atomic)
            try FileManager.default.removeItem(at: probe)
            try KeyStore.save(key)
            UserDefaults.standard.set(endpoint, forKey: "endpoint"); UserDefaults.standard.set(model, forKey: "model"); UserDefaults.standard.set(directory, forKey: "directory")
            settings = false; status = "配置已保存"
        } catch { configurationError = "无法保存配置：\(error.localizedDescription)" }
    }
    func saveText() {
        guard !text.isEmpty, !busy else { return }
        let result = text, duration = resultDuration, destination = URL(fileURLWithPath: directory, isDirectory: true)
        busy = true
        Task {
            defer { busy = false }
            do {
                savedURL = try await Task.detached { try TranscriptStore.save(text: result, duration: duration, directory: destination) }.value
                status = "文字已保存"
            } catch { status = "保存失败：\(error.localizedDescription)" }
        }
    }
    func selectProvider(gemini: Bool) {
        endpoint = gemini ? "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions" : "https://api.elevenlabs.io/v1/speech-to-text"
        model = gemini ? "gemini-3.8-flash" : "scribe_v2"
        key = ""
    }
    func chooseDirectory() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url { directory = url.path }
    }
    func preview() {
        do { guard let shot = try snapshot?.selected(start: start, end: end) else { return }; player = try AVAudioPlayer(data: shot.wav()); player?.play() }
        catch { status = error.localizedDescription }
    }
    func copy() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string); status = "已复制" }
    func transcribe(save: Bool) {
        guard !busy, let snapshot else { return }
        do {
            let selected = try snapshot.selected(start: start, end: end)
            guard selected.duration >= 0.1 else { status = "请选择至少 0.1 秒的语音"; return }
            let configuration = SpeechConfiguration(endpoint: endpoint, model: model, key: key)
            let destination = URL(fileURLWithPath: directory, isDirectory: true)
            busy = true; status = save ? "后台转写中，可以关闭窗口" : "正在转写所选片段…"
            task = Task {
                defer { busy = false; task = nil }
                do {
                    let result = try await Transcriber.transcribe(audio: selected, configuration: configuration)
                    text = result; resultDuration = selected.duration; savedURL = nil
                    if save {
                        do {
                            let url = try await Task.detached { try TranscriptStore.save(text: result, duration: selected.duration, directory: destination) }.value
                            savedURL = url; status = "已保存：\(url.lastPathComponent)"
                        } catch { status = "转写已完成，但保存失败：\(error.localizedDescription)。可修改目录后点击保存文字。" }
                    } else { copy() }
                } catch { status = "转写失败：\(error.localizedDescription)" }
            }
        } catch { status = "请选择有效的音频区间" }
    }
}
