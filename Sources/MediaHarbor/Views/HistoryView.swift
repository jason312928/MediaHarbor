import SwiftUI

struct HistoryView: View {
    let store: DownloadStore
    @State private var query = ""
    @Environment(\.appLanguage) private var language

    private var filtered: [DownloadJob] {
        guard !query.isEmpty else { return store.history }
        return store.history.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.sourceName.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        Group {
            if store.history.isEmpty {
                ContentUnavailableView(L10n.text("no_history", language), systemImage: "clock.arrow.circlepath", description: Text(L10n.text("history_desc", language)))
            } else {
                List(filtered) { job in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(job.title).fontWeight(.medium).lineLimit(1)
                            Text("\(job.sourceName) · \(job.qualityTitle) · \(MediaFormatters.relativeDate.localizedString(for: job.createdAt, relativeTo: .now))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if job.outputPath != nil {
                            Button { store.reveal(job) } label: { Image(systemName: "folder") }
                                .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 5)
                }
                .listStyle(.inset)
            }
        }
        .searchable(text: $query, prompt: L10n.text("search_history", language))
    }
}
