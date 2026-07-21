import Foundation

struct DownloadRequest: Sendable {
    let url: String
    let quality: QualityChoice
    let configuration: DownloadConfiguration
}

protocol DownloadArgumentContributor: Sendable {
    func arguments(for request: DownloadRequest) -> [String]
}

struct YTDLPCommandBuilder: Sendable {
    let contributors: [any DownloadArgumentContributor]

    init(contributors: [any DownloadArgumentContributor] = Self.standardContributors) {
        self.contributors = contributors
    }

    init(additionalContributors: [any DownloadArgumentContributor]) {
        self.contributors = Self.standardContributors + additionalContributors
    }

    func arguments(for request: DownloadRequest) -> [String] {
        contributors.flatMap { $0.arguments(for: request) } + [request.url]
    }

    private static let standardContributors: [any DownloadArgumentContributor] = [
        CoreDownloadArguments(),
        FormatArguments(),
        MetadataArguments(),
        SubtitleArguments(),
        SponsorBlockArguments(),
        BrowserCookieArguments(),
        PlaylistArguments()
    ]
}

private struct CoreDownloadArguments: DownloadArgumentContributor {
    func arguments(for request: DownloadRequest) -> [String] {
        [
            "--newline",
            "--progress",
            "--progress-template", "download:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
            "--print", "after_move:filepath",
            "--paths", request.configuration.outputDirectory,
            "--output", "%(title).180B [%(id)s].%(ext)s"
        ]
    }
}

private struct FormatArguments: DownloadArgumentContributor {
    func arguments(for request: DownloadRequest) -> [String] {
        if case .subtitles = request.quality { return ["--skip-download"] }
        var result = ["--format", request.quality.formatSelector]
        switch request.quality {
        case .video: result += ["--merge-output-format", "mp4"]
        case .audio: result += ["--extract-audio", "--audio-format", "m4a"]
        case .subtitles: break
        }
        return result
    }
}

private struct MetadataArguments: DownloadArgumentContributor {
    func arguments(for request: DownloadRequest) -> [String] {
        if case .subtitles = request.quality { return [] }
        return request.configuration.embedMetadata ? ["--embed-metadata", "--embed-thumbnail"] : []
    }
}

private struct SubtitleArguments: DownloadArgumentContributor {
    func arguments(for request: DownloadRequest) -> [String] {
        let subtitleOnly = request.quality == .subtitles
        guard subtitleOnly || request.configuration.downloadSubtitles || request.configuration.embedSubtitles else { return [] }

        var result = ["--write-subs"]
        if request.configuration.includeAutomaticSubtitles {
            result.append("--write-auto-subs")
        }

        let languages = request.configuration.subtitleLanguages.trimmingCharacters(in: .whitespacesAndNewlines)
        result += ["--sub-langs", languages.isEmpty ? "all,-live_chat" : languages]

        let format = request.configuration.subtitleFormat
        if format != "best" {
            result += ["--sub-format", "best", "--convert-subs", format]
        }
        if request.configuration.embedSubtitles && !subtitleOnly {
            result.append("--embed-subs")
            if !request.configuration.downloadSubtitles {
                result += ["--compat-options", "no-keep-subs"]
            }
        }
        return result
    }
}

private struct SponsorBlockArguments: DownloadArgumentContributor {
    func arguments(for request: DownloadRequest) -> [String] {
        if case .subtitles = request.quality { return [] }
        return request.configuration.sponsorBlock ? ["--sponsorblock-remove", "sponsor,selfpromo,interaction"] : []
    }
}

private struct BrowserCookieArguments: DownloadArgumentContributor {
    func arguments(for request: DownloadRequest) -> [String] {
        guard request.configuration.browserCookies != "None" else { return [] }
        return ["--cookies-from-browser", request.configuration.browserCookies.lowercased()]
    }
}

private struct PlaylistArguments: DownloadArgumentContributor {
    func arguments(for request: DownloadRequest) -> [String] {
        [request.configuration.includePlaylist ? "--yes-playlist" : "--no-playlist"]
    }
}
