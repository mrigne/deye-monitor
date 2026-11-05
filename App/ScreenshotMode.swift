import SwiftUI
import AppKit

/// `DeyeMonitor -demo -screenshots <dir>`: renders the panel, the parameters
/// window and the widgets with demo data into PNGs (for App Store
/// screenshots), then quits. Uses the app's own views, so no screen-recording
/// permission is needed.
@MainActor
enum ScreenshotMode {
    static func runIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screenshots"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { Task { await render(to: dir) } }
    }

    private static var windows: [NSWindow] = []

    private static func render(to dir: URL) async {
        NSApp.appearance = NSAppearance(named: .aqua)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = MonitorStore()
        store.demoMode = true
        await store.refreshNow()
        let s = store.currentSummary ?? .preview

        await snap(MonitorMenuView().environmentObject(store).padding(.bottom, 2), "mac-panel", dir)
        await snap(ParametersView().environmentObject(store).frame(width: 560, height: 620), "mac-parameters", dir)
        await snap(widget(SmallView(s: s, date: .now), width: 170), "mac-widget-small", dir)
        await snap(widget(MediumView(s: s, date: .now), width: 364), "mac-widget-medium", dir)
        if let tiff = store.menuBarImage.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("mac-menubar.png"))
        }
        store.demoMode = false   // don't leave demo mode switched on
        NSApp.terminate(nil)
    }

    private static func widget<V: View>(_ v: V, width: CGFloat) -> some View {
        v.padding(16)
            .frame(width: width, height: 170)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(white: 0.96)))
            .padding(1)
    }

    private static func snap<V: View>(_ view: V, _ name: String, _ dir: URL) async {
        let host = NSHostingView(rootView: view)
        host.frame.size = host.fittingSize
        let w = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        w.contentView = host
        w.backgroundColor = .windowBackgroundColor
        w.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))   // off-screen
        w.orderFrontRegardless()
        windows.append(w)
        try? await Task.sleep(nanoseconds: 600_000_000)       // let SwiftUI lay out
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(name).png"))
        w.orderOut(nil)
    }
}
