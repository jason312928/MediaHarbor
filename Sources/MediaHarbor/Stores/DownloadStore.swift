import AppKit
import Foundation
import Observation
import UserNotifications

struct BrowserLoginRecovery: Equatable {
    let url: URL
    let browserName: String
    let cookieSource: String
    let applicationURL: URL
}

struct BrowserLoginResolver {
    struct Browser: Equatable {
        let name: String
        let cookieSource: String
        let bundleIdentifiers: [String]
    }

    static let browsers = [
        Browser(name: "Safari", cookieSource: "Safari", bundleIdentifiers: ["com.apple.Safari"]),
        Browser(name: "Google Chrome", cookieSource: "Chrome", bundleIdentifiers: [
            "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.dev", "com.google.Chrome.canary"
        ]),
        Browser(name: "Microsoft Edge", cookieSource: "Edge", bundleIdentifiers: [
            "com.microsoft.edgemac", "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Dev", "com.microsoft.edgemac.Canary"
        ]),
        Browser(name: "Firefox", cookieSource: "Firefox", bundleIdentifiers: [
            "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly"
        ]),
        Browser(name: "Brave", cookieSource: "Brave", bundleIdentifiers: [
            "com.brave.Browser", "com.brave.Browser.beta", "com.brave.Browser.nightly"
        ]),
        Browser(name: "Chromium", cookieSource: "Chromium", bundleIdentifiers: ["org.chromium.Chromium"]),
        Browser(name: "Opera", cookieSource: "Opera", bundleIdentifiers: [
            "com.operasoftware.Opera", "com.operasoftware.OperaGX"
        ]),
        Browser(name: "Vivaldi", cookieSource: "Vivaldi", bundleIdentifiers: ["com.vivaldi.Vivaldi"]),
        Browser(name: "Whale", cookieSource: "Whale", bundleIdentifiers: ["com.naver.Whale"])
    ]

    static func recovery(
        for urlString: String,
        configuredCookieSource: String,
        defaultApplicationURL: URL?,
        applicationURLForBundleIdentifier: (String) -> URL?
    ) -> BrowserLoginRecovery? {
        guard let platform = SupportedPlatform.matching(urlString), platform.cookieHelpful,
              let mediaURL = URL(string: urlString) else { return nil }

        if configuredCookieSource.caseInsensitiveCompare("None") != .orderedSame {
            guard let browser = browser(cookieSource: configuredCookieSource),
                  let applicationURL = applicationURL(
                    for: browser,
                    defaultApplicationURL: defaultApplicationURL,
                    lookup: applicationURLForBundleIdentifier
                  ) else { return nil }
            return recovery(mediaURL: mediaURL, browser: browser, applicationURL: applicationURL)
        }

        if let defaultApplicationURL,
           let browser = browser(applicationURL: defaultApplicationURL) {
            return recovery(mediaURL: mediaURL, browser: browser, applicationURL: defaultApplicationURL)
        }

        for browser in browsers {
            if let applicationURL = applicationURL(
                for: browser,
                defaultApplicationURL: nil,
                lookup: applicationURLForBundleIdentifier
            ) {
                return recovery(mediaURL: mediaURL, browser: browser, applicationURL: applicationURL)
            }
        }
        return nil
    }

    private static func browser(cookieSource: String) -> Browser? {
        browsers.first { $0.cookieSource.caseInsensitiveCompare(cookieSource) == .orderedSame }
    }

    private static func browser(applicationURL: URL) -> Browser? {
        guard let identifier = Bundle(url: applicationURL)?.bundleIdentifier?.lowercased() else { return nil }
        return browsers.first { browser in
            browser.bundleIdentifiers.contains { identifier.hasPrefix($0.lowercased()) }
        }
    }

    private static func applicationURL(
        for browser: Browser,
        defaultApplicationURL: URL?,
        lookup: (String) -> URL?
    ) -> URL? {
        if let defaultApplicationURL,
           Self.browser(applicationURL: defaultApplicationURL) == browser {
            return defaultApplicationURL
        }
        return browser.bundleIdentifiers.lazy.compactMap(lookup).first
    }

    private static func recovery(mediaURL: URL, browser: Browser, applicationURL: URL) -> BrowserLoginRecovery {
        BrowserLoginRecovery(
            url: mediaURL,
            browserName: browser.name,
            cookieSource: browser.cookieSource,
            applicationURL: applicationURL
        )
    }
}

