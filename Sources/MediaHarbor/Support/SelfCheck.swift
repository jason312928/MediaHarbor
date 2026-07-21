import Foundation

enum SelfCheck {
    static func run() -> [String] {
        var failures: [String] = []

        let progress = YTDLPService.parseProgress("download: 42.5%|3.2MiB/s|00:12")
        if progress == nil || abs((progress?.fraction ?? 0) - 0.425) > 0.0001
            || progress?.speed != "3.2MiB/s" || progress?.eta != "00:12" {
            failures.append("progress parser")
        }

        let selector = QualityChoice.video(height: 1080).formatSelector
        if selector != "bestvideo[height<=1080]+bestaudio/best[height<=1080]" {
            failures.append("quality selector")
        }

        let configuration = DownloadConfiguration(
            outputDirectory: "/tmp/MediaHarborSelfCheck",
            embedMetadata: true,
            embedSubtitles: false,
            downloadSubtitles: false,
            includeAutomaticSubtitles: true,
            subtitleLanguages: "en",
            subtitleFormat: "srt",
            sponsorBlock: false,
            browserCookies: "None",
            includePlaylist: false
        )
        let command = YTDLPCommandBuilder(additionalContributors: [SelfCheckArgumentContributor()])
            .arguments(for: DownloadRequest(url: "https://example.com/media", quality: .audio, configuration: configuration))
        if !command.contains("--extract-audio") || !command.contains("--self-check-feature") || command.last != "https://example.com/media" {
            failures.append("composable command builder")
        }

        let json = #"{"id":"abc","title":"Example","formats":[{"format_id":"1","height":720},{"format_id":"2","height":1080},{"format_id":"3","height":1080}],"subtitles":{"en":[{"ext":"vtt"}]},"automatic_captions":{"zh-Hans":[{"ext":"json3"}],"live_chat":[{"ext":"json"}]}}"#
        do {
            let info = try JSONDecoder().decode(MediaInfo.self, from: Data(json.utf8))
            if info.qualityChoices != [.video(height: 1080), .video(height: 720), .audio, .subtitles] {
                failures.append("quality de-duplication")
            }
            if info.subtitleLanguages != ["en", "zh-Hans"] {
                failures.append("subtitle discovery")
            }
        } catch {
            failures.append("media JSON decoding: \(error.localizedDescription)")
        }

        let subtitleConfiguration = DownloadConfiguration(
            outputDirectory: "/tmp/MediaHarborSelfCheck",
            embedMetadata: true,
            embedSubtitles: false,
            downloadSubtitles: false,
            includeAutomaticSubtitles: true,
            subtitleLanguages: "all,-live_chat",
            subtitleFormat: "srt",
            sponsorBlock: true,
            browserCookies: "None",
            includePlaylist: false
        )
        let subtitleCommand = YTDLPCommandBuilder().arguments(for: DownloadRequest(
            url: "https://www.bilibili.com/video/example",
            quality: .subtitles,
            configuration: subtitleConfiguration
        ))
        if !subtitleCommand.contains("--skip-download") || !subtitleCommand.contains("--write-subs")
            || !subtitleCommand.contains("--write-auto-subs") || !subtitleCommand.contains("--convert-subs")
            || subtitleCommand.contains("--sponsorblock-remove") {
            failures.append("subtitle-only command")
        }

        let embedOnlyConfiguration = DownloadConfiguration(
            outputDirectory: "/tmp/MediaHarborSelfCheck",
            embedMetadata: false,
            embedSubtitles: true,
            downloadSubtitles: false,
            includeAutomaticSubtitles: false,
            subtitleLanguages: "en",
            subtitleFormat: "best",
            sponsorBlock: false,
            browserCookies: "None",
            includePlaylist: false
        )
        let embedCommand = YTDLPCommandBuilder().arguments(for: DownloadRequest(
            url: "https://example.com/video",
            quality: .video(height: 720),
            configuration: embedOnlyConfiguration
        ))
        if !embedCommand.contains("--embed-subs") || !embedCommand.contains("no-keep-subs")
            || embedCommand.contains("--write-auto-subs") {
            failures.append("embed-only subtitle command")
        }

        if SupportedPlatform.matching("https://www.tiktok.com/@creator/video/1")?.id != "tiktok"
            || SupportedPlatform.matching("https://b23.tv/example")?.id != "bilibili"
            || SupportedPlatform.matching("https://www.instagram.com/reel/example")?.id != "instagram" {
            failures.append("popular platform matching")
        }

        return failures
    }
}

private struct SelfCheckArgumentContributor: DownloadArgumentContributor {
    func arguments(for request: DownloadRequest) -> [String] { ["--self-check-feature"] }
}
