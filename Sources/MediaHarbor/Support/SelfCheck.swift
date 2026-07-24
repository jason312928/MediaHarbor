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

        let preparedCommand = YTDLPService.preparedDownloadArguments(
            command,
            temporaryDirectory: URL(fileURLWithPath: "/tmp/MediaHarborSelfCheck/job"),
            ffmpegURL: URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        )
        if !preparedCommand.contains("temp:/tmp/MediaHarborSelfCheck/job")
            || !preparedCommand.contains("--ffmpeg-location")
            || !preparedCommand.contains("/opt/homebrew/bin/ffmpeg")
            || preparedCommand.last != "https://example.com/media" {
            failures.append("download dependencies and temporary files")
        }

        let wordConfiguration = DownloadConfiguration(
            outputDirectory: "/tmp/MediaHarborSelfCheck",
            embedMetadata: false,
            embedSubtitles: false,
            downloadSubtitles: true,
            includeAutomaticSubtitles: false,
            subtitleLanguages: "ja",
            subtitleFormat: "rtf",
            sponsorBlock: false,
            browserCookies: "None",
            includePlaylist: false
        )
        let wordBaseCommand = YTDLPCommandBuilder().arguments(for: DownloadRequest(
            url: "https://example.com/video",
            quality: .subtitles,
            configuration: wordConfiguration
        ))
        let wordCommand = YTDLPService.preparedDownloadArguments(
            wordBaseCommand,
            temporaryDirectory: URL(fileURLWithPath: "/tmp/MediaHarborSelfCheck/word"),
            ffmpegURL: nil,
            stageSubtitles: true
        )
        if !wordCommand.contains("srt")
            || wordCommand.contains("rtf")
            || !wordCommand.contains("subtitle:/tmp/MediaHarborSelfCheck/word") {
            failures.append("Word subtitle staging")
        }

        let srt = """
        1
        00:00:01,000 --> 00:00:03,000
        <i>こんにちは</i>

        2
        00:00:04,000 --> 00:00:06,000
        字幕 &amp; transcript
        """
        let transcript = SubtitleDocumentExporter.transcriptParagraphs(fromSRT: srt)
        let rtf = SubtitleDocumentExporter.rtfDocument(title: "Example", paragraphs: transcript)
        if transcript != ["こんにちは", "字幕 & transcript"]
            || !rtf.hasPrefix("{\\rtf1")
            || !rtf.contains("\\u") {
            failures.append("Word subtitle conversion")
        }
        let documentCheckDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaHarborDocumentSelfCheck-\(UUID().uuidString)", isDirectory: true)
        do {
            let stagingDirectory = documentCheckDirectory.appendingPathComponent("staging", isDirectory: true)
            let outputDirectory = documentCheckDirectory.appendingPathComponent("output", isDirectory: true)
            try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
            try srt.write(
                to: stagingDirectory.appendingPathComponent("Example.ja.srt"),
                atomically: true,
                encoding: .utf8
            )
            let exports = try SubtitleDocumentExporter.exportRTFDocuments(
                from: stagingDirectory,
                to: outputDirectory
            )
            if exports.count != 1
                || exports.first?.pathExtension != "rtf"
                || !FileManager.default.fileExists(atPath: exports[0].path) {
                failures.append("Word subtitle file export")
            }
        } catch {
            failures.append("Word subtitle file export: \(error.localizedDescription)")
        }
        try? FileManager.default.removeItem(at: documentCheckDirectory)

        let json = #"{"id":"abc","title":"Example","width":1080,"height":1920,"formats":[{"format_id":"1","height":720},{"format_id":"2","height":1080},{"format_id":"3","height":1080}],"subtitles":{"en":[{"ext":"vtt"}]},"automatic_captions":{"zh-Hans":[{"ext":"json3"}],"live_chat":[{"ext":"json"}]}}"#
        do {
            let info = try JSONDecoder().decode(MediaInfo.self, from: Data(json.utf8))
            if info.qualityChoices != [.video(height: 1080), .video(height: 720), .audio, .subtitles] {
                failures.append("quality de-duplication")
            }
            if info.subtitleLanguages != ["en", "zh-Hans"] {
                failures.append("subtitle discovery")
            }
            if abs(info.displayAspectRatio - 0.5625) > 0.0001 {
                failures.append("portrait aspect ratio")
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

        let bilibiliThumbnail = ThumbnailRequestFactory.request(
            urlString: "http://i1.hdslb.com/bfs/archive/example.jpg",
            refererURLString: "https://www.bilibili.com/video/example"
        )
        if bilibiliThumbnail?.url?.scheme != "https"
            || bilibiliThumbnail?.value(forHTTPHeaderField: "Referer") != "https://www.bilibili.com/"
            || bilibiliThumbnail?.value(forHTTPHeaderField: "User-Agent") == nil {
            failures.append("Bilibili thumbnail request")
        }

        if WindowSizing.requiredContentWidth(sidebar: false, inspector: false) != 680
            || WindowSizing.requiredContentWidth(sidebar: true, inspector: false) != 890
            || WindowSizing.requiredContentWidth(sidebar: false, inspector: true) != 950
            || WindowSizing.requiredContentWidth(sidebar: true, inspector: true) != 1160 {
            failures.append("adaptive window sizing")
        }

        let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let rightAlignedWindow = CGRect(x: 760, y: 100, width: 680, height: 600)
        let leftExpansionOrigin = WindowSizing.anchoredOriginX(
            oldFrame: rightAlignedWindow,
            newWidth: 890,
            anchor: .trailingEdge,
            visibleFrame: visibleFrame
        )
        let leftAlignedWindow = CGRect(x: 0, y: 100, width: 680, height: 600)
        let rightExpansionOrigin = WindowSizing.anchoredOriginX(
            oldFrame: leftAlignedWindow,
            newWidth: 950,
            anchor: .leadingEdge,
            visibleFrame: visibleFrame
        )
        if leftExpansionOrigin != 550 || rightExpansionOrigin != 0 {
            failures.append("directional window expansion")
        }

        return failures
    }
}

private struct SelfCheckArgumentContributor: DownloadArgumentContributor {
    func arguments(for request: DownloadRequest) -> [String] { ["--self-check-feature"] }
}
