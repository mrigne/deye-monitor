import SwiftUI

@main
struct DeyeMonitorIOSApp: App {
    @StateObject private var store = MonitorStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            // iOS suspends the poll loop in the background; read as soon as we're back.
            if phase == .active { store.restart() }
        }
    }
}
