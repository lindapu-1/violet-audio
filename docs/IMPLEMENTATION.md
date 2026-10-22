# 紫麦 Violet：交付范围与验收

当前状态：开发中，尚未可供用户日常使用。

## 用户确定的行为
- 独立原生 macOS 应用，紫色麦克风菜单栏入口。
- Always-on 本地音频采集，未提交选段时不请求转写服务。
- 固定宽度波形时间轴，两端独立拖动，选择任意历史片段；支持最近 N 分钟及全局快捷键。
- 冻结查看时的时间轴，持续录音不得让已选片段漂移。
- 中文转写：用户自行配置 API，首次使用提供申请网站与配置引导。
- 两条操作：在界面等待转写并复制；后台转写并自动保存 Markdown，关闭窗口继续运行。
- 保存目录可配置；agent 可读取最新转写及历史文档。
- 本地测试录音、裁剪、实际中文 API、后台保存、复制和安装包。
- 开源源码、许可证、构建说明、GitHub 发布流程与可下载安装包。

## 实现路线
1. 有界 PCM 环形缓冲、不可变快照、区间选择和 WAV 编码（已实现，待测试结果）。
2. AVAudioEngine 麦克风与系统音频采集、暂停与设备变化处理。
3. 波形与选择手柄、预览、菜单栏、全局快捷键、权限引导。
4. Keychain 配置、ElevenLabs 和可配置 API 适配、后台任务与错误恢复。
5. Markdown 原子保存与 agent 文件协议。
6. 真实端到端测试、DMG、开源发布与安装验证。

## 已核实来源
- https://github.com/JerryZLiu/Dayflow ：MIT，SwiftUI，macOS 14+，GitHub Releases DMG。
- 本地 Backtrack 逆向报告：../backtrack-reverse-engineering/report.md（仅行为参考，不复制其代码或资产）。
- 参考项目的配置示例：ASR_MODEL=scribe_v2_realtime，ASR_LANGUAGE=zh。密钥不进入本仓库。

## 尚未完成的验证
目前没有真实录音、网络转写、UI 交互、安装测试或 GitHub 发布证据。不得以单元测试代替这些验收。

## 2026-10-22 实现进度

已编写：SwiftUI 主窗口与菜单栏、两端波形选择、最近 N 分钟、WAV 试听、⌘⇧V 热键、Keychain、ElevenLabs 文件转写与兼容协议适配、后台任务、Markdown 历史与 latest.md 原子保存、本机 .app 构建脚本。
待核验：以上 UI 与服务调用均尚需真实端到端测试；系统音频、设备恢复与开源发行仍未完成。麦克风当前需用户点击开始，后续完善首次授权后自动恢复录音。

## 持续采集与性能更新

- 系统音频已通过 ScreenCaptureKit 编写为独立音轨，可与麦克风分别启动/暂停及选段。未做系统录音权限后的运行验证。
- 波形快照在后台创建，峰值缓存，拖动区间不再重新扫描整个 30 分钟音频。
- 环形缓冲改为批量复制，增加大于缓冲容量的写入与多次环绕边界测试。
- 麦克风设备配置变化后尝试恢复；实际拔插与睡眠仍待测试。
- 新增 DMG 打包脚本。开发版 ad-hoc 签名不是 Developer ID 公证；本机仅发现 Apple Development 身份，公开发行信任链尚未解决。

## 配置与保存完善
- 增加 Gemini 的 Google AI Studio 获取 Key 入口；使用当前官方文档示例模型，模型名称仍可编辑。不承诺免费额度。
- 自定义 1–30 分钟回溯；快照加载中禁用转写，避免新旧区间混用。
- 配置保存前验证 HTTPS、非空 Key/模型及目标目录写入能力。
- 转写服务重定向不自动跟随，防止自定义认证头被转发至其他域名。
- 真正的 Gemini 请求、长音频、完整 UI 路径与系统权限后的采集仍待验收；开发 DMG 尚未包含本轮新增代码，最终交付前需重建。

## 窗口生命周期修复

采用 NSApplication、NSWindow 与 NSStatusItem 承担生命周期，SwiftUI 仅渲染内容。快捷键直接由 AppDelegate 回溯并显示窗口，不依赖已关闭视图的 NotificationCenter 订阅。录音/转写所有权始终在 AppModel。键位冲突显示提示，任务忙碌时退出需要明确选择中断。窗口关闭与快捷键唤回已实测。

## Debug 端到端验证入口

仅 Debug 支持 `VIOLET_UI_TEST_WAV`（16kHz 单声道 WAV）、`VIOLET_UI_TEST_KEY`、`VIOLET_UI_TEST_DIRECTORY` 三个环境变量同时提供时载入合成音频。界面橙色标记测试模式；不请求麦克风权限、不把凭据写入 Keychain。用于真实 UI 与服务链路验证，不作为实际采集通过证据。Release 编译排除此分支。构建脚本默认 release，只有显式 `CONFIGURATION=debug` 才构建测试版。

## 开源与安装状态（2026-10-23）

公开源码：https://github.com/lindapu-1/violet-audio 。开发预览状态，尚未发布正式 Release。已从生成的 DMG 安装到用户 Applications 并启动验证。增加应用启动/系统唤醒时按用户此前启用状态恢复麦克风与系统音频；真实睡眠恢复仍待手动验收。
