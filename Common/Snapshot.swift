import Foundation

/// Latest reading, written by the Deye Monitor app and read by its widget.
/// Widgets can't reach the local network, so the app does the polling and
/// hands the data over through this file in the user's Application Support.
struct DeyeSnapshot: Codable {
    var summary: DeyeSummary?
    var readAt: Date?          // when the inverter was last read successfully
    var error: String?         // last read error, if the latest attempt failed
    var pollInterval: Int
    var writtenAt: Date
    var registers: [UInt16: UInt16]? = nil   // raw values, for user-picked parameters
    var phases: Int? = nil
}

enum SnapshotFile {
    /// Real home directory (sandboxed widgets get a container path from
    /// FileManager, so ask the password database instead).
    static var realHome: String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }

    static var directory: URL {
        #if os(iOS) || MAS
        // iOS / Mac App Store: the app and its widget share an App Group container.
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedSettings.appGroup) {
            return group.appendingPathComponent("Library/Application Support/DeyeMonitor", isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DeyeMonitor", isDirectory: true)
        #else
        return URL(fileURLWithPath: realHome).appendingPathComponent("Library/Application Support/DeyeMonitor", isDirectory: true)
        #endif
    }

    static var url: URL { directory.appendingPathComponent("snapshot.json") }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func write(_ snapshot: DeyeSnapshot) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try encoder.encode(snapshot).write(to: url, options: .atomic)
        } catch {
            NSLog("DeyeMonitor: failed to write snapshot: \(error)")
        }
    }

    static func read() -> DeyeSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(DeyeSnapshot.self, from: data)
    }
}

/// Settings storage. macOS keeps the standard domain (so the installer's
/// /Library/Preferences prefill keeps working); iOS uses the App Group so the
/// widget can read the inverter address and talk to it itself.
enum SharedSettings {
    #if os(iOS)
    static let appGroup = "group.ua.com.mrigne.deyemonitor"
    #else
    static let appGroup = "CR2SHW9GDN.ua.com.mrigne.deyemonitor"   // macOS groups are Team-ID prefixed
    #endif

    static var defaults: UserDefaults {
        #if os(iOS) || MAS
        return UserDefaults(suiteName: appGroup) ?? .standard
        #else
        return .standard
        #endif
    }

    static var inverterIP: String { (defaults.string(forKey: "InverterIP") ?? "").trimmingCharacters(in: .whitespaces) }
    static var loggerSerial: UInt32? { defaults.string(forKey: "LoggerSerial").flatMap { UInt32($0) } }

    static func phaseCacheKey(ip: String, serial: UInt32) -> String { "DetectedPhases.\(ip).\(serial)" }

    static func cachedPhases(ip: String, serial: UInt32) -> Int? {
        let v = defaults.integer(forKey: phaseCacheKey(ip: ip, serial: serial))
        return v == 1 || v == 3 ? v : nil
    }

    static var demoMode: Bool { defaults.bool(forKey: "DemoMode") }

    /// 1 or 3 if the user forced it, else nil.
    static var forcedPhases: Int? {
        let v = defaults.integer(forKey: "PhaseMode")
        return v == 1 || v == 3 ? v : nil
    }
}
