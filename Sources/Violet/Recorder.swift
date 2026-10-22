import AVFoundation
import VioletCore

@MainActor final class Recorder: ObservableObject {
    @Published var recording = false
    @Published var starting = false
    @Published var error: String?
    let ring = AudioRing()
    private let engine = AVAudioEngine()
    private var installed = false
    private var observers: [NSObjectProtocol] = []
    private var recovery: Task<Void, Never>?
    init() {
        observers.append(NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.recover() }
        })
    }
    private func recover() {
        guard recording else { return }
        recovery?.cancel()
        engine.stop()
        if installed { engine.inputNode.removeTap(onBus: 0); installed = false }
        recording = false
        error = "音频设备变化，正在恢复录音…"
        recovery = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await start()
        }
    }

    func start() async {
        guard !recording, !starting else { return }
        starting = true
        defer { starting = false }
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            error = "请在系统设置 → 隐私与安全性 → 麦克风中允许紫麦录音。"; return
        }
        let input = engine.inputNode
        let source = input.outputFormat(forBus: 0)
        guard source.sampleRate > 0, source.channelCount > 0,
              let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: source, to: target) else {
            error = "没有可用的麦克风。"; return
        }
        let destination = ring
        input.installTap(onBus: 0, bufferSize: 4096, format: source) { buffer, _ in
            let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * 16000 / source.sampleRate) + 64)
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
            var supplied = false
            var conversionError: NSError?
            converter.convert(to: output, error: &conversionError) { _, status in
                if supplied { status.pointee = .noDataNow; return nil }
                supplied = true; status.pointee = .haveData; return buffer
            }
            guard conversionError == nil, let samples = output.floatChannelData?[0] else { return }
            destination.append(Array(UnsafeBufferPointer(start: samples, count: Int(output.frameLength))))
        }
        installed = true
        do { try engine.start(); recording = true; error = nil
            UserDefaults.standard.set(true, forKey: "recordingEnabled") }
        catch { self.error = error.localizedDescription; stop() }
    }
    func stop() {
        recovery?.cancel(); recovery = nil
        UserDefaults.standard.set(false, forKey: "recordingEnabled")
        engine.stop()
        if installed { engine.inputNode.removeTap(onBus: 0); installed = false }
        recording = false
    }
}
