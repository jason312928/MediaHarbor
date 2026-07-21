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

struct MediaSubtitle: Codable, Hashable, Sendable {
    let extensionName: String?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case extensionName = "ext"
        case name
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
    let width: Int?
    let height: Int?
    let extractor: String?
    let description: String?
    let formats: [MediaFormat]
    let chapters: [MediaChapter]?
    let subtitles: [String: [MediaSubtitle]]?
    let automaticCaptions: [String: [MediaSubtitle]]?

    enum CodingKeys: String, CodingKey {
        case id, title, thumbnail, uploader, duration, width, height, formats, chapters, description, subtitles
        case webpageURL = "webpage_url"
        case viewCount = "view_count"
        case extractor
        case automaticCaptions = "automatic_captions"
    }

    var sourceName: String {
        guard let extractor, !extractor.isEmpty else { return "Web media" }
        return extractor.split(separator: ":").first.map(String.init)?.capitalized ?? extractor
    }

    var displayAspectRatio: Double {
        if let width, let height, width > 0, height > 0 {
            return Self.clampedAspectRatio(Double(width) / Double(height))
        }
        let largestVideoFormat = formats
            .compactMap { format -> (area: Int, ratio: Double)? in
                guard let width = format.width, let height = format.height, width > 0, height > 0 else { return nil }
                return (width * height, Double(width) / Double(height))
            }
            .max { $0.area < $1.area }
        return Self.clampedAspectRatio(largestVideoFormat?.ratio ?? 16.0 / 9.0)
    }

    private static func clampedAspectRatio(_ ratio: Double) -> Double {
        min(max(ratio, 0.4), 2.4)
    }

    var qualityChoices: [QualityChoice] {
        let heights = Set(formats.compactMap(\.height).filter { $0 >= 144 })
            .sorted(by: >)
            .prefix(6)
        var choices = heights.map { QualityChoice.video(height: $0) }
        choices.append(.audio)
        if hasSubtitles { choices.append(.subtitles) }
        return choices
    }

    var hasSubtitles: Bool {
        !(subtitles?.isEmpty ?? true) || !(automaticCaptions?.isEmpty ?? true)
    }

    var subtitleLanguages: [String] {
        let manual = subtitles.map { Array($0.keys) } ?? []
        let automatic = automaticCaptions.map { Array($0.keys) } ?? []
        return Set(manual + automatic)
            .filter { !$0.isEmpty && $0 != "live_chat" }
            .sorted()
    }
}

enum QualityChoice: Hashable, Sendable, Identifiable {
    case video(height: Int)
    case audio
    case subtitles

    var id: String {
        switch self {
        case .video(let height): "video-\(height)"
        case .audio: "audio"
        case .subtitles: "subtitles"
        }
    }

    var title: String {
        switch self {
        case .video(let height):
            if height >= 2160 { return "4K" }
            if height >= 1440 { return "2K" }
            return "\(height)p"
        case .audio: return "Audio"
        case .subtitles: return "Subtitles"
        }
    }

    var detail: String {
        switch self {
        case .video(let height): height >= 2160 ? "Ultra HD" : height >= 1080 ? "High definition" : "Compact"
        case .audio: "M4A · audio only"
        case .subtitles: "Subtitle files only"
        }
    }

    var symbol: String {
        switch self {
        case .video(let height): height >= 2160 ? "4k.tv" : "play.rectangle"
        case .audio: "waveform"
        case .subtitles: "captions.bubble"
        }
    }

    var formatSelector: String {
        switch self {
        case .video(let height):
            return "bestvideo[height<=\(height)]+bestaudio/best[height<=\(height)]"
        case .audio:
            return "bestaudio/best"
        case .subtitles:
            return ""
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
    let downloadSubtitles: Bool
    let includeAutomaticSubtitles: Bool
    let subtitleLanguages: String
    let subtitleFormat: String
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
            downloadSubtitles: defaults.bool(forKey: "downloadSubtitles"),
            includeAutomaticSubtitles: defaults.object(forKey: "includeAutomaticSubtitles") as? Bool ?? true,
            subtitleLanguages: defaults.string(forKey: "subtitleLanguages") ?? "en,zh-Hans,zh-Hant",
            subtitleFormat: defaults.string(forKey: "subtitleFormat") ?? "srt",
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
