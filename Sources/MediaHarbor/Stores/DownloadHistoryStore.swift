import Foundation

struct DownloadHistoryStore {
    struct LoadResult {
        let jobs: [DownloadJob]
        let canSave: Bool
    }

    let url: URL
    private let fileManager: FileManager

    init(url: URL = Self.defaultURL, fileManager: FileManager = .default) {
        self.url = url
        self.fileManager = fileManager
    }

    func load() -> LoadResult {
        guard fileManager.fileExists(atPath: url.path) else {
            return LoadResult(jobs: [], canSave: true)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return LoadResult(jobs: [], canSave: false)
        }

        do {
            let decoded = try JSONDecoder().decode([FailableDecodable<DownloadJob>].self, from: data)
            let jobs = decoded.compactMap(\.value)
            guard jobs.count != decoded.count else {
                return LoadResult(jobs: jobs, canSave: true)
            }
            return LoadResult(jobs: jobs, canSave: preserveAndRewrite(jobs))
        } catch {
            return LoadResult(jobs: [], canSave: preserveAndRewrite([]))
        }
    }

    func save(_ history: [DownloadJob]) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Array(history.prefix(200)))
        try data.write(to: url, options: .atomic)
    }

    private func preserveAndRewrite(_ recoveredJobs: [DownloadJob]) -> Bool {
        let stem = url.deletingPathExtension().lastPathComponent
        let suffix = url.pathExtension.isEmpty ? "" : ".\(url.pathExtension)"
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent("\(stem).corrupt-\(UUID().uuidString)\(suffix)")
        do {
            try fileManager.copyItem(at: url, to: backupURL)
            try save(recoveredJobs)
            return true
        } catch {
            return false
        }
    }

    private static var defaultURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("MediaHarbor/history.json")
    }
}

private struct FailableDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) {
        value = try? Value(from: decoder)
    }
}
