import AppKit
import SwiftUI

enum LibraryMode {
    case history
    case favorites

    var emptySymbol: String { self == .history ? "clock.arrow.circlepath" : "star" }
}

struct LibraryBrowserView: View {
    let store: DownloadStore
    let mode: LibraryMode

    @Environment(\.appLanguage) private var language
    @State private var query = ""
    @State private var mediaFilter = LibraryMediaFilter.all
    @State private var sortOrder = LibrarySortOrder.newest
    @State private var confirmsClearingHistory = false
    @State private var collectionEditor: FavoriteCollectionEditor?

    private var records: [LibraryRecord] {
        let source: [LibraryRecord]
        switch mode {
        case .history:
            source = store.history.map {
                LibraryRecord(job: $0, libraryDate: $0.completedAt ?? $0.createdAt)
            }
        case .favorites:
            source = store.favorites.map {
                LibraryRecord(job: $0.job, libraryDate: $0.favoritedAt, collectionID: $0.collectionID)
            }
        }

        return source
            .filter { record in
                mediaFilter.includes(record.job)
                    && favoriteCollectionIncludes(record)
                    && (query.isEmpty
                        || record.job.title.localizedCaseInsensitiveContains(query)
                        || record.job.sourceName.localizedCaseInsensitiveContains(query)
                        || record.job.sourceURL.localizedCaseInsensitiveContains(query))
            }
            .sorted(by: sortOrder.comparator)
    }

    private var selectedID: Binding<UUID?> {
        @Bindable var store = store
        return mode == .history ? $store.selectedHistoryID : $store.selectedFavoriteID
    }

    private var selectedJob: DownloadJob? {
        switch mode {
        case .history: store.selectedHistoryJob
        case .favorites: store.selectedFavoriteJob
        }
    }

    var body: some View {
        Group {
            if rawCount == 0 {
                emptyState
            } else {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        libraryColumn
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if store.showDetailPanel, showsDetail(for: geometry.size.width) {
                            HStack(spacing: 0) {
                                Divider()
                                DownloadJobDetailView(
                                    store: store,
                                    job: selectedJob,
                                    context: mode == .history ? .history : .favorite
                                )
                                .frame(width: detailWidth(for: geometry.size.width))
                                .frame(maxHeight: .infinity, alignment: .top)
                                .clipped()
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut(duration: 0.22), value: store.showDetailPanel)
                    .clipped()
                }
            }
        }
        .toolbar { libraryToolbar }
        .onAppear {
            selectFirstVisibleRecordIfNeeded()
            store.refreshOutputAvailability()
        }
        .onChange(of: records.map(\.id)) { _, _ in selectFirstVisibleRecordIfNeeded() }
        .confirmationDialog(
            L10n.text("clear_history_confirm", language),
            isPresented: $confirmsClearingHistory,
            titleVisibility: .visible
        ) {
            Button(L10n.text("clear_history", language), role: .destructive) { store.clearHistory() }
            Button(L10n.text("cancel", language), role: .cancel) {}
        } message: {
            Text(L10n.text("clear_history_detail", language))
        }
        .sheet(item: $collectionEditor) { editor in
            FavoriteCollectionEditorSheet(editor: editor) { name in
                saveCollection(editor, name: name)
            }
        }
    }

    private var libraryColumn: some View {
        VStack(spacing: 0) {
            LibraryControls(
                query: $query,
                mediaFilter: $mediaFilter,
                sortOrder: $sortOrder,
                mode: mode,
                totalCount: rawCount,
                favoriteCount: store.favorites.count,
                missingCount: missingCount
            )
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.bar)

            Divider()

            if mode == .favorites {
                FavoriteCollectionsBar(
                    collections: store.favoriteCollections,
                    items: store.favorites,
                    selection: Binding(
                        get: { store.favoriteCollectionSelection },
                        set: { store.favoriteCollectionSelection = $0 }
                    ),
                    onCreate: { collectionEditor = .create },
                    onRename: { collectionEditor = .rename($0) },
                    onDelete: deleteCollection
                )
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.bar)

                Divider()
            }

