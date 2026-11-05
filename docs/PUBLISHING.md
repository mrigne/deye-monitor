# Публікація Deye Monitor

Є три способи розповсюдження. Всі збираються з одного коду.

| Канал | Що | Як збирається |
|---|---|---|
| **GitHub Releases** | `.pkg` для Mac (Developer ID, нотаризований) | `release.yml` на тег `v*` |
| **App Store (iPhone/iPad)** | схема `DeyeMonitoriOS` | `appstore.yml` на тег `v*` → TestFlight |
| **Mac App Store** | схема `DeyeMonitorMAS` (sandbox + App Group) | `appstore.yml` на тег `v*` → TestFlight |

Один тег `v1.2.0` запускає все: GitHub Release з `.pkg` і завантаження обох
збірок в App Store Connect. Далі ви на сайті Apple обираєте збірку і подаєте
її на перевірку.

Team ID: `CR2SHW9GDN`

| Ідентифікатор | Значення |
|---|---|
| iOS app / widget | `ua.com.mrigne.deyemonitor.ios` / `ua.com.mrigne.deyemonitor.ios.widget` |
| iOS App Group | `group.ua.com.mrigne.deyemonitor` |
| Mac app / widget (і pkg, і Mac App Store) | `ua.com.mrigne.deyemonitor` / `ua.com.mrigne.deyemonitor.widget` |
| Mac App Group (тільки Mac App Store) | `CR2SHW9GDN.ua.com.mrigne.deyemonitor` |

---

## Частина 1. Одноразове налаштування

### 1.1 API-ключ з роллю Admin

CI підписує збірки для App Store через Apple *cloud signing*. Сертифікати
Apple Distribution при цьому не треба експортувати в GitHub, але ключ
App Store Connect API **повинен мати роль Admin**.

1. https://appstoreconnect.apple.com → **Users and Access → Integrations →
   App Store Connect API → Team Keys**.
2. Знайдіть ключ, чий ID записаний у секреті `NOTARY_KEY_ID`, і подивіться колонку *Access*.
   - **Admin**: нічого робити не треба.
   - Інша роль: натисніть **+** і створіть новий ключ з Access = **Admin**.
     Скачайте `AuthKey_XXXX.p8` (скачати можна лише один раз) і оновіть три секрети в
     GitHub → repo → **Settings → Secrets and variables → Actions**:
     ```bash
     base64 -i ~/Downloads/AuthKey_XXXX.p8 | pbcopy     # → NOTARY_KEY_P8
     ```
     `NOTARY_KEY_ID` = Key ID, `NOTARY_ISSUER` = Issuer ID (вгорі сторінки).
     Нотаризація `.pkg` працює і з новим ключем.

### 1.2 Угоди

App Store Connect → **Business** (або *Agreements, Tax, and Banking*).
Прийміть актуальну **Apple Developer Program License Agreement**. Для безкоштовного
застосунку податки й банк заповнювати не треба.

### 1.3 Ідентифікатори

Зареєстровані автоматично (Xcode створив App ID і профілі для App Store).
Перевірити: https://developer.apple.com/account/resources/identifiers

| Тип | Identifier |
|---|---|
| App IDs | `ua.com.mrigne.deyemonitor`, `ua.com.mrigne.deyemonitor.widget`, `ua.com.mrigne.deyemonitor.ios`, `ua.com.mrigne.deyemonitor.ios.widget` |
| App Groups (фільтр праворуч вгорі → App Groups) | `group.ua.com.mrigne.deyemonitor` |

Mac App Group `CR2SHW9GDN.ua.com.mrigne.deyemonitor` у списку не з'являється.
Групи з префіксом Team ID окремої реєстрації не потребують.

Якщо чогось бракує, додайте вручну: **Identifiers → +**.
- **App IDs → App** → Description `Deye Monitor`, Bundle ID **Explicit** → ідентифікатор
  з таблиці. Для iOS-пари ввімкніть **App Groups** → *Configure* →
  `group.ua.com.mrigne.deyemonitor`. Для Mac-пари теж ввімкніть **App Groups**.
- **App Groups** → Description `Deye Monitor`, ID `group.ua.com.mrigne.deyemonitor`.

Або простіше: Xcode → схема → **Product → Archive → Distribute App → App Store Connect →
Export**. Xcode сам допише відсутнє.

Старі `dev.deye.monitor*` (з версії 1.0.0) можна видалити:
Identifiers → ідентифікатор → **Remove**.

