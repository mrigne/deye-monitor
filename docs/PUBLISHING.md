# Publishing Deye Monitor

Team ID: `CR2SHW9GDN`. Bundle IDs:

| Target | Bundle ID |
|---|---|
| macOS app (pkg / Developer ID) | `dev.deye.monitor` |
| macOS widget | `dev.deye.monitor.widget` |
| iOS app | `dev.deye.monitor.ios` |
| iOS widget | `dev.deye.monitor.ios.widget` |
| App Group (iOS) | `group.dev.deye.monitor` |

If Apple says an ID is already taken, change the prefix in `project.yml`
(and `SharedSettings.appGroup` in `Common/Snapshot.swift`), then run `xcodegen generate`.

---

## 1. iOS: run it on your own iPhone (5 minutes, free on any account)

1. iPhone: **Settings → Privacy & Security → Developer Mode → On** (it reboots).
2. Connect the iPhone by cable (or the same Wi‑Fi after the first pairing) and tap *Trust*.
3. `open DeyeMonitor.xcodeproj` → scheme **DeyeMonitoriOS** → choose your iPhone at the top.
4. Xcode → Settings → Accounts: your Apple ID must be signed in (team *Ihor Nerozia*).
   Signing is automatic. On the first build Xcode registers the device, both bundle IDs
   and the App Group for you.
5. ⌘R. On the phone: enter the inverter IP and logger SN → **Save** → **Allow** Local Network.
6. Widgets: long-press the Home Screen → **Edit → Add Widget → Deye Monitor**.
   Lock Screen: long-press the Lock Screen → **Customize → Lock Screen → widget area**.

With a paid developer account the build stays valid for a year. Re-run from Xcode when it expires.

## 2. iOS: TestFlight (install without a cable, for you and your family)

1. Go to https://appstoreconnect.apple.com → **Apps → + → New App**:
   - Platform iOS, name **Deye Monitor** (the name must be unique on the store, so try e.g. "Deye Monitor – Solar").
   - Bundle ID `dev.deye.monitor.ios`, SKU `deye-monitor-ios`.
2. Xcode: scheme **DeyeMonitoriOS**, device **Any iOS Device (arm64)** → **Product → Archive**.
3. In the Organizer: **Distribute App → App Store Connect → Upload** (automatic signing).
4. Wait about 10–20 minutes for processing. In App Store Connect → **TestFlight**:
   - **Internal Testing** → add yourself. You can install right away, with no Apple review.
   - **External Testing** (up to 10,000 people by email or public link) needs a short beta review (~1 day).
5. On the iPhone, install the **TestFlight** app from the App Store and accept the invite.

Each upload needs a higher build number. Bump `CURRENT_PROJECT_VERSION` in
`project.yml` (or `MARKETING_VERSION` for a new version) and run `xcodegen generate`.

## 3. iOS: public App Store release

In App Store Connect → your app → **iOS App 1.0**:

- **Screenshots**: 6.9" iPhone (1320×2868) is required; iPad 13" only if you keep iPad support.
  Get them in the Simulator with ⌘S.
- Description, keywords, support URL (the GitHub repo works) and **Privacy Policy URL**
  (required). The app collects no data, so a one-page "Deye Monitor does not collect any data"
  file in the repo (e.g. GitHub Pages) is enough.
- **App Privacy** → "Data Not Collected".
- Category: Utilities. Age rating: questionnaire, all "No" → 4+.
- **App Review Information** → Notes. This matters because the reviewer has no inverter:
  > The app reads a Deye solar inverter through its Solarman Wi‑Fi data logger on the
  > local network (TCP 8899). Without such hardware it shows the setup screen. A demo
  > video is attached / available at <link>.
  Attach a short screen recording from your phone. Without one, the app is often rejected
  under Guideline 2.1 ("cannot verify functionality").
- **Do not use "Deye" as the main word in the name or icon.** It is someone else's trademark
  (Guideline 5.2.1). Use something like "Solar Monitor for Deye inverters" (the description
  can say "compatible with Deye/Sunsynk"). Our icon is original artwork in blue with a sun,
  not the Deye logo.
- Pick the build → **Add for Review → Submit**. Review usually takes 1–2 days.

Encryption: `ITSAppUsesNonExemptEncryption = NO` is already set in Info.plist, so there is no export questionnaire.

---

## 4. macOS: Mac App Store

The current macOS build (`.pkg` from GitHub Releases) uses **Developer ID**. It is not
sandboxed, installs a LaunchAgent for all users, and its widget reads
`~/Library/Application Support`. The Mac App Store does not allow any of that, so the store
version needs a separate configuration:

| Needed for the Mac App Store | Change |
|---|---|
| App Sandbox | `com.apple.security.app-sandbox = true` + `com.apple.security.network.client = true` (TCP to the logger) |
| App ↔ widget data | App Group `CR2SHW9GDN.dev.deye.monitor` (on macOS the group is prefixed with the Team ID) instead of `~/Library/Application Support`, same as on iOS |
| Remove the LaunchAgent / pkg | Autostart via `SMAppService.mainApp.register()` (a "Launch at login" toggle in Settings) |
| Widget | Remove the `temporary-exception` entitlement (it gets rejected) |
| Signing | "Apple Distribution" + "Mac Installer Distribution" certificates (Xcode creates them itself in Automatic signing) |

After that change the steps are the same as for iOS:

1. App Store Connect → **+ New App** → platform **macOS**, Bundle ID `dev.deye.monitor`
   (or use the iOS record's bundle ID if you want one "Universal Purchase" for iPhone and Mac).
2. Xcode: scheme **DeyeMonitor**, destination **Any Mac** → **Product → Archive →
   Distribute App → App Store Connect → Upload**.
3. TestFlight for Mac works the same way (TestFlight app on the Mac).
4. Screenshots: 2880×1800 or 1440×900 (the menu bar panel, the parameters window, the widget).
   The privacy, review notes and name-trademark requirements are the same as in section 3.

GitHub Releases (Developer ID `.pkg`) and the Mac App Store can coexist, because they are
different builds of the same code.
