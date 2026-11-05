# Deye Monitor

<img width="337" height="439" alt="image" src="https://github.com/user-attachments/assets/f77808dd-610c-4f9a-bad1-94732d66edca" />
<img width="496" height="210" alt="image" src="https://github.com/user-attachments/assets/e96d4683-69d1-45e3-b4ac-158c603b27bd" />


macOS menu bar app + desktop widget, and an iPhone app with Home/Lock Screen
widgets, for Deye hybrid inverters. It reads the
inverter **directly** through the Solarman Wi‑Fi logger (Solarman V5 protocol,
TCP 8899) — no server, Docker or cloud needed.

- Menu bar: any values you choose (battery %, load, grid on/off as a plug icon, PV, temperatures, …)
- Drop-down panel: solar / load / battery / grid, today's kWh, plus any pinned parameters
- **Parameters…** window: every value the app reads (and raw registers) — tick *Menu bar* and/or *Panel*
- Widget (small / medium) for the desktop or Notification Center
- Single-phase (Sunsynk-style map) and three-phase inverters, auto-detected

## Install

Download `DeyeMonitor-<version>.pkg` from Releases and open it. It installs to
`/Applications` for **all users** and starts automatically at login (and
restarts if it crashes; *Quit* keeps it closed until next login).

On first launch: click the menu bar icon → ⚙︎ → enter **Inverter IP** and
**Logger SN** (the serial printed on the Wi‑Fi stick) → *Save & Connect*,
then allow **Local Network** access when macOS asks (or later in System
Settings → Privacy & Security → Local Network).

Widget: right-click the desktop → *Edit Widgets* → "Deye Monitor".

Uninstall: `sudo bash DeyeMonitor-uninstall.sh`.

## iPhone

`iOS/` — the same reader as a SwiftUI app: live values, today's kWh, pinned
parameters, settings. Widgets: Home Screen (small/medium, tap ↻ to read now)
and Lock Screen (battery gauge, inline, rectangular with 3 values you pick in
the app). The widget reads the inverter itself when the phone is on the home
Wi‑Fi, otherwise it shows the last reading. Install / TestFlight / App Store:
[docs/PUBLISHING.md](docs/PUBLISHING.md).

## Build

Requires Xcode 16+, macOS 14+.

```bash
packaging/build_pkg.sh                              # → dist/DeyeMonitor-1.0.pkg (ad-hoc signed)
VERSION=1.2.0 packaging/build_pkg.sh --prefill .env # preset INVERTER_IP / LOGGER_SERIAL for all users
```

Signed + notarized build: see the variables at the top of
`packaging/build_pkg.sh`. Releases are built by GitHub Actions on `v*` tags
(`.github/workflows/release.yml`).

`DeyeMonitor.xcodeproj` is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) — run `xcodegen generate`
after editing `project.yml`.

## How it works

- App icon: `packaging/icon/make_icon.swift` renders it (`swift make_icon.swift packaging/icon`)
- `Core/SolarmanClient.swift` — Solarman V5 framing + Modbus RTU (function 0x03)
- `Core/DeyeReader.swift` — reads register blocks, auto-detects phases
- `Core/ParamCatalog.swift` — every parameter: register, scaling, unit
- The widget can't access the local network (macOS rule), so the app writes
  `~/Library/Application Support/DeyeMonitor/snapshot.json` and the widget reads it.