### 1.4 Записи застосунків у App Store Connect

**Apps → + → New App**, двічі:

| Поле | iPhone | Mac |
|---|---|---|
| Platforms | iOS | macOS |
| Name | унікальна назва в App Store, напр. **"Solar Monitor for Deye"** | можна ту саму |
| Primary language | English (або Ukrainian) | |
| Bundle ID | `ua.com.mrigne.deyemonitor.ios` | `ua.com.mrigne.deyemonitor` |
| SKU | `deye-monitor-ios` | `deye-monitor-mac` |
| User Access | Full Access | Full Access |

> ⚠️ **Назва.** "Deye" — чужа торгова марка. Назву "Deye Monitor" Apple
> найімовірніше відхилить (Guideline 5.2.1). Беріть щось на зразок *"Solar Monitor
> for Deye"* / *"Inverter Monitor – Solarman"*, а в описі пишіть
> "compatible with Deye / Sunsynk hybrid inverters". Назва під іконкою
> (CFBundleDisplayName) може лишатись коротшою.

Без цих записів завантаження з CI падає з помилкою *"No suitable application records were found"*.

### 1.5 Privacy Policy

Файл уже є: [`docs/PRIVACY.md`](PRIVACY.md).
URL для App Store Connect: `https://github.com/mrigne/deye-monitor/blob/main/docs/PRIVACY.md`

---

## Частина 2. Випуск нової версії (щоразу)

```bash
git tag v1.2.0
git push origin v1.2.0
```

У GitHub → **Actions** запускаються:
- **Release** — `.pkg` на сторінці GitHub Releases;
- **App Store** — дві задачі (`ios`, `macos`): archive → cloud signing → upload.
  У *Summary* буде рядок "uploaded — see TestFlight".

Версію (`1.2.0`) CI бере з тегу. Номер збірки ставиться автоматично
(номер запуску GitHub), тож він завжди зростає.

Завантажити без тегу: **Actions → App Store → Run workflow** → `both` / `ios` / `macos`.
Версія тоді береться з `MARKETING_VERSION` у `project.yml`.

Через 10–30 хв Apple обробить збірку і надішле email *"has completed processing"*.

Без CI те саме можна зробити з Xcode: схема `DeyeMonitoriOS` (пристрій *Any iOS Device*)
або `DeyeMonitorMAS` (*Any Mac*) → **Product → Archive → Distribute App →
App Store Connect → Upload**.

---

## Частина 3. TestFlight (до публікації)

App Store Connect → застосунок → **TestFlight**.

- **Internal Testing** → *+* → група → додайте себе. Збірка доступна одразу, без рецензії.
- **External Testing**: до 10 000 людей, за email або публічним посиланням. Перша збірка
  проходить коротку бета-рецензію (~1 день).
- Встановлення:
  - на iPhone — застосунок **TestFlight** з App Store;
  - на Mac — **TestFlight** з Mac App Store.

Шифрування вже задекларовано в Info.plist (`ITSAppUsesNonExemptEncryption = NO`),
тож питань про export compliance не буде.

---

## Частина 4. Подача на рецензію і реліз

App Store Connect → застосунок → вкладка платформи → версія **1.x (Prepare for Submission)**.

### 4.1 Сторінка версії

| Поле | Що вписати |
|---|---|
| **Screenshots** | iPhone 6.9" — **1320×2868** (обов'язково). Якщо лишаєте iPad — ще iPad 13" **2064×2752**. Mac — **2880×1800** (або 1440×900). Від 1 до 10 штук. |
| Promotional Text | необов'язково |
| **Description** | що робить: дані інвертора напряму через Wi‑Fi‑логер Solarman, віджети, без хмари |
| Keywords | `solar,inverter,deye,sunsynk,solarman,battery,pv,widget,energy` |
| **Support URL** | `https://github.com/mrigne/deye-monitor` |
| Marketing URL | необов'язково |
| Version / Copyright | `2026 Ihor Nerozia` |
| **Build** | **+** → збірка, яку завантажив CI |

