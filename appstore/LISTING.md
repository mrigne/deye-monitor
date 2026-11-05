# App Store Connect — тексти і скріншоти

Принцип щодо Guideline 5.2.1 (чужа торгова марка):
**назва та іконка без "Deye"**. Сумісність вказана у підзаголовку і описі як
"for / works with", плюс дисклеймер "not affiliated". Так роблять більшість
сторонніх застосунків, наприклад "… for Philips Hue" чи "… for Tesla".
Сам застосунок теж має дисклеймер: Settings → About.

---

## Назви

| Поле | iPhone (запис iOS) | Mac (запис macOS) |
|---|---|---|
| **Name** (≤30) | `Solar Glance: Inverter Monitor` | `Solar Glance – Menu Bar` |
| **Subtitle** (≤30) | `Live data for Deye inverters` | `Deye inverter in your menu bar` |

Назви двох записів *мусять відрізнятися*. App Store Connect не дозволяє однакову назву для
двох застосунків в одному акаунті. Звідси і помилка, яку ви отримали.

Запасні варіанти підзаголовка, якщо рецензент все ж причепиться до "Deye":
- `For Solarman Wi‑Fi inverters`
- `Solar, battery & grid live`

Тоді "Deye" лишиться лише в описі.

Назва під іконкою на пристрої: **Solar Glance**.

---

## Promotional Text (≤170, можна міняти без нової версії)

```
See your solar production, battery charge, home load and grid status live — right on your Home Screen, Lock Screen or menu bar. No cloud, no account.
```

## Description — iPhone

```
Solar Glance shows what your hybrid solar inverter is doing right now — solar power, battery charge, home consumption and the grid — and keeps it on your Home Screen and Lock Screen.

It talks directly to the inverter's Solarman Wi‑Fi data logger on your home network. No cloud service, no account, no sign-in, and nothing leaves your network.

WORKS WITH
• Deye hybrid inverters (single-phase and three-phase), and other inverters that use the same register map, such as Sunsynk
• Solarman Wi‑Fi data loggers (the stick on the inverter; you need its IP address and serial number)

LIVE OVERVIEW
• Solar power, home load, grid import/export and grid voltage
• Battery charge, power and charging state
• Grid on/off at a glance — know instantly when there's an outage
• Today's solar, consumption, import and export in kWh

WIDGETS
• Home Screen widgets — small and medium, with a tap-to-refresh button
• Lock Screen widgets — battery gauge, a one-line summary, and a rectangular widget with any three values you choose

ANY PARAMETER YOU WANT
• PV strings, battery voltage and current, temperatures, generator port, battery capacity and more
• Even raw inverter registers — pin anything to the main screen or the Lock Screen

PRIVATE BY DESIGN
• Reads the inverter only over your local network
• Settings stay on your device; no analytics, no tracking

Try it without an inverter: tap "Try demo" on the first screen.

Solar Glance is an independent app. It is not affiliated with, endorsed by or sponsored by Ningbo Deye Inverter Technology Co., Ltd., Sunsynk or Solarman. All trademarks belong to their owners and are used only to describe compatibility.
```

## Description — Mac

```
Solar Glance puts your hybrid solar inverter in the macOS menu bar: battery charge, home load and a grid on/off plug icon — always visible, updated every few seconds.

Click it for the full picture: solar power, battery, grid import/export, today's energy and any parameters you pin. Desktop and Notification Center widgets are included.

It connects directly to the inverter's Solarman Wi‑Fi data logger on your local network. No cloud, no account, nothing leaves your network.

WORKS WITH
• Deye hybrid inverters (single-phase and three-phase), and other inverters with the same register map, such as Sunsynk
• Solarman Wi‑Fi data loggers (you need the logger's IP address and serial number)

FEATURES
• Choose exactly what appears in the menu bar — any value, in any order
• Grid status as a plug icon that is crossed out during an outage
• Parameters window with every value the inverter reports, plus raw registers
• Small and medium widgets
• Launch at login
• Demo mode to try it without an inverter

Solar Glance is an independent app. It is not affiliated with, endorsed by or sponsored by Ningbo Deye Inverter Technology Co., Ltd., Sunsynk or Solarman. All trademarks belong to their owners and are used only to describe compatibility.
```

## Keywords (≤100, через кому без пробілів)

```
solar,inverter,solarman,hybrid,battery,pv,photovoltaic,widget,energy,grid,outage,power,monitor,home
```
Торгових марок тут свідомо немає: Guideline 2.3.7 забороняє чужі бренди в keywords.
Пошук за словом "deye" все одно знаходитиме застосунок, бо воно є в підзаголовку.

## What's New (для першої версії)

```
First release.
```

## URL

