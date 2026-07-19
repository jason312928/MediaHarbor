import SwiftUI

struct SettingsView: View {
    let store: DownloadStore
    @Environment(\.appLanguage) private var language

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label(L10n.text("general", language), systemImage: "gearshape") }

            MediaSettingsView()
                .tabItem { Label(L10n.text("media", language), systemImage: "slider.horizontal.3") }

            EngineSettingsView(store: store)
                .tabItem { Label(L10n.text("engine", language), systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 580, height: 430)
        .scenePadding()
    }
}
