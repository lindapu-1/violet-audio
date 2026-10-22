# 发布与验收

## 普通用户发行

需要 Apple Developer ID Application 证书及已配置的 notarytool 钥匙串 profile。Apple Development 证书不能替代它。证书、私钥、密码不得提交至仓库。

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-existing-profile' \
./scripts/notarize-release.sh
```

脚本构建 release、启用 Hardened Runtime 与麦克风 entitlement、签名、提交 Apple 公证、校验 Accepted、装订票据并重新生成 SHA256。只有公证完成后才把产物作为普通用户正式发行。

参考：[Apple 自定义公证流程](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)。脚本尚未在可用 Developer ID 身份下实测；无证书时仅可构建明确标识的开发产物。

## 最终验收表

| 要求 | 当前证据 | 状态 |
|---|---|---|
| 中文引导与用户自配 API | 配置 UI、Keychain 代码；需要完整保存/重启验收 | 部分验证 |
| Always-on 麦克风 | AVAudioEngine；安装版等待系统授权 | 未完成 |
| 系统音频 | ScreenCaptureKit 编译通过 | 未完成 |
| 最近 N 分钟及两端波形裁剪 | 合成音频 UI 拖动与实际选段转写通过 | 通过；真实采集待验 |
| 快捷键与关窗重开 | 实际 CUA 操作通过 | 通过 |
| 中文转写及复制 | 实际 ElevenLabs 与系统粘贴通过 | 通过 |
| 关闭窗口后台保存 | 实际提交后关窗，磁盘 Markdown 与 latest.md 一致 | 通过 |
| 保存目录可设置 | 目录写入检查、UI 字段；测试目录真实写入 | 部分验证 |
| agent 读取上下文 | 从 latest.md 实际读取正文 | 通过 |
| 30 分钟有界缓冲 | 1801 秒样本模拟验证正确保留 1800 秒 | 通过；不代表实录稳定性 |
| 暂停间隔与恢复 | 间隔静音与过期清理测试通过；设备/睡眠恢复代码已写 | 部分验证 |
| 本地安装 | DMG 校验、复制安装、签名完整性和启动通过 | 通过（本机开发签名） |
| GitHub 开源 | 公开源码与云端 macOS 构建通过 | 通过 |
| 普通用户下载即用 | 缺 Developer ID、公证及正式 Release | 未完成 |

Gemini 协议适配有单元测试，但尚无真实账号请求证据。没有连续八小时运行、实际设备拔插或睡眠/唤醒实测证据。上述未完成项未满足前，不得宣称最终交付完成。
