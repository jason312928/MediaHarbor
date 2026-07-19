# Architecture

MediaHarbor keeps the macOS interface and the yt-dlp process boundary deliberately separate.

```text
SwiftUI views
    ↓ user intent / observable state
DownloadStore (@MainActor)
    ↓ structured async calls
YTDLPService (actor)
    ↓ YTDLPCommandBuilder + feature contributors
Process + JSON / progress lines
official yt-dlp executable
```

## State ownership

- `DownloadStore` owns scene-visible media, queue, selection, errors, and tool state.
- `@AppStorage` owns user preferences such as output location and subtitle options.
- `YTDLPService` owns running `Process` instances and serializes installation/update work.
- Completed history is encoded as JSON under Application Support; it never leaves the Mac.

## Process boundary

Analysis requests use `--dump-single-json`. The result is decoded into `MediaInfo`, so views never parse command output. Downloads use a dedicated progress template and `--print after_move:filepath`; only these stable lines cross back into the store.

New yt-dlp features should be added to `DownloadConfiguration` and implemented as a focused `DownloadArgumentContributor` in `YTDLPCommandBuilder`. The standard builder composes core output, format, metadata, subtitle, SponsorBlock, browser-cookie, and playlist contributors. Avoid placing command construction in views or growing `YTDLPService` into another monolith.

## Extension points

- Add a built-in download capability by implementing `DownloadArgumentContributor` and registering it in `standardContributors`. Experiments and optional modules can be injected through `YTDLPCommandBuilder(additionalContributors:)` without editing the service actor.
- Add a preference surface as a focused view under `Views/Settings/`, then register one tab in `SettingsView`.
- Add Discover UI under `Views/Components/`; the scene root should remain layout composition only.
- Add a language by extending `AppLanguage` and adding one translation table in `Localization.swift`. Missing optional strings fall back to English.
- Add a library destination through `SidebarDestination`, with its feature view kept in a separate source file.

## Platform design

- `NavigationSplitView` provides the source-list/detail structure.
- At compact widths, the source list and inspector collapse automatically while media cards switch to vertical composition.
- The main media options use the macOS inspector instead of a modal settings screen.
- Durable settings use a dedicated `Settings` scene.
- A `MenuBarExtra` provides lightweight active-download visibility.
- AppKit is limited to clipboard access, Finder reveal, app activation, and the directory panel.
- macOS 26 receives system Liquid Glass through an availability-gated view modifier; macOS 14–15 receive adaptive material cards.

## Security notes

- URLs are passed as `Process.arguments`, never interpolated into a shell command.
- yt-dlp is fetched over HTTPS from the official GitHub release URL.
- Browser cookies are read by yt-dlp only when the user explicitly enables the option.
- MediaHarbor contains no telemetry or remote application service.
