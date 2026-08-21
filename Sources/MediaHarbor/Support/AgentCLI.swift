@preconcurrency import Foundation
import Darwin

enum AgentCLICommand: Sendable {
    case analyze(url: String, configuration: DownloadConfiguration)
    case capabilities
    case download(url: String, quality: QualityChoice, configuration: DownloadConfiguration)
    case installEngine
    case help
}

enum AgentCLIParseError: LocalizedError, Equatable {
    case invalidURL(String)
    case missingCommand
    case missingValue(String)
    case unknownCommand(String)
    case unknownOption(String)
    case invalidValue(option: String, value: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value): "Invalid HTTP or HTTPS URL: \(value)"
        case .missingCommand: "Missing command."
        case .missingValue(let option): "Missing value for \(option)."
        case .unknownCommand(let command): "Unknown command: \(command)"
        case .unknownOption(let option): "Unknown option: \(option)"
        case .invalidValue(let option, let value): "Invalid value for \(option): \(value)"
        }
    }
}

enum AgentCLIParser {
    static let commandNames = ["analyze", "capabilities", "download", "install-engine"]

    static func isCLIInvocation(_ arguments: [String]) -> Bool {
        guard let first = arguments.first else { return false }
        return commandNames.contains(first) || ["help", "--help", "-h"].contains(first)
    }

    static func parse(_ arguments: [String], defaults: UserDefaults = .standard) throws -> AgentCLICommand {
        guard let command = arguments.first else { throw AgentCLIParseError.missingCommand }
        if ["help", "--help", "-h"].contains(command) { return .help }
        if command == "capabilities" {
            guard arguments.count == 1 else { throw AgentCLIParseError.unknownOption(arguments[1]) }
            return .capabilities
        }
        if command == "install-engine" {
            guard arguments.count == 1 else { throw AgentCLIParseError.unknownOption(arguments[1]) }
            return .installEngine
        }
        guard command == "analyze" || command == "download" else {
            throw AgentCLIParseError.unknownCommand(command)
        }

        var values = CLIConfigurationValues(configuration: DownloadConfiguration.current(defaults: defaults))
        var useAppSettings = true
        var url: String?
        var quality = "best"
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            if argument == "--no-app-settings" {
                useAppSettings = false
                index += 1
                continue
            }
            if !argument.hasPrefix("-") {
                guard url == nil else { throw AgentCLIParseError.unknownOption(argument) }
                url = argument
                index += 1
                continue
            }

            func requiredValue() throws -> String {
                guard index + 1 < arguments.count else { throw AgentCLIParseError.missingValue(argument) }
                return arguments[index + 1]
            }

            switch argument {
            case "-o", "--output": values.outputDirectory = try requiredValue(); index += 2
            case "-q", "--quality": quality = try requiredValue(); index += 2
            case "--cookies": values.browserCookies = try requiredValue(); index += 2
            case "--sub-langs": values.subtitleLanguages = try requiredValue(); index += 2
            case "--sub-format": values.subtitleFormat = try requiredValue().lowercased(); index += 2
            case "--subtitles": values.downloadSubtitles = true; index += 1
            case "--no-subtitles": values.downloadSubtitles = false; index += 1
            case "--embed-subs": values.embedSubtitles = true; index += 1
            case "--no-embed-subs": values.embedSubtitles = false; index += 1
            case "--auto-subs": values.includeAutomaticSubtitles = true; index += 1
            case "--no-auto-subs": values.includeAutomaticSubtitles = false; index += 1
            case "--metadata": values.embedMetadata = true; index += 1
            case "--no-metadata": values.embedMetadata = false; index += 1
            case "--sponsorblock": values.sponsorBlock = true; index += 1
            case "--no-sponsorblock": values.sponsorBlock = false; index += 1
            case "--playlist": values.includePlaylist = true; index += 1
            case "--no-playlist": values.includePlaylist = false; index += 1
            case "--help", "-h": return .help
            default: throw AgentCLIParseError.unknownOption(argument)
            }
        }

        guard let url, let parsedURL = URL(string: url), ["http", "https"].contains(parsedURL.scheme?.lowercased()) else {
            throw AgentCLIParseError.invalidURL(url ?? "")
        }
        if !useAppSettings {
            let overrides = values
            values = CLIConfigurationValues.agentDefaults
            values.applyExplicitValues(from: overrides, arguments: arguments)
        }
        try values.validate()
        let configuration = values.configuration
        if command == "analyze" { return .analyze(url: url, configuration: configuration) }
        return .download(url: url, quality: try qualityChoice(quality), configuration: configuration)
    }

    static func qualityChoice(_ value: String) throws -> QualityChoice {
        let normalized = value.lowercased()
        if normalized == "best" { return .video(height: .max) }
        if normalized == "audio" { return .audio }
        if normalized == "subtitles" { return .subtitles }
        let digits = normalized.hasSuffix("p") ? String(normalized.dropLast()) : normalized
        guard let height = Int(digits), height > 0 else {
            throw AgentCLIParseError.invalidValue(option: "--quality", value: value)
        }
        return .video(height: height)
    }
}

