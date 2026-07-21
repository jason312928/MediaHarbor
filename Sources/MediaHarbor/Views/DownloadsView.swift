import SwiftUI

struct DownloadsView: View {
    let store: DownloadStore
    @Environment(\.appLanguage) private var language

    var body: some View {
        @Bindable var store = store
        Group {
            if store.jobs.isEmpty {
                ContentUnavailableView {
                    Label(L10n.text("no_downloads", language), systemImage: "arrow.down.circle")
                } description: {
                    Text(L10n.text("no_downloads_desc", language))
                } actions: {
                    Button(L10n.text("find_media", language)) { store.selection = .discover }
                }
            } else {
                HSplitView {
                    List(selection: $store.selectedJobID) {
                        ForEach(store.jobs) { job in
                            DownloadRow(job: job)
                                .tag(job.id)
                                .contextMenu {
                                    if job.status.isActive {
                                        Button(L10n.text("cancel", language), role: .destructive) { store.cancel(jobID: job.id) }
                                    }
                                    if job.outputPath != nil {
                                        Button(L10n.text("show_finder", language)) { store.reveal(job) }
                                    }
                                }
                        }
                    }
                    .listStyle(.inset)
                    .frame(minWidth: 420, idealWidth: 580)

                    JobDetailView(store: store, job: store.selectedJob)
                        .frame(minWidth: 260, idealWidth: 320)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(L10n.text("clear_finished", language), systemImage: "checkmark.circle.badge.xmark") { store.clearCompleted() }
                    .disabled(!store.jobs.contains { [.completed, .failed, .cancelled].contains($0.status) })
            }
        }
        .onAppear { if store.selectedJobID == nil { store.selectedJobID = store.jobs.first?.id } }
    }
}

private struct DownloadRow: View {
    let job: DownloadJob
    @Environment(\.appLanguage) private var language

    var body: some View {
        HStack(spacing: 12) {
            RemoteThumbnail(urlString: job.thumbnail, refererURLString: job.sourceURL, contentMode: .fill, placeholderSymbol: "play.rectangle")
            .frame(width: 88, height: 50)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(job.title).fontWeight(.medium).lineLimit(1)
                    Spacer()
                    Text(job.qualityTitle).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                if job.status.isActive || job.status == .queued {
                    ProgressView(value: job.progress).progressViewStyle(.linear)
                }
                HStack(spacing: 7) {
                    StatusDot(status: job.status)
                    Text(job.status == .failed ? (job.detail ?? job.status.localizedTitle(language)) : job.status.localizedTitle(language)).lineLimit(1)
                    Spacer()
                    if let speed = job.speed, speed != "NA" { Text(speed) }
                    if let eta = job.eta, eta != "NA" { Text(L10n.text("eta", language, eta)) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct JobDetailView: View {
    let store: DownloadStore
    let job: DownloadJob?
    @Environment(\.appLanguage) private var language

    var body: some View {
        if let job {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    RemoteThumbnail(urlString: job.thumbnail, refererURLString: job.sourceURL)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 7) {
                        Text(job.title).font(.title3.bold())
                        Text(job.sourceName).foregroundStyle(.secondary)
                    }

                    VStack(spacing: 10) {
                        LabeledContent(L10n.text("status", language), value: job.status.localizedTitle(language))
                        LabeledContent(L10n.text("format", language), value: job.qualityTitle)
                        LabeledContent(L10n.text("progress", language), value: job.progress.formatted(.percent.precision(.fractionLength(0))))
                        if let speed = job.speed { LabeledContent(L10n.text("speed", language), value: speed) }
                    }
                    .font(.callout)

                    if job.status.isActive {
                        Button(L10n.text("cancel_download", language), role: .destructive) { store.cancel(jobID: job.id) }
                            .frame(maxWidth: .infinity)
                    } else if job.outputPath != nil {
                        Button(L10n.text("show_finder", language), systemImage: "folder") { store.reveal(job) }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(22)
            }
        } else {
            ContentUnavailableView(L10n.text("select_download", language), systemImage: "sidebar.right")
        }
    }
}
