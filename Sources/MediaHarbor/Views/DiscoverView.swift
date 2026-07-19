import SwiftUI

struct DiscoverView: View {
    let store: DownloadStore

    var body: some View {
        @Bindable var store = store
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: geometry.size.width < 600 ? 14 : 22) {
                    URLComposer(store: store)

                    if store.toolVersion == nil {
                        ToolWelcomeCard(store: store)
                    } else if store.isAnalyzing {
                        AnalysisPlaceholder()
                    } else if let media = store.media {
                        MediaPreview(store: store, media: media)
                    } else {
                        EmptyDiscoverState()
                    }
                }
                .frame(maxWidth: 920)
                .padding(geometry.size.width < 600 ? 14 : 28)
                .frame(maxWidth: .infinity)
            }
        }
        .dropDestination(for: String.self) { values, _ in
            guard let first = values.first else { return false }
            store.acceptDroppedText(first)
            return true
        }
        .inspector(isPresented: $store.showInspector) {
            DownloadInspector(store: store)
                .inspectorColumnWidth(min: 230, ideal: 270, max: 320)
        }
    }
}

private struct ToolWelcomeCard: View {
    let store: DownloadStore
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox.and.arrow.backward.fill")
                .font(.system(size: 42))
                .foregroundStyle(.blue)
            Text(L10n.text("install_engine", language)).font(.title2.bold())
            Text(L10n.text("install_engine_desc", language))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)
            Button(store.isInstallingTool ? L10n.text("installing", language) : L10n.text("install_ytdlp", language)) {
                store.installTool()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.isInstallingTool)
            Link(L10n.text("view_github", language), destination: URL(string: "https://github.com/yt-dlp/yt-dlp")!)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(34)
        .harborCard()
    }
}

private struct AnalysisPlaceholder: View {
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            Text(L10n.text("reading_media", language)).font(.headline)
            Text(L10n.text("sites_longer", language)).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .harborCard()
    }
}

private struct EmptyDiscoverState: View {
    @Environment(\.appLanguage) private var language

    var body: some View {
        ContentUnavailableView {
            Label(L10n.text("ready_link", language), systemImage: "arrow.down.app.dashed")
        } description: {
            Text(L10n.text("drag_link", language))
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}
