import SwiftUI

struct SidebarView: View {
    let store: DownloadStore
    @Environment(\.appLanguage) private var language

    var body: some View {
        @Bindable var store = store
        List(selection: $store.selection) {
            Section(L10n.text("library", language)) {
                ForEach(SidebarDestination.allCases) { destination in
                    Label {
                        HStack {
                            Text(destination.localizedTitle(language))
                            Spacer()
                            if destination == .queue, !store.activeJobs.isEmpty {
                                Text(store.activeJobs.count, format: .number)
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.blue, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                    } icon: {
                        Image(systemName: destination.symbol)
                    }
                    .tag(destination)
                }
            }
        }
        .listStyle(.sidebar)
    }
}
