import SwiftUI

@main
struct DeyeMonitorApp: App {
    @StateObject private var store = MonitorStore()

    var body: some Scene {
        MenuBarExtra {
            MonitorMenuView()
                .environmentObject(store)
        } label: {
            Image(nsImage: store.menuBarImage)
        }
        .menuBarExtraStyle(.window)

        Window("Deye Monitor Parameters", id: "parameters") {
            ParametersView()
                .environmentObject(store)
        }
        .defaultSize(width: 560, height: 620)
    }
}
