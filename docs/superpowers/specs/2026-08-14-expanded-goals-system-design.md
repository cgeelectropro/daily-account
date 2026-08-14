# Expanded Goals System

**Date:** 2026-08-14
**Status:** Approved

---

## Problem

The current "Goals" feature (`settings_screen.dart`'s "Objectives" section, labeled
Daily/Weekly Goals) is a single mutually-exclusive daily-*or*-weekly toggle with
exactly 4 hardcoded targets (Bible chapters, prayer minutes, evangelism contacts,
literature items). Limitations:

- A user cannot have a daily goal and a weekly goal for the same discipline at
  once — picking "weekly" mode discards the daily numbers (they're just hidden,
  sharing the same 4 storage keys).
- No monthly goals at all.
- Prayer targets are always in minutes; no hours option.
- Only 4 fixed metrics are goal-able. Every other discipline the app already
  logs (DDEG, fasting, church, discipleship, proclamation, and any custom
  activity) cannot have a goal.
- Goals are purely a display card on the Report screen — completing one does
  nothing: no congratulation, no reminder if the user is falling behind, no
  mention in the AI reflection, no badge.

This spec makes Daily, Weekly, and Monthly goals independent and simultaneous,
opens goal targets to any loggable metric (including user-defined custom
activities) with a "+ Add goal" flow, adds a minutes/hours unit choice for
duration goals, and wires goal completion into three existing surfaces
(reflection text, report badges, push notification) plus a new pace-reminder
mechanism (in-app banner + scheduled push) for goals falling behind partway
through their period.

---

## Design

### 1. `Goal` model (new file: `lib/models/goal.dart`)

```dart
enum GoalFrequency { daily, weekly, monthly }
enum GoalUnit { count, minutes, hours }

class Goal {
  String id;                 // stable: metricKey for built-ins, uuid-ish for custom
  String metricKey;          // key into the metric registry (see §2)
  GoalFrequency frequency;
  int target;                // always stored in the metric's base unit (see §5)
  GoalUnit unit;              // display unit chosen by the user
  String? customLabel;       // set only when metricKey has no registry entry
                              // (shouldn't normally happen — see §2) or the
                              // user renamed a custom-activity-derived goal
  String? customIcon;        // optional override; falls back to registry icon
}
```

`toMap()`/`fromMap()` follow the existing `CustomActivity` pattern exactly
(flat JSON map, enums serialized via `.name`/`.values.byName`).

Storage: `StorageService.getGoals()` / `saveGoals(List<Goal>)`, a JSON-encoded
list under SharedPreferences key `goals` — mirrors the existing
`custom_activities` key pattern in `storage_service.dart:418-448` exactly
(read whole list, mutate in memory, write whole list back; no per-item CRUD
needed given expected list sizes are small, under ~20).

### 2. Metric registry (new file: `lib/data/goal_metrics.dart`)

A static list of every goal-able metric:

```dart
class GoalMetric {
  final String key;           // e.g. 'bibleChapters', 'prayerMinutes', 'ddegTime'
  final String Function(S l) label;   // localized label
  final String icon;
  final GoalUnit baseUnit;    // GoalUnit.count or GoalUnit.minutes (duration
                               // metrics are always stored/summed in minutes;
                               // hours is a display-only conversion, see §5)
  const GoalMetric({required this.key, required this.label, required this.icon, required this.baseUnit});
}

class GoalMetrics {
  static const List<GoalMetric> builtIn = [
    GoalMetric(key: 'bibleChapters', label: ..., icon: '📖', baseUnit: GoalUnit.count),
    GoalMetric(key: 'prayer', label: ..., icon: '🙏', baseUnit: GoalUnit.minutes),       // alone + together combined, see §4
    GoalMetric(key: 'evangelismContacts', label: ..., icon: '📢', baseUnit: GoalUnit.count),
    GoalMetric(key: 'literatureItems', label: ..., icon: '📚', baseUnit: GoalUnit.count),
    GoalMetric(key: 'ddegTime', label: ..., icon: '🔥', baseUnit: GoalUnit.minutes),
    GoalMetric(key: 'fastingCount', label: ..., icon: '🍽️', baseUnit: GoalUnit.count),
    GoalMetric(key: 'churchCount', label: ..., icon: '⛪', baseUnit: GoalUnit.count),
    GoalMetric(key: 'discipleshipTime', label: ..., icon: '👥', baseUnit: GoalUnit.minutes),
    GoalMetric(key: 'proclamationCount', label: ..., icon: '📣', baseUnit: GoalUnit.count),
  ];

  /// Custom-activity-derived metrics, built at call time from the user's
  /// current custom activities (one metric per duration/counter field).
  static List<GoalMetric> fromCustomActivities(List<CustomActivity> activities) { ... }
}
```

