import SwiftUI

struct DownloadJobCard: View {
    let job: DownloadJob
    let isSelected: Bool
    var isFileMissing = false
    @Environment(\.appLanguage) private var language

    private var statusColor: Color {
        switch job.status {
        case .completed: .green
        case .failed: .red
        case .cancelled: .secondary
        case .queued: .orange
        default: .blue
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            RemoteThumbnail(
                urlString: job.thumbnail,
                refererURLString: job.sourceURL,
                contentMode: .fill,
                placeholderSymbol: "play.rectangle"
            )
            .frame(width: 104, height: 72)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(job.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if isFileMissing {
                        Label(L10n.text("file_missing", language), systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.12), in: Capsule())
                    } else {
                        DownloadStatusBadge(status: job.status)
                    }
                }

                Label(job.displaySourceName, systemImage: "play.square.stack")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: normalizedProgress)
                    .progressViewStyle(.linear)
                    .tint(statusColor)

                HStack(spacing: 8) {
                    DownloadMetadataChip(job.qualityTitle)
                    if let fileExtension = job.outputFileExtension {
                        DownloadMetadataChip(fileExtension.uppercased())
                    }
                    Spacer()
                    if job.status.isActive, let speed = job.speed, speed != "NA" {
                        Text(speed)
                    }
                    if job.status.isActive, let eta = job.eta, eta != "NA" {
                        Text(L10n.text("eta", language, eta))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(
            isSelected ? Color.accentColor.opacity(0.08) : Color.clear,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .harborCard(cornerRadius: 16)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
        .shadow(color: .black.opacity(isSelected ? 0.1 : 0.035), radius: isSelected ? 9 : 3, y: 2)
        .animation(.easeOut(duration: 0.16), value: isSelected)
    }

    private var normalizedProgress: Double {
        if job.status == .completed { return 1 }
        return min(max(job.progress, 0), 1)
    }
}

struct DownloadStatusBadge: View {
    let status: DownloadStatus
    @Environment(\.appLanguage) private var language

    private var color: Color {
        switch status {
        case .completed: .green
        case .failed: .red
        case .cancelled: .secondary
        case .queued: .orange
        default: .blue
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(status.localizedTitle(language))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}

struct DownloadMetadataChip: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.monospaced().weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

extension DownloadJob {
    var displaySourceName: String {
        let normalized = sourceName.lowercased()
        if normalized.contains("bilibili") { return "Bilibili" }
        if normalized.contains("youtube") { return "YouTube" }
        return sourceName
    }

    var outputFileExtension: String? {
        guard let outputPath else { return nil }
        let value = URL(fileURLWithPath: outputPath).pathExtension
        return value.isEmpty ? nil : value
    }
}
