# Contributing

Thanks for helping improve MediaHarbor and the ecosystem around yt-dlp.

## Before opening a pull request

1. Search existing issues and keep each change focused.
2. Build and run the core checks with `./script/test.sh`.
3. Exercise the changed workflow through `./script/build_and_run.sh`.
4. Do not commit downloaded tools, media, build output, cookies, or account data.
5. Keep website-specific extraction logic in yt-dlp whenever possible. MediaHarbor should remain a generic frontend.

Use SwiftUI for product state and standard macOS controls. Keep direct AppKit code limited to capabilities SwiftUI cannot provide cleanly. Process arguments belong in focused `DownloadArgumentContributor` implementations composed by `YTDLPCommandBuilder`, not in views or the process runner.

Bug reports should include the macOS version, Mac architecture, MediaHarbor commit, yt-dlp version, and sanitized error text. Never attach cookies or private URLs.
