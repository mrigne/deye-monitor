import SwiftUI
import AppKit

struct MonitorMenuView: View {
    @EnvironmentObject var store: MonitorStore
    @Environment(\.openWindow) private var openWindow
    @State private var showSettings = false
    @State private var ipDraft = ""
    @State private var serialDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let s = store.summary {
                metrics(s)
                today(s)
                if !store.panelParams.isEmpty { pinnedView }
            } else {
                Text(store.lastError ?? (store.isReading ? "Reading inverter…" : "Connecting…"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
            if showSettings || !store.isConfigured { settings }
        }
        .padding(14)
        .frame(width: 310)
        .onAppear {
            ipDraft = store.inverterIP
            serialDraft = store.loggerSerial
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            if let s = store.summary {
                let online = s.gridOnline ?? true
                HStack(spacing: 6) {
                    PlugIcon(online: online)
                    Text(online ? "Grid on" : "Grid off")
                }
                .font(.headline)
                .foregroundStyle(online ? .green : .red)
                if let v = s.gridVoltage, online {
                    Text(String(format: "%.0f V", v)).foregroundStyle(.secondary)
                }
            } else {
                Label("Deye Monitor", systemImage: "sun.max.fill").font(.headline)
            }
            Spacer()
            Button {
                store.refresh()
            } label: {
                if store.isReading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .help("Read the inverter now")
            .disabled(store.isReading || !store.isConfigured)
        }
    }

    private func metrics(_ s: DeyeSummary) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
            row("sun.max.fill", .yellow, "Solar", Fmt.power(s.pvPower))
            row("house.fill", .blue, "Load", Fmt.power(s.loadPower))
            if s.batterySoc != nil {
                row(Fmt.batterySymbol(s.batterySoc), .green, "Battery",
                    "\(Fmt.percent(s.batterySoc)) · \(batteryDetail(s))")
            }
            row("powerplug.fill", .orange, "Grid", gridDetail(s))
        }
    }

    private func today(_ s: DeyeSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today, kWh").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                stat("PV", s.todayPvKwh)
                stat("Load", s.todayLoadKwh)
                stat("Import", s.todayImportKwh)
                stat("Export", s.todayExportKwh)
            }
        }
    }

    /// Parameters the user pinned to the panel (Choose parameters…).
    private var pinnedView: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 5) {
            ForEach(store.panelParams, id: \.self) { id in
                if let p = store.param(id) {
                    GridRow {
                        Image(systemName: p.symbol).foregroundStyle(.secondary).frame(width: 18)
                        Text(p.title).foregroundStyle(.secondary).lineLimit(1)
                        Text(p.display(store.value(p))).monospacedDigit()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .font(.callout)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                HStack(spacing: 4) {
                    if let err = store.lastError {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(store.lastRead == nil ? err : "\(err) · data \(Fmt.age(store.currentSummary?.ageSeconds))")
                            .lineLimit(3)
                    } else if store.lastRead != nil {
                        if store.isStale {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                        Text("Read \(Fmt.age(store.currentSummary?.ageSeconds)) · every \(store.pollSeconds)s"
                             + (store.phases.map { " · \($0)-phase" } ?? ""))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack {
                Button("Parameters…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "parameters")
                }
                Spacer()
                Button {
                    showSettings.toggle()
                } label: { Image(systemName: "gearshape") }
                .buttonStyle(.borderless)
                .help("Settings")
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow {
                    Text("Inverter IP").font(.caption).foregroundStyle(.secondary)
                    TextField("192.168.1.100", text: $ipDraft).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Logger SN").font(.caption).foregroundStyle(.secondary)
                    TextField("1234567890", text: $serialDraft).textFieldStyle(.roundedBorder)
                }
            }
            HStack {
                if !serialDraft.isEmpty && UInt32(serialDraft.trimmingCharacters(in: .whitespaces)) == nil {
                    Text("SN must be digits").font(.caption).foregroundStyle(.red)
                }
                Spacer()
                Button("Save & Connect") {
                    store.applyConnectionSettings(ip: ipDraft, serial: serialDraft)
                }
                .keyboardShortcut(.defaultAction)
            }
            Picker("Inverter type", selection: $store.phaseMode) {
                Text("Auto-detect").tag(0)
                Text("Single-phase").tag(1)
                Text("Three-phase").tag(3)
            }
            Picker("Read every", selection: $store.pollSeconds) {
                Text("10 s").tag(10)
                Text("30 s").tag(30)
                Text("60 s").tag(60)
                Text("2 min").tag(120)
                Text("5 min").tag(300)
            }
        }
    }

    // MARK: Helpers

    private func row(_ symbol: String, _ color: Color, _ title: String, _ value: String) -> some View {
        GridRow {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 18)
            Text(title).foregroundStyle(.secondary)
            Text(value).monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func stat(_ title: String, _ v: Double?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(v.map { String(format: "%.1f", $0) } ?? "—").monospacedDigit()
        }
    }

    private func batteryDetail(_ s: DeyeSummary) -> String {
        let status = s.batteryStatus ?? ""
        guard let p = s.batteryPower, abs(p) >= 1 else { return status.isEmpty ? "Idle" : status }
        return "\(status) \(Fmt.power(p))".trimmingCharacters(in: .whitespaces)
    }

    private func gridDetail(_ s: DeyeSummary) -> String {
        if s.gridOnline == false { return "Offline" }
        guard let p = s.gridPower, abs(p) >= 1 else { return "Idle" }
        return p > 0 ? "Import \(Fmt.power(p))" : "Export \(Fmt.power(p))"
    }
}