**Скріншоти:**
- *iPhone:* симулятор **iPhone 18 Pro Max** (екран 6.9") → застосунок → **⌘S**
  (файл зберігається на робочий стіл у потрібному розмірі). Зробіть 3–4: головний екран,
  параметри, віджет на домашньому екрані, екран блокування.
- *Mac:* відкрийте панель з рядка меню та вікно Parameters, натисніть ⇧⌘5 і
  збережіть, а потім обріжте зображення до 2880×1800 (Preview → Tools → Adjust Size).

### 4.2 App Information (ліве меню)

- **Category**: Utilities (secondary: Weather або Lifestyle).
- **Content Rights**: "does not contain third-party content".
- **Age Rating**: заповнити анкету, всі відповіді "None/No" → 4+.
- **Privacy Policy URL**: див. 1.5.

### 4.3 App Privacy (ліве меню)

**Get Started → Data Types → "No, we do not collect data from this app"** → Publish.

### 4.4 Pricing and Availability

Price: **Free (0)**. Availability: всі країни (або виберіть потрібні).

### 4.5 App Review Information (внизу сторінки версії)

- Contact: ваше ім'я, телефон, email.
- Sign-in required: **No**.
- **Notes**:
  > This app reads a Deye/Sunsynk hybrid solar inverter through its Solarman
  > Wi‑Fi data logger on the user's local network (TCP port 8899, Solarman V5 /
  > Modbus). It has no server or account. Without such hardware the app shows the
  > setup screen; a screen recording of it working with a real inverter is attached.
- **Attachment**: 20–40 с відео з телефона (Пункт керування → запис екрана),
  де видно: введення IP/SN → живі дані → віджет. **Обов'язково.** Без відео часто
  відхиляють за Guideline 2.1 ("can't verify functionality").

### 4.6 Відправка

**Add for Review → Submit to App Review**. Зазвичай перевірка триває 24–48 год.
Перед подачею оберіть *Version Release*:
- *Manually release* — після схвалення ви самі натискаєте **Release**;
- *Automatically* — застосунок виходить одразу після схвалення.

Mac і iPhone подаються окремо (різні записи), але кроки однакові.

### 4.7 Оновлення

Новий тег → CI завантажує збірку → в App Store Connect **+ (поруч з версією) →
нова версія 1.x** → "What's New" → вибрати збірку → Submit.

---

## Частина 5. Чим Mac App Store версія відрізняється від `.pkg`

| | `.pkg` (GitHub) | Mac App Store |
|---|---|---|
| Схема | `DeyeMonitor` | `DeyeMonitorMAS` (прапорець `MAS`) |
| Sandbox | ні | так (`network.client`) |
| Дані для віджета | `~/Library/Application Support/DeyeMonitor` | App Group `CR2SHW9GDN.ua.com.mrigne.deyemonitor` |
| Автозапуск | LaunchAgent для всіх користувачів | перемикач **Launch at login** у налаштуваннях застосунку |
| Префіл IP/SN інсталятором | так (`--prefill`) | ні |

Обидві версії мають однаковий Bundle ID. На одному Mac краще тримати лише одну
з них. Перед установкою з App Store видаліть `.pkg`-версію:
`sudo bash DeyeMonitor-uninstall.sh`.

---

## Частина 6. Поставити на свій iPhone без App Store (розробка)

1. iPhone: **Settings → Privacy & Security → Developer Mode → On**.
2. Підключіть кабелем, натисніть *Trust*.
3. Відкрийте проєкт:
   ```bash
   open DeyeMonitor.xcodeproj
   ```
   Схема **DeyeMonitoriOS**, ваш iPhone → ⌘R.
4. На телефоні: IP і SN → **Save** → **Allow** Local Network.
5. Віджети: затисніть домашній екран → **Edit → Add Widget → Deye Monitor**.
   На екрані блокування: затисніть його → **Customize**.

---

## Якщо щось пішло не так

| Помилка в CI | Причина / що робити |
|---|---|
| `Cloud signing permission error` / `No signing certificate "iOS Distribution"` | Ключ API не Admin → п. 1.1 |
| `No suitable application records were found` | Нема запису застосунку → п. 1.4 |
| `The bundle version must be higher than the previously uploaded version` | Перезапустіть workflow, номер збірки зросте |
| `Provisioning profile doesn't include the App Groups entitlement` | Відкрийте проєкт у Xcode, Archive відповідної схеми локально (Xcode оновить профілі) і перезапустіть CI |
| `Missing required icon` / `Invalid Info.plist` | Напишіть мені з текстом помилки з логу |
| Рецензія: Guideline 2.1 (не змогли перевірити) | Додайте/оновіть відео і відповідайте в Resolution Center |
| Рецензія: Guideline 5.2.1 (торгова марка) | Змініть назву (п. 1.4), заберіть "Deye" з назви/субтитру |
