import SwiftUI

struct DownloadInspector: View {
    let store: DownloadStore
    @Environment(\.appLanguage) private var language
    @AppStorage("embedMetadata") private var embedMetadata = true
    @AppStorage("embedSubtitles") private var embedSubtitles = false
    @AppStorage("sponsorBlock") private var sponsorBlock = false
    @AppStorage("includePlaylist") private var includePlaylist = false

    var body: some View {
        Form {
            Section(L10n.text("download_options", language)) {
                Toggle(L10n.text("embed_metadata", language), isOn: $embedMetadata)
                Toggle(L10n.text("embed_subtitles", language), isOn: $embedSubtitles)
                Toggle(L10n.text("remove_sponsor", language), isOn: $sponsorBlock)
                Toggle(L10n.text("full_playlist", language), isOn: $includePlaylist)
            }

            if let media = store.media {
                Section(L10n.text("media", language)) {
                    LabeledContent(L10n.text("website", language), value: media.sourceName)
                    LabeledContent(L10n.text("duration", language), value: MediaFormatters.duration(media.duration, language: language))
                    LabeledContent(L10n.text("formats", language), value: media.formats.count.formatted())
                    if let chapters = media.chapters, !chapters.isEmpty {
                        LabeledContent(L10n.text("chapters", language), value: chapters.count.formatted())
                    }
                }
            } else {
                Section {
                    Text(L10n.text("analyze_inspect", language))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
