import WidgetKit
import SwiftUI
import AppIntents

/// iOS widget: reads the inverter itself when the phone is on the home Wi-Fi
/// (using the address the app saved in the App Group), and otherwise falls
/// back to the last reading the app or widget stored.
struct LiveProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeyeEntry {
        DeyeEntry(date: .now, summary: .preview, error: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DeyeEntry) -> Void) {
        if context.isPreview { return completion(placeholder(in: context)) }
        DispatchQueue.global(qos: .userInitiated).async { completion(Self.load()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeyeEntry>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let entry = Self.load()
            // iOS budgets widget refreshes (~every 15 min at best).
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    static func load() -> DeyeEntry {
        var liveError: String?
        let ip = SharedSettings.inverterIP
        if !ip.isEmpty, let serial = SharedSettings.loggerSerial {
            let reader = DeyeReader(host: ip, loggerSerial: serial, timeout: 4)
            let phases = SharedSettings.forcedPhases ?? SharedSettings.cachedPhases(ip: ip, serial: serial) ?? reader.detectPhases()
            do {
                let r = try reader.read(phases: phases)
                var s = r.summary
                s.ageSeconds = 0
                let old = SnapshotFile.read()
                SnapshotFile.write(DeyeSnapshot(summary: s, readAt: .now, error: nil,
                                                pollInterval: old?.pollInterval ?? 30, writtenAt: .now,
                                                registers: r.raw, phases: r.phases))
                return DeyeEntry(date: .now, summary: s, error: nil, registers: r.raw, phases: r.phases)
            } catch {
                liveError = "Not reachable — on home Wi-Fi?"
            }
        } else {
            liveError = "Not set up"
        }

        // Fall back to the last reading the app (or this widget) saved.
        guard let snap = SnapshotFile.read(), var s = snap.summary else {
            return DeyeEntry(date: .now, summary: nil, error: liveError ?? "No data yet")
        }
        if let t = snap.readAt { s.ageSeconds = Int(Date().timeIntervalSince(t)) }
        s.pollError = liveError
        return DeyeEntry(date: .now, summary: s, error: nil, registers: snap.registers ?? [:], phases: snap.phases ?? 1)
    }
}

/// Tap ↻ on the widget: the system re-runs the timeline (a fresh read) after this returns.
struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Deye Monitor"
    func perform() async throws -> some IntentResult { .result() }
}

struct HomeWidgetView: View {
    let entry: DeyeEntry
    var body: some View {
        DeyeWidgetView(entry: entry, hint: "Open Deye Monitor and set the inverter IP and logger SN")
            .overlay(alignment: .bottomTrailing) {
                if entry.summary != nil {
                    Button(intent: RefreshIntent()) {
                    Image(systemName: "arrow.clockwise").font(.caption2)
                }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .offset(x: 4, y: 4)
                }
            }
    }
}

struct DeyeHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DeyeMonitorWidget", provider: LiveProvider()) { HomeWidgetView(entry: $0) }
            .configurationDisplayName("Deye Monitor")
            .description("Solar, battery, load and grid from your inverter.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: Lock Screen

struct LockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DeyeEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryInline: inline
            default: rectangular
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private var circular: some View {
        let soc = entry.summary?.batterySoc ?? 0
        return Gauge(value: soc, in: 0...100) {
            Image(systemName: entry.summary?.gridOnline == false ? "bolt.slash.fill" : "bolt.fill")
        } currentValueLabel: {
            Text(entry.summary?.batterySoc.map { String(format: "%.0f", $0) } ?? "—")
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var inline: some View {
        let s = entry.summary
        return Text("☀︎ \(Fmt.powerShort(s?.pvPower))  🔋\(Fmt.percent(s?.batterySoc))  \(s?.gridOnline == false ? "⚡︎off" : "")")
    }

    private var rectangular: some View {
        let ids = Array(SharedSettings.defaults.stringArray(forKey: "MenuBarParams")?.prefix(3) ?? [])
        let params = ids.compactMap { ParamCatalog.find($0, phases: entry.phases) }
        return VStack(alignment: .leading, spacing: 1) {
            if entry.summary == nil || entry.registers.isEmpty {
                Text(entry.error ?? "No data").font(.caption)
            } else {
                ForEach(params) { p in
                    let v = p.value(entry.registers)
                    HStack(spacing: 4) {
                        if p.kind == .gridOnline {
                            PlugIcon(online: (v ?? 1) > 0).frame(width: 16)
                            Text((v ?? 1) > 0 ? "Grid on" : "Grid off")
                        } else {
                            Image(systemName: p.id == "battery_soc" ? Fmt.batterySymbol(v) : p.symbol).frame(width: 16)
                            Text(p.short(v)).monospacedDigit()
                        }
                    }
                }
            }
        }
        .font(.system(.body, design: .rounded).weight(.medium))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DeyeLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DeyeMonitorLock", provider: LiveProvider()) { LockWidgetView(entry: $0) }
            .configurationDisplayName("Deye Monitor")
            .description("Battery and grid at a glance. Pick the rectangular widget's values in the app.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct DeyeIOSWidgets: WidgetBundle {
    var body: some Widget {
        DeyeHomeWidget()
        DeyeLockWidget()
    }
}
