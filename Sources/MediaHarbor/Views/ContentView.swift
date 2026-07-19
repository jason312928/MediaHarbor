import SwiftUI

struct ContentView: View {
    let store: DownloadStore
    @Environment(\.appLanguage) private var language
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        @Bindable var store = store
        GeometryReader { geometry in
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(store: store)
                    .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 250)
            } detail: {
                Group {
                    switch store.selection {
                    case .discover: DiscoverView(store: store)
                    case .queue: DownloadsView(store: store)
                    case .history: HistoryView(store: store)
                    }
                }
                .navigationTitle(store.selection.localizedTitle(language))
            }
            .navigationSplitViewStyle(.balanced)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { store.pasteAndAnalyze() } label: {
                        Label(L10n.text("paste_url", language), systemImage: "doc.on.clipboard")
                    }
                    .help(L10n.text("paste_help", language))

                    Button { store.showInspector.toggle() } label: {
                        Label(L10n.text("inspector", language), systemImage: "sidebar.trailing")
                    }
                    .help(L10n.text("inspector_help", language))
                }
            }
            .onAppear { applyCompactLayout(for: geometry.size.width) }
            .onChange(of: geometry.size.width) { _, width in
                applyCompactLayout(for: width)
            }
            .alert("MediaHarbor", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )) {
                Button(L10n.text("ok", language), role: .cancel) { store.errorMessage = nil }
            } message: {
                Text(store.errorMessage ?? L10n.text("unknown_error", language))
            }
        }
    }

    private func applyCompactLayout(for width: CGFloat) {
        if width < 860 {
            if columnVisibility == .all {
                columnVisibility = .detailOnly
            }
            if store.showInspector {
                store.showInspector = false
            }
        }
    }
}
