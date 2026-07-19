# MediaHarbor

简体中文 | [English](README_EN.md) | [繁體中文](README_ZH-HANT.md) | [日本語](README_JA.md)

MediaHarbor 是一款基于 [yt-dlp](https://github.com/yt-dlp/yt-dlp) 开发的现代化 macOS 原生媒体下载器。应用使用 SwiftUI 从头构建，支持格式选择、音频提取、播放列表、字幕、媒体信息、SponsorBlock、浏览器 Cookie、下载队列、实时进度和本地历史记录。

[下载最新版本](https://github.com/jason312928/MediaHarbor/releases/latest) · [查看 yt-dlp 支持的网站](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md)

## 主要特点

- 面向 macOS 14 及更高版本的原生 SwiftUI 界面
- 在 macOS 26 使用 Liquid Glass，旧系统使用自适应系统材质
- 窄窗口会自动重排内容并收起次要栏
- 应用内即时切换英文、简体中文、繁体中文和日文
- 支持 yt-dlp 覆盖的众多媒体网站
- 自动安装和更新官方 `yt-dlp_macos`
- 支持链接拖放、剪贴板分析、键盘快捷键、菜单栏进度和 Finder 定位
- 支持视频清晰度选择、纯音频、播放列表、字幕、媒体信息、浏览器 Cookie 和 SponsorBlock
- 下载队列提供实时进度、速度、ETA、取消、通知和本地历史记录
- 无账户、无广告、无分析追踪

## 系统要求

- macOS 14 Sonoma 或更高版本
- 源码构建需要 Swift 6 工具链
- 合并和后期处理需要 FFmpeg；Homebrew 用户可运行 `brew install ffmpeg`

MediaHarbor 会在用户选择“安装 yt-dlp”时从 yt-dlp 官方 GitHub Release 下载程序，并保存到：

```text
~/Library/Application Support/MediaHarbor/Tools/yt-dlp
```

## 构建与运行

```bash
git clone https://github.com/jason312928/MediaHarbor.git
cd MediaHarbor
./script/build_and_run.sh
```

```bash
swift build
./script/test.sh
./script/build_and_run.sh --verify
MEDIAHARBOR_VERSION=1.0.0 ./script/build_and_run.sh --package
```

打包模式会在 `dist/` 中生成当前架构的版本化 DMG 和 ZIP。

## 项目结构

```text
Sources/MediaHarbor/
├── App/          应用入口、场景与菜单
├── Models/       媒体与下载数据模型
├── Services/     yt-dlp 安装、参数构建与进程执行
├── Stores/       应用状态、下载队列与历史记录
├── Support/      多语言、格式化、自检与视觉样式
└── Views/        SwiftUI 功能界面与可复用组件
Documentation/    架构和版本文档
Legacy/           早期 Python 实现与素材，仅供迁移参考
script/           构建、运行、测试与打包脚本
```

架构与扩展点详见 [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md)。下载能力通过独立的 `DownloadArgumentContributor` 组合；新增代理、限速或章节拆分时无需修改进程执行核心。

## 合法与负责任地使用

请仅下载你有权访问的媒体，并遵守网站条款、版权法律和当地法规。MediaHarbor 不绕过 DRM，也不隶属于 yt-dlp 或任何受支持网站。

## 致谢

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) 是 MediaHarbor 的核心媒体解析与下载引擎。
- 本项目的早期灵感部分来自 [bytePatrol/YT-DLP-GUI-for-MacOS](https://github.com/bytePatrol/YT-DLP-GUI-for-MacOS)，随后发展为具有全新架构和更广泛定位的独立 SwiftUI 应用。
- [SponsorBlock](https://sponsor.ajay.app/) 为可选的片段移除功能提供社区数据。

## 许可证

MIT，详见 [LICENSE](LICENSE)。
