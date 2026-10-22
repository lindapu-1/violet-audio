import AVFoundation
import ScreenCaptureKit
import VioletCore

/// Separate system track: app audio never gets appended to the microphone timeline.
@MainActor final class SystemRecorder: ObservableObject {
    @Published var recording = false
    @Published var starting = false
    @Published var error: String?
    let ring = AudioRing()
    private var stream: SCStream?
    private var stoppedAt: Date?
    private var output: SystemAudioOutput?
    func start() async {
        guard !recording, !starting else { return }
        starting = true; defer { starting = false }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { throw NSError(domain: "Violet", code: 1, userInfo: [NSLocalizedDescriptionKey: "没有可用的显示器音频来源"]) }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = 2; config.height = 2
            config.minimumFrameInterval = CMTime(seconds: 1, preferredTimescale: 1)
            config.capturesAudio = true; config.sampleRate = 16000; config.channelCount = 1
            config.excludesCurrentProcessAudio = true
            let output = SystemAudioOutput(ring: ring) { [weak self] message in
                Task { @MainActor in self?.error = message; self?.recording = false; self?.stoppedAt = Date() }
            }
            let stream = SCStream(filter: filter, configuration: config, delegate: output)
            try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: DispatchQueue(label: "app.violet.system-audio"))
            self.output = output; self.stream = stream
            if let stoppedAt { ring.appendSilence(seconds: Date().timeIntervalSince(stoppedAt)); self.stoppedAt = nil }
            try await stream.startCapture()
            recording = true; error = nil
            UserDefaults.standard.set(true, forKey: "systemRecordingEnabled")
        } catch {
            self.error = "系统音频未开始：\(error.localizedDescription)。请检查系统设置中的屏幕与系统音频录制权限。"
            stream = nil; output = nil
        }
    }
    func suspend() async {
        let wanted = UserDefaults.standard.bool(forKey: "systemRecordingEnabled")
        await stop()
        UserDefaults.standard.set(wanted, forKey: "systemRecordingEnabled")
    }
    func stop() async {
        if recording { stoppedAt = Date() }
        UserDefaults.standard.set(false, forKey: "systemRecordingEnabled")
        do { try await stream?.stopCapture() } catch { self.error = error.localizedDescription }
        recording = false; stream = nil; output = nil
    }
}
private final class SystemAudioOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    let ring: AudioRing
    let onError: (String) -> Void
    init(ring: AudioRing, onError: @escaping (String) -> Void) { self.ring = ring; self.onError = onError }
    func stream(_ stream: SCStream, didStopWithError error: Error) { onError("系统音频中断：\(error.localizedDescription)") }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid,
              let description = sampleBuffer.formatDescription else { return }
        let format = AVAudioFormat(cmAudioFormatDescription: description)
        guard format.commonFormat == .pcmFormatFloat32,
              format.sampleRate == 16000, format.channelCount == 1 else { return }
        var block: CMBlockBuffer?
        var list = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: 0, mData: nil))
        let code = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, bufferListSizeNeededOut: nil, bufferListOut: &list, bufferListSize: MemoryLayout<AudioBufferList>.size, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: 0, blockBufferOut: &block)
        guard code == noErr, let data = list.mBuffers.mData else { return }
        let count = Int(list.mBuffers.mDataByteSize) / MemoryLayout<Float>.size
        ring.append(Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: count)))
    }
}
