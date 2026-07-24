import SwiftUI

struct DownloadInspector: View {
    let store: DownloadStore
    @Environment(\.appLanguage) private var language
    @AppStorage("embedMetadata") private var embedMetadata = true
    @AppStorage("embedSubtitles") private var embedSubtitles = false
    @AppStorage("downloadSubtitles") private var downloadSubtitles = false
    @AppStorage("includeAutomaticSubtitles") private var includeAutomaticSubtitles = true
    @AppStorage("subtitleLanguages") private var subtitleLanguages = "en,zh-Hans,zh-Hant"
    @AppStorage("subtitleFormat") private var subtitleFormat = "srt"
    @AppStorage("sponsorBlock") private var sponsorBlock = false
    @AppStorage("includePlaylist") private var includePlaylist = false

    var body: some View {
        Form {
            Section(L10n.text("download_options", language)) {
                Toggle(L10n.text("embed_metadata", language), isOn: $embedMetadata)
                Toggle(L10n.text("download_subtitles", language), isOn: $downloadSubtitles)
                Toggle(L10n.text("embed_subtitles", language), isOn: $embedSubtitles)
                Toggle(L10n.text("remove_sponsor", language), isOn: $sponsorBlock)
                Toggle(L10n.text("full_playlist", language), isOn: $includePlaylist)
            }

            if downloadSubtitles || embedSubtitles {
                Section(L10n.text("subtitle_options", language)) {
                    TextField(L10n.text("languages", language), text: $subtitleLanguages)
                    if let media = store.media, !media.subtitleLanguages.isEmpty {
                        Menu(L10n.text("available_languages", language, media.subtitleLanguages.count)) {
                            Button(L10n.text("all_languages", language)) { subtitleLanguages = "all,-live_chat" }
                            Divider()
                            ForEach(media.subtitleLanguages, id: \.self) { code in
                                Button(code) { subtitleLanguages = code }
                            }
                        }
                    }
                    Picker(L10n.text("subtitle_format", language), selection: $subtitleFormat) {
                        Text("SRT").tag("srt")
                        Text("WebVTT").tag("vtt")
                        Text("ASS").tag("ass")
                        Text(L10n.text("word_rtf", language)).tag("rtf")
                        Text(L10n.text("original_best", language)).tag("best")
                    }
                    Toggle(L10n.text("automatic_subtitles", language), isOn: $includeAutomaticSubtitles)
                }
            }

            if let media = store.media {
                Section(L10n.text("media", language)) {
                    LabeledContent(L10n.text("website", language), value: media.sourceName)
                    LabeledContent(L10n.text("duration", language), value: MediaFormatters.duration(media.duration, language: language))
                    LabeledContent(L10n.text("formats", language), value: media.formats.count.formatted())
                    LabeledContent(L10n.text("subtitle_languages", language), value: media.subtitleLanguages.count.formatted())
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
