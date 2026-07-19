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
            subtitleLanguages: "en",
            sponsorBlock: false,
            browserCookies: "None",
            includePlaylist: false
        )
        let command = YTDLPCommandBuilder(additionalContributors: [SelfCheckArgumentContributor()])
            .arguments(for: DownloadRequest(url: "https://example.com/media", quality: .audio, configuration: configuration))
        if !command.contains("--extract-audio") || !command.contains("--self-check-feature") || command.last != "https://example.com/media" {
            failures.append("composable command builder")
        }

        let json = #"{"id":"abc","title":"Example","formats":[{"format_id":"1","height":720},{"format_id":"2","height":1080},{"format_id":"3","height":1080}]}"#
        do {
            let info = try JSONDecoder().decode(MediaInfo.self, from: Data(json.utf8))
            if info.qualityChoices != [.video(height: 1080), .video(height: 720), .audio] {
                failures.append("quality de-duplication")
            }
        } catch {
            failures.append("media JSON decoding: \(error.localizedDescription)")
        }

        return failures
    }
}

private struct SelfCheckArgumentContributor: DownloadArgumentContributor {
    func arguments(for request: DownloadRequest) -> [String] { ["--self-check-feature"] }
}
