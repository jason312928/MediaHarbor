import SwiftUI

struct ContentView: View {
    let store: DownloadStore
    @Environment(\.appLanguage) private var language
    @Environment(\.scenePhase) private var scenePhase
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
                    case .favorites: FavoritesView(store: store)
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

                    Button(action: toggleTrailingPanel) {
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
                if store.selection == .discover, isPresented, !isExpandingWindow,
                   WindowSizing.needsExpansion(windowReference.window, sidebar: isSidebarVisible, inspector: true) {
                    store.showInspector = false
                    presentTrailingPanel()
                }
            }
            .onChange(of: store.showDetailPanel) { _, isPresented in
                if store.selection != .discover, isPresented, !isExpandingWindow,
                   WindowSizing.needsExpansion(windowReference.window, sidebar: isSidebarVisible, inspector: true) {
                    store.showDetailPanel = false
                    presentTrailingPanel()
                }
            }
            .onChange(of: store.selection) { _, _ in applyPanelConstraints(for: geometry.size.width) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    store.resumeAfterBrowserLogin()
                    store.refreshOutputAvailability()
                }
            }
            .alert("MediaHarbor", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.dismissError() } }
            )) {
                if let recovery = store.loginRecovery {
                    Button(L10n.text("open_browser_login", language, recovery.browserName)) {
                        store.openBrowserLogin()
                    }
                }
                Button(
                    L10n.text(store.loginRecovery == nil ? "ok" : "cancel", language),
                    role: .cancel
                ) { store.dismissError() }
            } message: {
                if let recovery = store.loginRecovery {
                    Text("\(store.errorMessage ?? L10n.text("unknown_error", language))\n\n\(L10n.text("browser_login_help", language, recovery.browserName))")
                } else {
                    Text(store.errorMessage ?? L10n.text("unknown_error", language))
                }
            }
        }
    }

    private var isSidebarVisible: Bool { columnVisibility != .detailOnly }
    private var isTrailingPanelVisible: Bool {
        store.selection == .discover ? store.showInspector : store.showDetailPanel
    }

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
                        inspector: isTrailingPanelVisible,
                        anchor: .trailingEdge
                    ) {
                        columnVisibility = requestedVisibility
                    }
                }
            }
        )
    }

    private func toggleTrailingPanel() {
        if isTrailingPanelVisible {
            setTrailingPanelVisible(false)
        } else {
            presentTrailingPanel()
        }
    }

    private func presentTrailingPanel() {
        expandWindow(sidebar: isSidebarVisible, inspector: true, anchor: .leadingEdge) {
            setTrailingPanelVisible(true)
        }
    }

    private func setTrailingPanelVisible(_ isVisible: Bool) {
        if store.selection == .discover {
            store.showInspector = isVisible
        } else {
            store.showDetailPanel = isVisible
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
        if isTrailingPanelVisible {
            let required = WindowSizing.requiredContentWidth(sidebar: isSidebarVisible, inspector: true)
            if width + 1 < required { setTrailingPanelVisible(false) }
        }
        if isSidebarVisible {
            let required = WindowSizing.requiredContentWidth(sidebar: true, inspector: isTrailingPanelVisible)
            if width + 1 < required { columnVisibility = .detailOnly }
        }
        if width < WindowSizing.detailWidth {
            columnVisibility = .detailOnly
            setTrailingPanelVisible(false)
        }
    }
}
