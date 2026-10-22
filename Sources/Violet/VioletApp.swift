import SwiftUI
import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    let shortcut = GlobalShortcut()
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var workspaceObservers: [NSObjectProtocol] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenus()
        shortcut.action = { [weak self] in self?.recall() }
        if !shortcut.registered { model.status = "快捷键 ⌘⇧V 被其他应用占用，请使用菜单栏回溯。" }
        showWindow()
        resumeCapture()
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.model.recorder.suspend()
                await self?.model.systemRecorder.suspend()
            }
        })
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.resumeCapture() }
        })
    }
    private func resumeCapture() {
        guard !model.testFixture else { return }
        Task {
            if UserDefaults.standard.bool(forKey: "recordingEnabled") { await model.recorder.start() }
            if UserDefaults.standard.bool(forKey: "systemRecordingEnabled") { await model.systemRecorder.start() }
        }
    }
    @objc func recall() { model.refresh(); model.status = "已回溯最新音轨"; showWindow() }
    @objc func settings() { model.settings = true; showWindow() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc private func statusClicked() {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp, let menu = statusMenu, let button = statusItem?.button {
            NSMenu.popUpContextMenu(menu, with: event, for: button)
        } else { recall() }
    }
    private func installMenus() {
        let menu = NSMenu()
        let recall = NSMenuItem(title: "回溯录音", action: #selector(recall), keyEquivalent: "v")
        recall.keyEquivalentModifierMask = [.command, .shift]; recall.target = self; menu.addItem(recall)
        let settings = NSMenuItem(title: "设置…", action: #selector(settings), keyEquivalent: ","); settings.target = self; menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出紫麦", action: #selector(quit), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "紫麦")
        item.button?.contentTintColor = .systemPurple
        item.button?.target = self; item.button?.action = #selector(statusClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item; statusMenu = menu
        let main = NSMenu(); let application = NSMenuItem(); application.submenu = menu.copy() as? NSMenu; main.addItem(application)
        let edit = NSMenuItem(); edit.title = "编辑"; let editMenu = NSMenu(title: "编辑")
        for (title, selector, key) in [("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            editMenu.addItem(NSMenuItem(title: title, action: Selector(selector), keyEquivalent: key))
        }
        edit.submenu = editMenu; main.addItem(edit); NSApp.mainMenu = main
    }
    func showWindow() {
        if window == nil {
            let created = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            created.title = "紫麦 · Violet"
            created.isReleasedWhenClosed = false
            created.contentView = NSHostingView(rootView: MainView(model: model, recorder: model.recorder, systemRecorder: model.systemRecorder))
            created.center(); window = created
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.busy else { return .terminateNow }
        let alert = NSAlert(); alert.messageText = "转写或保存仍在进行"; alert.informativeText = "关闭窗口可以继续后台处理；现在退出会中断任务。"
        alert.addButton(withTitle: "继续后台处理"); alert.addButton(withTitle: "退出并中断")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
}
@main struct VioletApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate; app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}
struct MainView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var recorder: Recorder
    @ObservedObject var systemRecorder: SystemRecorder
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Image(systemName: "mic.fill").font(.system(size: 30)).foregroundStyle(.purple)
                VStack(alignment: .leading) {
                    Text("留住刚刚说过的话").font(.title.bold())
                    Text(recorder.recording ? "正在本地录音 · 最多保留最近 30 分钟" : "录音已暂停").foregroundStyle(.secondary)
                }
                Spacer()
                Button(recorder.starting ? "等待麦克风授权…" : recorder.recording ? "暂停" : "开始录音") { if recorder.recording { recorder.stop() } else { Task { await recorder.start() } } }.disabled(recorder.starting)
                Button { model.settings = true } label: { Image(systemName: "gearshape") }
            }
            if model.testFixture { Text("测试模式 · 使用合成音频，未开启麦克风").font(.caption.bold()).foregroundStyle(.orange) }
            if let error = recorder.error { Text(error).foregroundStyle(.red) }
            if let error = systemRecorder.error { Text(error).foregroundStyle(.red) }
            HStack {
                Picker("音轨", selection: $model.source) { Text("麦克风").tag("麦克风"); Text("系统音频").tag("系统音频") }.pickerStyle(.segmented).frame(width: 240)
                    .onChange(of: model.source) { _, _ in model.refresh() }
                Spacer()
                Button(systemRecorder.recording ? "暂停系统采集" : "开启系统音频") {
                    Task { if systemRecorder.recording { await systemRecorder.stop() } else { await systemRecorder.start() } }
                }.disabled(systemRecorder.starting)
            }
            HStack {
                Text("选取一段声音").font(.headline)
                Spacer()
                ForEach([1,5,15], id: \.self) { minutes in Button("最近 \(minutes) 分钟") { model.refresh(minutes: Double(minutes)) } }
                Stepper("\(Int(model.recallMinutes)) 分钟", value: $model.recallMinutes, in: 1...30, step: 1).frame(width: 110)
                Button("回溯") { model.refresh() }
            }
            if model.loading { ProgressView("加载音轨…").controlSize(.small) }
            if let snapshot = model.snapshot, snapshot.duration > 0 {
                Waveform(peaks: model.peaks, duration: snapshot.duration, start: $model.start, end: $model.end).frame(height: 132)
                HStack {
                    Text("起点 \(model.start, specifier: "%.1f") 秒 → 终点 \(model.end, specifier: "%.1f") 秒").monospacedDigit()
                    Spacer()
                    Text("已选 \(model.end - model.start, specifier: "%.1f") 秒").foregroundStyle(.purple)
                    Button("试听") { model.preview() }
                }.font(.caption)
            } else {
                RoundedRectangle(cornerRadius: 16).fill(.purple.opacity(0.06)).overlay(Text("开始录音后，点击“回溯”选择历史片段").foregroundStyle(.secondary)).frame(height: 156)
            }
            HStack {
                Button("转写并复制") { model.transcribe(save: false) }.buttonStyle(.borderedProminent)
                Button("后台转写并保存") { model.transcribe(save: true) }.buttonStyle(.bordered)
                if model.busy { ProgressView().controlSize(.small) }
                Spacer()
                Text("仅选中片段发送给转写服务").font(.caption).foregroundStyle(.secondary)
            }.disabled(model.busy || model.loading || model.end <= model.start)
            HStack {
                Text(model.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Spacer()
                if !model.text.isEmpty {
                    Button("复制文字") { model.copy() }
                    Button("保存文字") { model.saveText() }.disabled(model.busy)
                }
                if let url = model.savedURL { Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([url]) } }
            }
            ScrollView { Text(model.text.isEmpty ? "转写后的中文会显示在这里。" : model.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding() }
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        }.padding(28).frame(minWidth: 760, minHeight: 590).tint(.purple)
            .sheet(isPresented: $model.settings) { ConfigurationView(model: model) }
            .onAppear { model.refresh() }

    }
}
struct Waveform: View {
    let peaks: [Float]
    let duration: Double
    @Binding var start: Double
    @Binding var end: Double
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12).fill(.purple.opacity(0.05))
                Canvas { context, size in
                    for (i, peak) in peaks.enumerated() {
                        let x = Double(i) / Double(max(1, peaks.count)) * size.width
                        let height = max(2, min(1, Double(peak) * 3) * (size.height - 26))
                        context.fill(Path(roundedRect: CGRect(x: x, y: (size.height-height)/2, width: 2, height: height), cornerRadius: 1), with: .color(.purple.opacity(0.65)))
                    }
                }
                Rectangle().fill(.purple.opacity(0.13)).frame(width: max(0, (end-start)/duration*width)).offset(x: start/duration*width)
                handle("起点", position: start/duration*width).gesture(DragGesture(coordinateSpace: .named("wave")).onChanged { start = max(0, min(end - 0.1, $0.location.x/width*duration)) })
                handle("终点", position: end/duration*width).gesture(DragGesture(coordinateSpace: .named("wave")).onChanged { end = min(duration, max(start + 0.1, $0.location.x/width*duration)) })
            }.coordinateSpace(name: "wave")
        }
    }
    func handle(_ label: String, position: Double) -> some View {
        RoundedRectangle(cornerRadius: 5).fill(.purple).frame(width: 18).overlay(Image(systemName: "scissors").font(.system(size: 11)).foregroundStyle(.white)).offset(x: position-9).accessibilityLabel(label)
    }
}
struct ConfigurationView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("让紫麦听懂中文").font(.title.bold())
            Text("录音保留在本地。选段转写时，音频才会发送到你配置的服务。费用与额度由服务商决定。").foregroundStyle(.secondary)
            HStack {
                Button("使用 ElevenLabs") { model.selectProvider(gemini: false) }
                Link("申请 API Key ↗", destination: URL(string: "https://elevenlabs.io/app/settings/api-keys")!)
            }
            HStack {
                Button("使用 Gemini") { model.selectProvider(gemini: true) }
                Link("Google AI Studio 获取 Key ↗", destination: URL(string: "https://aistudio.google.com/apikey")!)
            }
            Text("Gemini 的可用区域、免费额度和收费以 Google 控制台为准。长片段自动分段处理，避免单次请求过大。").font(.caption).foregroundStyle(.secondary)
            Text("登录服务商 → 创建具有语音转写权限的 Key → 粘贴到下面。也可配置支持 OpenAI 音频转写协议的 HTTPS 接口。").font(.caption)
            TextField("完整转写接口 URL", text: $model.endpoint)
            TextField("模型名称", text: $model.model)
            SecureField("API Key（保存到系统钥匙串）", text: $model.key)
            Divider()
            Text("Markdown 保存目录").font(.headline)
            HStack { TextField("路径", text: $model.directory); Button("选择…") { model.chooseDirectory() } }
            Text("后台转写会保存独立文档和 latest.md，agent 可直接读取。关闭窗口不会停止录音或正在进行的任务。").font(.caption).foregroundStyle(.secondary)
            if let error = model.configurationError { Text(error).foregroundStyle(.red).font(.caption) }
            HStack { Button("稍后配置") { model.settings = false }; Spacer(); Button("保存配置") { model.saveSettings() }.buttonStyle(.borderedProminent) }
        }.textFieldStyle(.roundedBorder).padding(30).frame(width: 570).tint(.purple)
    }
}