            if records.isEmpty {
                Group {
                    if query.isEmpty, mode == .favorites, store.favoriteCollectionSelection != .all {
                        ContentUnavailableView(
                            L10n.text("no_group_items", language),
                            systemImage: "folder",
                            description: Text(L10n.text("no_group_items_desc", language))
                        )
                    } else {
                        ContentUnavailableView.search(text: query)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(groupedRecords) { group in
                            Section {
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 330, maximum: 540), spacing: 12)],
                                    alignment: .leading,
                                    spacing: 12
                                ) {
                                    ForEach(group.records) { record in
                                        LibraryRecordCard(
                                            store: store,
                                            job: record.job,
                                            isSelected: selectedID.wrappedValue == record.id,
                                            date: record.libraryDate
                                        )
                                        .onTapGesture { selectedID.wrappedValue = record.id }
                                        .onTapGesture(count: 2) { open(record.job) }
                                        .contextMenu { recordMenu(record.job) }
                                    }
                                }
                            } header: {
                                HStack(spacing: 7) {
                                    Text(group.title(language))
                                        .font(.headline)
                                    Text(group.records.count, format: .number)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.leading, 2)
                            }
                        }
                    }
                    .padding(18)
                }
                .scrollIndicators(.automatic)
            }

            Divider()
            Text(L10n.text("library_item_count", language, records.count))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
    }

    @ToolbarContentBuilder
    private var libraryToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if mode == .history {
                Button(role: .destructive) { confirmsClearingHistory = true } label: {
                    Label(L10n.text("clear_history", language), systemImage: "trash")
                }
                .disabled(store.history.isEmpty)
                .help(L10n.text("clear_history", language))
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                L10n.text(mode == .history ? "no_history" : "no_favorites", language),
                systemImage: mode.emptySymbol
            )
        } description: {
            Text(L10n.text(mode == .history ? "history_desc" : "favorites_desc", language))
        } actions: {
            Button(L10n.text("find_media", language)) { store.selection = .discover }
        }
    }

    @ViewBuilder
    private func recordMenu(_ job: DownloadJob) -> some View {
        Button { store.toggleFavorite(job) } label: {
            Label(
                L10n.text(store.isFavorite(job) ? "remove_favorite" : "add_favorite", language),
                systemImage: store.isFavorite(job) ? "star.slash" : "star"
            )
        }
        Button { store.downloadAgain(job) } label: {
            Label(L10n.text("download_again", language), systemImage: "arrow.clockwise")
        }
        if store.outputExists(job) {
            Button { store.openOutput(job) } label: {
                Label(L10n.text("open_file", language), systemImage: "play.rectangle")
            }
            Button { store.reveal(job) } label: {
                Label(L10n.text("show_finder", language), systemImage: "folder")
            }
        }
        if store.isFavorite(job) {
            Menu {
                favoriteCollectionMenuItems(job)
            } label: {
                Label(L10n.text("move_to_group", language), systemImage: "folder")
            }
        }
        Divider()
        Button(role: .destructive) {
            if mode == .history { store.deleteHistoryRecord(jobID: job.id) }
            else { store.toggleFavorite(job) }
        } label: {
            Label(
                L10n.text(mode == .history ? "delete_history_record" : "remove_favorite", language),
                systemImage: mode == .history ? "trash" : "star.slash"
            )
        }
    }

    private var rawCount: Int { mode == .history ? store.history.count : store.favorites.count }
    private var missingCount: Int {
        let jobs = mode == .history ? store.history : store.favorites.map(\.job)
        return jobs.filter(store.outputIsMissing).count
    }

    private var groupedRecords: [LibraryDateGroup] {
        let grouped = Dictionary(grouping: records) { LibraryDateGroup.Kind(date: $0.libraryDate) }
        let kinds = sortOrder == .oldest
            ? Array(LibraryDateGroup.Kind.allCases.reversed())
            : LibraryDateGroup.Kind.allCases
        return kinds.compactMap { kind in
            guard let values = grouped[kind], !values.isEmpty else { return nil }
            return LibraryDateGroup(kind: kind, records: values)
        }
    }

    private func favoriteCollectionIncludes(_ record: LibraryRecord) -> Bool {
        guard mode == .favorites else { return true }
        switch store.favoriteCollectionSelection {
        case .all: return true
        case .ungrouped: return record.collectionID == nil
        case .collection(let id): return record.collectionID == id
        }
    }

    @ViewBuilder
    private func favoriteCollectionMenuItems(_ job: DownloadJob) -> some View {
        Button {
            store.moveFavorite(jobID: job.id, to: nil)
        } label: {
            if store.favoriteCollection(for: job) == nil {
                Label(L10n.text("ungrouped", language), systemImage: "checkmark")
            } else {
                Text(L10n.text("ungrouped", language))
            }
        }
        ForEach(store.favoriteCollections) { collection in
            Button {
                store.moveFavorite(jobID: job.id, to: collection.id)
            } label: {
                if store.favoriteCollection(for: job)?.id == collection.id {
                    Label(collection.name, systemImage: "checkmark")
                } else {
                    Text(collection.name)
                }
            }
        }
    }

    private func saveCollection(_ editor: FavoriteCollectionEditor, name: String) {
        switch editor {
        case .create:
            if let id = store.createFavoriteCollection(named: name) {
                store.favoriteCollectionSelection = .collection(id)
            }
        case .rename(let collection):
            store.renameFavoriteCollection(id: collection.id, to: name)
        }
    }

    private func deleteCollection(_ collection: FavoriteCollection) {
        store.deleteFavoriteCollection(id: collection.id)
    }

    private func selectFirstVisibleRecordIfNeeded() {
        guard !records.contains(where: { $0.id == selectedID.wrappedValue }) else { return }
        selectedID.wrappedValue = records.first?.id
    }

    private func showsDetail(for width: CGFloat) -> Bool { width >= 790 }
    private func detailWidth(for width: CGFloat) -> CGFloat { min(410, max(320, width * 0.35)) }

    private func open(_ job: DownloadJob) {
        if store.outputExists(job) { _ = store.openOutput(job) }
        else if let url = URL(string: job.sourceURL) { NSWorkspace.shared.open(url) }
    }
}

