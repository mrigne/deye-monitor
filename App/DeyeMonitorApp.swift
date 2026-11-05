import SwiftUI

@main
struct DeyeMonitorApp: App {
    @StateObject private var store = MonitorStore()

    init() { ScreenshotMode.runIfRequested() }

    var body: some Scene {
        MenuBarExtra {
            MonitorMenuView()
                .environmentObject(store)
        } label: {
            Image(nsImage: store.menuBarImage)
        }
        .menuBarExtraStyle(.window)

        Window("\(AppInfo.name) Parameters", id: "parameters") {
            ParametersView()
                .environmentObject(store)
        }
        .defaultSize(width: 560, height: 620)
    }
}
