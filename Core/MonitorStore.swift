import Foundation
import SwiftUI
import WidgetKit

/// Polls the inverter directly (Solarman V5) and publishes the latest reading.
@MainActor
final class MonitorStore: ObservableObject {
    @Published private(set) var summary: DeyeSummary?
    /// Raw registers from the last successful read (every parameter derives from these).
    @Published private(set) var registers: [UInt16: UInt16] = [:]
    @Published private(set) var lastError: String?
    @Published private(set) var lastRead: Date?
    @Published private(set) var isReading = false
    @Published private(set) var phases: Int?

    private static let d = SharedSettings.defaults

    @Published var inverterIP: String { didSet { Self.d.set(inverterIP, forKey: "InverterIP") } }
    @Published var loggerSerial: String { didSet { Self.d.set(loggerSerial, forKey: "LoggerSerial") } }
    /// 0 = auto-detect, 1 or 3 = forced
    @Published var phaseMode: Int { didSet { Self.d.set(phaseMode, forKey: "PhaseMode"); phases = nil; restart() } }
    @Published var pollSeconds: Int { didSet { Self.d.set(pollSeconds, forKey: "PollSeconds"); restart() } }
    /// Parameter ids (see ParamCatalog) shown in the menu bar, in order.
    @Published var menuBarParams: [String] { didSet { Self.d.set(menuBarParams, forKey: "MenuBarParams") } }
    /// Extra parameter ids listed in the drop-down panel, in order.
    @Published var panelParams: [String] { didSet { Self.d.set(panelParams, forKey: "PanelParams") } }

    private var loop: Task<Void, Never>?
    private let queue = DispatchQueue(label: "dev.deye.monitor.inverter")   // one read at a time
    private var lastWidgetReload: Date = .distantPast
    private var lastWidgetState: String = ""

    init() {
        // Defaults may also come from /Library/Preferences/dev.deye.monitor.plist
        // (written by the installer), which UserDefaults reads automatically.
        Self.d.register(defaults: ["PollSeconds": 30, "PhaseMode": 0,
                                   "MenuBarParams": ["battery_soc", "load_power", "grid_online"],
                                   "PanelParams": ["battery_voltage", "pv1_power", "pv2_power", "heatsink_temp"]])
        inverterIP = Self.d.string(forKey: "InverterIP") ?? ""
        loggerSerial = Self.d.string(forKey: "LoggerSerial") ?? ""
        phaseMode = Self.d.integer(forKey: "PhaseMode")
        pollSeconds = Self.d.integer(forKey: "PollSeconds")
        menuBarParams = Self.d.stringArray(forKey: "MenuBarParams") ?? []
        panelParams = Self.d.stringArray(forKey: "PanelParams") ?? []
        restart()
    }

    var isConfigured: Bool { !inverterIP.trimmingCharacters(in: .whitespaces).isEmpty && UInt32(loggerSerial) != nil }

    /// Call after editing IP / serial.
    func applyConnectionSettings(ip: String, serial: String) {
        inverterIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        loggerSerial = serial.trimmingCharacters(in: .whitespacesAndNewlines)
        phases = nil
        summary = nil
        lastError = nil
        restart()
        WidgetCenter.shared.reloadAllTimelines()   // widgets pick up the new address
    }

