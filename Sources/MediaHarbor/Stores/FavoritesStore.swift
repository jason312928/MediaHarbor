import Foundation

struct FavoritesStore {
    struct LoadResult {
        let items: [FavoriteItem]
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
            return LoadResult(items: [], canSave: true)
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([FailableFavorite<FavoriteItem>].self, from: data)
            let items = decoded.compactMap(\.value)
            guard items.count != decoded.count else {
                return LoadResult(items: items, canSave: true)
            }
            return LoadResult(items: items, canSave: preserveAndRewrite(items))
        } catch {
            return LoadResult(items: [], canSave: preserveAndRewrite([]))
        }
    }

    func save(_ items: [FavoriteItem]) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Array(items.prefix(500)))
        try data.write(to: url, options: .atomic)
    }

    private func preserveAndRewrite(_ recoveredItems: [FavoriteItem]) -> Bool {
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent("favorites.corrupt-\(UUID().uuidString).json")
        do {
            try fileManager.copyItem(at: url, to: backupURL)
            try save(recoveredItems)
            return true
        } catch {
            return false
        }
    }

    private static var defaultURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("MediaHarbor/favorites.json")
    }
}

private struct FailableFavorite<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) {
        value = try? Value(from: decoder)
    }
}
