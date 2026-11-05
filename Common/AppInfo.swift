import Foundation

enum AppInfo {
    /// Name shown in the UI (App Store builds use their own display name).
    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Deye Monitor"
    }

    static let compatibility = "Works with Deye and Sunsynk hybrid inverters through the Solarman Wi‑Fi data logger. Not affiliated with or endorsed by Deye or Sunsynk."
}
