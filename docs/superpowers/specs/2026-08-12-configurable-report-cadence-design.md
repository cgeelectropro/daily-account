# Configurable Reporting Cadence

**Date:** 2026-08-12
**Status:** Approved

---

## Problem

The app hardcodes "weekly, ending Sunday" as the only reporting cadence:
- `ReportService.weekDates()` always computes Monday→Sunday.
- The report screen's weekly/monthly toggle defaults to weekly and has no
  connection to a user preference.
- `NotificationService` schedules a primary reminder + 2 follow-ups
  specifically anchored to Sunday (`_nextInstanceOfSunday`), with static
  English text ("Sunday — Send Your Account").
- `HomeShell._checkAutoSend()` only fires `if (now.weekday != DateTime.sunday) return;`.

The user should be able to choose **Weekly** (on any day of the week) or
**Monthly** (on a specific day, or the last day of the month) as their
reporting cadence, and have report generation, the report screen's default
view, reminder notifications, and auto-send all follow that choice.

---

## Design

### 1. Settings

Three new string settings, stored via the existing
`StorageService.getSetting`/`setSetting` (SharedPreferences):

| Key | Values | Default |
|---|---|---|
| `reportCadence` | `"weekly"` \| `"monthly"` | `"weekly"` |
| `reportWeeklyDay` | `"1"`–`"7"` (`DateTime.weekday` convention: 1=Mon...7=Sun) | `"7"` (Sunday) |
| `reportMonthlyDay` | `"1"`–`"31"` or `"last"` | `"last"` |

Defaulting to weekly/Sunday preserves current behavior for existing users
with no migration needed — reading an unset key returns the fallback.

### 2. `ReportCadenceService` (new file: `lib/services/report_cadence_service.dart`)

A small singleton service (same pattern as other services:
`static final instance = ReportCadenceService._()`) centralizing all
cadence math so no other file re-implements "what day is the report day."

```dart
enum ReportCadence { weekly, monthly }

class ReportCadenceService {
  static final instance = ReportCadenceService._();
  ReportCadenceService._();

  Future<ReportCadence> getCadence();
  Future<int> getWeeklyDay();          // 1-7, DateTime.weekday convention
  Future<String> getMonthlyDay();      // "1".."31" or "last"

  Future<void> setCadence(ReportCadence cadence);
  Future<void> setWeeklyDay(int weekday);
  Future<void> setMonthlyDay(String day); // "last" or "1".."31"

  /// Resolves "last" or a clamped day number against [year]/[month].
  int resolveMonthlyDay(int year, int month, String configuredDay);

  /// True if [date] (default: today) is the configured report/send day.
  Future<bool> isReportDay([DateTime? date]);
}
```

`ReportService.weekDates()` (see §3) calls `getWeeklyDay()` directly rather
than duplicating window math in a second place — `ReportCadenceService`
owns the settings and the day-resolution math (`resolveMonthlyDay`,
`isReportDay`); `ReportService` keeps owning date-range construction, since
that's already its job for the weekly and monthly report builders.

`resolveMonthlyDay` clamps: if the configured day is `"31"` and the month
has 28/29/30 days, it resolves to that month's actual last day. `"last"`
always resolves to the month's last day.

`isReportDay` branches on cadence:
- weekly: `date.weekday == configuredWeeklyDay`
- monthly: `date.day == resolveMonthlyDay(date.year, date.month, configuredMonthlyDay)`

### 3. `ReportService` changes (`report_service.dart`)

- `weekDates([DateTime? ref])` is synchronous today and called from 9+
  places across `report_service.dart`, `pdf_report_service.dart`,
  `home_shell.dart`, and `report_screen.dart` — some in otherwise-sync
  contexts. Making it read a setting (which requires `await`) means either:
  - (a) making `weekDates` itself `async` and updating every call site to
    `await` it, or
  - (b) adding a new optional parameter `weekDates([DateTime? ref, int? endWeekday])`
    that defaults to Sunday (`DateTime.sunday`) when omitted, keeping the
    method synchronous, and having the *callers that need the configured
    day* (report building, auto-send, the report screen) fetch
    `ReportCadenceService.instance.getWeeklyDay()` once and pass it in.

  **Decision: (b).** It's the smaller, lower-risk change — no call site
  that doesn't care about cadence needs to change at all, and the ones that
  do (the actual report builders: `computeWeekStats`, `computeTrend`,
  `buildFullReport`, `buildCompactReport`) already take a `[DateTime? ref]`
  parameter and already sit inside `async` functions, so adding one more
  awaited lookup at the top of each is a small, local change.
