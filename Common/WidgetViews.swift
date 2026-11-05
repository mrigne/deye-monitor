import WidgetKit
import SwiftUI

struct DeyeEntry: TimelineEntry {
    let date: Date
    let summary: DeyeSummary?
    let error: String?
}

// MARK: Views

struct DeyeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DeyeEntry
    /// Shown under an error, e.g. how to fix the configuration.
    var hint: String = ""

    var body: some View {
        Group {
            if let s = entry.summary {
                switch family {
                case .systemSmall: SmallView(s: s, date: entry.date)
                default: MediumView(s: s, date: entry.date)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle").font(.title2).foregroundStyle(.orange)
                    Text(entry.error ?? "No data").font(.caption).multilineTextAlignment(.center)
                    Text(hint)
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct GridBadge: View {
    let s: DeyeSummary
    var body: some View {
        let online = s.gridOnline ?? true
        Image(systemName: online ? "bolt.fill" : "bolt.slash.fill")
            .foregroundStyle(online ? .green : .red)
    }
}

private struct SocRing: View {
    let soc: Double
    var body: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: 6)
            Circle()
                .trim(from: 0, to: min(1, max(0, soc / 100)))
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(Fmt.percent(soc)).font(.system(.callout, design: .rounded).weight(.semibold))
        }
    }
    private var color: Color { soc < 20 ? .red : soc < 50 ? .orange : .green }
}

private struct Metric: View {
    let symbol: String
    let color: Color
    let value: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 14)
            Text(value).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .font(.callout)
    }
}

private func updatedText(_ s: DeyeSummary, _ fetched: Date) -> Text {
    // Inverter reading time = fetch time - age reported by the server.
    let readAt = fetched.addingTimeInterval(-Double(s.ageSeconds ?? 0))
    return Text(readAt, style: .time)
}

private func gridValue(_ s: DeyeSummary) -> String {
    if s.gridOnline == false { return "Off" }
    guard let p = s.gridPower, abs(p) >= 1 else { return "0 W" }
    return (p > 0 ? "↓ " : "↑ ") + Fmt.power(p)
}

struct SmallView: View {
    let s: DeyeSummary
    let date: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let soc = s.batterySoc {
                    SocRing(soc: soc).frame(width: 52, height: 52)
                } else {
                    Image(systemName: "sun.max.fill").font(.largeTitle).foregroundStyle(.yellow)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    GridBadge(s: s).font(.title3)
                    if s.pollError != nil {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                }
            }
            Metric(symbol: "sun.max.fill", color: .yellow, value: Fmt.power(s.pvPower))
            Metric(symbol: "house.fill", color: .blue, value: Fmt.power(s.loadPower))
            updatedText(s, date).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct MediumView: View {
    let s: DeyeSummary
    let date: Date
    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 6) {
                if let soc = s.batterySoc {
                    SocRing(soc: soc).frame(width: 64, height: 64)
                    Text(s.batteryStatus ?? "").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Image(systemName: "sun.max.fill").font(.largeTitle).foregroundStyle(.yellow)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Metric(symbol: "sun.max.fill", color: .yellow, value: Fmt.power(s.pvPower))
                    Spacer()
                    GridBadge(s: s)
                }
                Metric(symbol: "house.fill", color: .blue, value: Fmt.power(s.loadPower))
                Metric(symbol: "powerplug.fill", color: .orange, value: gridValue(s))
                if let line = Fmt.outageLine(s.outage) {
                    Text(line).font(.caption2)
                        .foregroundStyle(s.outage?.status == "active" ? .red : .secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Text("Today \(String(format: "%.1f", s.todayPvKwh ?? 0)) kWh ·")
                    updatedText(s, date)
                    if s.pollError != nil {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

