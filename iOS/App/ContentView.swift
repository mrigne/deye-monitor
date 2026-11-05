import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: MonitorStore
    @State private var showSettings = false
    @State private var showParams = false

    var body: some View {
        NavigationStack {
            List {
                if !store.isConfigured {
                    Section {
                        Text("Enter your inverter's IP address and the data logger serial number to start.")
                        Button("Set up connection") { showSettings = true }
                        Button("Try demo (no inverter needed)") { store.demoMode = true }
                    }
                }
                if store.demoMode && !ProcessInfo.processInfo.arguments.contains("-screenshots") {
                    Section {
                        Label("Demo mode — sample data. Turn it off in Settings.", systemImage: "play.circle")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if let s = store.summary {
                    statusSection(s)
                    nowSection(s)
                    todaySection(s)
                    if !store.panelParams.isEmpty { pinnedSection }
                } else if store.isConfigured {
                    Section {
                        HStack {
                            if store.isReading { ProgressView() }
                            Text(store.lastError ?? "Reading inverter…").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(AppInfo.name)
            .refreshable { await store.refreshNow() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showParams = true } label: { Image(systemName: "slider.horizontal.3") }
                        .disabled(store.registers.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView().environmentObject(store) }
            .sheet(isPresented: $showParams) { ParametersView().environmentObject(store) }
        }
    }

    // MARK: Sections

    private func statusSection(_ s: DeyeSummary) -> some View {
        Section {
            let online = s.gridOnline ?? true
            HStack {
                PlugIcon(online: online).font(.title2)
                    .foregroundStyle(online ? .green : .red)
                VStack(alignment: .leading) {
                    Text(online ? "Grid on" : "Grid off").font(.headline)
                    if let v = s.gridVoltage, online {
                        Text(String(format: "%.0f V", v)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(online ? .green : .red)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if let t = store.lastRead {
                        TimelineView(.periodic(from: .now, by: 5)) { _ in
                            Text(Fmt.age(Int(Date().timeIntervalSince(t)))).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if store.isReading { ProgressView().controlSize(.small) }
                }
            }
            if let e = store.lastError {
                Label(e, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundStyle(.orange)
            }
        }
    }

    private func nowSection(_ s: DeyeSummary) -> some View {
        Section("Now") {
            row("Solar", "sun.max.fill", .yellow, Fmt.power(s.pvPower))
            row("Home load", "house.fill", .blue, Fmt.power(s.loadPower))
            row(gridTitle(s), "powerplug.fill", .orange, s.gridOnline == false ? "Off" : Fmt.power(s.gridPower))
            if let soc = s.batterySoc {
                row("Battery", Fmt.batterySymbol(soc), soc < 20 ? .red : soc < 50 ? .orange : .green,
                    "\(Fmt.percent(soc)) · \(Fmt.power(s.batteryPower))")
                if let st = s.batteryStatus { row("Battery state", "arrow.left.arrow.right", .secondary, st) }
            }
        }
    }

    private func todaySection(_ s: DeyeSummary) -> some View {
        Section("Today") {
            row("Solar", "sun.max", .yellow, Fmt.kwh(s.todayPvKwh))
            row("Consumed", "house", .blue, Fmt.kwh(s.todayLoadKwh))
            row("Imported", "arrow.down.circle", .orange, Fmt.kwh(s.todayImportKwh))
            row("Exported", "arrow.up.circle", .green, Fmt.kwh(s.todayExportKwh))
        }
    }

    private var pinnedSection: some View {
        Section("My parameters") {
            ForEach(store.panelParams, id: \.self) { id in
                if let p = store.param(id) {
                    row(p.title, p.symbol, .accentColor, p.display(store.value(p)))
                }
            }
        }
    }

    private func gridTitle(_ s: DeyeSummary) -> String {
        guard let p = s.gridPower, s.gridOnline != false else { return "Grid" }
        return p > 0 ? "Grid import" : p < 0 ? "Grid export" : "Grid"
    }

    private func row(_ title: String, _ symbol: String, _ color: Color, _ value: String) -> some View {
        HStack {
            Label { Text(title) } icon: { Image(systemName: symbol).foregroundStyle(color) }
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(.secondary)
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var store: MonitorStore
    @Environment(\.dismiss) private var dismiss
    @State private var ip = ""
    @State private var serial = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Inverter IP, e.g. 192.168.1.50", text: $ip)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Logger serial number", text: $serial)
                        .keyboardType(.numberPad)
                } header: { Text("Connection") } footer: {
                    Text("The phone must be on the same Wi-Fi as the inverter's data logger. Allow Local Network access when iOS asks.")
                }
                Section {
                    Toggle("Demo mode (sample data)", isOn: $store.demoMode)
                }
                Section("Inverter") {
                    Picker("Type", selection: $store.phaseMode) {
                        Text("Auto-detect").tag(0)
                        Text("Single-phase").tag(1)
                        Text("Three-phase").tag(3)
                    }
                    Picker("Refresh every", selection: $store.pollSeconds) {
                        ForEach([10, 15, 30, 60, 120, 300], id: \.self) { Text("\($0) s").tag($0) }
                    }
                }
                Section {
                    Text("Add the \(AppInfo.name) widget from the Home Screen or Lock Screen editor. Widgets refresh roughly every 15 minutes (iOS limit); tap ↻ on the widget to read now.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("About") {
                    Text(AppInfo.compatibility).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.applyConnectionSettings(ip: ip, serial: serial)
                        dismiss()
                    }
                    .disabled(ip.trimmingCharacters(in: .whitespaces).isEmpty || UInt32(serial.trimmingCharacters(in: .whitespaces)) == nil)
                }
            }
            .onAppear { ip = store.inverterIP; serial = store.loggerSerial }
        }
    }
}

// MARK: - Parameter picker

struct ParametersView: View {
    @EnvironmentObject var store: MonitorStore
    @Environment(\.dismiss) private var dismiss
    @State private var showRaw = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.catalog) { paramRow($0) }
                } footer: {
                    Text("“App” adds the value to the main screen. “Lock” shows it on the rectangular Lock Screen widget (first 3).")
                }
                Section {
                    Toggle("Show raw registers", isOn: $showRaw)
                    if showRaw { ForEach(store.rawParams) { paramRow($0) } }
                }
            }
            .navigationTitle("Parameters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func paramRow(_ p: ParamDef) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(p.title, systemImage: p.symbol)
                Spacer()
                Text(p.display(store.value(p))).monospacedDigit().foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                chip("App", on: store.panelParams.contains(p.id)) { store.setInPanel(p.id, $0) }
                chip("Lock", on: store.menuBarParams.contains(p.id)) { store.setInMenuBar(p.id, $0) }
            }
        }
    }

    private func chip(_ title: String, on: Bool, set: @escaping (Bool) -> Void) -> some View {
        Button { set(!on) } label: {
            Label(title, systemImage: on ? "checkmark.circle.fill" : "circle")
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .tint(on ? .accentColor : .secondary)
    }
}
