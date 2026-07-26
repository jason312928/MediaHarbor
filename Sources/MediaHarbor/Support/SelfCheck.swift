import Foundation
import Darwin

enum SelfCheck {
    static func run() async -> [String] {
        var failures: [String] = []

        let progress = YTDLPService.parseProgress("download: 42.5%|3.2MiB/s|00:12")
        if progress == nil || abs((progress?.fraction ?? 0) - 0.425) > 0.0001
            || progress?.speed != "3.2MiB/s" || progress?.eta != "00:12" {
            failures.append("progress parser")
        }

        let updaterCheckDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaHarborUpdaterSelfCheck-\(UUID().uuidString)", isDirectory: true)
        do {
            let destination = updaterCheckDirectory.appendingPathComponent("yt-dlp")
            let candidate = updaterCheckDirectory.appendingPathComponent("candidate")
            try FileManager.default.createDirectory(at: updaterCheckDirectory, withIntermediateDirectories: true)
            try "old-version".write(to: destination, atomically: true, encoding: .utf8)
            try "new-version".write(to: candidate, atomically: true, encoding: .utf8)
            let stagingURL = try YTDLPService.stageDownloadedExecutable(from: candidate, nextTo: destination)
            try YTDLPService.activateDownloadedExecutable(from: stagingURL, to: destination)

            let installed = try String(contentsOf: destination, encoding: .utf8)
            if installed != "new-version"
                || !FileManager.default.fileExists(atPath: candidate.path)
                || FileManager.default.fileExists(atPath: stagingURL.path)
                || !FileManager.default.isExecutableFile(atPath: destination.path) {
                failures.append("atomic yt-dlp update")
            }

            let preservedDestination = updaterCheckDirectory.appendingPathComponent("preserved-yt-dlp")
            let missingStagingURL = updaterCheckDirectory.appendingPathComponent("missing-candidate")
            try "preserved-version".write(to: preservedDestination, atomically: true, encoding: .utf8)
            do {
                try YTDLPService.activateDownloadedExecutable(from: missingStagingURL, to: preservedDestination)
                failures.append("failed yt-dlp update")
            } catch {
                let preserved = try String(contentsOf: preservedDestination, encoding: .utf8)
                if preserved != "preserved-version" {
                    failures.append("failed yt-dlp update preserves installed tool")
                }
            }
        } catch {
            failures.append("atomic yt-dlp update: \(error.localizedDescription)")
        }
        try? FileManager.default.removeItem(at: updaterCheckDirectory)
        failures += await cancellableProcessFailures()

        let historyCheckDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaHarborHistorySelfCheck-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: historyCheckDirectory, withIntermediateDirectories: true)
            let first = SelfCheck.downloadJob(title: "First")
            let second = SelfCheck.downloadJob(title: "Second")
            let encoder = JSONEncoder()
            let mixedURL = historyCheckDirectory.appendingPathComponent("history.json")
            let mixedData = try JSONSerialization.data(withJSONObject: [
                try JSONSerialization.jsonObject(with: encoder.encode(first)),
                ["id": "incomplete-record"],
                try JSONSerialization.jsonObject(with: encoder.encode(second))
            ])
            try mixedData.write(to: mixedURL)

            let mixedStore = DownloadHistoryStore(url: mixedURL)
            let mixedResult = mixedStore.load()
            let repairedJobs = try JSONDecoder().decode([DownloadJob].self, from: Data(contentsOf: mixedURL))
            let mixedBackups = try FileManager.default.contentsOfDirectory(
                at: historyCheckDirectory,
                includingPropertiesForKeys: nil
            ).filter { $0.lastPathComponent.hasPrefix("history.corrupt-") }
            if mixedResult.jobs.map(\.id) != [first.id, second.id]
                || !mixedResult.canSave
                || repairedJobs.map(\.id) != [first.id, second.id]
                || mixedBackups.count != 1 {
                failures.append("lossy download history recovery")
            }