private struct CLIConfigurationValues {
    var outputDirectory: String
    var embedMetadata: Bool
    var embedSubtitles: Bool
    var downloadSubtitles: Bool
    var includeAutomaticSubtitles: Bool
    var subtitleLanguages: String
    var subtitleFormat: String
    var sponsorBlock: Bool
    var browserCookies: String
    var includePlaylist: Bool

    init(configuration: DownloadConfiguration) {
        outputDirectory = configuration.outputDirectory
        embedMetadata = configuration.embedMetadata
        embedSubtitles = configuration.embedSubtitles
        downloadSubtitles = configuration.downloadSubtitles
        includeAutomaticSubtitles = configuration.includeAutomaticSubtitles
        subtitleLanguages = configuration.subtitleLanguages
        subtitleFormat = configuration.subtitleFormat
        sponsorBlock = configuration.sponsorBlock
        browserCookies = configuration.browserCookies
        includePlaylist = configuration.includePlaylist
    }

    static var agentDefaults: Self {
        Self(configuration: DownloadConfiguration(
            outputDirectory: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path,
            embedMetadata: true,
            embedSubtitles: false,
            downloadSubtitles: false,
            includeAutomaticSubtitles: true,
            subtitleLanguages: "en,zh-Hans,zh-Hant",
            subtitleFormat: "srt",
            sponsorBlock: false,
            browserCookies: "None",
            includePlaylist: false
        ))
    }

    mutating func applyExplicitValues(from source: Self, arguments: [String]) {
        if arguments.contains("-o") || arguments.contains("--output") { outputDirectory = source.outputDirectory }
        if arguments.contains("--cookies") { browserCookies = source.browserCookies }
        if arguments.contains("--sub-langs") { subtitleLanguages = source.subtitleLanguages }
        if arguments.contains("--sub-format") { subtitleFormat = source.subtitleFormat }
        if arguments.contains("--subtitles") || arguments.contains("--no-subtitles") { downloadSubtitles = source.downloadSubtitles }
        if arguments.contains("--embed-subs") || arguments.contains("--no-embed-subs") { embedSubtitles = source.embedSubtitles }
        if arguments.contains("--auto-subs") || arguments.contains("--no-auto-subs") { includeAutomaticSubtitles = source.includeAutomaticSubtitles }
        if arguments.contains("--metadata") || arguments.contains("--no-metadata") { embedMetadata = source.embedMetadata }
        if arguments.contains("--sponsorblock") || arguments.contains("--no-sponsorblock") { sponsorBlock = source.sponsorBlock }
        if arguments.contains("--playlist") || arguments.contains("--no-playlist") { includePlaylist = source.includePlaylist }
    }

    func validate() throws {
        let formats = ["srt", "vtt", "ass", "best", "docx"]
        guard formats.contains(subtitleFormat) else {
            throw AgentCLIParseError.invalidValue(option: "--sub-format", value: subtitleFormat)
        }
        let browsers = ["none", "safari", "chrome", "firefox", "edge", "brave", "chromium", "opera", "vivaldi", "whale"]
        guard browsers.contains(browserCookies.lowercased()) else {
            throw AgentCLIParseError.invalidValue(option: "--cookies", value: browserCookies)
        }
    }

    var configuration: DownloadConfiguration {
        DownloadConfiguration(
            outputDirectory: NSString(string: outputDirectory).expandingTildeInPath,
            embedMetadata: embedMetadata,
            embedSubtitles: embedSubtitles,
            downloadSubtitles: downloadSubtitles,
            includeAutomaticSubtitles: includeAutomaticSubtitles,
            subtitleLanguages: subtitleLanguages,
            subtitleFormat: subtitleFormat,
            sponsorBlock: sponsorBlock,
            browserCookies: browserCookies.lowercased() == "none" ? "None" : browserCookies,
            includePlaylist: includePlaylist
        )
    }
}

final class AgentCLIRunner: @unchecked Sendable {
    private let service = YTDLPService()
    private let output = AgentCLIOutput()
    private let jobID = UUID()

