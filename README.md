# Deye Monitor

macOS menu bar app + desktop widget for Deye hybrid inverters. It reads the
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

- `App/SolarmanClient.swift` — Solarman V5 framing + Modbus RTU (function 0x03)
- `App/DeyeReader.swift` — reads register blocks, auto-detects phases
- `App/ParamCatalog.swift` — every parameter: register, scaling, unit
- The widget can't access the local network (macOS rule), so the app writes
  `~/Library/Application Support/DeyeMonitor/snapshot.json` and the widget reads it.
