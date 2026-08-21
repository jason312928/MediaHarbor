import SwiftUI

struct FavoritesView: View {
    let store: DownloadStore

    var body: some View {
        LibraryBrowserView(store: store, mode: .favorites)
    }
}
