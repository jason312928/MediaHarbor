@preconcurrency import Foundation
import Darwin

enum YTDLPError: LocalizedError {
    case toolMissing
    case invalidResponse
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .toolMissing: "yt-dlp is not installed yet. Install it from the welcome screen."
        case .invalidResponse: "The website returned media information MediaHarbor could not read."
        case .commandFailed(let message): message
        }
    }
}

actor YTDLPService {
    private var processes: [UUID: Process] = [:]
    private let commandBuilder: YTDLPCommandBuilder

    init(commandBuilder: YTDLPCommandBuilder = YTDLPCommandBuilder()) {
        self.commandBuilder = commandBuilder
    }

    static let releaseURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!

    nonisolated static var managedExecutableURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("MediaHarbor/Tools/yt-dlp")
    }

    func executableURL() -> URL? {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "yt-dlp", withExtension: nil, subdirectory: "Tools"),
            Self.managedExecutableURL,
            URL(fileURLWithPath: "/opt/homebrew/bin/yt-dlp"),
            URL(fileURLWithPath: "/usr/local/bin/yt-dlp")
        ]
        return candidates.compactMap { $0 }.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    nonisolated static func ffmpegExecutableURL(fileManager: FileManager = .default) -> URL? {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "ffmpeg", withExtension: nil, subdirectory: "Tools"),
            managedExecutableURL.deletingLastPathComponent().appendingPathComponent("ffmpeg"),
            URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"),
            URL(fileURLWithPath: "/usr/local/bin/ffmpeg"),
            URL(fileURLWithPath: "/opt/local/bin/ffmpeg")
        ]
        return candidates.compactMap { $0 }.first { fileManager.isExecutableFile(atPath: $0.path) }
    }

    func version() async -> String? {
        guard let executable = executableURL() else { return nil }
        return try? await run(executable: executable, arguments: ["--version"]).stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func installOrUpdate() async throws -> String {
        let (temporaryURL, response) = try await URLSession.shared.download(from: Self.releaseURL)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw YTDLPError.commandFailed("Could not download yt-dlp from its official GitHub release.")
        }

        let destination = Self.managedExecutableURL
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        guard chmod(destination.path, 0o755) == 0 else {
            throw YTDLPError.commandFailed("yt-dlp downloaded, but MediaHarbor could not make it executable.")
        }
        return await version() ?? "Installed"
    }

    func analyze(url: String, configuration: DownloadConfiguration) async throws -> MediaInfo {
        guard let executable = executableURL() else { throw YTDLPError.toolMissing }
        var arguments = ["--dump-single-json", "--no-warnings", "--no-playlist"]
        if configuration.browserCookies != "None" {
            arguments += ["--cookies-from-browser", configuration.browserCookies.lowercased()]
        }
        arguments.append(url)
        let result = try await run(
            executable: executable,
            arguments: arguments
        )
        guard let data = result.stdout.data(using: .utf8) else { throw YTDLPError.invalidResponse }
        do {
            return try JSONDecoder().decode(MediaInfo.self, from: data)
        } catch {
            throw YTDLPError.invalidResponse
        }
    }

    func download(
        jobID: UUID,
        url: String,
        quality: QualityChoice,
        configuration: DownloadConfiguration,
        onProgress: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws -> String {
        guard let executable = executableURL() else { throw YTDLPError.toolMissing }
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: configuration.outputDirectory),
            withIntermediateDirectories: true
        )

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaHarbor", isDirectory: true)
            .appendingPathComponent(jobID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let baseArguments = commandBuilder.arguments(
            for: DownloadRequest(url: url, quality: quality, configuration: configuration)
        )
        let shouldExportSubtitleDocument = configuration.subtitleFormat == "rtf"
            && (quality == .subtitles || configuration.downloadSubtitles || configuration.embedSubtitles)
        let arguments = Self.preparedDownloadArguments(
            baseArguments,
            temporaryDirectory: temporaryDirectory,
            ffmpegURL: Self.ffmpegExecutableURL(),
            stageSubtitles: shouldExportSubtitleDocument
        )

        let result = try await run(executable: executable, arguments: arguments, processID: jobID) { line in
            if let progress = Self.parseProgress(line) { onProgress(progress) }
        }
        let exportedDocuments: [URL]
        if shouldExportSubtitleDocument {
            exportedDocuments = try SubtitleDocumentExporter.exportRTFDocuments(
                from: temporaryDirectory,
                to: URL(fileURLWithPath: configuration.outputDirectory, isDirectory: true)
            )
        } else {
            exportedDocuments = []
        }
        let paths = result.stdout.split(whereSeparator: \.isNewline).map(String.init)
        if quality == .subtitles {
            return exportedDocuments.first?.path ?? configuration.outputDirectory
        }
        return paths.last(where: { $0.hasPrefix("/") }) ?? configuration.outputDirectory
    }

    nonisolated static func preparedDownloadArguments(
        _ baseArguments: [String],
        temporaryDirectory: URL,
        ffmpegURL: URL?,
        stageSubtitles: Bool = false
    ) -> [String] {
        guard let sourceURL = baseArguments.last else { return baseArguments }
        var arguments = Array(baseArguments.dropLast())
        arguments += ["--paths", "temp:\(temporaryDirectory.path)"]
        if stageSubtitles {
            arguments += ["--paths", "subtitle:\(temporaryDirectory.path)"]
        }
        if let ffmpegURL {
            arguments += ["--ffmpeg-location", ffmpegURL.path]
        }
        arguments.append(sourceURL)
        return arguments
    }

    func cancel(jobID: UUID) {
        processes[jobID]?.terminate()
        processes[jobID] = nil
    }

    nonisolated static func parseProgress(_ line: String) -> DownloadProgress? {
        guard line.hasPrefix("download:") else { return nil }
        let fields = line.dropFirst("download:".count).split(separator: "|", omittingEmptySubsequences: false)
        guard let first = fields.first else { return nil }
        let numeric = first.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        guard let percent = Double(numeric) else { return nil }
        let speed = fields.count > 1 ? String(fields[1]).trimmingCharacters(in: .whitespaces) : nil
        let eta = fields.count > 2 ? String(fields[2]).trimmingCharacters(in: .whitespaces) : nil
        return DownloadProgress(fraction: min(max(percent / 100, 0), 1), speed: speed, eta: eta, detail: line)
    }

    private func run(
        executable: URL,
        arguments: [String],
        processID: UUID? = nil,
        onLine: (@Sendable (String) -> Void)? = nil
    ) async throws -> (stdout: String, stderr: String) {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        if let processID { processes[processID] = process }
        let output = OutputCollector(onLine: onLine)
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            output.append(handle.availableData, isError: false)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            output.append(handle.availableData, isError: true)
        }

        do { try process.run() } catch {
            if let processID { processes[processID] = nil }
            throw YTDLPError.commandFailed(error.localizedDescription)
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in continuation.resume() }
        }
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        output.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile(), isError: false)
        output.append(stderrPipe.fileHandleForReading.readDataToEndOfFile(), isError: true)
        if let processID { processes[processID] = nil }

        let captured = output.values
        guard process.terminationStatus == 0 else {
            let message = captured.stderr.split(whereSeparator: \.isNewline).last.map(String.init)
                ?? "yt-dlp exited with status \(process.terminationStatus)."
            throw YTDLPError.commandFailed(message)
        }
        return captured
    }
}

private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var stdout = Data()
    private var stderr = Data()
    private var lineBuffer = ""
    private let onLine: (@Sendable (String) -> Void)?

    init(onLine: (@Sendable (String) -> Void)?) { self.onLine = onLine }

    func append(_ data: Data, isError: Bool) {
        guard !data.isEmpty else { return }
        lock.lock()
        if isError { stderr.append(data) } else { stdout.append(data) }
        if !isError, let text = String(data: data, encoding: .utf8) {
            lineBuffer += text
            let lines = lineBuffer.components(separatedBy: .newlines)
            lineBuffer = lines.last ?? ""
            let completed = lines.dropLast()
            lock.unlock()
            completed.forEach { onLine?($0) }
            return
        }
        lock.unlock()
    }

    var values: (stdout: String, stderr: String) {
        lock.lock()
        defer { lock.unlock() }
        return (
            String(data: stdout, encoding: .utf8) ?? "",
            String(data: stderr, encoding: .utf8) ?? ""
        )
    }
}
