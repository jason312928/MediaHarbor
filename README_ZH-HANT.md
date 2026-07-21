# MediaHarbor

[简体中文](README.md) | [English](README_EN.md) | 繁體中文 | [日本語](README_JA.md)

MediaHarbor 是一款以 [yt-dlp](https://github.com/yt-dlp/yt-dlp) 為核心打造的現代化 macOS 原生媒體下載器。應用程式使用 SwiftUI 從頭建構，支援格式選擇、音訊擷取、播放清單、字幕、媒體資訊、SponsorBlock、瀏覽器 Cookie、下載佇列、即時進度及本機歷史記錄。

[下載最新版本](https://github.com/jason312928/MediaHarbor/releases/latest) · [查看 yt-dlp 支援的網站](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md)

## 主要特色

- 面向 macOS 14 或以上版本的原生 SwiftUI 介面
- 在 macOS 26 使用 Liquid Glass，舊系統使用自適應系統材質
- 窄視窗會自動重排內容並收合次要欄位
- 可即時切換英文、簡體中文、繁體中文及日文
- 支援 yt-dlp 涵蓋的眾多媒體網站，包括 YouTube、TikTok、嗶哩嗶哩、Instagram、X / Twitter、Facebook、Twitch、Vimeo、SoundCloud 及 Reddit
- 按需安裝及更新官方 `yt-dlp_macos`
- 支援連結拖放、剪貼簿分析、鍵盤快捷鍵、選單列進度及 Finder 定位
- 支援影片畫質、純音訊及僅字幕下載；可偵測人工與自動字幕、篩選語言、輸出 SRT/VTT/ASS，並選擇保留獨立字幕檔或嵌入影片
- 支援播放清單、媒體資訊、瀏覽器 Cookie 及 SponsorBlock；登入或受限內容可直接讀取常用瀏覽器 Cookie
- 下載佇列提供進度、速度、ETA、取消、通知及本機歷史記錄
- 無帳號、無廣告、無分析追蹤

## 系統需求

- macOS 14 Sonoma 或以上版本
- 從原始碼建構需要 Swift 6 工具鏈
- 合併及後製需要 FFmpeg；Homebrew 使用者可執行 `brew install ffmpeg`

MediaHarbor 會在使用者選擇安裝時，從 yt-dlp 官方 GitHub Release 下載程式並儲存於：

```text
~/Library/Application Support/MediaHarbor/Tools/yt-dlp
```

## 建構與執行

```bash
git clone https://github.com/jason312928/MediaHarbor.git
cd MediaHarbor
./script/build_and_run.sh
```

```bash
swift build
./script/test.sh
./script/build_and_run.sh --verify
MEDIAHARBOR_VERSION=1.1.0 ./script/build_and_run.sh --package
```

打包模式會在 `dist/` 內建立目前架構的版本化 DMG 與 ZIP。

## 專案結構

```text
Sources/MediaHarbor/
├── App/          應用程式入口、場景與選單
├── Models/       媒體與下載資料模型
├── Services/     yt-dlp 安裝、參數建立與程序執行
├── Stores/       應用程式狀態、下載佇列與本機歷史
├── Support/      多語言、格式化、自我檢查與視覺樣式
└── Views/        SwiftUI 功能介面與可重用元件
Documentation/    架構與版本文件
script/           建構、執行、測試與打包腳本
```

資料流程與擴充點請參閱 [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md)。下載能力以獨立的 `DownloadArgumentContributor` 組合，新增代理、限速或章節分割時無需修改程序執行核心。

## 合法及負責任地使用

請只下載你獲授權存取的媒體，並遵守網站條款、版權法及當地法規。MediaHarbor 不會繞過 DRM，也不隸屬於 yt-dlp 或任何受支援網站。

## 鳴謝

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) 是 MediaHarbor 的核心媒體解析與下載引擎。
- [SponsorBlock](https://sponsor.ajay.app/) 為可選的片段移除功能提供社群資料。

## 授權條款

MIT，詳見 [LICENSE](LICENSE)。
