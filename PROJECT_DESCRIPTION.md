# Daily Account

**The spiritual accountability companion for serious disciples of Christ.**

Daily Account is a beautifully crafted, offline-first mobile application built for the CMFI (Christian Missionary Fellowship International) discipleship tradition. It empowers believers to faithfully track their daily spiritual disciplines, build holy habits through powerful analytics, and stay accountable to their disciple maker — all from one sacred space on their phone.

---

## Vision

Every disciple of Christ needs a system of accountability. Daily Account replaces scattered notebooks, forgotten journals, and inconsistent self-reports with a single, elegant tool that makes spiritual discipline tracking effortless, insightful, and beautiful.

The app is designed to feel like opening a leather-bound devotional — warm espresso tones, gold-leaf accents, and serif typography that honors the gravity of the spiritual life it serves.

---

## Core Features

### 1. Daily Spiritual Discipline Logging

Track 10+ core CMFI disciplines every day with auto-saving — no "submit" button needed. Every field change is persisted instantly.

| Discipline | What's Tracked |
|---|---|
| **Bible Reading** | Scripture reference, number of chapters, book autocomplete (all 66 books) |
| **Christian Literature** | Multiple entries — title, amount, unit (pages/chapters/books) |
| **DDEG** (Daily Dynamic Encounter with God) | Scripture passage, time spent, personal notes |
| **Prayer — Alone** | Duration (timer or manual), personal notes |
| **Prayer — With Others** | Duration, context (who/where/what) |
| **Evangelism** | Contacts reached, outcome, notes, new believers count, discipleship follow-up |
| **Fasting** | Type (complete/partial/Esther fast), duration, prayer focus |
| **Giving** | Type, amount, purpose |
| **Church Attendance** | Type of gathering, notes |
| **Discipleship** | Who was discipled, topic covered, duration |
| **Proclamation** | Count of proclamations, duration |
| **Other Activities** | Free-text for anything not covered above |

Each day shows a **progress ring** (0–100%) calculated across all disciplines, giving an at-a-glance view of spiritual engagement.

### 2. Activity Stopwatch

A dedicated stopwatch screen lets users time any spiritual activity in real time.

- **10 built-in activities** — Bible Reading, Literature, DDEG, Prayer (Alone), Prayer (Others), Evangelism, Fasting, Discipleship, Church, Proclamation
- **Custom activities** — Users define their own activities with custom names, emoji icons, and optional pre-start fields
- **One-at-a-time enforcement** — Starting a new timer auto-pauses the previous one
- **Pre-start context capture** — Before the timer starts, relevant fields are collected (e.g., Bible book/chapter for Bible Reading, prayer focus for Prayer)
- **Auto-write to daily log** — When a timer stops, the duration and captured fields are automatically merged into today's log entry (durations accumulate, text fields append)
- **Android Foreground Service** — The timer runs in a native foreground service that survives app backgrounding and system kills. The notification displays a real-time Android chronometer that counts independently of the Dart isolate.
- **Floating Overlay** — An optional draggable bubble displays the running timer over other apps (requires SYSTEM_ALERT_WINDOW permission). Tap to expand/collapse. Themed in the app's espresso + gold palette.
- **Notification Controls** — Pause and Stop buttons directly in the notification shade.

### 3. Weekly & Monthly Reports

Comprehensive accountability reports generated automatically from logged data.

- **Two report formats:**
  - **Full Report** — Detailed day-by-day breakdown with all fields. Optimized for email and clipboard.
  - **Compact Report** — Summary-first with condensed daily notes. Optimized for WhatsApp's message length limits.