`fromCustomActivities` generates one `GoalMetric` per `CustomField` of type
`counter` or `duration` across all the user's custom activities, with
`key = 'custom:${activity.id}:${field.label}'` (colon-delimited, parsed back
apart by `GoalProgressService`) and `baseUnit` derived from the field type
(`counter` → count, `duration` → minutes).

The "+ Add goal" picker (§6) shows `GoalMetrics.builtIn` under a "Built-in"
heading and `GoalMetrics.fromCustomActivities(...)` under "Your Activities",
excluding whichever metrics already have an active goal at the frequency
being edited (no duplicate goals for the same metric+frequency pair).

### 3. `GoalProgressService` (new file: `lib/services/goal_progress_service.dart`)

The core new engine — computes how much of a goal's target has been reached
for its current period.

```dart
class GoalProgressService {
  static final instance = GoalProgressService._();
  GoalProgressService._();

  /// Progress toward [goal], in the goal's baseUnit (count or minutes),
  /// for the period containing [ref] (default: today).
  Future<int> computeProgress(Goal goal, [DateTime? ref]) async { ... }

  /// True if computeProgress(goal, ref) >= goal.target.
  Future<bool> isComplete(Goal goal, [DateTime? ref]) async { ... }

  /// Fraction of the goal's period elapsed so far (0.0-1.0), used by the
  /// pace-reminder logic in §8.
  double periodElapsedFraction(GoalFrequency frequency, [DateTime? ref]) { ... }
}
```

**Period resolution** (reuses existing infrastructure, does not reimplement
date math):
- `daily`: just `ref`'s date, a single-day log fetch.
- `weekly`: `ReportService.instance.weekDates(ref, await ReportCadenceService.instance.getWeeklyDay())` — reuses the cadence-aware weekly window from the prior feature, so a goal's "week" always matches the user's configured report week, not a hardcoded Monday-Sunday.
- `monthly`: first day to last day of `ref`'s calendar month (`DateTime(ref.year, ref.month, 1)` through `DateTime(ref.year, ref.month + 1, 0)`).

**Metric summation** (per built-in `metricKey`, generalizing the
session-aware duration logic already in
`ReportService._totalConsecratedMinutes`/`computeWeekStats` rather than
duplicating it — extract that logic into a shared static helper both
services call, see §3a below):

