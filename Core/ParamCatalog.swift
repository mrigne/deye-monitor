import Foundation

/// Every value Deye Monitor can show, computed from the registers it reads.
/// Register map and scaling mirror the dashboard's inverter.py.
struct ParamDef: Identifiable {
    enum Kind {
        case power, percent, voltage, current, temperature, energy, ampHours, wattHours
        case gridOnline      // 1 = grid present, 0 = outage
        case batteryState    // battery current sign: +1 charging, -1 discharging, 0 idle
        case raw
    }

    let id: String
    let title: String
    let symbol: String
    let kind: Kind
    let value: ([UInt16: UInt16]) -> Double?

    /// Full text for the menu panel and the picker.
    func display(_ v: Double?) -> String {
        guard let v else { return "—" }
        switch kind {
        case .power: return Fmt.power(v) + (v < 0 ? " (−)" : "")
        case .percent: return String(format: "%.0f %%", v)
        case .voltage: return String(format: "%.1f V", v)
        case .current: return String(format: "%.2f A", v)
        case .temperature: return String(format: "%.1f °C", v)
        case .energy: return String(format: "%.1f kWh", v)
        case .ampHours: return String(format: "%.0f Ah", v)
        case .wattHours: return v >= 1000 ? String(format: "%.1f kWh", v / 1000) : String(format: "%.0f Wh", v)
        case .gridOnline: return v > 0 ? "On" : "Off"
        case .batteryState: return v > 0 ? "Charging" : v < 0 ? "Discharging" : "Idle"
        case .raw: return String(format: "%.0f", v)
        }
    }

    /// Compact text for the menu bar.
    func short(_ v: Double?) -> String {
        guard let v else { return "—" }
        switch kind {
        case .power: return (v < 0 ? "−" : "") + Fmt.powerShort(v)
        case .percent: return String(format: "%.0f%%", v)
        case .voltage: return String(format: "%.0fV", v)
        case .current: return String(format: "%.1fA", v)
        case .temperature: return String(format: "%.0f°", v)
        case .energy: return String(format: "%.1fkWh", v)
        case .ampHours: return String(format: "%.0fAh", v)
        case .wattHours: return v >= 1000 ? String(format: "%.1fkWh", v / 1000) : String(format: "%.0fWh", v)
        case .gridOnline: return v > 0 ? "On" : "Off"
        case .batteryState: return v > 0 ? "Chg" : v < 0 ? "Dis" : "Idle"
        case .raw: return String(format: "%.0f", v)
        }
    }

    /// How the parameter appears in the menu bar.
    func menuBarItem(_ regs: [UInt16: UInt16]) -> MenuBarItem {
        let v = value(regs)
        switch kind {
        case .gridOnline: return .plug(online: (v ?? 1) > 0)
        case .percent where id == "battery_soc": return .metric(Fmt.batterySymbol(v), short(v))
        default: return .metric(symbol, short(v))
        }
    }
}

enum ParamCatalog {
    private static func u(_ r: [UInt16: UInt16], _ a: UInt16) -> Double? { r[a].map(Double.init) }
    private static func s(_ r: [UInt16: UInt16], _ a: UInt16) -> Double? { r[a].map { Double(Int16(bitPattern: $0)) } }
    private static func scaled(_ r: [UInt16: UInt16], _ a: UInt16, _ d: Double) -> Double? { u(r, a).map { $0 / d } }
    private static func temp(_ r: [UInt16: UInt16], _ a: UInt16) -> Double? { u(r, a).map { ($0 - 1000) / 10 } }
    private static func sum(_ a: Double?, _ b: Double?) -> Double? { a == nil && b == nil ? nil : (a ?? 0) + (b ?? 0) }

    /// Known parameters for the inverter type, in display order.
    static func known(phases: Int) -> [ParamDef] {
        phases == 3 ? threePhase : singlePhase
    }

    static func find(_ id: String, phases: Int) -> ParamDef? {
        if let p = known(phases: phases).first(where: { $0.id == id }) { return p }
        if id.hasPrefix("reg_"), let a = UInt16(id.dropFirst(4)) { return raw(a) }
        return nil
    }