private struct LibraryRecord: Identifiable {
    let job: DownloadJob
    let libraryDate: Date
    var collectionID: UUID? = nil
    var id: UUID { job.id }
}

private struct LibraryDateGroup: Identifiable {
    enum Kind: Int, CaseIterable {
        case today, thisWeek, earlier

        init(date: Date) {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) { self = .today }
            else if calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: date)
                == calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: Date()) { self = .thisWeek }
            else { self = .earlier }
        }
    }

    let kind: Kind
    let records: [LibraryRecord]
    var id: Int { kind.rawValue }

    func title(_ language: AppLanguage) -> String {
        switch kind {
        case .today: L10n.text("today", language)
        case .thisWeek: L10n.text("this_week", language)
        case .earlier: L10n.text("earlier", language)
        }
    }
}

private enum LibraryMediaFilter: String, CaseIterable, Identifiable {
    case all, video, audio, subtitles
    var id: String { rawValue }

    func includes(_ job: DownloadJob) -> Bool {
        switch self {
        case .all: true
        case .video: !includesAudio(job) && !includesSubtitles(job)
        case .audio: includesAudio(job)
        case .subtitles: includesSubtitles(job)
        }
    }

    func title(_ language: AppLanguage) -> String { L10n.text("library_filter_\(rawValue)", language) }
    private func includesAudio(_ job: DownloadJob) -> Bool { job.qualityTitle.lowercased() == "audio" }
    private func includesSubtitles(_ job: DownloadJob) -> Bool { job.qualityTitle.lowercased() == "subtitles" }
}

private enum LibrarySortOrder: String, CaseIterable, Identifiable {
    case newest, oldest, title
    var id: String { rawValue }

