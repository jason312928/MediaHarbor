import SwiftUI

struct DownloadsView: View {
    let store: DownloadStore
    @Environment(\.appLanguage) private var language
    @State private var searchText = ""
    @State private var statusFilter = DownloadStatusFilter.all
    @State private var sortOrder = DownloadSortOrder.newest

    private var visibleJobs: [DownloadJob] {
        store.jobs
            .filter { job in
                statusFilter.includes(job.status)
                    && (searchText.isEmpty
                        || job.title.localizedCaseInsensitiveContains(searchText)
                        || job.sourceName.localizedCaseInsensitiveContains(searchText))
            }
            .sorted(by: sortOrder.areInIncreasingOrder)
    }

    var body: some View {
        @Bindable var store = store
        Group {
            if store.jobs.isEmpty {
                emptyState
            } else {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        taskColumn(selection: $store.selectedJobID)
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: .infinity, alignment: .top)

                        if store.showDetailPanel {
                            HStack(spacing: 0) {
                                Divider()

                                DownloadJobDetailView(store: store, job: store.selectedJob)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(L10n.text("clear_finished", language), systemImage: "checkmark.circle.badge.xmark") {
                    store.clearCompleted()
                }
                .disabled(!store.jobs.contains { [.completed, .failed, .cancelled].contains($0.status) })
            }
        }
        .onAppear {
            selectFirstVisibleJobIfNeeded()
            store.refreshOutputAvailability()
        }
        .onChange(of: visibleJobs.map(\.id)) { _, _ in selectFirstVisibleJobIfNeeded() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(L10n.text("no_downloads", language), systemImage: "arrow.down.circle")
        } description: {
            Text(L10n.text("no_downloads_desc", language))
        } actions: {
            Button(L10n.text("find_media", language)) { store.selection = .discover }
        }
    }

    private func taskColumn(selection: Binding<UUID?>) -> some View {
        VStack(spacing: 0) {
            DownloadToolbar(
                searchText: $searchText,
                statusFilter: $statusFilter,
                sortOrder: $sortOrder
            )
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.bar)

            Divider()

            if visibleJobs.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(visibleJobs) { job in
                            Button {
                                selection.wrappedValue = job.id
                            } label: {
                                DownloadJobCard(
                                    job: job,
                                    isSelected: selection.wrappedValue == job.id,
                                    isFileMissing: store.outputIsMissing(job)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if job.status.isActive {
                                    Button(L10n.text("cancel", language), role: .destructive) {
                                        store.cancel(jobID: job.id)
                                    }
                                }
                                if store.outputExists(job) {
                                    Button(L10n.text("show_finder", language)) { store.reveal(job) }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }

            Divider()
            Text(L10n.text("download_item_count", language, visibleJobs.count))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func selectFirstVisibleJobIfNeeded() {
        guard !visibleJobs.contains(where: { $0.id == store.selectedJobID }) else { return }
        store.selectedJobID = visibleJobs.first?.id
    }

    private func detailWidth(for availableWidth: CGFloat) -> CGFloat {
        min(420, max(300, availableWidth * 0.36))
    }
}

private struct DownloadToolbar: View {
    @Binding var searchText: String
    @Binding var statusFilter: DownloadStatusFilter
    @Binding var sortOrder: DownloadSortOrder
    @Environment(\.appLanguage) private var language

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(L10n.text("search_downloads", language), text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(minWidth: 190, maxWidth: .infinity, minHeight: 34, maxHeight: 34)
            .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.separator.opacity(0.5))
            }

            Menu {
                ForEach(DownloadStatusFilter.allCases) { filter in
                    Button {
                        statusFilter = filter
                    } label: {
                        if statusFilter == filter {
                            Label(filter.localizedTitle(language), systemImage: "checkmark")
                        } else {
                            Text(filter.localizedTitle(language))
                        }
                    }
                }
            } label: {
                Label(statusFilter.localizedTitle(language), systemImage: "line.3.horizontal.decrease")
                    .lineLimit(1)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Menu {
                ForEach(DownloadSortOrder.allCases) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        if sortOrder == order {
                            Label(order.localizedTitle(language), systemImage: "checkmark")
                        } else {
                            Text(order.localizedTitle(language))
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .frame(width: 24, height: 24)
            }
            .menuStyle(.borderlessButton)
            .help(L10n.text("sort_downloads", language))
        }
    }
}

private enum DownloadStatusFilter: String, CaseIterable, Identifiable {
    case all, active, completed, failed

    var id: String { rawValue }

    func includes(_ status: DownloadStatus) -> Bool {
        switch self {
        case .all: true
        case .active: status.isActive || status == .queued
        case .completed: status == .completed
        case .failed: status == .failed || status == .cancelled
        }
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        L10n.text("download_filter_\(rawValue)", language)
    }
}

private enum DownloadSortOrder: String, CaseIterable, Identifiable {
    case newest, status

    var id: String { rawValue }

    func areInIncreasingOrder(_ lhs: DownloadJob, _ rhs: DownloadJob) -> Bool {
        switch self {
        case .newest: return lhs.createdAt > rhs.createdAt
        case .status:
            if lhs.status.sortPriority == rhs.status.sortPriority { return lhs.createdAt > rhs.createdAt }
            return lhs.status.sortPriority < rhs.status.sortPriority
        }
    }

    func localizedTitle(_ language: AppLanguage) -> String {
        L10n.text("download_sort_\(rawValue)", language)
    }
}

private extension DownloadStatus {
    var sortPriority: Int {
        switch self {
        case .downloading, .processing, .preparing: 0
        case .queued: 1
        case .failed: 2
        case .completed: 3
        case .cancelled: 4
        }
    }
}
