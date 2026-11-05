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
        URL(fileURLWithPath: realHome).appendingPathComponent("Library/Application Support/DeyeMonitor", isDirectory: true)
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