- **Monthly Reports** — Aggregated statistics across an entire month.
- **Delivery channels:**
  - Email (pre-filled with disciple maker's address and formatted subject line)
  - WhatsApp (deep link with compact report pre-loaded)
  - System share sheet (any app)
  - PDF export (beautifully formatted, shareable/printable)
  - Clipboard copy
- **Report History** — All generated reports are archived in SQLite with send tracking (when, via which channel). Viewable, re-sendable, and deletable.
- **Pending Report Queue** — If sending fails (offline, app closed), the report is queued and can be retried.

### 4. Analytics Dashboard

The Report screen doubles as an analytics hub with rich data visualization.

- **Weekly completion bar chart** (fl_chart) — 7 bars showing daily completion percentage
- **Streak counter** — Consecutive days with at least one discipline logged
- **Week/month statistics** — Bible chapters read, evangelism contacts, literature items, prayer minutes
- **Trend analysis** — Current week consistency vs. last month, with up/down/steady indicators
- **Per-discipline breakdown** — Identifies strongest and weakest disciplines
- **Goal tracking** — User-set targets (daily or weekly) for Bible chapters, prayer minutes, evangelism contacts, and literature items. Visual progress bars show goal attainment.
- **Achievement badges** — Earned badges for milestones (e.g., 7-day streak, 10+ chapters in a week). Displayed as earned vs. locked.

### 5. Prayer Request Tracker

A dedicated screen for managing prayer requests with lifecycle tracking.

- **Add requests** with title, description, and category (Personal, Family, Church, Nation)
- **Mark as answered** — Record when and how God answered
- **Toggle view** between active and answered requests
- **Full CRUD** — Create, read, update, delete with confirmation dialogs
- **Timestamps** — Creation date and answer date tracked

### 6. Fasting Period Tracker

Multi-day fasting support beyond the daily log.

- **Three fasting types** — Complete, Partial, Esther (aligned with CMFI tradition)
- **Date range** — Start and end dates with day counter (e.g., "Day 3 of 7")
- **Active fast indicator** — Shows current progress on ongoing fasts
- **Prayer focus** — Dedicated field for the spiritual intention of the fast
- **History** — View all past fasting periods

### 7. Voice Notes

Audio recording and playback attached to each daily log entry.

- **Record** voice reflections, prayers, or sermon notes
- **Playback** with full audio controls
- **One per day** — Voice note is stored alongside the day's log entry
- **Persistent** — Audio files saved to app storage, path stored in database

### 8. Android Home Screen Widgets

Four native Android widgets built with Kotlin and the `home_widget` Flutter package.

| Widget | Size | Function |
|--------|------|----------|
| **Discipline Bar** | Variable | Shows today's completion progress across disciplines |
| **Full Altar** | Large | Comprehensive view of today's spiritual activity |
| **Proclamation Counter** | 2x2 | Tap-to-increment proclamation counter |
| **Scripture Card** | Variable | Displays a daily scripture verse |

All widgets receive live data from the Flutter app, support deep-linking back into specific app sections, and include timer controls.

### 9. Smart Notifications

A comprehensive notification system with multiple channels.

- **Per-discipline reminders** — Set individual reminder times for each discipline (e.g., Bible reading at 6:00 AM, prayer at 9:00 PM)
- **Sunday send reminder** — Prompts user to send their weekly report
- **Scheduled via `flutter_local_notifications`** with proper timezone handling
- **Action buttons** — Notification actions for timer control (Pause/Stop) directly from the notification shade

### 10. Daily Reflection

An intelligent, contextual reflection card that appears on each day's log.

- **Dynamic messaging** based on completeness (great day / good day / getting started)
- **Focus suggestions** — Identifies unfilled disciplines and encourages engagement
- **AI reflection field** — Space for AI-generated or personal reflections (model field: `aiReflection`)

---

## Design & User Experience

### Theme: "The Sacred Ledger"

The visual language draws from illuminated manuscripts and leather-bound journals.

- **Dark mode (Espresso):** Deep browns (#0D0A05 → #241A0C), gold accents (#D4AF64), cream text (#F0E8D8)
- **Light mode (Parchment):** Warm whites (#FFFDF8 → #EDE6D6), rich deep gold (#9A7B1C), near-black text (#1A1207)
- **Typography:** Cormorant Garamond (display headings) + Lora (body text) via Google Fonts
- **Animations:** Subtle entrance animations via `flutter_animate` — fade-ins, slides, and staggered reveals
- **Gold gradient accents** on primary actions and progress indicators
- **Section cards** with collapsible sections, emoji icons, and gold borders

### Navigation

4-tab bottom navigation with emoji icons:
1. **Stopwatch** — Activity timer hub
2. **Log** — Daily discipline entry (with week strip for date navigation)
3. **Report** — Analytics dashboard and report sending
4. **Settings** — Profile, preferences, and data management

### Splash Screen

An animated illuminated-manuscript-style splash with:
- Golden cross with radiating light rays
- Ornamental rings with rotation animation
- Staggered typography fade-in
- Automatic routing to onboarding (first launch) or home screen

### Onboarding

A 4-page guided setup for first-time users:
1. **Welcome** — App introduction
2. **How It Works** — Feature overview
3. **Profile Setup** — Name, disciple maker's email and WhatsApp number
4. **Language Selection** — English or French

---

## Security & Privacy

- **App Lock** — Biometric authentication (fingerprint/face) or PIN via `local_auth`
- **100% Offline** — No server, no cloud, no account creation. All data stays on device.
- **Local SQLite database** — Encrypted with device-level security
- **No analytics or tracking** — Zero telemetry, zero data collection

---

## Data Management

### Storage

- **SQLite** — Primary database for logs, reports, prayer requests, fasting periods
- **SharedPreferences** — Settings, timer state, custom activities, goals
- **File system** — Voice note audio files, backup archives

### Backup & Restore

- **Auto-backup** — Silent backup on every app launch (throttled to once per 6 hours)
- **Manual backup** — Export full database as a file
- **Restore** — Import from backup file with confirmation dialog
- **Backup includes:** All logs, settings, reports, prayer requests, fasting periods, custom activities

---

## Internationalization

Full bilingual support:
- **English** (default)
- **French** (complete translation)
- ~320 localization strings per language
- Language switchable at runtime from Settings or Onboarding
- Date formatting respects locale

---

## Technical Architecture

### Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Flutter (Dart) |
| **Min SDK** | Android 21 (Lollipop 5.0) |
| **Database** | SQLite via `sqflite` |
| **Settings** | `shared_preferences` |
| **Notifications** | `flutter_local_notifications` |
| **Background Service** | `flutter_background_service` |
| **Floating Overlay** | `flutter_overlay_window` |
| **PDF Generation** | `pdf` + `printing` |
| **Charts** | `fl_chart` |
| **Audio** | `record` + `audioplayers` |
| **Home Widgets** | `home_widget` + native Kotlin providers |
| **Biometrics** | `local_auth` |
| **Sharing** | `share_plus` + `url_launcher` |
| **Typography** | `google_fonts` |
| **Animations** | `flutter_animate` |

### Architecture Pattern

**Singleton service-based** — No external state management library (no Provider, Riverpod, or BLoC). Services are singletons accessed via `ServiceName.instance`. Screens are StatefulWidgets that call services directly.

```
Models → Services → Screens
```

- **Models** define data structures with `toMap()`/`fromMap()` serialization
- **Services** handle all business logic, persistence, and platform integration
- **Screens** are pure UI with inline state management

### Services

| Service | Responsibility |
|---------|---------------|
| `StorageService` | SQLite CRUD, SharedPreferences, database migrations |
| `TimerService` | Activity stopwatch lifecycle, session persistence, log writing |
| `BackgroundTimerService` | Android foreground service for background timer execution |
| `NotificationService` | Scheduling, display, and action handling for all notifications |
| `ReportService` | Report generation (full/compact/monthly), statistics, trends, delivery |
| `PdfReportService` | PDF document generation and sharing |
| `BackupService` | Auto-backup, manual export/import, data restoration |

### Key Design Decisions

- **Auto-persistence** — No save buttons. Every field change triggers immediate write to database.
- **Date-keyed storage** — All logs indexed by `yyyy-MM-dd` string keys for simple retrieval.
- **Duration accumulation** — Timer sessions add to existing durations rather than overwriting, supporting multiple sessions per discipline per day.
- **Native chronometer** — Android notification uses `usesChronometer: true` for system-level time display that runs independently of the Dart isolate.
- **Foreground service** — Dedicated background isolate ensures timer survives app suspension.

---

## Android Permissions

| Permission | Purpose |
|-----------|---------|
| `POST_NOTIFICATIONS` | Daily reminders and timer notifications |
| `RECEIVE_BOOT_COMPLETED` | Reschedule notifications after device reboot |
| `SCHEDULE_EXACT_ALARM` | Precise daily reminder scheduling |
| `USE_EXACT_ALARM` | Precise alarm support (Android 12+) |
| `WAKE_LOCK` | Keep device awake during timer operations |
| `VIBRATE` | Notification vibration |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Prevent timer/notification throttling |
| `USE_FULL_SCREEN_INTENT` | Alarm-style notification display |
| `FOREGROUND_SERVICE` | Background timer execution |
| `FOREGROUND_SERVICE_SPECIAL_USE` | Foreground service type (Android 14+) |
| `SYSTEM_ALERT_WINDOW` | Floating timer overlay |
| `RECORD_AUDIO` | Voice note recording |

---

## Project Metadata

- **Package name:** `com.jilengineering.dailyaccount`
- **App name:** Daily Account
- **Version:** 2.0.0+4
- **Publisher:** JIL Engineering (EmmanuelTechLabs)
- **Platforms:** Android (primary), iOS (project exists, not primary target)
- **Languages:** English, French
- **License:** Proprietary
- **Dart SDK:** >=3.2.0 <4.0.0

---

## File Structure

```
lib/
  main.dart                          # App entry point + overlay entry point
  theme/
    app_theme.dart                   # Color palette, typography, gradients
  models/
    daily_log.dart                   # DailyLog + LiteratureEntry
    activity_timer.dart              # ActivityType, TimerKey, TimerSession
    custom_activity.dart             # User-defined activities
    prayer_request.dart              # Prayer request lifecycle
    fasting_period.dart              # Multi-day fasting tracker
    saved_report.dart                # Archived report with send history
  services/
    storage_service.dart             # SQLite + SharedPreferences
    timer_service.dart               # Stopwatch lifecycle + overlay/service integration
    background_timer_service.dart    # Android foreground service isolate
    notification_service.dart        # Scheduling + display + actions
    report_service.dart              # Report generation + delivery
    pdf_report_service.dart          # PDF formatting + export
    backup_service.dart              # Auto/manual backup + restore
  screens/
    splash_screen.dart               # Animated illuminated-manuscript splash
    onboarding_screen.dart           # 4-page first-time setup
    lock_screen.dart                 # Biometric/PIN authentication
    home_shell.dart                  # Tab navigation + week strip + pending report handling
    log_screen.dart                  # Daily discipline entry (1654 lines)
    stopwatch_screen.dart            # Activity timer hub (1420 lines)
    report_screen.dart               # Analytics dashboard + report sending (1069 lines)
    report_history_screen.dart       # Archived reports list
    settings_screen.dart             # Profile, reminders, backup, app info
    prayer_request_screen.dart       # Prayer request CRUD
  widgets/
    common_widgets.dart              # SectionCard, GoldField, ProgressRing, StatTile
    timer_overlay.dart               # Floating timer bubble
  utils/
    bible_books.dart                 # All 66 book names for autocomplete
  l10n/
    app_en.arb                       # English strings (~320 entries)
    app_fr.arb                       # French strings (~320 entries)
    generated/                       # Auto-generated localization classes
assets/
  verses.json                        # 14 bilingual scripture verses
  app_icon.png                       # App launcher icon
android/
  app/src/main/kotlin/.../
    MainActivity.kt                  # Flutter activity
    WidgetHelper.kt                  # Shared widget utilities
    DisciplineBarWidgetProvider.kt   # Discipline progress widget
    FullAltarWidgetProvider.kt       # Full daily overview widget
    ProclamationWidgetProvider.kt    # Tap-to-increment widget
    ScriptureWidgetProvider.kt       # Daily verse widget
```

---

## What Makes Daily Account Unique

1. **Purpose-built for CMFI discipleship** — Not a generic habit tracker. Every field, every metric, every report format is tailored to the specific spiritual disciplines practiced in CMFI communities worldwide.

2. **Accountability by design** — The weekly report system with direct WhatsApp/email delivery to a disciple maker creates a real human accountability loop, not just self-tracking.

3. **Offline-first with zero compromise** — No account creation, no cloud dependency, no data harvesting. A disciple in rural Cameroon with intermittent connectivity can use every feature.

4. **The Sacred Ledger aesthetic** — This is not another flat, sterile productivity app. The espresso-and-gold design language communicates that what you're tracking matters — it's sacred work.

5. **Activity stopwatch with background persistence** — Time your prayers, your Bible study, your evangelism outreach. The timer runs in a native foreground service, displays over other apps, and automatically writes completed sessions to your daily log.

---

*Built with love for the Body of Christ.*
*JIL Engineering / EmmanuelTechLabs*
