import SwiftUI

struct HistoryView: View {
    let store: DownloadStore

    var body: some View {
        LibraryBrowserView(store: store, mode: .history)
    }
}
