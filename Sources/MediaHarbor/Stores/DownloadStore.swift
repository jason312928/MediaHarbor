import AppKit
import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class DownloadStore {
    var selection: SidebarDestination = .discover
    var urlText = ""
    var media: MediaInfo?
    var selectedQuality: QualityChoice?
    var jobs: [DownloadJob] = []
    var history: [DownloadJob] = []
    var selectedJobID: UUID?
    var isAnalyzing = false
    var isInstallingTool = false
    var toolVersion: String?
    var errorMessage: String?
    var showInspector = true

    private let service = YTDLPService()
    private var analysisTask: Task<Void, Never>?
    private var downloadTasks: [UUID: Task<Void, Never>] = [:]

    init() {
        history = Self.loadHistory()
        Task { await refreshToolStatus() }
    }

    var activeJobs: [DownloadJob] { jobs.filter { $0.status.isActive || $0.status == .queued } }
    var completedJobs: [DownloadJob] { jobs.filter { $0.status == .completed } }
    var selectedJob: DownloadJob? { jobs.first { $0.id == selectedJobID } }

    func pasteAndAnalyze() {
        if let value = NSPasteboard.general.string(forType: .string) {
            urlText = value.trimmingCharacters(in: .whitespacesAndNewlines)
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

        analysisTask = Task {
            do {
                let result = try await service.analyze(url: candidate)
                guard !Task.isCancelled else { return }
                media = result
                selectedQuality = result.qualityChoices.first
                isAnalyzing = false
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                isAnalyzing = false
            }
        }
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

    func reveal(_ job: DownloadJob) {
        guard let path = job.outputPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func clearCompleted() {
        jobs.removeAll { [.completed, .failed, .cancelled].contains($0.status) }
        if !jobs.contains(where: { $0.id == selectedJobID }) { selectedJobID = jobs.first?.id }
    }

    func installTool() {
        isInstallingTool = true
        errorMessage = nil
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
                }
                if let completed = jobs.first(where: { $0.id == jobID }) {
                    history.removeAll { $0.id == completed.id }
                    history.insert(completed, at: 0)
                    Self.saveHistory(history)
                    notifyCompletion(completed)
                }
            } catch {
                guard !Task.isCancelled else { return }
                update(jobID) {
                    $0.status = .failed
                    $0.detail = error.localizedDescription
                }
            }
            downloadTasks[jobID] = nil
        }
    }

    private func update(_ id: UUID, mutation: (inout DownloadJob) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        mutation(&jobs[index])
    }

    private func notifyCompletion(_ job: DownloadJob) {
        let content = UNMutableNotificationContent()
        content.title = "Download complete"
        content.body = job.title
        let request = UNNotificationRequest(identifier: job.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static var historyURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("MediaHarbor/history.json")
    }

    private static func loadHistory() -> [DownloadJob] {
        guard let data = try? Data(contentsOf: historyURL) else { return [] }
        return (try? JSONDecoder().decode([DownloadJob].self, from: data)) ?? []
    }

    private static func saveHistory(_ history: [DownloadJob]) {
        do {
            try FileManager.default.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Array(history.prefix(200)))
            try data.write(to: historyURL, options: .atomic)
        } catch {
            // History persistence should never interrupt a completed download.
        }
    }
}