    /// Any register the app reads, unscaled.
    static func raw(_ addr: UInt16) -> ParamDef {
        ParamDef(id: "reg_\(addr)", title: "Register \(addr)", symbol: "number", kind: .raw) { $0[addr].map(Double.init) }
    }

    // MARK: Single-phase (Sunsynk-style register map)

    private static let singlePhase: [ParamDef] = {
        let battV: ([UInt16: UInt16]) -> Double? = { scaled($0, 183, 100) }
        let battI: ([UInt16: UInt16]) -> Double? = { r in s(r, 191).map { -$0 / 100 } }
        return [
            ParamDef(id: "pv_power", title: "Solar power", symbol: "sun.max.fill", kind: .power) { sum(u($0, 186), u($0, 187)) },
            ParamDef(id: "pv1_power", title: "PV1 power", symbol: "sun.min.fill", kind: .power) { u($0, 186) },
            ParamDef(id: "pv2_power", title: "PV2 power", symbol: "sun.min.fill", kind: .power) { u($0, 187) },
            ParamDef(id: "battery_soc", title: "Battery charge", symbol: "battery.75percent", kind: .percent) { u($0, 184) },
            ParamDef(id: "battery_power", title: "Battery power (+charge / −discharge)", symbol: "bolt.batteryblock.fill", kind: .power) { r in
                guard let v = battV(r), let i = battI(r) else { return nil }
                return (v * i).rounded()
            },
            ParamDef(id: "battery_status", title: "Battery state", symbol: "battery.100.bolt", kind: .batteryState) { r in
                battI(r).map { $0 > 0 ? 1 : $0 < 0 ? -1 : 0 }
            },
            ParamDef(id: "battery_voltage", title: "Battery voltage", symbol: "bolt.batteryblock", kind: .voltage, value: battV),
            ParamDef(id: "battery_current", title: "Battery current", symbol: "arrow.left.arrow.right", kind: .current, value: battI),
            ParamDef(id: "battery_capacity", title: "Battery capacity", symbol: "battery.100", kind: .ampHours) { u($0, 107) },
            ParamDef(id: "battery_nominal_voltage", title: "Battery nominal voltage", symbol: "bolt.batteryblock", kind: .voltage) { scaled($0, 236, 100) },
            ParamDef(id: "battery_discharge_limit", title: "Battery depth of discharge", symbol: "battery.25percent", kind: .percent) { u($0, 237) },
            ParamDef(id: "battery_usable_wh", title: "Battery usable energy", symbol: "battery.100.bolt", kind: .wattHours) { r in
                guard let cap = u(r, 107), let dod = u(r, 237), let nom = scaled(r, 236, 100) else { return nil }
                return cap / 100 * dod * nom
            },
            ParamDef(id: "load_power", title: "Home load", symbol: "house.fill", kind: .power) { u($0, 178) },
            ParamDef(id: "load_l1", title: "Load L1", symbol: "house", kind: .power) { u($0, 176) },
            ParamDef(id: "grid_online", title: "Grid status", symbol: "powerplug.fill", kind: .gridOnline) { r in
                scaled(r, 150, 10).map { $0 > 100 ? 1 : 0 }
            },
            ParamDef(id: "grid_power", title: "Grid power (+import / −export)", symbol: "bolt.horizontal.fill", kind: .power) { s($0, 169) },
            ParamDef(id: "grid_voltage", title: "Grid voltage", symbol: "bolt.fill", kind: .voltage) { scaled($0, 150, 10) },
            ParamDef(id: "generator_power", title: "Generator power", symbol: "fuelpump.fill", kind: .power) { u($0, 166) },
            ParamDef(id: "dc_temp", title: "DC temperature", symbol: "thermometer", kind: .temperature) { temp($0, 90) },
            ParamDef(id: "heatsink_temp", title: "Heatsink temperature", symbol: "thermometer", kind: .temperature) { temp($0, 91) },
            ParamDef(id: "today_pv", title: "Solar today", symbol: "sun.max", kind: .energy) { scaled($0, 108, 10) },
            ParamDef(id: "today_load", title: "Load today", symbol: "house", kind: .energy) { scaled($0, 84, 10) },
            ParamDef(id: "today_import", title: "Grid import today", symbol: "arrow.down.circle", kind: .energy) { scaled($0, 76, 10) },
            ParamDef(id: "today_export", title: "Grid export today", symbol: "arrow.up.circle", kind: .energy) { scaled($0, 77, 10) },
        ]
    }()

