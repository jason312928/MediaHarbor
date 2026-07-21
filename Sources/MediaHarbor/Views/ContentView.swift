import SwiftUI

struct ContentView: View {
    let store: DownloadStore
    @Environment(\.appLanguage) private var language
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var windowReference = WeakWindowReference()
    @State private var isExpandingWindow = false

    var body: some View {
        @Bindable var store = store
        GeometryReader { geometry in
            NavigationSplitView(columnVisibility: columnVisibilityBinding) {
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

                    Button {
                        if store.showInspector {
                            store.showInspector = false
                        } else {
                            presentInspector()
                        }
                    } label: {
                        Label(L10n.text("inspector", language), systemImage: "sidebar.trailing")
                    }
                    .help(L10n.text("inspector_help", language))
                }
            }
            .background(WindowAccessor(reference: windowReference).frame(width: 0, height: 0))
            .onAppear { applyPanelConstraints(for: geometry.size.width) }
            .onChange(of: geometry.size.width) { _, width in
                applyPanelConstraints(for: width)
            }
            .onChange(of: store.showInspector) { _, isPresented in
                if isPresented, !isExpandingWindow,
                   WindowSizing.needsExpansion(windowReference.window, sidebar: isSidebarVisible, inspector: true) {
                    store.showInspector = false
                    presentInspector()
                }
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

    private var isSidebarVisible: Bool { columnVisibility != .detailOnly }

    private var columnVisibilityBinding: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { columnVisibility },
            set: { requestedVisibility in
                guard requestedVisibility != columnVisibility else { return }
                if requestedVisibility == .detailOnly {
                    columnVisibility = .detailOnly
                } else {
                    expandWindow(
                        sidebar: true,
                        inspector: store.showInspector,
                        anchor: .trailingEdge
                    ) {
                        columnVisibility = requestedVisibility
                    }
                }
            }
        )
    }

    private func presentInspector() {
        expandWindow(sidebar: isSidebarVisible, inspector: true, anchor: .leadingEdge) {
            store.showInspector = true
        }
    }

    private func expandWindow(
        sidebar: Bool,
        inspector: Bool,
        anchor: WindowSizing.ExpansionAnchor,
        completion: @escaping () -> Void
    ) {
        guard !isExpandingWindow else { return }
        isExpandingWindow = true
        WindowSizing.expandIfNeeded(
            windowReference.window,
            sidebar: sidebar,
            inspector: inspector,
            anchor: anchor
        ) {
            isExpandingWindow = false
            completion()
        }
    }

    private func applyPanelConstraints(for width: CGFloat) {
        guard !isExpandingWindow else { return }
        if store.showInspector {
            let required = WindowSizing.requiredContentWidth(sidebar: isSidebarVisible, inspector: true)
            if width + 1 < required { store.showInspector = false }
        }
        if isSidebarVisible {
            let required = WindowSizing.requiredContentWidth(sidebar: true, inspector: store.showInspector)
            if width + 1 < required { columnVisibility = .detailOnly }
        }
        if width < WindowSizing.detailWidth {
            columnVisibility = .detailOnly
            store.showInspector = false
        }
    }
}
