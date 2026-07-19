# MediaHarbor

[简体中文](README.md) | English | [繁體中文](README_ZH-HANT.md) | [日本語](README_JA.md)

MediaHarbor is a modern, native media downloader for macOS powered by [yt-dlp](https://github.com/yt-dlp/yt-dlp). Built from the ground up with SwiftUI, it provides format selection, audio extraction, playlists, subtitles, metadata, SponsorBlock, browser cookies, download queues, live progress, and local history.

[Download the latest release](https://github.com/jason312928/MediaHarbor/releases/latest) · [Browse yt-dlp supported sites](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md)

## Highlights

- Native SwiftUI interface for macOS 14 and later
- Liquid Glass on macOS 26 and adaptive system materials on earlier releases
- Responsive compact-window layout that automatically collapses secondary columns
- Live switching between English, Simplified Chinese, Traditional Chinese, and Japanese
- Works with the broad yt-dlp supported-sites catalog
- Installs and updates the official `yt-dlp_macos` release on demand
- URL drag and drop, clipboard analysis, keyboard commands, menu bar progress, and Finder reveal
- Video quality discovery, audio-only downloads, playlists, subtitles, metadata, browser cookies, and SponsorBlock
- Download queue with progress, speed, ETA, cancellation, notifications, and local history
- No accounts, ads, analytics, or bundled tracking

## Requirements

- macOS 14 Sonoma or later
- Swift 6 toolchain for source builds
- FFmpeg for merging and post-processing; Homebrew users can run `brew install ffmpeg`

MediaHarbor downloads yt-dlp from its official GitHub release when the user chooses **Install yt-dlp**. The executable is stored at:

```text
~/Library/Application Support/MediaHarbor/Tools/yt-dlp
```

## Build and run

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

Package mode creates versioned DMG and ZIP artifacts for the current architecture in `dist/`.

## Project layout

```text
Sources/MediaHarbor/
├── App/          App entry point, scenes, and menus
├── Models/       Media and download value types
├── Services/     yt-dlp installation, argument building, and process execution
├── Stores/       Application state, download queue, and local history
├── Support/      Localization, formatting, self-checks, and visual styles
└── Views/        SwiftUI feature surfaces and reusable components
Documentation/    Architecture and release documentation
Legacy/           Earlier Python implementation and assets for migration reference
script/           Build, run, test, and packaging entry points
```

See [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md) for the data flow and extension points. Download capabilities are composed as focused `DownloadArgumentContributor` implementations, so features such as proxies, rate limits, or chapter splitting do not need to modify the process runner.

## Legal and responsible use

Only download media you are authorized to access. Follow applicable website terms, copyright law, and local regulations. MediaHarbor does not bypass DRM and is not affiliated with yt-dlp or any supported website.

## Acknowledgments

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) provides the media extraction and download engine at the heart of MediaHarbor.
- The project was inspired in part by [bytePatrol/YT-DLP-GUI-for-MacOS](https://github.com/bytePatrol/YT-DLP-GUI-for-MacOS), then evolved into an independent native SwiftUI application with a new architecture and broader scope.
- [SponsorBlock](https://sponsor.ajay.app/) provides community-maintained data for the optional segment-removal integration.

## License

MIT. See [LICENSE](LICENSE).
