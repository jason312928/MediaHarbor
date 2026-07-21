import SwiftUI

struct EngineSettingsView: View {
    let store: DownloadStore
    @Environment(\.appLanguage) private var language
    @AppStorage("browserCookies") private var browserCookies = "None"

    var body: some View {
        Form {
            Section(L10n.text("browser_cookies", language)) {
                Picker(L10n.text("read_cookies", language), selection: $browserCookies) {
                    Text(L10n.text("none", language)).tag("None")
                    ForEach(["Safari", "Chrome", "Firefox", "Edge", "Brave", "Chromium", "Opera", "Vivaldi", "Whale"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
                Text(L10n.text("cookies_help", language))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L10n.text("download_engine", language)) {
                LabeledContent(L10n.text("installed_version", language), value: store.toolVersion ?? L10n.text("not_installed", language))
                Button(store.isInstallingTool ? L10n.text("updating", language) : L10n.text("update_ytdlp", language)) { store.installTool() }
                    .disabled(store.isInstallingTool)
                Link(L10n.text("supported_sites", language), destination: URL(string: "https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md")!)
            }
        }
        .formStyle(.grouped)
    }
}
