import SwiftUI

struct MediaSettingsView: View {
    @Environment(\.appLanguage) private var language
    @AppStorage("embedSubtitles") private var embedSubtitles = false
    @AppStorage("subtitleLanguages") private var subtitleLanguages = "en,zh-Hans,zh-Hant"
    @AppStorage("sponsorBlock") private var sponsorBlock = false

    var body: some View {
        Form {
            Section(L10n.text("subtitles", language)) {
                Toggle(L10n.text("download_embed_subtitles", language), isOn: $embedSubtitles)
                TextField(L10n.text("languages", language), text: $subtitleLanguages)
                    .disabled(!embedSubtitles)
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
}
