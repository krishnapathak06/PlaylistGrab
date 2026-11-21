import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationSplitView {
            List(selection: $state.section) {
                Label("New Download", systemImage: "plus.circle")
                    .tag(SidebarSection.new)

                Label("Downloads", systemImage: "arrow.down.circle")
                    .badge(state.activeCount)
                    .tag(SidebarSection.downloads)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            switch state.section ?? .new {
            case .new:
                NewDownloadView()
            case .downloads:
                DownloadsView()
            }
        }
    }
}
