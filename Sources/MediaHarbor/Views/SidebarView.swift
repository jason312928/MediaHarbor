import SwiftUI

struct SidebarView: View {
    let store: DownloadStore
    @Environment(\.appLanguage) private var language

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
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
                                } else if destination == .favorites, !store.favorites.isEmpty {
                                    Text(store.favorites.count, format: .number)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }
                            }
                        } icon: {
                            Image(systemName: destination.symbol)
                        }
                        .tag(destination)

                        if destination == .favorites, store.selection == .favorites {
                            FavoriteSidebarRows(store: store)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            SettingsLink {
                Label(L10n.text("settings", language), systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
    }
}

private struct FavoriteSidebarRows: View {
    let store: DownloadStore
    @Environment(\.appLanguage) private var language

    var body: some View {
        favoriteRow(
            title: L10n.text("all_favorites", language),
            symbol: "star.fill",
            count: store.favorites.count,
            selection: .all
        )

        ForEach(store.favoriteCollections) { collection in
            favoriteRow(
                title: collection.name,
                symbol: "folder",
                count: store.favorites.filter { $0.collectionID == collection.id }.count,
                selection: .collection(collection.id)
            )
        }

        favoriteRow(
            title: L10n.text("ungrouped", language),
            symbol: "tray",
            count: store.favorites.filter { $0.collectionID == nil }.count,
            selection: .ungrouped
        )
    }

    private func favoriteRow(
        title: String,
        symbol: String,
        count: Int,
        selection: FavoriteCollectionSelection
    ) -> some View {
        let isSelected = store.favoriteCollectionSelection == selection
        return Button {
            store.selection = .favorites
            store.favoriteCollectionSelection = selection
        } label: {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .frame(width: 15)
                Text(title)
                    .lineLimit(1)
                Spacer()
                Text(count, format: .number)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .font(.callout.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 3, leading: 36, bottom: 3, trailing: 12))
        .accessibilityLabel("\(title), \(count)")
    }
}