| metricKey | Sums |
|---|---|
| `bibleChapters` | `log.totalBibleChapters` per day |
| `prayer` | prayer-alone + prayer-together minutes per day (session-aware: use `prayerAloneSessions`/`prayerOthersSessions` if non-empty, else legacy `prayerAloneDuration`/`prayerOthersDuration`, exactly as `report_service.dart`'s existing `computeWeekStats` already does at lines 95-110) |
| `evangelismContacts` | `int.tryParse(log.evangelismContacts) ?? 0` per day |
| `literatureItems` | count of `log.literature` entries with non-empty title, per day |
| `ddegTime` | DDEG minutes per day, session-aware (`ddegSessions` else legacy `ddegTime`, mirroring `_totalConsecratedMinutes`'s existing pattern) |
| `fastingCount` | 1 per day where `fastingType.isNotEmpty \|\| fastingDuration.isNotEmpty` |
| `churchCount` | 1 per day where `churchType.isNotEmpty` |
| `discipleshipTime` | `discipleshipDuration` minutes per day |
| `proclamationCount` | `int.tryParse(log.proclamationCount) ?? 0` per day |
| `custom:<activityId>:<fieldLabel>` | reads `log.customActivityData[activityId]['fields'][fieldLabel]`; parsed as int for counter fields, as duration-minutes (via the shared duration parser) for duration fields |

#### 3a. Extracting the shared duration parser

`ReportService` currently has `_parseDurationMinutes` (static, private) and
`_totalConsecratedMinutes` (static, private) in `report_service.dart`. Move
`_parseDurationMinutes` to a new small shared utility
(`lib/services/duration_parser.dart`, a single top-level function
`int parseDurationMinutes(String s)` — no class needed, this is pure
string-parsing logic) and update `ReportService` to call the shared version
instead of its own private copy. `GoalProgressService` imports the same
shared function. This avoids a third divergent copy of duration-parsing
logic entering the codebase (there were already two: `report_service.dart`
and `timer_service.dart` each have their own `_parseDurationMinutes` —
unifying `report_service.dart`'s copy into the new shared file is in scope;
`timer_service.dart`'s copy is pre-existing and out of scope for this
feature, not worth an unrelated refactor here).

### 4. Settings screen — "Goals" section rework

- Section title changes from the current `_goalFrequency == 'daily' ? l.dailyGoals : l.weeklyGoals` (`settings_screen.dart:835`) to a single new ARB key `goalsSection` ("Goals"). The old `dailyGoals`/`weeklyGoals`/`dailyGoalsDesc`/`weeklyGoalsDesc`/`goalFrequency` ARB keys become unused by this section (left in the ARB files — other code may still reference `goalFrequency`'s string value during migration, see §7 — but the `SectionCard` title stops using them).
- Inside, three subsections rendered in order: **Daily**, **Weekly**, **Monthly** — each its own small `SectionCard` or a shared collapsible group, showing that frequency's active `Goal` entries as rows (icon, label, target + unit, edit/remove) plus an "+ Add goal" button at the bottom of each subsection.
- Tapping "+ Add goal" under a given frequency opens a bottom sheet (matches the existing custom-activity-creation bottom-sheet pattern already used elsewhere in `settings_screen.dart`/`stopwatch_screen.dart`): a scrollable list of `GoalMetrics.builtIn` + `GoalMetrics.fromCustomActivities(...)` (minus metrics already goaled at this frequency), each row tappable; tapping one opens a small target-entry step (number field, plus a minutes/hours segmented toggle if the metric's `baseUnit` is `GoalUnit.minutes`).
- Editing an existing goal row re-opens the same target-entry step pre-filled with its current value/unit.
- State: replace `_goalFrequency`/`_goalBibleChapters`/`_goalPrayerMinutes`/`_goalEvangelismContacts`/`_goalLiteratureItems` (`settings_screen.dart:60-64`) with `List<Goal> _goals = [];`, loaded via `StorageService.instance.getGoals()` in `_load()`.

### 5. Unit conversion (minutes/hours display)

`Goal.target` and all `GoalProgressService` computations are always in the
metric's `baseUnit` (count, or minutes for every duration metric — never
hours internally, to avoid fractional-minute rounding drift). `Goal.unit`
is purely a **display/input** preference: when the user picks "hours" for a
duration goal, the target-entry field shows/accepts hours and the app
converts hours × 60 → minutes on save, and minutes ÷ 60 (rounded to 1
decimal, e.g. "1.5h") when rendering progress. `GoalUnit.count` is the only
valid unit for count-based metrics — the minutes/hours toggle only appears
when the picked metric's `baseUnit` is `GoalUnit.minutes`.

### 6. Report screen — three progress cards

`_buildGoalsCard` (`report_screen.dart:578-...`) splits into a
`_buildGoalsCard(GoalFrequency frequency, ...)` parameterized method, called
up to 3 times (once per frequency with ≥1 active goal). Each card fetches
its frequency's goals from the now-loaded `List<Goal> _goals`, computes
progress for each via `GoalProgressService.instance.computeProgress(goal,
_weekRef)`, and renders the same progress-bar-per-goal layout the current
single card uses, just scoped to one frequency and titled "Daily Goals" /
"Weekly Goals" / "Monthly Goals".

`_hasGoals` (`report_screen.dart:119`) becomes `_goals.isNotEmpty`.

### 7. Migration

One-time migration, run from `StorageService` (mirrors the existing SQLite
schema-migration pattern already in that file — this is a SharedPreferences
migration, gated by checking whether the new `goals` key is already
present, so it runs at most once):

```dart
Future<void> migrateGoalsIfNeeded() async {
  final p = await SharedPreferences.getInstance();
  if (p.containsKey('goals')) return; // already migrated
  final oldFrequency = p.getString('goalFrequency') ?? 'weekly';
  final freq = oldFrequency == 'daily' ? GoalFrequency.daily : GoalFrequency.weekly;
  final goals = <Goal>[];
  void addIfPositive(String metricKey, String oldKey, GoalUnit unit) {
    final v = int.tryParse(p.getString(oldKey) ?? '0') ?? 0;
    if (v > 0) goals.add(Goal(id: metricKey, metricKey: metricKey, frequency: freq, target: v, unit: unit));
  }
  addIfPositive('bibleChapters', 'goalBibleChapters', GoalUnit.count);
  addIfPositive('prayer', 'goalPrayerMinutes', GoalUnit.minutes);
  addIfPositive('evangelismContacts', 'goalEvangelismContacts', GoalUnit.count);
  addIfPositive('literatureItems', 'goalLiteratureItems', GoalUnit.count);
  await saveGoals(goals); // writes the 'goals' key, marking migration done
}
```

Called once during app startup (alongside the other one-time init calls in
`main.dart`, or lazily on first `getGoals()` call if no `main.dart` init
hook exists for this class — check the existing `StorageService` init
pattern at implementation time and match it). Old keys
(`goalFrequency`, `goalBibleChapters`, `goalPrayerMinutes`,
`goalEvangelismContacts`, `goalLiteratureItems`) are **not deleted** —
left as harmless orphaned settings, consistent with how this codebase
generally handles renamed/superseded settings keys (see the reporting
cadence feature's decision to keep `sundayHour`/`sundayFollowUps` key names
unchanged rather than migrate them).

`backup_service.dart:128-129` currently lists the 5 old goal keys for
backup/restore inclusion — add `'goals'` to that list so the new data is
included in exports; the old keys can stay listed too (harmless, small).

### 8. Congratulations (3 surfaces)

**Detection point:** a single new method,
`GoalProgressService.instance.justCompletedGoals(DailyLog before, DailyLog after)`
→ `Future<List<Goal>>`, returns goals whose `computeProgress` crosses from
`< target` to `>= target` when comparing the log state before vs. after a
save.

`LogScreen._persist()` (`log_screen.dart:544-552`) is synchronous and fires
a debounced `Timer` whose callback calls `StorageService.instance.saveLog(_log)`
without awaiting it — by the time `_persist()` runs, `_log` has *already*
been mutated in-memory by whichever field's `onChanged` handler called
`_persist()` (there are 46 such call sites in this file; instrumenting each
individually is not viable). The correct "before" state is therefore **not**
a snapshot taken inside `_persist()`, but whatever was last actually
persisted to storage. Change the `Timer`'s callback to `async` and,
immediately before calling `saveLog`, fetch
`final before = await StorageService.instance.getLog(_log.dateKey);` (the
row as it stood before this save overwrites it — `null` on a brand-new
day's first save, treated as an all-zero log). After `saveLog(_log)`
completes, call
`final completed = await GoalProgressService.instance.justCompletedGoals(before, _log);`
This adds exactly one extra read per debounced save (already a 500ms-debounced,
low-frequency operation, so the added read is not a performance concern).

1. **Reflection panel**: `ReflectionContext` (`reflection_service.dart:50-76`)
   gains `final List<Goal> completedGoalsToday;` (default `const []`).
   `RuleBasedReflectionProvider._buildEncouragement`
   (`reflection_service.dart:279`) gets one new early-priority template
   ("You hit your {goalLabel} goal today! 🎉") when the list is non-empty,
   before its existing streak/discipline-rate encouragement checks.

2. **Report screen badge**: `_computeBadges` (`report_screen.dart:121-133`)
   appends one badge per currently-complete goal in the viewed period
   (`await GoalProgressService.instance.isComplete(goal, _weekRef)` for
   each of `_goals`), using the goal's own icon and a label like "{target}
   {metric} — Complete!". Distinct from the existing fixed badges (streak,
   Bible marathon, etc.), which are untouched.

3. **Push notification**: in `LogScreen._persist()`, after
   `justCompletedGoals` returns a non-empty list, call a new
   `NotificationService.instance.showGoalCompletedNotification(Goal goal)`
   — a one-shot, immediately-fired local notification (not scheduled;
   uses the same `flutter_local_notifications` `.show()` immediate-display
   path the app already uses elsewhere, not `.zonedSchedule()`), one per
   completed goal, with a new notification ID range (see §10 below for ID
   allocation) and celebratory copy.

### 9. Pace reminders (2 surfaces)

**Threshold:** a goal is "behind pace" when
`GoalProgressService.instance.periodElapsedFraction(goal.frequency) > 0.5`
AND `progress / target < 0.5` — i.e., past the period's midpoint but under
half done. (Simple linear-pace heuristic; not proportional to elapsed
fraction beyond the 50% checkpoint, keeping the logic and copy simple: one
check, one message, not a continuously-recalculated percentage-behind
figure.)

1. **In-app banner**: computed live, same lifecycle-check pattern as
   `HomeShell._checkAutoSend` (`home_shell.dart:358`, called from
   `initState` and `didChangeAppLifecycleState`'s resumed branch). New
   `HomeShell._checkGoalPace()` method iterates `_goals`, calls the
   behind-pace check above for each, and if any are behind, shows a
   dismissible banner on the Report screen (new state:
   `List<Goal> _behindPaceGoals` threaded down similarly to how
   `_hasPendingReport` already flows from `HomeShell` today) — e.g. "You're
   halfway through the week — 3 goals could use some attention." tapping
   it navigates to the Report tab's goals card.

2. **Background push**: `NotificationService` gains
   `scheduleGoalPaceChecks()`, called from the existing `rescheduleAll()`
   (mirroring how every other notification category is (re)armed there).
   Three new one-shot-per-period notifications (not full recurring
   `dayOfWeekAndTime` schedules, since the check itself must run at
   fire-time to know if the user is actually behind — same one-shot +
   re-arm-on-next-`init()` pattern the monthly report reminder from the
   prior cadence feature already established):
   - Daily: fires at a fixed check-in time (e.g. 15:00 local) if today's
     goals aren't yet at pace.
   - Weekly: fires at the midpoint of the configured report week (i.e.,
     `weeklyEndDay - 3`, computed via the existing weekday-walking helper
     pattern from `notification_service.dart`).
   - Monthly: fires on day 15 (fixed, not tied to `reportMonthlyDay` —
     goal periods are always calendar months per §3, independent of the
     report cadence's monthly-day setting).
   This codebase's `zonedSchedule` usage (confirmed in
   `notification_service.dart`'s `_safeZonedSchedule`) bakes notification
   title/body text in at **schedule time** — there is no fire-time
   callback that recomputes content when the OS actually displays it, for
   any existing notification category in this app. Goal pace checks
   follow the same constraint: pace is computed when
   `scheduleGoalPaceChecks()` runs (app start/resume, via `rescheduleAll()`)
   and the notification is scheduled or skipped based on that snapshot.
   This means a user who catches up on a goal shortly after the check runs
   may still see a stale "you're behind" notification later that day/week —
   an accepted approximation, consistent with how the existing monthly
   cadence reminder already re-arms only on next app open rather than
   truly live. To keep the staleness window small, `didChangeAppLifecycleState`
   already re-runs `rescheduleAll()`-adjacent logic on resume (per
   `HomeShell`'s existing pattern) — extend `_checkGoalPace()` (§9.1) to
   also re-call `scheduleGoalPaceChecks()` so returning to the app
   refreshes the scheduled checks, not just the in-app banner.
   New settings: `goalPaceRemindersEnabled` (bool, default true, one
   toggle in the Goals settings section — not per-frequency, keeps the
   settings surface small).

### 10. Notification ID allocation

Per the existing ID-range convention documented at the top of
`notification_service.dart` (`///  110–120 = Per-discipline reminders`,
etc.), allocate two new ranges:
- `130-139`: goal-completed one-shot notifications (not a fixed single ID
  like most categories, since multiple goals could complete in one save —
  reuse a rotating/hashed ID within the range, or just always use `130`
  and accept that a rapid double-completion overwrites the first — simpler,
  acceptable given this is a celebratory nice-to-have, not a durable
  record).
- `140-142`: goal pace-check reminders (140=daily, 141=weekly, 142=monthly).

---

## Testing

- `GoalProgressService`: unit tests for `computeProgress` across all 9
  built-in metric keys plus a representative custom-activity metric key,
  for each of the 3 frequencies, using constructed `DailyLog` fixtures —
  no Flutter widget dependencies, fast pure-Dart tests
  (`test/goal_progress_service_test.dart`).
- `periodElapsedFraction`: unit tests for daily/weekly/monthly at various
  reference dates, including month-length edge cases (Feb vs. 31-day
  months) for the monthly case.
- `justCompletedGoals`: unit tests confirming it returns a goal only when
  crossing from under-target to at-or-over-target, not when already
  complete before the save (no duplicate congratulations) and not when
  still under target after the save.
- Migration (`migrateGoalsIfNeeded`): unit test with `SharedPreferences`
  mock values simulating an old-format user, confirming correct `Goal`
  list produced and confirming a second call is a no-op (idempotency).
- No widget tests for the settings/report screen UI additions, consistent
  with this project's established practice (per the reporting-cadence
  feature's precedent) — manual verification is the acceptance bar for UI
  work.

---

## Out of scope

- Editing the *unit* of an in-progress goal without resetting its target
  (changing minutes→hours mid-period just re-displays the same underlying
  minutes value converted; no special handling needed since minutes is
  always the source of truth per §5 — noting this explicitly so it's clear
  no extra work is required here, not because it's deferred).
- Historical goal-completion tracking / a "goals achieved over time"
  screen — this spec only tracks the *current* period's progress and
  fires point-in-time celebrations; it does not persist a log of past
  completions for later review.
- Per-goal custom pace-reminder timing (e.g. letting the user pick when
  the "behind pace" check fires) — the three fixed check times in §9 are
  not user-configurable in this pass.
- Goals tied to metrics this app doesn't already log in some form (e.g. a
  goal with no underlying `DailyLog`/custom-activity field to sum) — every
  goal must bind to something in the metric registry from §2; free-text
  "manual" goals with no automatic progress tracking are not supported.