| Поле | Значення |
|---|---|
| Support URL | `https://github.com/mrigne/deye-monitor/issues` |
| Marketing URL | `https://github.com/mrigne/deye-monitor` (необов'язково) |
| Privacy Policy URL | `https://github.com/mrigne/deye-monitor/blob/main/docs/PRIVACY.md` |

> ⚠️ Назва репозиторію `deye-monitor` у посиланнях допустима. Якщо хочете
> прибрати "deye" і звідти, перейменуйте репозиторій на GitHub (старі посилання
> перенаправляться).

## Інше

| Поле | Значення |
|---|---|
| Category | Primary: **Utilities**, Secondary: **Lifestyle** |
| Age Rating | всі відповіді "None" / "No" → **4+** |
| Price | Free |
| App Privacy | **Data Not Collected** |
| Copyright | `2026 Ihor Nerozia` |
| Content Rights | Does not contain, show, or access third-party content |

---

## App Review Information → Notes

```
Solar Glance reads a hybrid solar inverter (Deye and compatible models) through its Solarman Wi‑Fi data logger on the user's local network (TCP port 8899, Solarman V5 / Modbus). It has no server, account or sign-in.

To review without the hardware: on the first screen tap "Try demo (no inverter needed)". Demo mode shows realistic sample data in the app and in all widgets. It can be switched off in Settings.

Local Network permission is requested only to reach the user's own inverter.

The app is independent and states in its description and in Settings → About that it is not affiliated with or endorsed by Deye, Sunsynk or Solarman; these names are used only to describe compatibility.

A screen recording with a real inverter is attached.
```

**Attachment**: `appstore/review/solar-glance-review.mp4` — 35 с, реальний інвертор:
віджети «Not set up» → введення IP/SN → живі дані → pull-to-refresh → параметри →
віджети з живими даними. Файл не в git, бо в ньому видно IP і SN логера.
Перезаписати можна через Пункт керування → Запис екрана на телефоні.

---

## Скріншоти

Готові файли для завантаження:

| Куди | Файли | Розмір |
|---|---|---|
| iPhone 6.9" Display | `appstore/iphone/1-main.png` … `4-settings.png` | 1320×2868 |
| Mac | `appstore/mac/1-menubar.png`, `2-parameters.png` | 2880×1800 |

Порядок важливий: перший скріншот видно в результатах пошуку.
Достатньо 6.9" — менші розміри iPhone App Store Connect зменшує сам.
iPad-скріншоти не потрібні: застосунок тепер лише для iPhone.

Перегенерувати:
1. Сирі знімки iPhone: симулятор iPhone Pro Max → **Try demo** → `xcrun simctl io booted screenshot appstore/raw/ios-….png`.
2. Сирі знімки Mac: зберіть незапідписаний `DeyeMonitorMAS` і запустіть
   `Solar Glance.app/Contents/MacOS/DeyeMonitor -demo -screenshots <тека>`,
   потім скопіюйте PNG у `appstore/raw/mac/`.
3. `swift appstore/compose.swift` — збирає маркетингові скріншоти з підписами.

---

## Українська локалізація (необов'язково)

App Store Connect → App Information → Localizable Information → **+ Ukrainian**.

- **Name**: `Solar Glance: моніторинг СЕС` (iPhone) / `Solar Glance – Menu Bar` (Mac)
- **Subtitle**: `Дані інвертора Deye наживо`
- **Promotional Text**: `Генерація сонця, заряд батареї, споживання та стан мережі — наживо на екрані «Додому», заблокованому екрані чи в рядку меню. Без хмари та акаунтів.`
- **Description**:
```
Solar Glance показує, що зараз робить ваш гібридний сонячний інвертор: генерацію панелей, заряд батареї, споживання будинку та мережу — і тримає це на екрані «Додому» та заблокованому екрані.

Застосунок підключається напряму до Wi‑Fi‑логера Solarman у вашій домашній мережі. Без хмари, без акаунта, дані не виходять за межі вашої мережі.

ПРАЦЮЄ З
• гібридними інверторами Deye (одно- і трифазними) та сумісними, наприклад Sunsynk
• Wi‑Fi‑логерами Solarman (потрібні IP-адреса і серійний номер логера)

МОЖЛИВОСТІ
• сонце, споживання, імпорт/експорт мережі, напруга
• заряд, потужність і стан батареї
• чи є світло — одразу видно, коли відключення
• енергія за сьогодні в кВт·год
• віджети для екрана «Додому» і заблокованого екрана
• будь-які параметри інвертора, навіть «сирі» регістри
• демо-режим без інвертора

Solar Glance — незалежний застосунок, не пов'язаний з Ningbo Deye Inverter Technology Co., Ltd., Sunsynk чи Solarman і не схвалений ними. Торгові марки належать їхнім власникам і згадуються лише для опису сумісності.
```
- **Keywords**: `сонячна,інвертор,СЕС,батарея,панелі,віджет,енергія,світло,відключення,мережа,solar,inverter`
