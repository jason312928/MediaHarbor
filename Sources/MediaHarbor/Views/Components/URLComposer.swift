import SwiftUI

struct URLComposer: View {
    let store: DownloadStore
    @Environment(\.appLanguage) private var language
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    title
                    Spacer()
                    sailboat
                }
                title
            }

            ViewThatFits(in: .horizontal) {
                inputRow(compact: false)
                inputRow(compact: true)
            }

            popularSites
        }
        .padding(22)
        .harborCard(cornerRadius: 24)
        .onAppear { if store.urlText.isEmpty { isFocused = true } }
    }

    private var popularSites: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("popular_sites", language))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SupportedPlatform.popular) { platform in
                        Label(platform.name, systemImage: platform.symbol)
                            .font(.caption)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(.quaternary.opacity(0.55), in: Capsule())
                    }
                }
            }
        }
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.text("bring_media", language))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(L10n.text("paste_supported", language))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sailboat: some View {
        Image(systemName: "sailboat.fill")
            .font(.system(size: 30))
            .foregroundStyle(.blue.gradient)
    }

    @ViewBuilder
    private func inputRow(compact: Bool) -> some View {
        @Bindable var store = store
        let field = HStack(spacing: 10) {
            Image(systemName: "link").foregroundStyle(.secondary)
            TextField("https://…", text: $store.urlText)
                .textFieldStyle(.plain)
                .font(.body.monospaced())
                .focused($isFocused)
                .onSubmit { store.analyze() }
            if !store.urlText.isEmpty {
                Button { store.urlText = ""; store.media = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }

        Group {
            if compact {
                VStack(spacing: 10) {
                    field
                    analyzeButton.frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: 10) {
                    field
                    analyzeButton
                }
            }
        }
        .padding(13)
        .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 13))
        .overlay { RoundedRectangle(cornerRadius: 13).stroke(.separator.opacity(0.5)) }
    }

    private var analyzeButton: some View {
        Button(L10n.text("analyze", language), systemImage: "sparkle.magnifyingglass") { store.analyze() }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.urlText.isEmpty || store.isAnalyzing || store.toolVersion == nil)
    }
}