- Those four methods fetch the configured weekly day once at the top
  (`final endWeekday = await ReportCadenceService.instance.getWeeklyDay();`)
  and pass it through to `weekDates(ref, endWeekday)`.
  - Sunday-ending (default) reproduces exactly today's Monday→Sunday
    behavior — no behavior change for existing users.
  - Friday-ending, for example, produces Saturday→Friday.
- `buildMonthlyReport`, `computeMonthStats`: **no change**. A calendar month
  is a calendar month regardless of which day triggers sending it.

### 4. Report screen (`report_screen.dart`)

- `_isMonthly` initializes from `ReportCadenceService.instance.getCadence()`
  in `initState`/first load, instead of the hardcoded `false`.
- The manual weekly/monthly toggle button is unchanged — user can still tap
  to peek at the other period; it just starts on whichever period matches
  their configured cadence.
- Line ~422's `DateTime.now().weekday == DateTime.sunday` (controls a
  "send now" nudge shown only on the report day) becomes
  `await ReportCadenceService.instance.isReportDay()`.

### 5. Notifications (`notification_service.dart`)

- `scheduleSundayReminder(hour, minute, {title, body, followUpCount})` is
  renamed `scheduleReportReminder(...)` and generalized. Structurally
  unchanged: one primary reminder (id 2) + two same-day follow-ups at
  +30min and +60min (ids 21, 22) — only *which day* they land on changes.
  - Computing the next occurrence becomes cadence-aware: reuse the existing
    `_nextInstanceOfWeekday(weekday, hour, minute)` for weekly mode; add
    `_nextInstanceOfMonthlyDay(day, hour, minute)` for monthly mode (walks
    forward day-by-day, like the existing `_nextInstanceOfWeekday` pattern,
    checking `date.day == resolveMonthlyDay(...)`).
  - **Recurrence matcher caveat:** the existing weekly scheduling passes
    `matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime` to
    `flutter_local_notifications`, which lets the OS auto-repeat the
    notification every week without the app re-scheduling it. There is no
    `dayOfMonthAndTime` equivalent in this plugin — monthly recurrence
    (especially "last day of month," which isn't a fixed day number) isn't
    expressible as a single recurring OS alarm. So monthly-cadence
    reminders schedule a **one-shot** notification for the next occurrence
    only (no `matchDateTimeComponents`), and the app re-schedules the next
    one each time `init()` runs (already called on every app start — see
    existing `init()` call sites) and whenever `cancelReportFollowUps()`
    runs (see below). This means a monthly reminder could be missed if the
    app isn't opened between one occurrence and the next; acceptable given
    monthly cadence already implies long gaps and the user opens the app
    daily to log.
- `cancelSundayFollowUps()` → `cancelReportFollowUps()`; same generalization,
  re-schedules for the next occurrence of the configured cadence (and, for
  monthly mode, this is also what re-arms the one-shot notification for
  next month).
- `rescheduleAll()` (called from `init()`, itself called on every app
  launch per `main.dart`) already re-reads settings and re-calls the Sunday
  scheduler every time the app starts — this existing behavior is what
  keeps a monthly one-shot notification re-armed in practice, since users
  open the app daily to log. No new "keep-alive" mechanism needed.
- Existing setting keys `sundayHour`/`sundayMin`/`sundayFollowUps` are
  **kept as-is** (not renamed) — they store the reminder's time-of-day and
  follow-up count, which stay meaningful regardless of which day/cadence is
  configured. Only the three new keys from §1 are added.
- `scheduleAutoSendReminder`, `scheduleMidWeekNudge`, and
  `scheduleSaturdaySummary` are separate, unrelated notification features
  and are **not modified** — except `scheduleAutoSendReminder`'s call to
  `_nextInstanceOfSunday` in `rescheduleAll()`, which becomes cadence-aware
  the same way `scheduleReportReminder` does, since it exists to remind the
  user their auto-send is about to fire on the (configurable) report day.
- Reminder text becomes dynamic (per your choice to insert the actual
  day/cadence rather than generic wording):
  - Weekly: e.g. *"Friday — Send Your Account"* — day name interpolated.
  - Monthly, specific day: e.g. *"The 25th — Send Your Account"*.
  - Monthly, last day: e.g. *"Month-end — Send Your Account"*.
  - Two new localized string templates in `app_en.arb`/`app_fr.arb`
    (`notifReportTitleWeekly`, `notifReportTitleMonthly` or similar, with
    placeholders), replacing the static `notifSundayTitle`/`notifSundayBody`
    keys. Existing Sunday-specific ARB keys are removed once no longer
    referenced.
- All notification IDs currently documented as "Sunday reminder", "Sunday
  follow-up #1/#2" etc. keep their numeric IDs (2, 3, 21, 22) — only the
  doc comments and scheduling logic change, not the ID scheme, so existing
  scheduled notifications on upgrade get cleanly cancelled/rescheduled by
  the existing cancel-then-reschedule flow.

### 6. Auto-send (`home_shell.dart`)

- `_checkAutoSend()`'s guard `if (now.weekday != DateTime.sunday) return;`
  becomes `if (!await ReportCadenceService.instance.isReportDay(now)) return;`.
- Report building branches on cadence:
  - weekly → `buildFullReport`/`buildCompactReport` (unchanged).
  - monthly → `buildMonthlyReport(name, l, now.year, now.month)`. Monthly
    auto-send only has one report format (no separate "compact" variant
    today), so it's used for both the WhatsApp send and the archive save.
- The "already sent this period" dedup key (`lastAutoSend`, currently a
  week key like `2026-W32`) generalizes to a period key: weekly keeps the
  Monday-of-week key; monthly uses a `yyyy-MM` key. Both are just strings
  compared for equality, so no format constraint beyond uniqueness per
  period.

### 7. Settings screen (`settings_screen.dart`)

New section (replacing/extending the current Sunday-reminder-time UI):
- Segmented control: **Weekly** / **Monthly**.
- If Weekly: 7 day chips (Mon–Sun, localized day names) — tap to select
  `reportWeeklyDay`.
- If Monthly: a day picker — chips or a dropdown for 1–31, plus a
  **"Last day of month"** option — selects `reportMonthlyDay`.
- Existing reminder-time picker (hour/minute) and follow-up toggle are
  unchanged — they configure *when* on the report day the reminder fires,
  which is orthogonal to *which day* that is.
- Saving any of these three settings re-calls
  `NotificationService.instance.scheduleReportReminder(...)` so the
  schedule updates immediately (matching how the existing Sunday-time
  picker already re-schedules on change).

---

## Testing

Since `ReportCadenceService`'s core logic (`resolveMonthlyDay`,
`isReportDay`) is pure date math with no Flutter widget/plugin
dependencies, it's covered by fast unit tests
(`test/report_cadence_service_test.dart`):
- `resolveMonthlyDay`: exact day within range, day clamped in a short
  month (31 → 28 in Feb), `"last"` in months of varying length, leap-year
  February.
