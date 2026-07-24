import SwiftUI

struct MediaSettingsView: View {
    @Environment(\.appLanguage) private var language
    @AppStorage("embedSubtitles") private var embedSubtitles = false
    @AppStorage("downloadSubtitles") private var downloadSubtitles = false
    @AppStorage("includeAutomaticSubtitles") private var includeAutomaticSubtitles = true
    @AppStorage("subtitleLanguages") private var subtitleLanguages = "en,zh-Hans,zh-Hant"
    @AppStorage("subtitleFormat") private var subtitleFormat = "srt"
    @AppStorage("sponsorBlock") private var sponsorBlock = false

    var body: some View {
        Form {
            Section(L10n.text("subtitles", language)) {
                Toggle(L10n.text("download_subtitles", language), isOn: $downloadSubtitles)
                Toggle(L10n.text("embed_subtitles", language), isOn: $embedSubtitles)
                Toggle(L10n.text("automatic_subtitles", language), isOn: $includeAutomaticSubtitles)
                    .disabled(!subtitlesEnabled)
                TextField(L10n.text("languages", language), text: $subtitleLanguages)
                    .disabled(!subtitlesEnabled)
                Picker(L10n.text("subtitle_format", language), selection: $subtitleFormat) {
                    Text("SRT").tag("srt")
                    Text("WebVTT").tag("vtt")
                    Text("ASS").tag("ass")
                    Text(L10n.text("word_rtf", language)).tag("rtf")
                    Text(L10n.text("original_best", language)).tag("best")
                }
                .disabled(!subtitlesEnabled)
                Text(L10n.text("language_selector_help", language))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L10n.text("post_processing", language)) {
                Toggle(L10n.text("remove_sponsor", language), isOn: $sponsorBlock)
                Text(L10n.text("sponsor_help", language))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var subtitlesEnabled: Bool { downloadSubtitles || embedSubtitles }
}
