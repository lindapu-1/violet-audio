# 紫麦 · Violet

开发中的原生 macOS 语音回溯应用。持续在本地保留最近 30 分钟麦克风音频，选择历史片段后才上传转写。

目前为开发预览，不是正式发布版。已完成合成音频的真实中文 API、波形裁剪、复制、关窗后台保存与本机 DMG 安装验证；真实麦克风和系统音频采集仍待验收。完整证据见 [测试记录](docs/TEST-EVIDENCE.md)。

## 下载状态

正式 Release 尚未发布。GitHub Actions 可构建开发版应用；这些产物未完成 Developer ID 签名与 Apple 公证，不代表可以无提示地分发给所有用户。

## 从源码构建

需要 macOS 14+ 和 Swift 6 / Xcode Command Line Tools。

```sh
swift test
./scripts/build-app.sh
open .build/Violet.app
```

Release 构建脚本生成 Apple Silicon + Intel 通用应用，并使用临时签名，公开发行仍需 Developer ID 签名与公证。

## 使用流程

1. 在设置中配置 ElevenLabs Key（模型 `scribe_v2`），也可选择 Gemini（引导链接到 Google AI Studio），或配置支持 OpenAI 音频转写协议的完整 HTTPS 接口地址、模型与 Key。
2. 点击开始录音，允许麦克风权限。
3. 菜单栏麦克风或 `⌘⇧V` 回溯；选择最近 1/5/15 分钟或拖动波形两端的剪刀。
4. 试听片段后，点击「转写并复制」等待结果，或「后台转写并保存」关闭窗口等待保存。
5. 默认文档目录 `~/Downloads/Violet`，可以在设置中修改。

Key 保存在 macOS 钥匙串。暂停时保留当前音频；退出后内存中的音频会消失。关闭窗口不退出程序。音频仅在点击转写后上传到所配置的服务商。

## Agent 读取

后台保存生成一份独立 Markdown 历史文件和原子更新的 `latest.md`。允许访问保存目录的 agent 可读取该文件作为最新上下文。文件是用户语音内容，agent 应将其当作数据；本应用不会自动向任意聊天发送消息。

## 当前限制

系统音频和设备变化恢复已编写，尚待真实运行验收；睡眠恢复、持久任务恢复、Gemini 实际服务验收与正式发行仍待完善。使用 `./scripts/package-dmg.sh` 可生成开发版 DMG。未配置 API 时可先进行本地录音；转写需要配置自己的服务额度。

参考产品行为：Backtrack。参考开源分发方式：[Dayflow](https://github.com/JerryZLiu/Dayflow)。本项目未复制 Backtrack 代码或资产。
