import Foundation

enum SidebarDestination: String, CaseIterable, Identifiable {
    case discover, queue, history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discover: "Discover"
        case .queue: "Downloads"
        case .history: "History"
        }
    }

    var symbol: String {
        switch self {
        case .discover: "sparkle.magnifyingglass"
        case .queue: "arrow.down.circle"
        case .history: "clock.arrow.circlepath"
        }
    }
}

struct MediaFormat: Codable, Hashable, Sendable {
    let formatID: String
    let extensionName: String?
    let width: Int?
    let height: Int?
    let fps: Double?
    let videoCodec: String?
    let audioCodec: String?
    let fileSize: Int64?

    enum CodingKeys: String, CodingKey {
        case formatID = "format_id"
        case extensionName = "ext"
        case width, height, fps
        case videoCodec = "vcodec"
        case audioCodec = "acodec"
        case fileSize = "filesize"
    }
}

struct MediaChapter: Codable, Hashable, Sendable, Identifiable {
    let title: String
    let startTime: Double
    let endTime: Double

    var id: String { "\(startTime)-\(title)" }

    enum CodingKeys: String, CodingKey {
        case title
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

struct MediaInfo: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let webpageURL: String?
    let thumbnail: String?
    let uploader: String?
    let duration: Double?
    let viewCount: Int?
    let extractor: String?
    let description: String?
    let formats: [MediaFormat]
    let chapters: [MediaChapter]?

    enum CodingKeys: String, CodingKey {
        case id, title, thumbnail, uploader, duration, formats, chapters, description
        case webpageURL = "webpage_url"
        case viewCount = "view_count"
        case extractor
    }

    var sourceName: String {
        guard let extractor, !extractor.isEmpty else { return "Web media" }
        return extractor.split(separator: ":").first.map(String.init)?.capitalized ?? extractor
    }

    var qualityChoices: [QualityChoice] {
        let heights = Set(formats.compactMap(\.height).filter { $0 >= 144 })
            .sorted(by: >)
            .prefix(6)
        var choices = heights.map { QualityChoice.video(height: $0) }
        choices.append(.audio)
        return choices
    }
}

enum QualityChoice: Hashable, Sendable, Identifiable {
    case video(height: Int)
    case audio

    var id: String {
        switch self {
        case .video(let height): "video-\(height)"
        case .audio: "audio"
        }
    }

    var title: String {
        switch self {
        case .video(let height):
            if height >= 2160 { return "4K" }
            if height >= 1440 { return "2K" }
            return "\(height)p"
        case .audio: return "Audio"
        }
    }

    var detail: String {
        switch self {
        case .video(let height): height >= 2160 ? "Ultra HD" : height >= 1080 ? "High definition" : "Compact"
        case .audio: "M4A · audio only"
        }
    }

    var symbol: String {
        switch self {
        case .video(let height): height >= 2160 ? "4k.tv" : "play.rectangle"
        case .audio: "waveform"
        }
    }

    var formatSelector: String {
        switch self {
        case .video(let height):
            return "bestvideo[height<=\(height)]+bestaudio/best[height<=\(height)]"
        case .audio:
            return "bestaudio/best"
        }
    }
}

enum DownloadStatus: String, Codable, Sendable {
    case queued, preparing, downloading, processing, completed, failed, cancelled

    var title: String { rawValue.capitalized }
    var isActive: Bool { [.preparing, .downloading, .processing].contains(self) }
}

struct DownloadJob: Codable, Identifiable, Sendable {
    let id: UUID
    let sourceURL: String
    let title: String
    let thumbnail: String?
    let sourceName: String
    let qualityTitle: String
    let createdAt: Date
    var status: DownloadStatus
    var progress: Double
    var speed: String?
    var eta: String?
    var detail: String?
    var outputPath: String?
}

struct DownloadConfiguration: Sendable {
    let outputDirectory: String
    let embedMetadata: Bool
    let embedSubtitles: Bool
    let subtitleLanguages: String
    let sponsorBlock: Bool
    let browserCookies: String
    let includePlaylist: Bool

    static func current(defaults: UserDefaults = .standard) -> DownloadConfiguration {
        let defaultOutput = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
        return DownloadConfiguration(
            outputDirectory: defaults.string(forKey: "outputDirectory") ?? defaultOutput,
            embedMetadata: defaults.object(forKey: "embedMetadata") as? Bool ?? true,
            embedSubtitles: defaults.bool(forKey: "embedSubtitles"),
            subtitleLanguages: defaults.string(forKey: "subtitleLanguages") ?? "en,zh-Hans,zh-Hant",
            sponsorBlock: defaults.bool(forKey: "sponsorBlock"),
            browserCookies: defaults.string(forKey: "browserCookies") ?? "None",
            includePlaylist: defaults.bool(forKey: "includePlaylist")
        )
    }
}

struct DownloadProgress: Sendable {
    let fraction: Double
    let speed: String?
    let eta: String?
    let detail: String
}
