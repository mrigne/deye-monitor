import Foundation

/// Snapshot of the values shown in the menu bar, panel and widget.
struct DeyeSummary: Codable, Equatable {
    struct Outage: Codable, Equatable {
        var status: String          // active | upcoming | none | unknown ...
        var endTime: String?
        var nextStart: String?
        var nextEnd: String?
    }

    var ok: Bool
    var error: String?
    var updatedAt: String?
    var ageSeconds: Int?
    var pollInterval: Int?
    var pollError: String?
    var pvPower: Double?
    var loadPower: Double?
    var gridPower: Double?          // + import, - export
    var gridVoltage: Double?
    var gridOnline: Bool?
    var batterySoc: Double?
    var batteryPower: Double?       // + discharge, - charge
    var batteryStatus: String?
    var todayPvKwh: Double?
    var todayLoadKwh: Double?
    var todayImportKwh: Double?
    var todayExportKwh: Double?
    var outage: Outage?

    static let preview = DeyeSummary(
        ok: true, updatedAt: nil, ageSeconds: 12, pollInterval: 60,
        pvPower: 2340, loadPower: 870, gridPower: -1200, gridVoltage: 229,
        gridOnline: true, batterySoc: 78, batteryPower: -270, batteryStatus: "Charging",
        todayPvKwh: 11.4, todayLoadKwh: 7.9, todayImportKwh: 0.6, todayExportKwh: 3.1,
        outage: Outage(status: "upcoming", nextStart: nil, nextEnd: nil))
}

enum Fmt {
    /// 850 W, 2.3 kW
    static func power(_ w: Double?) -> String {
        guard let w else { return "—" }
        let a = abs(w)
        return a >= 1000 ? String(format: "%.1f kW", a / 1000) : String(format: "%.0f W", a)
    }

    /// Compact for the menu bar: 850W, 2.3kW
    static func powerShort(_ w: Double?) -> String {
        guard let w else { return "—" }
        let a = abs(w)
        return a >= 1000 ? String(format: "%.1fkW", a / 1000) : String(format: "%.0fW", a)
    }

    static func kwh(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.1f kWh", v)
    }

    static func percent(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.0f%%", v)
    }

    static func age(_ seconds: Int?) -> String {
        guard let s = seconds else { return "—" }
        if s < 60 { return "\(s)s ago" }
        if s < 3600 { return "\(s / 60)m ago" }
        return "\(s / 3600)h \(s % 3600 / 60)m ago"
    }

    static func batterySymbol(_ soc: Double?) -> String {
        guard let soc else { return "battery.0percent" }
        switch soc {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    /// Parses the dashboard's naive local ISO timestamps (with or without micros).
    static func date(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        for f in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = f
            if let d = df.date(from: iso) { return d }
        }
        return nil
    }

    static func time(_ iso: String?) -> String {
        guard let d = date(iso) else { return "—" }
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: d)
    }

    static func outageLine(_ o: DeyeSummary.Outage?) -> String? {
        guard let o else { return nil }
        switch o.status {
        case "active": return "Outage now, until \(time(o.endTime))"
        case "upcoming":
            if o.nextStart != nil { return "Next outage \(time(o.nextStart))–\(time(o.nextEnd))" }
            return nil
        default: return nil
        }
    }
}
