import Foundation

/// Sample single-phase inverter registers for Demo mode — lets people (and
/// App Review) try the app without an inverter, and is used for screenshots.
enum DemoData {
    private static func s16(_ v: Int) -> UInt16 { UInt16(bitPattern: Int16(v)) }

    /// A sunny afternoon: ~2.6 kW of solar, battery charging, a little export.
    static func registers(at date: Date = .now) -> [UInt16: UInt16] {
        // Gentle drift so the numbers look alive between refreshes.
        let t = date.timeIntervalSinceReferenceDate
        let wobble = Int((sin(t / 40) * 60).rounded())
        let pv1 = 1460 + wobble, pv2 = 1180 + wobble / 2
        let load = 1240 - wobble / 3
        let battAmps = 18.0                                   // charging
        let battVolts = 53.4
        let battW = Int(battAmps * battVolts)                 // ≈ 960 W
        let grid = load + battW - pv1 - pv2                   // − = export
        return [
            76: 12, 77: 31, 84: 96, 90: 1352, 91: 1418,
            107: 200, 108: 142,
            150: 2297, 166: 0, 169: s16(grid), 176: UInt16(load), 178: UInt16(load),
            183: UInt16(battVolts * 100), 184: 78,
            186: UInt16(pv1), 187: UInt16(pv2),
            191: s16(Int(-battAmps * 100)),
            236: 5120, 237: 80,
        ]
    }

    static func reading(at date: Date = .now) -> DeyeReader.Reading {
        let r = registers(at: date)
        return DeyeReader.Reading(summary: DeyeReader.convert1P(r), phases: 1, raw: r)
    }
}
