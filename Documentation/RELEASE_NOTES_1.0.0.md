# MediaHarbor 1.0.0

The first public release of MediaHarbor: a modern, native macOS frontend for yt-dlp, built from the ground up with SwiftUI.

MediaHarbor 1.0.0 includes responsive window layouts, live English, Simplified Chinese, Traditional Chinese, and Japanese interfaces, format discovery, audio extraction, playlists, subtitles, metadata, SponsorBlock, browser cookies, a download queue, live progress, notifications, and local history. The app installs and updates the official yt-dlp macOS executable on demand.

## Downloads

- `MediaHarbor-v1.0.0-macos-arm64.dmg` — recommended installer for Apple Silicon Macs
- `MediaHarbor-v1.0.0-macos-arm64.zip` — portable archive for Apple Silicon Macs
- Intel Mac users can build from source with Swift 6 and the macOS 26 SDK.

This community preview is ad-hoc signed but not Apple-notarized. On first launch, macOS may ask you to confirm the app in **System Settings → Privacy & Security → Open Anyway**.

## 安装说明

这是 MediaHarbor 的首个公开版本。Apple Silicon 用户建议下载 DMG，打开后将 `MediaHarbor.app` 拖入 Applications 文件夹。应用采用临时签名，但尚未通过 Apple 公证；如果首次打开时被 macOS 阻止，请前往 **系统设置 → 隐私与安全性 → 仍要打开**。

MediaHarbor 会在你选择安装时从 yt-dlp 官方 GitHub Release 下载下载引擎。本仓库和安装包均不捆绑 yt-dlp、媒体文件、Cookie、账户信息或分析追踪。

## SHA-256

```text
83a4fd371ff92f95fcb715493f7c7a2509bc6482cf3c673b841253d544fa4021  MediaHarbor-v1.0.0-macos-arm64.zip
f3adc01c314584747738c04a7e2ab31f6a204c94d4d7e7574433e8e768968142  MediaHarbor-v1.0.0-macos-arm64.dmg
```

MediaHarbor is powered by [yt-dlp](https://github.com/yt-dlp/yt-dlp) and was inspired in part by [bytePatrol/YT-DLP-GUI-for-MacOS](https://github.com/bytePatrol/YT-DLP-GUI-for-MacOS).