    func restart() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.readNow()
                let secs = max(10, self?.pollSeconds ?? 30)
                try? await Task.sleep(nanoseconds: UInt64(secs) * 1_000_000_000)
            }
        }
    }

    /// Manual "read now" from the menu.
    func refresh() {
        Task { await refreshNow() }
    }

    func refreshNow() async {
        await readNow()
        reloadWidget(force: true)
    }

    private func readNow() async {
        guard isConfigured else {
            lastError = "Set inverter IP and logger serial in Settings"
            writeSnapshot()
            return
        }
        guard !isReading else { return }
        isReading = true
        defer { isReading = false }

        let ip = inverterIP
        let serial = UInt32(loggerSerial)!
        let forced = phaseMode == 1 || phaseMode == 3 ? phaseMode : nil
        let knownPhases = forced ?? phases ?? cachedPhases(ip: ip, serial: serial)

        let result: Result<DeyeReader.Reading, Error> = await withCheckedContinuation { cont in
            queue.async {
                let reader = DeyeReader(host: ip, loggerSerial: serial)
                let p = knownPhases ?? reader.detectPhases()
                do {
                    let r = try reader.read(phases: p)
                    cont.resume(returning: .success(r))
                } catch {
                    cont.resume(returning: .failure(error))
                }
            }
        }

        switch result {
        case .success(let reading):
            var s = reading.summary
            s.pollInterval = pollSeconds
            s.updatedAt = ISO8601DateFormatter().string(from: Date())
            summary = s
            registers = reading.raw
            lastRead = Date()
            lastError = nil
            if phases != reading.phases {
                phases = reading.phases
                Self.d.set(reading.phases, forKey: phaseCacheKey(ip: ip, serial: serial))
            }
        case .failure(let error):
            lastError = error.localizedDescription
        }
        writeSnapshot()
        reloadWidget(force: false)
    }

    private func phaseCacheKey(ip: String, serial: UInt32) -> String { SharedSettings.phaseCacheKey(ip: ip, serial: serial) }

    private func cachedPhases(ip: String, serial: UInt32) -> Int? { SharedSettings.cachedPhases(ip: ip, serial: serial) }

    // MARK: Widget hand-off

    /// Summary as the widget/menu should show it now (age + error flag filled in).
    var currentSummary: DeyeSummary? {
        guard var s = summary else { return nil }
        if let t = lastRead { s.ageSeconds = Int(Date().timeIntervalSince(t)) }
        s.pollError = lastError
        return s
    }

    private func writeSnapshot() {
        SnapshotFile.write(DeyeSnapshot(summary: summary, readAt: lastRead, error: lastError,
                                        pollInterval: pollSeconds, writtenAt: Date(),
                                        registers: registers.isEmpty ? nil : registers, phases: phases))
    }

    /// Widget reloads are budgeted by macOS, so only ask when something the
    /// widget shows actually changed (or every 5 minutes).
    private func reloadWidget(force: Bool) {
        let s = summary
        let state = [s?.gridOnline.map { "\($0)" } ?? "-",
                     s?.batterySoc.map { String(format: "%.0f", $0) } ?? "-",
                     s?.pvPower.map { String(format: "%.0f", ($0 / 100).rounded()) } ?? "-",
                     lastError == nil ? "ok" : "err"].joined(separator: "|")
        let due = Date().timeIntervalSince(lastWidgetReload) > 300
        guard force || due || state != lastWidgetState else { return }
        lastWidgetState = state
        lastWidgetReload = Date()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Menu bar

    var isStale: Bool {
        guard let t = lastRead else { return false }
        return Date().timeIntervalSince(t) > Double(pollSeconds * 3 + 30)
    }

    var menuBarItems: [MenuBarItem] {
        guard summary != nil else {
            return [.icon(lastError == nil ? "sun.max" : "exclamationmark.triangle")]
        }
        let p = phases ?? 1
        var items = menuBarParams.compactMap { ParamCatalog.find($0, phases: p)?.menuBarItem(registers) }
        if lastError != nil || isStale { items.append(.icon("exclamationmark.triangle")) }
        return items.isEmpty ? [.icon("sun.max.fill")] : items
    }

    // MARK: Parameter selection

    /// Known parameters for the detected inverter type.
    var catalog: [ParamDef] { ParamCatalog.known(phases: phases ?? 1) }

    /// Every register read in the last poll, as raw parameters.
    var rawParams: [ParamDef] { registers.keys.sorted().map(ParamCatalog.raw) }

    func param(_ id: String) -> ParamDef? { ParamCatalog.find(id, phases: phases ?? 1) }

    func value(_ p: ParamDef) -> Double? { registers.isEmpty ? nil : p.value(registers) }

    func setInMenuBar(_ id: String, _ on: Bool) {
        if on, !menuBarParams.contains(id) { menuBarParams.append(id) }
        if !on { menuBarParams.removeAll { $0 == id } }
    }

    func setInPanel(_ id: String, _ on: Bool) {
        if on, !panelParams.contains(id) { panelParams.append(id) }
        if !on { panelParams.removeAll { $0 == id } }
    }

    func move(_ id: String, inMenuBar: Bool, by offset: Int) {
        var list = inMenuBar ? menuBarParams : panelParams
        guard let i = list.firstIndex(of: id) else { return }
        let j = max(0, min(list.count - 1, i + offset))
        list.swapAt(i, j)
        if inMenuBar { menuBarParams = list } else { panelParams = list }
    }

    #if os(macOS)
    var menuBarImage: NSImage { MenuBarLabel.image(menuBarItems) }
    #endif
}
