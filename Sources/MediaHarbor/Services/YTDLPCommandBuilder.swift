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
        var result = ["--format", request.quality.formatSelector]
        switch request.quality {
        case .video: result += ["--merge-output-format", "mp4"]
        case .audio: result += ["--extract-audio", "--audio-format", "m4a"]
        }
        return result
    }
}

private struct MetadataArguments: DownloadArgumentContributor {
    func arguments(for request: DownloadRequest) -> [String] {
        request.configuration.embedMetadata ? ["--embed-metadata", "--embed-thumbnail"] : []
    }
}

private struct SubtitleArguments: DownloadArgumentContributor {
    func arguments(for request: DownloadRequest) -> [String] {
        guard request.configuration.embedSubtitles else { return [] }
        return ["--write-subs", "--write-auto-subs", "--sub-langs", request.configuration.subtitleLanguages, "--embed-subs"]
    }
}

private struct SponsorBlockArguments: DownloadArgumentContributor {
    func arguments(for request: DownloadRequest) -> [String] {
        request.configuration.sponsorBlock ? ["--sponsorblock-remove", "sponsor,selfpromo,interaction"] : []
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