    func comparator(_ lhs: LibraryRecord, _ rhs: LibraryRecord) -> Bool {
        switch self {
        case .newest: lhs.libraryDate > rhs.libraryDate
        case .oldest: lhs.libraryDate < rhs.libraryDate
        case .title: lhs.job.title.localizedStandardCompare(rhs.job.title) == .orderedAscending
        }
    }

    func title(_ language: AppLanguage) -> String { L10n.text("library_sort_\(rawValue)", language) }
}

private struct LibraryControls: View {
    @Binding var query: String
    @Binding var mediaFilter: LibraryMediaFilter
    @Binding var sortOrder: LibrarySortOrder
    let mode: LibraryMode
    let totalCount: Int
    let favoriteCount: Int
    let missingCount: Int
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(
                        L10n.text(mode == .history ? "search_history" : "search_favorites", language),
                        text: $query
                    )
                    .textFieldStyle(.plain)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 11)
                .frame(minWidth: 180, maxWidth: .infinity, minHeight: 34, maxHeight: 34)
                .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(.separator.opacity(0.45)) }

                Menu {
                    ForEach(LibrarySortOrder.allCases) { order in
                        Button { sortOrder = order } label: {
                            if sortOrder == order { Label(order.title(language), systemImage: "checkmark") }
                            else { Text(order.title(language)) }
                        }
                    }
                } label: {
                    Label(sortOrder.title(language), systemImage: "arrow.up.arrow.down")
                        .lineLimit(1)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            ViewThatFits(in: .horizontal) {
                HStack { filterPicker; Spacer(); summary }
                VStack(alignment: .leading, spacing: 9) { filterPicker; summary }
            }
        }
    }

    private var filterPicker: some View {
        Picker(L10n.text("media_type", language), selection: $mediaFilter) {
            ForEach(LibraryMediaFilter.allCases) { filter in
                Text(filter.title(language)).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }

    private var summary: some View {
        HStack(spacing: 12) {
            Label(totalCount.formatted(), systemImage: mode == .history ? "clock" : "star.fill")
                .foregroundStyle(mode == .history ? AnyShapeStyle(.secondary) : AnyShapeStyle(.yellow))
            if mode == .history, favoriteCount > 0 {
                Label(favoriteCount.formatted(), systemImage: "star.fill").foregroundStyle(.yellow)
            }
            if missingCount > 0 {
                Label(missingCount.formatted(), systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
        }
        .font(.caption.weight(.semibold))
        .fixedSize()
    }
}

private struct LibraryRecordCard: View {
    let store: DownloadStore
    let job: DownloadJob
    let isSelected: Bool
    let date: Date
    @Environment(\.appLanguage) private var language

    var body: some View {
        HStack(spacing: 13) {
            RemoteThumbnail(
                urlString: job.thumbnail,
                refererURLString: job.sourceURL,
                contentMode: .fill,
                placeholderSymbol: "play.rectangle"
            )
            .frame(width: 116, height: 78)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 8) {
                    Text(job.title)
                        .font(.headline)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button { store.toggleFavorite(job) } label: {
                        Image(systemName: store.isFavorite(job) ? "star.fill" : "star")
                            .foregroundStyle(store.isFavorite(job) ? .yellow : .secondary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .help(L10n.text(store.isFavorite(job) ? "remove_favorite" : "add_favorite", language))
                }

                Label(job.displaySourceName, systemImage: "play.square.stack")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    DownloadMetadataChip(job.qualityTitle)
                    if let ext = job.outputFileExtension { DownloadMetadataChip(ext.uppercased()) }
                    Spacer(minLength: 4)
                    if store.outputIsMissing(job) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    Text(date, format: .dateTime.hour().minute())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 16))
        .harborCard(cornerRadius: 16)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: isSelected ? 1.5 : 1)
        }
        .shadow(color: .black.opacity(isSelected ? 0.08 : 0.025), radius: isSelected ? 8 : 3, y: 2)
        .animation(.easeOut(duration: 0.16), value: isSelected)
    }
}