- `isReportDay`: weekly mode matches only the configured weekday; monthly
  mode matches only the resolved day; both false on other days.

`ReportService.weekDates()`'s generalized window math is covered in
`test/report_service_test.dart` (existing file): Sunday-ending anchor
reproduces today's Monday→Sunday window (regression guard for existing
behavior); a Friday-ending anchor produces the correct Saturday→Friday
window; window always contains the reference date.

`_nextInstanceOfMonthlyDay` in `notification_service.dart` is also pure
date-walking logic and gets unit tests alongside the existing
`_nextInstanceOfWeekday` tests (if any exist) or as new tests verifying it
returns a date with the correct day-of-month, in the future, respecting
the hour/minute.

No widget tests are planned for the settings screen UI addition — manual
verification (run the app, change cadence, confirm the report screen and
reminder schedule update) is sufficient for a settings picker of this size.

---

## Out of scope

- Daily or custom/arbitrary-interval cadences (e.g. "every 10 days") — only
  weekly and monthly, matching the CMFI weekly-account tradition and the
  existing monthly report feature.
- Per-disciple-maker cadence (the app supports one disciple maker contact
  at a time; cadence is a single global setting, consistent with existing
  settings).
- Migrating/backfilling historical reports if the user changes cadence
  mid-stream — report history (`saveReport` archive) is keyed by whatever
  period was active when it was sent; changing cadence going forward does
  not rewrite past archive entries.
