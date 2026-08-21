import Foundation

struct FavoritesStore {
    struct LoadResult {
        let items: [FavoriteItem]
        let collections: [FavoriteCollection]
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
            return LoadResult(items: [], collections: [], canSave: true)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return LoadResult(items: [], collections: [], canSave: false)
        }

        do {
            let document = try JSONDecoder().decode(FavoritesDocument.self, from: data)
            guard document.hadItemLoss else {
                return LoadResult(items: document.items, collections: document.collections, canSave: true)
            }
            return LoadResult(
                items: document.items,
                collections: document.collections,
                canSave: preserveAndRewrite(items: document.items, collections: document.collections)
            )
        } catch {
            do {
                let decoded = try JSONDecoder().decode([FailableFavorite<FavoriteItem>].self, from: data)
                let items = decoded.compactMap(\.value)
                return LoadResult(
                    items: items,
                    collections: [],
                    canSave: preserveAndRewrite(items: items, collections: [])
                )
            } catch {
                return LoadResult(
                    items: [],
                    collections: [],
                    canSave: preserveAndRewrite(items: [], collections: [])
                )
            }
        }
    }

    func save(items: [FavoriteItem], collections: [FavoriteCollection]) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let document = FavoritesDocument(
            collections: Array(collections.prefix(100)),
            items: Array(items.prefix(500))
        )
        let data = try JSONEncoder().encode(document)
        try data.write(to: url, options: .atomic)
    }

    private func preserveAndRewrite(items: [FavoriteItem], collections: [FavoriteCollection]) -> Bool {
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent("favorites.corrupt-\(UUID().uuidString).json")
        do {
            try fileManager.copyItem(at: url, to: backupURL)
            try save(items: items, collections: collections)
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

private struct FavoritesDocument: Codable {
    let version: Int
    let collections: [FavoriteCollection]
    let items: [FavoriteItem]
    let hadItemLoss: Bool

    init(collections: [FavoriteCollection], items: [FavoriteItem]) {
        version = 2
        self.collections = collections
        self.items = items
        hadItemLoss = false
    }

    private enum CodingKeys: String, CodingKey {
        case version, collections, items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 2
        collections = try container.decodeIfPresent([FavoriteCollection].self, forKey: .collections) ?? []
        let decoded = try container.decode([FailableFavorite<FavoriteItem>].self, forKey: .items)
        items = decoded.compactMap(\.value)
        hadItemLoss = items.count != decoded.count
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(collections, forKey: .collections)
        try container.encode(items, forKey: .items)
    }
}

private struct FailableFavorite<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) {
        value = try? Value(from: decoder)
    }
}
