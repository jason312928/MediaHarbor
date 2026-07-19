import AppKit
import SwiftUI
import UserNotifications

@main
struct MediaHarborApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = DownloadStore()
    @AppStorage("appLanguage") private var languageCode = AppLanguage.system.rawValue

    private var language: AppLanguage { AppLanguage.resolved(languageCode) }

    var body: some Scene {
        WindowGroup("MediaHarbor", id: "main") {
            ContentView(store: store)
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
                .frame(minWidth: 680, minHeight: 520)
        }
        .defaultSize(width: 1160, height: 760)
        .windowResizability(.contentMinSize)
        .commands { HarborCommands(store: store, language: language) }

        Settings {
            SettingsView(store: store)
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
        }

        MenuBarExtra {
            MenuBarView(store: store, language: language)
        } label: {
            Label("MediaHarbor", systemImage: store.activeJobs.isEmpty ? "arrow.down.circle" : "arrow.down.circle.fill")
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--self-test") {
            let failures = SelfCheck.run()
            if failures.isEmpty {
                print("All MediaHarbor self-checks passed.")
                exit(EXIT_SUCCESS)
            }
            fputs("Self-check failures: \(failures.joined(separator: ", "))\n", stderr)
            exit(EXIT_FAILURE)
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

private struct HarborCommands: Commands {
    let store: DownloadStore
    let language: AppLanguage

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(L10n.text("paste_analyze", language)) { store.pasteAndAnalyze() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            Button(L10n.text("analyze_url", language)) { store.analyze() }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(store.urlText.isEmpty || store.isAnalyzing)
            Divider()
            Button(L10n.text("start_download", language)) { store.enqueueDownload() }
                .keyboardShortcut("d", modifiers: [.command])
                .disabled(store.media == nil || store.selectedQuality == nil)
        }

        CommandMenu(L10n.text("downloads", language)) {
            Button(L10n.text("show_downloads", language)) { store.selection = .queue }
                .keyboardShortcut("2", modifiers: [.command])
            Button(L10n.text("clear_finished", language)) { store.clearCompleted() }
                .disabled(store.jobs.isEmpty)
            Button(L10n.text("toggle_inspector", language)) { store.showInspector.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .option])
        }
    }
}

private struct MenuBarView: View {
    let store: DownloadStore
    let language: AppLanguage
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if store.activeJobs.isEmpty {
            Text(L10n.text("no_active_downloads", language))
        } else {
            ForEach(store.activeJobs.prefix(4)) { job in
                Button {
                    store.selection = .queue
                    store.selectedJobID = job.id
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Text("\(job.title.prefix(24)) · \(Int(job.progress * 100))%")
                }
            }
        }
        Divider()
        Button(L10n.text("open_app", language)) {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button(L10n.text("quit", language)) { NSApp.terminate(nil) }
    }
}