@MainActor
@Observable
final class DownloadStore {
    var selection: SidebarDestination = .discover
    var urlText = ""
    var media: MediaInfo?
    var selectedQuality: QualityChoice?
    var jobs: [DownloadJob] = []
    var history: [DownloadJob] = []
    var favorites: [FavoriteItem] = []
    var selectedJobID: UUID?
    var selectedHistoryID: UUID?
    var selectedFavoriteID: UUID?
    var isAnalyzing = false
    var isInstallingTool = false
    var toolVersion: String?
    var errorMessage: String?
    var loginRecovery: BrowserLoginRecovery?
    var showInspector = true
    var missingOutputIDs: Set<UUID> = []

    private let service = YTDLPService()
    private let historyStore: DownloadHistoryStore
    private let favoritesStore: FavoritesStore
    private let outputFileMonitor = OutputFileMonitor()
    private var canSaveHistory: Bool
    private var canSaveFavorites: Bool
    private var analysisTask: Task<Void, Never>?
    private var downloadTasks: [UUID: Task<Void, Never>] = [:]
    private var pendingLoginRecovery: BrowserLoginRecovery?

    init(
        historyStore: DownloadHistoryStore = DownloadHistoryStore(),
        favoritesStore: FavoritesStore = FavoritesStore()
    ) {
        self.historyStore = historyStore
        self.favoritesStore = favoritesStore
        let loadedHistory = historyStore.load()
        history = loadedHistory.jobs
        canSaveHistory = loadedHistory.canSave
        let loadedFavorites = favoritesStore.load()
        favorites = loadedFavorites.items
        canSaveFavorites = loadedFavorites.canSave
        outputFileMonitor.onChange = { [weak self] in self?.refreshOutputAvailability() }
        refreshOutputAvailability()
        Task { await refreshToolStatus() }
    }

    var activeJobs: [DownloadJob] { jobs.filter { $0.status.isActive || $0.status == .queued } }
    var completedJobs: [DownloadJob] { jobs.filter { $0.status == .completed } }
    var selectedJob: DownloadJob? { jobs.first { $0.id == selectedJobID } }
    var selectedHistoryJob: DownloadJob? { history.first { $0.id == selectedHistoryID } }
    var selectedFavoriteJob: DownloadJob? { favorites.first { $0.id == selectedFavoriteID }?.job }

    func isFavorite(_ job: DownloadJob) -> Bool {
        favorites.contains { $0.id == job.id }
    }

    func toggleFavorite(_ job: DownloadJob) {
        if let index = favorites.firstIndex(where: { $0.id == job.id }) {
            favorites.remove(at: index)
            if selectedFavoriteID == job.id { selectedFavoriteID = favorites.first?.id }
        } else {
            favorites.insert(FavoriteItem(job: job, favoritedAt: Date()), at: 0)
            selectedFavoriteID = job.id
        }
        saveFavorites()
        refreshOutputAvailability()
    }

    func deleteHistoryRecord(jobID: UUID) {
        history.removeAll { $0.id == jobID }
        if selectedHistoryID == jobID { selectedHistoryID = history.first?.id }
        saveHistory()
        refreshOutputAvailability()
    }

    func clearHistory() {
        history.removeAll()
        selectedHistoryID = nil
        saveHistory()
        refreshOutputAvailability()
    }

    func downloadAgain(_ job: DownloadJob) {
        urlText = job.sourceURL
        selection = .discover
        analyze()
    }

    func pasteAndAnalyze() {
        if let value = NSPasteboard.general.string(forType: .string) {
            urlText = value.trimmingCharacters(in: .whitespacesAndNewlines)
            selection = .discover
            analyze()
        }
    }

    func acceptDroppedText(_ text: String) {
        urlText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        analyze()
    }

    func analyze() {
        let candidate = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: candidate), url.scheme == "http" || url.scheme == "https" else {
            errorMessage = "Paste a valid http or https media URL."
            return
        }
        analysisTask?.cancel()
        media = nil
        selectedQuality = nil
        isAnalyzing = true
        errorMessage = nil
        loginRecovery = nil
        let configuration = DownloadConfiguration.current()