    // MARK: Three-phase register map

    private static let threePhase: [ParamDef] = {
        let battV: ([UInt16: UInt16]) -> Double? = { scaled($0, 587, 100) }
        let battI: ([UInt16: UInt16]) -> Double? = { r in s(r, 586).map { -$0 / 100 } }
        return [
            ParamDef(id: "pv_power", title: "Solar power", symbol: "sun.max.fill", kind: .power) { sum(u($0, 514), u($0, 515)) },
            ParamDef(id: "pv1_power", title: "PV1 power", symbol: "sun.min.fill", kind: .power) { u($0, 514) },
            ParamDef(id: "pv2_power", title: "PV2 power", symbol: "sun.min.fill", kind: .power) { u($0, 515) },
            ParamDef(id: "battery_soc", title: "Battery charge", symbol: "battery.75percent", kind: .percent) { u($0, 588) },
            ParamDef(id: "battery_power", title: "Battery power (+charge / −discharge)", symbol: "bolt.batteryblock.fill", kind: .power) { r in
                guard let v = battV(r), let i = battI(r) else { return nil }
                return (v * i).rounded()
            },
            ParamDef(id: "battery_status", title: "Battery state", symbol: "battery.100.bolt", kind: .batteryState) { r in
                battI(r).map { $0 > 0 ? 1 : $0 < 0 ? -1 : 0 }
            },
            ParamDef(id: "battery_voltage", title: "Battery voltage", symbol: "bolt.batteryblock", kind: .voltage, value: battV),
            ParamDef(id: "battery_current", title: "Battery current", symbol: "arrow.left.arrow.right", kind: .current, value: battI),
            ParamDef(id: "load_power", title: "Home load", symbol: "house.fill", kind: .power) { u($0, 653) },
            ParamDef(id: "load_l1", title: "Load L1", symbol: "house", kind: .power) { u($0, 650) },
            ParamDef(id: "load_l2", title: "Load L2", symbol: "house", kind: .power) { u($0, 651) },
            ParamDef(id: "load_l3", title: "Load L3", symbol: "house", kind: .power) { u($0, 652) },
            ParamDef(id: "grid_online", title: "Grid status", symbol: "powerplug.fill", kind: .gridOnline) { r in
                scaled(r, 598, 10).map { $0 > 100 ? 1 : 0 }
            },
            ParamDef(id: "grid_power", title: "Grid power (+import / −export)", symbol: "bolt.horizontal.fill", kind: .power) { s($0, 607) },
            ParamDef(id: "grid_voltage", title: "Grid voltage", symbol: "bolt.fill", kind: .voltage) { scaled($0, 598, 10) },
            ParamDef(id: "voltage_l1", title: "Voltage L1", symbol: "bolt", kind: .voltage) { scaled($0, 644, 10) },
            ParamDef(id: "voltage_l2", title: "Voltage L2", symbol: "bolt", kind: .voltage) { scaled($0, 645, 10) },
            ParamDef(id: "voltage_l3", title: "Voltage L3", symbol: "bolt", kind: .voltage) { scaled($0, 646, 10) },
            ParamDef(id: "generator_power", title: "Generator power", symbol: "fuelpump.fill", kind: .power) { u($0, 667) },
            ParamDef(id: "dc_temp", title: "DC temperature", symbol: "thermometer", kind: .temperature) { temp($0, 540) },
            ParamDef(id: "heatsink_temp", title: "Heatsink temperature", symbol: "thermometer", kind: .temperature) { temp($0, 541) },
            ParamDef(id: "today_pv", title: "Solar today", symbol: "sun.max", kind: .energy) { scaled($0, 502, 10) },
            ParamDef(id: "today_load", title: "Load today", symbol: "house", kind: .energy) { scaled($0, 526, 10) },
            ParamDef(id: "today_import", title: "Grid import today", symbol: "arrow.down.circle", kind: .energy) { scaled($0, 520, 10) },
            ParamDef(id: "today_export", title: "Grid export today", symbol: "arrow.up.circle", kind: .energy) { scaled($0, 521, 10) },
        ]
    }()
}
