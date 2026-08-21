import SwiftUI

struct HistoryView: View {
    let store: DownloadStore
    @Environment(\.appLanguage) private var language
    @State private var query = ""

    private var filteredJobs: [DownloadJob] {
        guard !query.isEmpty else { return store.history }
        return store.history.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.sourceName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Group {
            if store.history.isEmpty {
                ContentUnavailableView(
                    L10n.text("no_history", language),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(L10n.text("history_desc", language))
                )
            } else if filteredJobs.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredJobs) { job in
                            Button {
                                if store.outputExists(job) { store.reveal(job) }
                            } label: {
                                DownloadJobCard(
                                    job: job,
                                    isSelected: false,
                                    isFileMissing: store.outputIsMissing(job)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(!store.outputExists(job))
                            .contextMenu {
                                if store.outputExists(job) {
                                    Button(L10n.text("show_finder", language)) { store.reveal(job) }
                                }
                                if let sourceURL = URL(string: job.sourceURL) {
                                    Link(L10n.text("open_source", language), destination: sourceURL)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 820)
                    .padding(28)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .searchable(text: $query, prompt: L10n.text("search_history", language))
        .onAppear { store.refreshOutputAvailability() }
    }
}