        analysisTask = Task {
            do {
                let result = try await service.analyze(url: candidate, configuration: configuration)
                guard !Task.isCancelled else { return }
                media = result
                selectedQuality = result.qualityChoices.first
                isAnalyzing = false
            } catch {
                guard !Task.isCancelled else { return }
                loginRecovery = Self.loginRecovery(for: error, url: candidate, configuration: configuration)
                errorMessage = error.localizedDescription
                isAnalyzing = false
            }
        }
    }

    func openBrowserLogin() {
        guard let recovery = loginRecovery else { return }
        beginBrowserLogin(recovery)
    }

    /// Opens a platform page for a signed-in browser session even when yt-dlp
    /// returned a limited, but otherwise valid, media response.
    func openBrowserLogin(for urlString: String) {
        let configuration = DownloadConfiguration.current()
        guard let recovery = Self.loginRecovery(for: urlString, configuration: configuration) else {
            errorMessage = "No supported browser was found for browser sign-in."
            return
        }
        beginBrowserLogin(recovery)
    }

    private func beginBrowserLogin(_ recovery: BrowserLoginRecovery) {
        UserDefaults.standard.set(recovery.cookieSource, forKey: "browserCookies")
        pendingLoginRecovery = recovery
        dismissError()

        NSWorkspace.shared.open(
            [recovery.url],
            withApplicationAt: recovery.applicationURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { [weak self] _, error in
            guard let error else { return }
            Task { @MainActor [weak self] in
                self?.pendingLoginRecovery = nil
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    func resumeAfterBrowserLogin() {
        guard pendingLoginRecovery != nil, !isAnalyzing else { return }
        pendingLoginRecovery = nil
        analyze()
    }

    func dismissError() {
        errorMessage = nil
        loginRecovery = nil
    }

    func enqueueDownload() {
        guard let media, let selectedQuality else { return }
        let sourceURL = media.webpageURL ?? urlText
        let job = DownloadJob(
            id: UUID(),
            sourceURL: sourceURL,
            title: media.title,
            thumbnail: media.thumbnail,
            sourceName: media.sourceName,
            qualityTitle: selectedQuality.title,
            createdAt: Date(),
            status: .queued,
            progress: 0,
            speed: nil,
            eta: nil,
            detail: "Waiting to start",
            outputPath: nil
        )
        jobs.insert(job, at: 0)
        selectedJobID = job.id
        selection = .queue
        start(jobID: job.id, quality: selectedQuality)
    }

    func cancel(jobID: UUID) {
        downloadTasks[jobID]?.cancel()
        downloadTasks[jobID] = nil
        update(jobID) { job in
            job.status = .cancelled
            job.detail = "Cancelled"
        }
        Task { await service.cancel(jobID: jobID) }
    }

    func resume(jobID: UUID) {
        guard let job = jobs.first(where: { $0.id == jobID }),
              [.cancelled, .failed].contains(job.status),
              let quality = qualityChoice(for: job) else { return }

        update(jobID) {
            $0.status = .queued
            $0.detail = "Waiting to resume"
            $0.speed = nil
            $0.eta = nil
        }
        downloadTasks[jobID] = Task { [weak self] in
            guard let self else { return }
            await service.waitUntilIdle(jobID: jobID)
            guard !Task.isCancelled,
                  jobs.first(where: { $0.id == jobID })?.status == .queued else { return }
            start(jobID: jobID, quality: quality)
        }
    }

    func deleteCancelledDownload(jobID: UUID) {
        guard let job = jobs.first(where: { $0.id == jobID }),
              [.cancelled, .failed].contains(job.status) else { return }
        let configuration = DownloadConfiguration.current()
        downloadTasks[jobID]?.cancel()
        downloadTasks[jobID] = nil
        Task { [weak self] in
            guard let self else { return }
            await service.cancel(jobID: jobID)
            await service.waitUntilIdle(jobID: jobID)
            do {
                try await service.removePartialDownload(jobID: jobID, configuration: configuration)
                jobs.removeAll { $0.id == jobID }
                if selectedJobID == jobID { selectedJobID = jobs.first?.id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func outputExists(_ job: DownloadJob) -> Bool {
        guard let path = job.outputPath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    func outputIsMissing(_ job: DownloadJob) -> Bool {
        job.outputPath != nil && missingOutputIDs.contains(job.id)
    }

    func refreshOutputAvailability() {
        let recordedOutputs = (jobs + history + favorites.map(\.job)).filter { $0.outputPath != nil }
        missingOutputIDs = Set(recordedOutputs.filter { !outputExists($0) }.map(\.id))
        outputFileMonitor.watch(outputPaths: recordedOutputs.compactMap(\.outputPath))
    }

    @discardableResult
    func reveal(_ job: DownloadJob) -> Bool {
        guard let path = job.outputPath, FileManager.default.fileExists(atPath: path) else { return false }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        return true
    }

    @discardableResult
    func openOutput(_ job: DownloadJob) -> Bool {
        guard let path = job.outputPath, FileManager.default.fileExists(atPath: path) else { return false }
        return NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func moveOutputToTrash(_ job: DownloadJob) throws {
        guard let path = job.outputPath, FileManager.default.fileExists(atPath: path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
        refreshOutputAvailability()
    }

    func clearCompleted() {
        jobs.removeAll { [.completed, .failed, .cancelled].contains($0.status) }
        if !jobs.contains(where: { $0.id == selectedJobID }) { selectedJobID = jobs.first?.id }
    }

    func installTool() {
        isInstallingTool = true
        dismissError()
        Task {
            do { toolVersion = try await service.installOrUpdate() }
            catch { errorMessage = error.localizedDescription }
            isInstallingTool = false
        }
    }

    func refreshToolStatus() async {
        toolVersion = await service.version()
    }

    private func start(jobID: UUID, quality: QualityChoice) {
        guard let job = jobs.first(where: { $0.id == jobID }) else { return }
        update(jobID) { $0.status = .preparing; $0.detail = "Preparing yt-dlp" }
        let configuration = DownloadConfiguration.current()

        downloadTasks[jobID] = Task {
            do {
                let outputPath = try await service.download(
                    jobID: jobID,
                    url: job.sourceURL,
                    quality: quality,
                    configuration: configuration
                ) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.update(jobID) {
                            guard $0.status == .preparing || $0.status == .downloading else { return }
                            $0.status = .downloading
                            $0.progress = progress.fraction
                            $0.speed = progress.speed
                            $0.eta = progress.eta
                            $0.detail = "Downloading"
                        }
                    }
                }
                guard !Task.isCancelled else { return }
                update(jobID) {
                    $0.status = .completed
                    $0.progress = 1
                    $0.detail = "Saved"
                    $0.outputPath = outputPath
                    $0.completedAt = Date()
                }
                if let completed = jobs.first(where: { $0.id == jobID }) {
                    history.removeAll { $0.id == completed.id }
                    history.insert(completed, at: 0)
                    saveHistory()
                    if let favoriteIndex = favorites.firstIndex(where: { $0.id == completed.id }) {
                        favorites[favoriteIndex].job = completed
                        saveFavorites()
                    }
                    notifyCompletion(completed)
                    refreshOutputAvailability()
                }
            } catch {
                guard !Task.isCancelled else { return }
                update(jobID) {
                    $0.status = .failed
                    $0.detail = Self.message(for: error, url: job.sourceURL, configuration: configuration)
                }
            }
            downloadTasks[jobID] = nil
        }
    }

    private func update(_ id: UUID, mutation: (inout DownloadJob) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        mutation(&jobs[index])
    }

    private func saveHistory() {
        guard canSaveHistory else { return }
        do {
            try historyStore.save(history)
        } catch {
            canSaveHistory = false
            errorMessage = error.localizedDescription
        }
    }

    private func saveFavorites() {
        guard canSaveFavorites else { return }
        do {
            try favoritesStore.save(favorites)
        } catch {
            canSaveFavorites = false
            errorMessage = error.localizedDescription
        }
    }

    private func qualityChoice(for job: DownloadJob) -> QualityChoice? {
        switch job.qualityTitle.lowercased() {
        case "best": return .video(height: .max)
        case "4k": return .video(height: 2160)
        case "2k": return .video(height: 1440)
        case "audio": return .audio
        case "subtitles": return .subtitles
        default:
            let digits = job.qualityTitle.prefix { $0.isNumber }
            guard let height = Int(digits) else { return nil }
            return .video(height: height)
        }
    }

    private func notifyCompletion(_ job: DownloadJob) {
        let content = UNMutableNotificationContent()
        content.title = "Download complete"
        content.body = job.title
        let request = UNNotificationRequest(identifier: job.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static func message(for error: Error, url: String, configuration: DownloadConfiguration) -> String {
        let message = error.localizedDescription
        guard configuration.browserCookies == "None",
              let platform = SupportedPlatform.matching(url), platform.cookieHelpful else { return message }
        return "\(message)\n\n\(platform.name) may require a signed-in browser session. Choose a browser in Settings › Engine and try again."
    }

    private static func loginRecovery(
        for error: Error,
        url: String,
        configuration: DownloadConfiguration
    ) -> BrowserLoginRecovery? {
        guard case YTDLPError.commandFailed = error else { return nil }
        return loginRecovery(for: url, configuration: configuration)
    }

    private static func loginRecovery(
        for url: String,
        configuration: DownloadConfiguration
    ) -> BrowserLoginRecovery? {
        BrowserLoginResolver.recovery(
            for: url,
            configuredCookieSource: configuration.browserCookies,
            defaultApplicationURL: URL(string: url).flatMap {
                NSWorkspace.shared.urlForApplication(toOpen: $0)
            },
            applicationURLForBundleIdentifier: { identifier in
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
            }
        )
    }

}