            let truncatedURL = historyCheckDirectory.appendingPathComponent("truncated.json")
            let truncatedData = Data(#"[{"id":"unfinished""#.utf8)
            try truncatedData.write(to: truncatedURL)
            let truncatedResult = DownloadHistoryStore(url: truncatedURL).load()
            let truncatedBackups = try FileManager.default.contentsOfDirectory(
                at: historyCheckDirectory,
                includingPropertiesForKeys: nil
            ).filter { $0.lastPathComponent.hasPrefix("truncated.corrupt-") }
            let truncatedBackupData = try truncatedBackups.first.map { try Data(contentsOf: $0) }
            let repairedTruncatedJobs = try JSONDecoder().decode(
                [DownloadJob].self,
                from: Data(contentsOf: truncatedURL)
            )
            if !truncatedResult.jobs.isEmpty
                || !truncatedResult.canSave
                || truncatedBackups.count != 1
                || truncatedBackupData != truncatedData
                || !repairedTruncatedJobs.isEmpty {
                failures.append("corrupt download history backup")
            }

            let cappedURL = historyCheckDirectory.appendingPathComponent("capped.json")
            let cappedStore = DownloadHistoryStore(url: cappedURL)
            let oversizedHistory = (0..<205).map { SelfCheck.downloadJob(title: "Item \($0)") }
            try cappedStore.save(oversizedHistory)
            if cappedStore.load().jobs.count != 200 {
                failures.append("download history limit")
            }
        } catch {
            failures.append("download history persistence: \(error.localizedDescription)")
        }
        try? FileManager.default.removeItem(at: historyCheckDirectory)

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
        let progressTemplate = command.firstIndex(of: "--progress-template").flatMap { index in
            command.indices.contains(index + 1) ? command[index + 1] : nil
        }
        if progressTemplate != "download:download:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s" {
            failures.append("yt-dlp progress template")
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

    private static func downloadJob(title: String) -> DownloadJob {
        DownloadJob(
            id: UUID(),
            sourceURL: "https://example.com/media",
            title: title,
            thumbnail: nil,
            sourceName: "Example",
            qualityTitle: "1080p",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            status: .completed,
            progress: 1,
            speed: nil,
            eta: nil,
            detail: "Saved",
            outputPath: "/tmp/example.mp4"
        )
    }

    private static func cancellableProcessFailures() async -> [String] {
        var failures: [String] = []
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaHarborProcessSelfCheck-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return ["process cancellation setup: \(error.localizedDescription)"]
        }
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = YTDLPService(terminationGracePeriod: .milliseconds(200))
        let shell = URL(fileURLWithPath: "/bin/sh")

        do {
            let captured = try await service.runProcessForSelfCheck(
                executable: shell,
                arguments: ["-c", "printf 'complete stdout'; printf 'complete stderr' >&2"],
                runID: UUID()
            )
            if captured.stdout != "complete stdout" || captured.stderr != "complete stderr" {
                failures.append("process output capture")
            }
        } catch {
            failures.append("process output capture: \(error.localizedDescription)")
        }

        let preCancelledID = UUID()
        let preCancelledMarker = directory.appendingPathComponent("pre-cancelled")
        let preCancelledTask = Task<Void, Error> {
            do { try await Task.sleep(for: .seconds(10)) } catch {}
            _ = try await service.runProcessForSelfCheck(
                executable: shell,
                arguments: [
                    "-c",
                    "/usr/bin/touch \"$1\"; exec /bin/sleep 3",
                    "self-check",
                    preCancelledMarker.path
                ],
                runID: preCancelledID
            )
        }
        preCancelledTask.cancel()
        let preCancelled = await taskWasCancelled(preCancelledTask)
        try? await Task.sleep(for: .milliseconds(50))
        let preCancelledActive = await service.hasActiveProcessForSelfCheck(runID: preCancelledID)
        if !preCancelled
            || FileManager.default.fileExists(atPath: preCancelledMarker.path)
            || preCancelledActive {
            failures.append("pre-cancelled process launch")
        }

        let runningID = UUID()
        let runningMarker = directory.appendingPathComponent("running")
        let runningTask = Task<Void, Error> {
            _ = try await service.runProcessForSelfCheck(
                executable: shell,
                arguments: [
                    "-c",
                    "/usr/bin/touch \"$1\"; exec /bin/sleep 3",
                    "self-check",
                    runningMarker.path
                ],
                runID: runningID
            )
        }
        let runningStarted = await waitForFile(runningMarker)
        let runningCancelStart = ContinuousClock.now
        runningTask.cancel()
        let runningCancelled = await taskWasCancelled(runningTask)
        let runningCancelDuration = runningCancelStart.duration(to: .now)
        let runningActive = await service.hasActiveProcessForSelfCheck(runID: runningID)
        if !runningStarted || !runningCancelled || runningCancelDuration > .seconds(1) || runningActive {
            failures.append("running process cancellation")
        }

        let ignoringID = UUID()
        let ignoringMarker = directory.appendingPathComponent("ignoring-sigterm")
        let ignoringTask = Task<Void, Error> {
            _ = try await service.runProcessForSelfCheck(
                executable: shell,
                arguments: [
                    "-c",
                    "/bin/sh -c 'trap \"\" TERM; printf \"%s\" \"$$\" > \"$1\"; exec /bin/sleep 3' descendant \"$1\" & wait",
                    "self-check",
                    ignoringMarker.path
                ],
                runID: ignoringID
            )
        }
        let ignoringDescendantPID = await waitForPID(in: ignoringMarker)
        let ignoringCancelStart = ContinuousClock.now
        ignoringTask.cancel()
        let ignoringCancelled = await taskWasCancelled(ignoringTask)
        let ignoringCancelDuration = ignoringCancelStart.duration(to: .now)
        let ignoringActive = await service.hasActiveProcessForSelfCheck(runID: ignoringID)
        let ignoringDescendantExited: Bool
        if let ignoringDescendantPID {
            ignoringDescendantExited = await waitForProcessExit(ignoringDescendantPID)
        } else {
            ignoringDescendantExited = false
        }
        if ignoringDescendantPID == nil
            || !ignoringCancelled
            || ignoringCancelDuration > .seconds(1)
            || ignoringActive
            || !ignoringDescendantExited {
            failures.append("process cancellation escalation")
        }
        if let ignoringDescendantPID, !ignoringDescendantExited {
            _ = kill(ignoringDescendantPID, SIGKILL)
        }

        return failures
    }

    private static func taskWasCancelled(_ task: Task<Void, Error>) async -> Bool {
        do {
            try await task.value
            return false
        } catch is CancellationError {
            return true
        } catch {
            return false
        }
    }

    private static func waitForFile(_ url: URL) async -> Bool {
        for _ in 0..<200 {
            if FileManager.default.fileExists(atPath: url.path) { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }

    private static func waitForPID(in url: URL) async -> Int32? {
        for _ in 0..<200 {
            if let text = try? String(contentsOf: url, encoding: .utf8),
               let processIdentifier = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return processIdentifier
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return nil
    }

    private static func waitForProcessExit(_ processIdentifier: Int32) async -> Bool {
        for _ in 0..<100 {
            if kill(processIdentifier, 0) != 0, errno == ESRCH { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
}

private struct SelfCheckArgumentContributor: DownloadArgumentContributor {
    func arguments(for request: DownloadRequest) -> [String] { ["--self-check-feature"] }
}
