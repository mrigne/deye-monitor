import WidgetKit
import SwiftUI

/// Shows what the Deye Monitor app last read from the inverter. The widget
/// itself never touches the network (macOS blocks widgets from the LAN);
/// it reads the snapshot file the app keeps up to date.
struct MonitorProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeyeEntry {
        DeyeEntry(date: .now, summary: .preview, error: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DeyeEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeyeEntry>) -> Void) {
        // Reading a local file is cheap; the app also reloads the widget when
        // values change. macOS still decides the actual refresh cadence.
        let next = Calendar.current.date(byAdding: .minute, value: 2, to: .now)!
        completion(Timeline(entries: [load()], policy: .after(next)))
    }

    private func load() -> DeyeEntry {
        guard let snap = SnapshotFile.read() else {
            return DeyeEntry(date: .now, summary: nil, error: "No data yet")
        }
        guard var s = snap.summary else {
            return DeyeEntry(date: .now, summary: nil, error: snap.error ?? "No data yet")
        }
        if let t = snap.readAt { s.ageSeconds = Int(Date().timeIntervalSince(t)) }
        s.pollError = snap.error
        // App not running (or stuck): flag the data as stale.
        if Date().timeIntervalSince(snap.writtenAt) > Double(max(snap.pollInterval, 30) * 4 + 60) {
            s.pollError = "Deye Monitor is not running"
        }
        return DeyeEntry(date: .now, summary: s, error: nil)
    }
}

struct MonitorWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DeyeMonitorWidget", provider: MonitorProvider()) { entry in
            DeyeWidgetView(entry: entry, hint: "Open Deye Monitor in the menu bar and set the inverter IP and logger SN")
        }
        .configurationDisplayName("Deye Monitor")
        .description("Solar, battery, load and grid read directly from your inverter.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct MonitorWidgetBundle: WidgetBundle {
    var body: some Widget { MonitorWidget() }
}
