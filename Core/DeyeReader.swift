import Foundation

/// Reads a Deye hybrid inverter and converts registers to a DeyeSummary.
/// Register map and scaling mirror the dashboard's inverter.py.
final class DeyeReader {
    struct Reading {
        var summary: DeyeSummary
        var phases: Int
        var raw: [UInt16: UInt16]
    }

    private let client: SolarmanClient

    init(host: String, loggerSerial: UInt32, timeout: TimeInterval = 10) {
        client = SolarmanClient(host: host, loggerSerial: loggerSerial, timeout: timeout)
    }

    deinit { client.close() }

    // Register blocks that cover every value we need (kept short: < 50 regs).
    private static let blocks1P: [(UInt16, UInt16)] = [(76, 33), (150, 42), (236, 2)]   // 76–108, 150–191, 236–237
    private static let blocks3P: [(UInt16, UInt16)] = [(502, 40), (586, 22), (644, 24)] // 502–541, 586–607, 644–667

    private static let needed1P: [UInt16] = [76, 77, 84, 90, 91, 107, 108, 150, 166, 169, 176, 178,
                                             183, 184, 186, 187, 191, 236, 237]
    private static let needed3P: [UInt16] = [502, 514, 515, 520, 521, 526, 540, 541, 586, 587, 588,
                                             598, 607, 644, 645, 646, 650, 651, 652, 653, 667]

    /// Single-phase vs three-phase: L2/L3 voltage registers are only live on 3-phase units.
    func detectPhases() -> Int {
        defer { client.close() }
        for attempt in 0..<2 {
            if let v = try? client.readHoldingRegisters(645, count: 2),
               Double(v[0]) / 10 > 50 || Double(v[1]) / 10 > 50 {
                return 3
            }
            if attempt == 0 { Thread.sleep(forTimeInterval: 1) }
        }
        return 1
    }

    /// One full read. Opens a connection, reads all blocks, closes it again
    /// (the logger copes badly with long-lived or parallel connections).
    func read(phases: Int) throws -> Reading {
        defer { client.close() }
        let blocks = phases == 3 ? Self.blocks3P : Self.blocks1P
        let needed = Set(phases == 3 ? Self.needed3P : Self.needed1P)
        var regs: [UInt16: UInt16] = [:]

        for (start, count) in blocks {
            do {
                let values = try readBlockWithRetry(start, count)
                for (i, v) in values.enumerated() { regs[start + UInt16(i)] = v }
            } catch {
                // Some firmwares reject a block containing an unsupported
                // register — fall back to the individual registers we need.
                var gotAny = false
                for addr in (start..<(start + count)) where needed.contains(addr) {
                    if let v = try? client.readHoldingRegisters(addr, count: 1).first {
                        regs[addr] = v
                        gotAny = true
                    }
                    Thread.sleep(forTimeInterval: 0.05)
                }
                if !gotAny { throw error }
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        let summary = phases == 3 ? Self.convert3P(regs) : Self.convert1P(regs)
        return Reading(summary: summary, phases: phases, raw: regs)
    }

    private func readBlockWithRetry(_ start: UInt16, _ count: UInt16) throws -> [UInt16] {
        do {
            return try client.readHoldingRegisters(start, count: count)
        } catch SolarmanError.modbusException(let code) {
            throw SolarmanError.modbusException(code)   // not transient
        } catch {
            // Logger hiccup: reconnect once and retry.
            client.close()
            Thread.sleep(forTimeInterval: 0.5)
            return try client.readHoldingRegisters(start, count: count)
        }
    }

    // MARK: Conversion

    private static func signed(_ v: UInt16?) -> Double? { v.map { Double(Int16(bitPattern: $0)) } }
    private static func u(_ v: UInt16?) -> Double? { v.map(Double.init) }
    private static func temp(_ v: UInt16?) -> Double? { v.map { (Double($0) - 1000) / 10 } }

    private static func base(pv1: Double?, pv2: Double?, battV: Double?, battIraw: Double?,
                             soc: Double?, gridV: Double?, gridP: Double?, load: Double?,
                             dailyPV: Double?, imp: Double?, exp: Double?, dailyLoad: Double?) -> DeyeSummary {
        var s = DeyeSummary(ok: true)
        s.pvPower = (pv1 ?? 0) + (pv2 ?? 0)
        s.loadPower = load
        s.gridPower = gridP
        s.gridVoltage = gridV
        s.gridOnline = (gridV ?? 0) > 100           // same rule as the dashboard
        // Battery present if its voltage is plausible.
        if let v = battV, v > 10 {
            let current = -(battIraw ?? 0) / 100     // + charging, - discharging
            s.batterySoc = soc
            s.batteryPower = (v * current).rounded()
            s.batteryStatus = current > 0 ? "Charging" : current < 0 ? "Discharging" : "Idle"
        }
        s.todayPvKwh = dailyPV.map { $0 / 10 }
        s.todayImportKwh = imp.map { $0 / 10 }
        s.todayExportKwh = exp.map { $0 / 10 }
        s.todayLoadKwh = dailyLoad.map { $0 / 10 }
        return s
    }

    static func convert1P(_ r: [UInt16: UInt16]) -> DeyeSummary {
        base(pv1: u(r[186]), pv2: u(r[187]),
             battV: u(r[183]).map { $0 / 100 }, battIraw: signed(r[191]), soc: u(r[184]),
             gridV: u(r[150]).map { $0 / 10 }, gridP: signed(r[169]), load: u(r[178]),
             dailyPV: u(r[108]), imp: u(r[76]), exp: u(r[77]), dailyLoad: u(r[84]))
    }

    static func convert3P(_ r: [UInt16: UInt16]) -> DeyeSummary {
        base(pv1: u(r[514]), pv2: u(r[515]),
             battV: u(r[587]).map { $0 / 100 }, battIraw: signed(r[586]), soc: u(r[588]),
             gridV: u(r[598]).map { $0 / 10 }, gridP: signed(r[607]), load: u(r[653]),
             dailyPV: u(r[502]), imp: u(r[520]), exp: u(r[521]), dailyLoad: u(r[526]))
    }
}
