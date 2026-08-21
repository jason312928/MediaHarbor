import SwiftUI
import AppKit

enum DownloadDetailContext {
    case download
    case history
    case favorite
}

struct DownloadJobDetailView: View {
    let store: DownloadStore
    let job: DownloadJob?
    var context: DownloadDetailContext = .download
    @Environment(\.appLanguage) private var language
    @Environment(\.scenePhase) private var scenePhase
    @State private var outputAvailability = OutputAvailability.unknown
    @State private var pendingDeletion: PendingDeletion?
    @State private var fileAlertMessage: String?
    @State private var copiedSourceURL: String?

    var body: some View {
        Group {
            if let job {
                GeometryReader { geometry in
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 16) {
                            hero(job)
                            if job.status != .completed {
                                progressSection(job)
                            }
                            if outputAvailability == .missing {
                                missingFileNotice
                            }
                            actions(job)
                            sourceLinkSection(job)
                            metadataSection(job)
                            if job.status == .failed, let detail = job.detail, !detail.isEmpty {
                                failureMessage(detail)
                            }
                        }
                        .frame(width: max(geometry.size.width - 32, 0), alignment: .leading)
                        .padding(16)
                    }
                    .scrollIndicators(.automatic)
                }
            } else {
                ContentUnavailableView(L10n.text("select_download", language), systemImage: "sidebar.right")
            }
        }
        .task(id: detailRefreshID) { refreshOutputAvailability() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshOutputAvailability() }
        }
        .confirmationDialog(
            deletionTitle,
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(deletionActionTitle, role: .destructive) { performPendingDeletion() }
            Button(L10n.text("cancel", language), role: .cancel) {}
        } message: {
            Text(deletionDetail)
        }
        .alert("MediaHarbor", isPresented: Binding(
            get: { fileAlertMessage != nil },
            set: { if !$0 { fileAlertMessage = nil } }
        )) {
            Button(L10n.text("ok", language), role: .cancel) { fileAlertMessage = nil }
        } message: {
            Text(fileAlertMessage ?? L10n.text("file_missing", language))
        }
    }

    private func hero(_ job: DownloadJob) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            RemoteThumbnail(
                urlString: job.thumbnail,
                refererURLString: job.sourceURL,
                contentMode: .fill,
                placeholderSymbol: "play.rectangle"
            )
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: 220)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.08))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(job.title)
                    .font(.title2.bold())
                    .lineLimit(3)
                HStack(spacing: 10) {
                    Label(job.displaySourceName, systemImage: "play.square.stack")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Button { store.toggleFavorite(job) } label: {
                        Image(systemName: store.isFavorite(job) ? "star.fill" : "star")
                            .foregroundStyle(store.isFavorite(job) ? .yellow : .secondary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .help(L10n.text(store.isFavorite(job) ? "remove_favorite" : "add_favorite", language))
                    if job.status == .completed {
                        DownloadStatusBadge(status: job.status)
                    }
                }
            }
        }
    }

    private var detailRefreshID: String {
        "\(job?.id.uuidString ?? "none")|\(job?.outputPath ?? "")"
    }

    private func progressSection(_ job: DownloadJob) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                DownloadStatusBadge(status: job.status)
                Spacer()
                Text(job.progress.formatted(.percent.precision(.fractionLength(0))))
                    .font(.title3.monospacedDigit().weight(.semibold))
            }
            ProgressView(value: job.status == .completed ? 1 : job.progress)
                .progressViewStyle(.linear)
                .tint(progressColor(job.status))
        }
        .padding(16)
        .harborCard(cornerRadius: 16)
    }

    private func metadataSection(_ job: DownloadJob) -> some View {
        VStack(spacing: 0) {
            DownloadDetailRow(label: L10n.text("format", language), value: formatDescription(job))
            Divider()
            if job.status.isActive, let speed = job.speed, speed != "NA" {
                DownloadDetailRow(label: L10n.text("speed", language), value: speed)
                Divider()
            }
            if job.status.isActive, let eta = job.eta, eta != "NA" {
                DownloadDetailRow(label: L10n.text("remaining_time", language), value: eta)
                Divider()
            }
            if let fileSize = outputFileSize(job) {
                DownloadDetailRow(label: L10n.text("file_size", language), value: fileSize)
                Divider()
            }
            if let path = job.outputPath {
                DownloadDetailRow(label: L10n.text("save_location", language), value: abbreviatedPath(path))
                Divider()
            }
            DownloadDetailRow(
                label: L10n.text("created_at", language),
                value: job.createdAt.formatted(date: .abbreviated, time: .shortened)
            )
        }
        .padding(.horizontal, 16)
        .harborCard(cornerRadius: 16)
    }

    private func failureMessage(_ detail: String) -> some View {
        Label {
            Text(detail)
                .font(.callout)
                .textSelection(.enabled)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .foregroundStyle(.red)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var missingFileNotice: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(L10n.text("file_missing", language), systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
            Text(L10n.text("file_missing_detail", language))
                .font(.callout)
        }
        .foregroundStyle(.orange)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func actions(_ job: DownloadJob) -> some View {
        VStack(spacing: 8) {
            if context != .download {
                Button {
                    store.downloadAgain(job)
                } label: {
                    Label(L10n.text("download_again", language), systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if store.isFavorite(job) {
                Menu {
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
                } label: {
                    Label(
                        store.favoriteCollection(for: job)?.name ?? L10n.text("ungrouped", language),
                        systemImage: "folder"
                    )
                    .frame(maxWidth: .infinity)
                }
                .menuStyle(.borderlessButton)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 7))
            }

            if [.cancelled, .failed].contains(job.status) {
                Button {
                    store.resume(jobID: job.id)
                } label: {
                    Label(L10n.text("resume_download", language), systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(role: .destructive) {
                    pendingDeletion = .partialDownload
                } label: {
                    Label(L10n.text("delete_file", language), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            if job.outputPath != nil, outputAvailability != .missing {
                Button {
                    guard store.openOutput(job) else { return reportMissingFile() }
                } label: {
                    Label(L10n.text("open_file", language), systemImage: "play.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                HStack(spacing: 8) {
                    Button {
                        guard store.reveal(job) else { return reportMissingFile() }
                    } label: {
                        Label(L10n.text("show_finder", language), systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    Button {
                        copyPath(job)
                    } label: {
                        Label(L10n.text("copy_path", language), systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button(role: .destructive) {
                    pendingDeletion = .completedOutput
                } label: {
                    Label(L10n.text("delete_video", language), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            if job.status.isActive {
                Button(role: .destructive) {
                    store.cancel(jobID: job.id)
                } label: {
                    Label(L10n.text("cancel_download", language), systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if context == .history {
                Button(role: .destructive) {
                    store.deleteHistoryRecord(jobID: job.id)
                } label: {
                    Label(L10n.text("delete_history_record", language), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else if context == .favorite {
                Button(role: .destructive) {
                    store.toggleFavorite(job)
                } label: {
                    Label(L10n.text("remove_favorite", language), systemImage: "star.slash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

        }
        .frame(maxWidth: .infinity)
    }

    private func sourceLinkSection(_ job: DownloadJob) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.text("source_link", language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if copiedSourceURL == job.sourceURL {
                    Label(L10n.text("copied", language), systemImage: "checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            }

            HStack(spacing: 8) {
                ScrollView(.horizontal) {
                    Text(job.sourceURL)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 9)
                        .frame(height: 30)
                        .contentShape(Rectangle())
                        .onTapGesture { copySourceURL(job.sourceURL) }
                }
                .scrollIndicators(.automatic)
                .frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30)
                .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .help(L10n.text("click_to_copy", language))

                Button {
                    guard let url = URL(string: job.sourceURL) else { return }
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .frame(width: 26, height: 30)
                .fixedSize()
                .help(L10n.text("open_source", language))
            }
        }
        .padding(12)
        .harborCard(cornerRadius: 12)
    }

    private func progressColor(_ status: DownloadStatus) -> Color {
        switch status {
        case .completed: .green
        case .failed: .red
        case .cancelled: .secondary
        case .queued: .orange
        default: .blue
        }
    }

    private func formatDescription(_ job: DownloadJob) -> String {
        [job.qualityTitle, job.outputFileExtension?.uppercased()].compactMap { $0 }.joined(separator: " · ")
    }

    private func outputFileSize(_ job: DownloadJob) -> String? {
        guard let outputPath = job.outputPath,
              let values = try? URL(fileURLWithPath: outputPath).resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    private func abbreviatedPath(_ path: String) -> String {
        NSString(string: path).abbreviatingWithTildeInPath
    }

    private func copyPath(_ job: DownloadJob) {
        guard let path = job.outputPath else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    private func copySourceURL(_ sourceURL: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sourceURL, forType: .string)
        withAnimation(.easeOut(duration: 0.15)) { copiedSourceURL = sourceURL }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            guard copiedSourceURL == sourceURL else { return }
            withAnimation(.easeOut(duration: 0.15)) { copiedSourceURL = nil }
        }
    }

    private func refreshOutputAvailability() {
        guard let job, job.outputPath != nil else {
            outputAvailability = .unknown
            return
        }
        outputAvailability = store.outputExists(job) ? .available : .missing
    }

    private func reportMissingFile() {
        outputAvailability = .missing
        fileAlertMessage = L10n.text("file_missing_detail", language)
    }

    private func deleteOutput() {
        guard let job else { return }
        do {
            try store.moveOutputToTrash(job)
            outputAvailability = .missing
        } catch {
            refreshOutputAvailability()
            fileAlertMessage = outputAvailability == .missing
                ? L10n.text("file_missing_detail", language)
                : error.localizedDescription
        }
    }

    private var deletionTitle: String {
        switch pendingDeletion {
        case .partialDownload: L10n.text("delete_partial_confirm", language)
        default: L10n.text("delete_video_confirm", language)
        }
    }

    private var deletionDetail: String {
        switch pendingDeletion {
        case .partialDownload: L10n.text("delete_partial_detail", language)
        default: L10n.text("delete_video_detail", language)
        }
    }

    private var deletionActionTitle: String {
        switch pendingDeletion {
        case .partialDownload: L10n.text("delete_file", language)
        default: L10n.text("move_to_trash", language)
        }
    }

    private func performPendingDeletion() {
        let request = pendingDeletion
        pendingDeletion = nil
        switch request {
        case .partialDownload:
            guard let job else { return }
            store.deleteCancelledDownload(jobID: job.id)
        case .completedOutput:
            deleteOutput()
        case nil:
            break
        }
    }
}

private enum OutputAvailability: Equatable {
    case unknown, available, missing
}

private enum PendingDeletion {
    case completedOutput
    case partialDownload
}

private struct DownloadDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
            Text(value)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity)
        .font(.callout)
        .padding(.vertical, 11)
    }
}