    func run(arguments: [String]) async -> Int32 {
        do {
            let command = try AgentCLIParser.parse(arguments)
            switch command {
            case .help:
                print(Self.helpText)
                return 0
            case .capabilities:
                let engineVersion = await service.version()
                output.event("capabilities", data: CapabilitiesPayload(
                    schemaVersion: 1,
                    commands: AgentCLIParser.commandNames,
                    qualities: ["best", "2160p", "1440p", "1080p", "720p", "480p", "360p", "audio", "subtitles"],
                    subtitleFormats: ["srt", "vtt", "ass", "best", "docx"],
                    browsers: ["none", "safari", "chrome", "firefox", "edge", "brave", "chromium", "opera", "vivaldi", "whale"],
                    output: "jsonl",
                    engineVersion: engineVersion,
                    ffmpegPath: YTDLPService.ffmpegExecutableURL()?.path
                ))
                return 0
            case .installEngine:
                output.event("status", data: StatusPayload(status: "installing", message: "Installing the official yt-dlp engine"))
                let version = try await service.installOrUpdate()
                output.event("complete", data: InstallPayload(version: version, path: YTDLPService.managedExecutableURL.path))
                return 0
            case .analyze(let url, let configuration):
                output.event("status", data: StatusPayload(status: "analyzing", message: url))
                let media = try await service.analyze(url: url, configuration: configuration)
                output.event("result", data: AnalyzePayload(media: media))
                return 0
            case .download(let url, let quality, let configuration):
                output.event("status", data: StatusPayload(status: "preparing", message: url))
                let path = try await service.download(
                    jobID: jobID,
                    url: url,
                    quality: quality,
                    configuration: configuration
                ) { [output] progress in
                    output.event("progress", data: ProgressPayload(
                        fraction: progress.fraction,
                        percent: progress.fraction * 100,
                        speed: progress.speed,
                        eta: progress.eta
                    ))
                }
                output.event("complete", data: DownloadResultPayload(path: path, quality: quality.agentCLIName))
                return 0
            }
        } catch let error as AgentCLIParseError {
            output.error(code: "usage", message: error.localizedDescription)
            Self.writeError("\(error.localizedDescription)\nRun MediaHarbor --help for usage.\n")
            return 2
        } catch {
            if Task.isCancelled {
                output.error(code: "cancelled", message: "The operation was cancelled.")
                return 130
            }
            let code: String
            if let ytDLPError = error as? YTDLPError, case .toolMissing = ytDLPError {
                code = "engine_missing"
            } else {
                code = "operation_failed"
            }
            output.error(code: code, message: error.localizedDescription)
            return code == "engine_missing" ? 3 : 4
        }
    }

    func cancel() async { await service.cancel(jobID: jobID) }

    private static func writeError(_ value: String) {
        FileHandle.standardError.write(Data(value.utf8))
    }

    static let helpText = """
    MediaHarbor agent CLI

    Usage:
      MediaHarbor capabilities
      MediaHarbor analyze URL [options]
      MediaHarbor download URL [options]
      MediaHarbor install-engine

    Download options:
      -q, --quality VALUE       best, HEIGHT[p], audio, or subtitles (default: best)
      -o, --output DIRECTORY    destination directory
          --cookies BROWSER    none, safari, chrome, firefox, edge, brave, chromium, opera, vivaldi, whale
          --subtitles           keep separate subtitle files
          --embed-subs          embed subtitles in video
          --sub-langs CODES     comma-separated yt-dlp language selectors
          --sub-format FORMAT   srt, vtt, ass, best, or docx
          --[no-]auto-subs      include/exclude automatic captions
          --[no-]metadata       enable/disable embedded metadata
          --[no-]sponsorblock   enable/disable SponsorBlock removal
          --[no-]playlist       enable/disable playlists
          --no-app-settings     start from deterministic defaults instead of App settings

    Analyze accepts --cookies and --no-app-settings. Other configuration options are also
    accepted for consistent automation. Events are emitted as JSON Lines on stdout.
    Exit codes: 0 success, 2 usage, 3 engine missing, 4 operation failed, 130 cancelled.
    """
}

private extension QualityChoice {
    var agentCLIName: String {
        switch self {
        case .video(height: .max): "best"
        case .video(let height): "\(height)p"
        case .audio: "audio"
        case .subtitles: "subtitles"
        }
    }
}

private final class AgentCLIOutput: @unchecked Sendable {
    private let lock = NSLock()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    func event<T: Encodable>(_ name: String, data: T) {
        write(EventEnvelope(schemaVersion: 1, event: name, data: data))
    }

    func error(code: String, message: String) {
        event("error", data: ErrorPayload(code: code, message: message))
    }

    private func write<T: Encodable>(_ value: T) {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? encoder.encode(value) else { return }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
    }
}

private struct EventEnvelope<Data: Encodable>: Encodable {
    let schemaVersion: Int
    let event: String
    let data: Data
}

private struct CapabilitiesPayload: Encodable {
    let schemaVersion: Int
    let commands: [String]
    let qualities: [String]
    let subtitleFormats: [String]
    let browsers: [String]
    let output: String
    let engineVersion: String?
    let ffmpegPath: String?
}

private struct StatusPayload: Encodable { let status: String; let message: String }
private struct InstallPayload: Encodable { let version: String; let path: String }
private struct AnalyzePayload: Encodable { let media: MediaInfo }
private struct ProgressPayload: Encodable { let fraction: Double; let percent: Double; let speed: String?; let eta: String? }
private struct DownloadResultPayload: Encodable { let path: String; let quality: String }
private struct ErrorPayload: Encodable { let code: String; let message: String }
