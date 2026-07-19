import SwiftUI

struct MediaPreview: View {
    let store: DownloadStore
    let media: MediaInfo
    @Environment(\.appLanguage) private var language

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 20) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    thumbnail.frame(width: 260, height: 146)
                    metadata
                }
                VStack(alignment: .leading, spacing: 16) {
                    thumbnail.aspectRatio(16 / 9, contentMode: .fit)
                    metadata
                }
            }

            Divider()

            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(L10n.text("choose_format", language)).font(.headline)
                    Spacer()
                    Text(L10n.text("merge_automatically", language)).font(.caption).foregroundStyle(.tertiary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("choose_format", language)).font(.headline)
                    Text(L10n.text("merge_automatically", language)).font(.caption).foregroundStyle(.tertiary)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                ForEach(media.qualityChoices) { quality in
                    QualityButton(quality: quality, isSelected: store.selectedQuality == quality) {
                        store.selectedQuality = quality
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack {
                    readyLabel
                    Spacer()
                    addButton
                }
                VStack(alignment: .leading, spacing: 12) {
                    readyLabel
                    addButton.frame(maxWidth: .infinity)
                }
            }
        }
        .padding(22)
        .harborCard(cornerRadius: 24)
    }

    private var thumbnail: some View {
        AsyncImage(url: media.thumbnail.flatMap(URL.init(string:))) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                Rectangle().fill(.quaternary)
                Image(systemName: "play.rectangle.fill").font(.largeTitle).foregroundStyle(.tertiary)
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(media.sourceName.uppercased())
                .font(.caption.weight(.bold)).tracking(1).foregroundStyle(.blue)
            Text(media.title).font(.title2.bold()).lineLimit(3)
            if let uploader = media.uploader { Text(uploader).foregroundStyle(.secondary) }
            HStack(spacing: 14) {
                Label(MediaFormatters.duration(media.duration, language: language), systemImage: "clock")
                if let views = MediaFormatters.count(media.viewCount) {
                    Label(L10n.text("views", language, views), systemImage: "eye")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var readyLabel: some View {
        Label(L10n.text("ready_for", language, media.sourceName), systemImage: "checkmark.circle.fill")
            .font(.callout).foregroundStyle(.green)
    }

    private var addButton: some View {
        Button(L10n.text("add_downloads", language), systemImage: "arrow.down.circle.fill") { store.enqueueDownload() }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
    }
}

private struct QualityButton: View {
    let quality: QualityChoice
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.appLanguage) private var language

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: quality.symbol)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(quality.localizedTitle(language)).fontWeight(.semibold)
                    Text(quality.localizedDetail(language)).font(.caption).opacity(0.72)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? AnyShapeStyle(.blue.gradient) : AnyShapeStyle(.quaternary.opacity(0.45)), in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
