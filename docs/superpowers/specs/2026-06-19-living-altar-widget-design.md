# The Living Altar — Android Widget Redesign

**Date**: 2026-06-19
**Status**: Approved
**App**: Daily Account (CMFI spiritual accountability)

---

## Overview

Replace the current monolithic 4x3 Android home screen widget with four purpose-built widgets ("The Living Altar" system) that prioritize actionability, spiritual motivation, and polished UI design. All widgets feature real-time sync with app activity — no stale data. All user-facing text on widgets respects the app's current language setting (English/French).

## Design Priorities

1. **Actionability** — do more from the home screen without opening the app (toggle disciplines, control timers)
2. **Spiritual motivation** — time-aware scripture and proclamations that inspire throughout the day
3. **Great UI design** — espresso + gold-leaf palette, Cormorant Garamond + Lora typography, cohesive with app identity

## Visual Identity

- **Background**: Espresso dark with subtle radial gradient
- **Accent**: Gold (#D4A843) for completed states, active elements, borders
- **Muted**: Sand color for pending/secondary text
- **Typography**: Cormorant Garamond (numbers, scripture, headings), Lora (labels, body)
- **Border**: Thin gold border (1dp), rounded corners (Android 12+ widget style)
- **Signature**: Cross watermark at 10% opacity where space allows

## Language Awareness

All widget text respects the app's in-app language setting (English or French). The app saves its current locale to SharedPreferences key `widget_locale` (`"en"` or `"fr"`). Each widget provider reads this value on every `onUpdate()` and selects the appropriate strings:

- Labels (e.g., "Daily Verse" / "Verset du Jour", "Proclamations Today" / "Proclamations Aujourd'hui")
- Discipline abbreviations (BIB, LIT, DDG, PRY, EVG — kept as abbreviations in both languages for space)
- Button text ("Start Timer" / "Démarrer", "Open Log" / "Ouvrir Journal")
- Motivational text ("Keep your streak alive" / "Maintenez votre série")
- The proclamation: "JESUS CHRIST IS THE LORD" / "JÉSUS-CHRIST EST LE SEIGNEUR"

String resources are defined in `res/values/strings.xml` (English) and `res/values-fr/strings.xml` (French).

---

## Widget 1: Scripture Card (2x2)

### Purpose
Pure spiritual motivation — a beautiful, living piece of scripture on the home screen.

### Layout
- Espresso background with subtle radial gradient (slightly lighter center)
- Faint cross watermark at 10% opacity, centered
- Scripture text in Cormorant Garamond italic, gold, centered vertically
- Small reference below in Lora, muted sand color
- Bottom edge: thin gold divider line, then label — "Daily Verse" or "Proclamation" in small caps

### Content Rotation Logic
- **6:00 AM – 12:00 PM**: Daily Bible verse (from curated list of ~365 verses, indexed by day-of-year)
- **12:00 PM – 10:00 PM**: Fixed proclamation — "JESUS CHRIST IS THE LORD" / "JÉSUS-CHRIST EST LE SEIGNEUR" (based on app language). Label changes to "Proclamation".
- **If DDEG was logged today**: Override with user's own scripture reference + "Your Word Today" / "Votre Parole Aujourd'hui" label
- Widget refreshes every 30 minutes via Android `AlarmManager`
- Also refreshes on any piggyback widget update (discipline toggle, timer change)

### Interaction
- Tap anywhere → Opens the app to today's log screen

### Content Sources
- `assets/verses.json` — 365 curated daily verses (indexed by day-of-year), with `en` and `fr` translations per entry
- Proclamation text is hardcoded in string resources (no JSON needed) — one fixed declaration in each language

---

## Widget 2: Discipline Bar (4x2)

### Purpose
Actionability — quick-toggle disciplines and see today's progress at a glance.

### Layout

**Left portion (1/4 width)**:
- Circular completion ring, gold stroke on espresso background
- Percentage number inside the ring in Cormorant Garamond bold
- Streak counter below the ring — small flame icon + number in sand color

**Right portion (3/4 width)**:
- Single horizontal row of 5 discipline icons, evenly spaced
- Each icon inside a small rounded square (pill shape)
- **Completed**: Gold-filled background, white icon — glowing, alive
- **Pending**: Dark espresso background, muted sand icon — waiting
- Below each icon: 3-letter label in tiny Lora (BIB, LIT, DDG, PRY, EVG)

### Discipline Mapping
1. **BIB** — Bible chapters
2. **LIT** — Christian literature
3. **DDG** — DDEG (devotional/exegetical guide)
4. **PRY** — Prayer
5. **EVG** — Evangelism

### Interaction
- Tap any discipline icon → Toggles on/off immediately via deep link `dailyaccount://toggle/{discipline}`
- Tap the completion ring → Opens the app to today's log
- Ring and icons update in real-time after toggle (~100ms)

---

## Widget 3: Full Altar (4x3)

### Purpose
The complete experience — scripture, disciplines, and timer control in one cohesive widget.

### Layout (Three Horizontal Zones)

#### Top Zone — Scripture Strip
- Full-width bar, slightly darker espresso than the body
- Scripture text in Cormorant Garamond italic, gold, single line (ellipsized if long)
- Small reference right-aligned in sand
- Thin gold divider separating from middle zone
- Same time-aware content rotation as Scripture Card widget

#### Middle Zone — Discipline Row + Progress
- Identical layout to the Discipline Bar widget
- Completion ring on left, 5 toggleable discipline icons on right
- Same interaction model (tap icon = toggle, tap ring = open app)
- Streak flame + count tucked under the ring

#### Bottom Zone — Timer Controls (Adaptive)

**When no timer is running:**
- Two action buttons side by side:
  - "Start Timer" (gold fill) — tapping shows discipline picker (Prayer | Bible | Literature) as 3 gold-outlined pills, tapping one starts the timer immediately
  - "Open Log" (outline style)
- Subtle motivational line between buttons: "5 of 7 days this week" or "Keep your streak alive" in small sand text

**When a timer IS running:**
- Left: discipline label + elapsed time in large Cormorant Garamond numerals (e.g., "Prayer — 12:34")
- Right: Pause button (gold outline) and Stop button (clay/red outline)
- Subtle pulsing gold dot next to the time to indicate "live"
- Tapping Stop saves the duration to today's log automatically

### Timer Display — Chronometer Approach
- Uses Android's built-in `Chronometer` RemoteView for real-time counting without update loops
- When timer starts: set `Chronometer.base` to `SystemClock.elapsedRealtime() - elapsedMs`, call `start()`
- When timer pauses/stops: call `stop()`, show frozen time
- Battery-efficient — OS handles the counting, no `AlarmManager` polling needed

---

## Widget 4: Proclamation Counter (2x2)

### Purpose
Actionability + spiritual motivation — tap to declare "Jesus Christ is the Lord" throughout the day without opening the app.

### Layout
- Espresso background, thin gold border, rounded corners
- Large counter number in Cormorant Garamond bold, gold, centered (e.g., "47")
- Below the number: "JESUS CHRIST IS THE LORD" or "JÉSUS-CHRIST EST LE SEIGNEUR" (based on app language) in small caps Lora, sand color, max 2 lines
- Bottom edge: thin gold divider, then label "Proclamations Today" / "Proclamations Aujourd'hui" in tiny Lora, muted sand

### Interaction
- **Tap anywhere** → Increments counter by 1, widget updates instantly
- **Long press** → Opens app to the full proclamation screen
- Counter resets daily at midnight (via `AlarmManager` or on first tap of new day)

### Real-Time Sync
- Each tap fires deep link `dailyaccount://proclamation/increment`
- App receives via `HomeWidget.widgetClicked`, increments `proclamationCount` on today's `DailyLog`, saves to SQLite
- Immediately saves updated `proclamation_count` to SharedPreferences → calls `HomeWidget.updateWidget()`
- If user increments in-app (on the proclamation screen), widget updates immediately too
- Counter value persisted in SharedPreferences key `proclamation_count` (int)

### Language
- Proclamation text and label read from `res/values/strings.xml` or `res/values-fr/strings.xml` based on `widget_locale` SharedPreferences value

---

## Real-Time Sync Architecture

### Core Principle
The widget must reflect app activity instantly. No stale data, no waiting for scheduled refreshes.

### SharedPreferences Data Contract (App → Widget)

| Key | Type | Description |
|-----|------|-------------|
| `disc_bible` | boolean | Bible chapters completed today |
| `disc_literature` | boolean | Christian literature completed today |
| `disc_ddeg` | boolean | DDEG completed today |
| `disc_prayer` | boolean | Prayer completed today |
| `disc_evangelism` | boolean | Evangelism completed today |
| `completion_percent` | int | 0-100, today's overall completion |
| `streak_count` | int | Current consecutive days streak |
| `scripture_text` | String | Current verse or proclamation text |
| `scripture_ref` | String | Scripture reference or "Proclamation" |
| `timer_running` | boolean | Whether a timer is currently active |
| `timer_discipline` | String | Which discipline is being timed |
| `timer_start_ms` | long | System clock millis when timer started |
| `timer_elapsed` | String | Formatted elapsed time for display |
| `proclamation_count` | int | Today's proclamation counter |
| `widget_locale` | String | App language for widget text (`"en"` or `"fr"`) |

### Sync Triggers (App → Widget, Immediate)

| App Event | Data Updated | Method |
|-----------|-------------|--------|
| Discipline toggled in LogScreen | `disc_*`, `completion_percent` | `HomeWidget.saveWidgetData()` + `updateWidget()` |
| Discipline toggled from widget | Same | Widget handler saves → self-refresh via `onUpdate()` |
| Timer started/paused/stopped (in-app) | `timer_*` fields | Immediate widget update |
| Timer controlled from widget | Same | Deep link → app processes → saves → updates widget |
| Log auto-saved | `completion_percent`, all `disc_*` | Fires on every `_persist()` call |
| Streak changes | `streak_count` | On day rollover or log save |
| Proclamation incremented in-app | `proclamation_count` | Immediate widget update |
| Proclamation incremented from widget | Same | Deep link → app processes → saves → updates widget |
| App language changed in Settings | `widget_locale` | Immediate update → all widgets re-render with new language |

### Deep Link URI Schema (Widget → App)

| URI | Action |
|-----|--------|
| `dailyaccount://toggle/{discipline}` | Toggle discipline on/off in today's log |
| `dailyaccount://timer/start/{discipline}` | Start timer for specified discipline |
| `dailyaccount://timer/pause` | Pause running timer |
| `dailyaccount://timer/stop` | Stop timer and save duration to today's log |
| `dailyaccount://open/log` | Open app to today's log screen |
| `dailyaccount://proclamation/increment` | Increment today's proclamation count by 1 |
| `dailyaccount://open/proclamation` | Open app to proclamation screen (long press) |

### Widget → App Flow (Example: Discipline Toggle)
1. `PendingIntent` fires `dailyaccount://toggle/{discipline}`
2. `HomeWidget.widgetClicked` stream picks it up in `home_shell.dart`
3. `_toggleDisciplineFromWidget()` loads today's log, toggles the field, saves to SQLite
4. Immediately calls `HomeWidget.saveWidgetData()` with updated values
5. Calls `HomeWidget.updateWidget()` — widget reflects change within ~100ms

### Scripture Refresh
- Not real-time (doesn't need to be) — refreshes via `AlarmManager` every 30 minutes
- Also refreshes on any widget update (piggybacks on discipline/timer updates)
- Time-of-day check in `onUpdate()`: morning → verse, afternoon → proclamation, DDEG logged → user's scripture

### Offline Resilience
- All data flows through SharedPreferences (local) — no network dependency
- Widget works identically in airplane mode
- SQLite is source of truth; SharedPreferences is the widget's read cache

---

## Android Implementation Structure

### Files

| File | Purpose |
|------|---------|
| `ScriptureWidgetProvider.kt` | Provider for Scripture Card widget |
| `DisciplineBarWidgetProvider.kt` | Provider for Discipline Bar widget |
| `FullAltarWidgetProvider.kt` | Provider for Full Altar widget |
| `ProclamationWidgetProvider.kt` | Provider for Proclamation Counter widget |
| `WidgetHelper.kt` | Shared utilities: scripture loading, data reading, locale, theme constants |
| `widget_scripture.xml` | Layout for Scripture Card (2x2) |
| `widget_discipline_bar.xml` | Layout for Discipline Bar (4x2) |
| `widget_full_altar.xml` | Layout for Full Altar (4x3) |
| `widget_proclamation.xml` | Layout for Proclamation Counter (2x2) |
| `appwidget_info_scripture.xml` | Widget metadata: min 2x2 |
| `appwidget_info_discipline_bar.xml` | Widget metadata: min 4x2 |
| `appwidget_info_full_altar.xml` | Widget metadata: min 4x3 |
| `appwidget_info_proclamation.xml` | Widget metadata: min 2x2 |
| `res/values/strings.xml` | English widget strings |
| `res/values-fr/strings.xml` | French widget strings |
| `assets/verses.json` | 365 curated daily Bible verses (en + fr per entry) |

### AndroidManifest.xml

Four `<receiver>` entries (one per provider class), each with its own `appwidget-provider` metadata XML pointing to the corresponding `appwidget_info_*.xml`.

### Flutter Side
- `HomeWidget.saveWidgetData()` calls added to:
  - `LogScreen._persist()` — on every field change
  - `TimerService` — on timer state changes
  - `home_shell.dart._toggleDisciplineFromWidget()` — on widget-initiated toggles
- `HomeWidget.widgetClicked` stream handler expanded to process timer and proclamation deep links
- On language change in Settings: save `widget_locale` → `HomeWidget.updateWidget()` to re-render all widgets

---

## Out of Scope

- Fasting display on widget (keep widget focused on daily disciplines)
- Voice note controls on widget
- Weekly goals display on widget
- iOS widget (Android only for now)
- Network-dependent features

---

## Success Criteria

1. All four widgets render correctly with espresso + gold theme
2. Discipline toggles from widget reflect in app and vice versa within ~100ms
3. Timer can be started, paused, and stopped entirely from the widget
4. Timer displays real-time elapsed time via Android Chronometer
5. Scripture rotates based on time of day (verse → fixed proclamation → DDEG override)
6. Proclamation counter increments from widget and syncs to app in real-time
7. All widget text displays in the user's chosen app language (English/French)
8. Changing language in Settings immediately updates all widget text
9. Widget survives device reboot (AlarmManager re-registration)
10. Zero battery impact from widget updates (no polling loops)
11. Works fully offline
