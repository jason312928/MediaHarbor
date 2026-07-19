import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @Environment(\.appLanguage) private var language
    @AppStorage("appLanguage") private var languageCode = AppLanguage.system.rawValue
    @AppStorage("outputDirectory") private var outputDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].path
    @AppStorage("embedMetadata") private var embedMetadata = true
    @AppStorage("includePlaylist") private var includePlaylist = false

    var body: some View {
        Form {
            Section(L10n.text("save_to", language)) {
                HStack {
                    Image(systemName: "folder.fill").foregroundStyle(.blue)
                    Text(outputDirectory).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button(L10n.text("choose", language), action: chooseDirectory)
                }
            }
            Section(L10n.text("app_language", language)) {
                Picker(L10n.text("app_language", language), selection: $languageCode) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.nativeName).tag(option.rawValue)
                    }
                }
                .labelsHidden()
            }
            Section(L10n.text("defaults", language)) {
                Toggle(L10n.text("embed_metadata_thumbnail", language), isOn: $embedMetadata)
                Toggle(L10n.text("full_playlist_default", language), isOn: $includePlaylist)
            }
        }
        .formStyle(.grouped)
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.title = L10n.text("save_to", language)
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: outputDirectory)
        if panel.runModal() == .OK, let url = panel.url { outputDirectory = url.path }
    }
}
