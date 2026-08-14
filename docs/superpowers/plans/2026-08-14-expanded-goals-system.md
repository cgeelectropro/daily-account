# Expanded Goals System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single daily-or-weekly goal toggle with independent, simultaneous Daily/Weekly/Monthly goal sets, open goal targets to any loggable metric (built-in disciplines and custom activities) via an "+ Add goal" flow, add minutes/hours units for duration goals, and wire goal completion/pace into the AI reflection, report badges, and notifications.

**Architecture:** A new `Goal` model + `GoalMetric` registry decouple "what can be a goal" from "which 4 things happen to be goals today." A new `GoalProgressService` is the single engine that computes progress for any goal over any period, reusing the cadence-aware weekly window from the reporting-cadence feature and a newly-extracted shared duration parser. Settings/report screens read/write through this service instead of ad-hoc SharedPreferences keys. Congratulations and pace reminders are additive hooks into existing update paths (`LogScreen._persist()`, `HomeShell`'s lifecycle checks, `NotificationService.rescheduleAll()`) rather than new polling loops.

**Tech Stack:** Flutter/Dart, SharedPreferences (via `StorageService`, JSON-list pattern matching `custom_activities`), `flutter_local_notifications` (existing plugin, one-shot + zonedSchedule), `flutter_test` for unit tests.

## Global Constraints

- `GoalFrequency` has exactly 3 values: `daily`, `weekly`, `monthly`. All three can have active goals simultaneously.
- `Goal.target`/all `GoalProgressService` computations are always in the metric's base unit (`GoalUnit.count` or `GoalUnit.minutes` — duration goals are NEVER stored in hours; hours is a display/input-only conversion, see plan §5 task).
- Weekly goal periods use `ReportService.instance.weekDates(ref, await ReportCadenceService.instance.getWeeklyDay())` — the same cadence-aware window the reporting-cadence feature established. Do not reimplement week-boundary math.
- Monthly goal periods are always calendar months (`DateTime(year, month, 1)` through `DateTime(year, month+1, 0)`), independent of the reporting cadence's `reportMonthlyDay` setting.
- Old goal setting keys (`goalFrequency`, `goalBibleChapters`, `goalPrayerMinutes`, `goalEvangelismContacts`, `goalLiteratureItems`) are migrated once into the new `goals` list and then left in place, never deleted.
- `flutter_local_notifications`' `zonedSchedule` in this codebase bakes title/body text in at schedule time — there is no fire-time callback. Any "is the user still behind" check must happen at schedule time, re-armed on next app open, matching the existing monthly cadence reminder's established pattern.
- No widget tests for settings/report screen UI additions — unit tests only for the pure-logic services (`GoalProgressService`, migration), consistent with the reporting-cadence feature's precedent.

---

## File Structure

- **Create** `lib/models/goal.dart` — `GoalFrequency`, `GoalUnit` enums; `Goal` class with `toMap`/`fromMap`.
- **Create** `lib/data/goal_metrics.dart` — `GoalMetric` class; `GoalMetrics.builtIn` list; `GoalMetrics.fromCustomActivities(...)`.
- **Create** `lib/services/duration_parser.dart` — extracted `parseDurationMinutes(String)` top-level function.
- **Create** `lib/services/goal_progress_service.dart` — `GoalProgressService` singleton: `computeProgress`, `isComplete`, `periodElapsedFraction`, `justCompletedGoals`.
- **Create** `test/goal_progress_service_test.dart`, `test/duration_parser_test.dart`, `test/goal_migration_test.dart`.
- **Modify** `lib/services/report_service.dart` — remove private `_parseDurationMinutes`, call the shared `parseDurationMinutes` instead.
- **Modify** `lib/services/storage_service.dart` — add `getGoals()`/`saveGoals()` (mirrors `getCustomActivities`/`saveCustomActivities`) and `migrateGoalsIfNeeded()`.
- **Modify** `lib/main.dart` — call `StorageService.instance.migrateGoalsIfNeeded()` during startup.
- **Modify** `lib/services/backup_service.dart` — add `'goals'` to the exported settings-key list.
- **Modify** `lib/screens/settings_screen.dart` — replace the 5 old goal state vars with `List<Goal> _goals`; rework the Goals `SectionCard` into 3 frequency subsections + "+ Add goal" bottom sheet.
- **Modify** `lib/screens/report_screen.dart` — `_buildGoalsCard` becomes frequency-parameterized, called up to 3 times; `_computeBadges` appends per-goal completion badges.
- **Modify** `lib/screens/log_screen.dart` — `_persist()` becomes goal-completion-aware; `_buildReflectionContext`/`_scheduleReflectionUpdate` thread completed goals through to `ReflectionContext`.
- **Modify** `lib/services/reflection_service.dart` — `ReflectionContext` gains `completedGoalsToday`; `_buildEncouragement` gets a new top-priority signal.
- **Modify** `lib/services/notification_service.dart` — add `showGoalCompletedNotification`, `scheduleGoalPaceChecks`; new ID ranges 130-139, 140-142.
- **Modify** `lib/screens/home_shell.dart` — add `_checkGoalPace()` (lifecycle-hooked, same pattern as `_checkAutoSend`), thread `_behindPaceGoals` down to the Report tab.
- **Modify** `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`, and their generated `.dart` counterparts — new ARB keys for the Goals section, add-goal flow, congratulation/pace copy.

---

### Task 1: `Goal` model + `GoalMetric` registry

**Files:**
- Create: `lib/models/goal.dart`
- Create: `lib/data/goal_metrics.dart`
- Test: `test/goal_model_test.dart`

**Interfaces:**
- Consumes: `CustomActivity`, `CustomField`, `CustomFieldType` from `lib/models/custom_activity.dart` (existing, unchanged — `CustomFieldType` enum values are `text, number, duration, yesNo, notes, counter`).
- Produces (used by Tasks 2-8):
  - `enum GoalFrequency { daily, weekly, monthly }`
  - `enum GoalUnit { count, minutes, hours }`
  - `class Goal { String id; String metricKey; GoalFrequency frequency; int target; GoalUnit unit; String? customLabel; String? customIcon; }` with a standard constructor (all fields required except the two nullable ones, which default to `null`), `Map<String, dynamic> toMap()`, `factory Goal.fromMap(Map<String, dynamic> m)`.
  - `class GoalMetric { final String key; final String Function(dynamic l) label; final String icon; final GoalUnit baseUnit; }` (typed as `String Function(dynamic l)` here, will be tightened to `String Function(S l)` once wired to the localization class in Task 4 — for this task, keep it generic to avoid a premature l10n dependency in a pure model file).
  - `class GoalMetrics { static const List<GoalMetric> builtIn = [...]; static List<GoalMetric> fromCustomActivities(List<CustomActivity> activities); }`

- [ ] **Step 1: Write the failing test for `Goal.toMap`/`fromMap` round-trip**

Create `test/goal_model_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/models/goal.dart';

void main() {
  group('Goal', () {
    test('toMap / fromMap round-trip preserves all fields', () {
      final goal = Goal(
        id: 'bibleChapters',
        metricKey: 'bibleChapters',
        frequency: GoalFrequency.weekly,
        target: 20,
        unit: GoalUnit.count,
      );
      final restored = Goal.fromMap(goal.toMap());
      expect(restored.id, 'bibleChapters');
      expect(restored.metricKey, 'bibleChapters');
      expect(restored.frequency, GoalFrequency.weekly);
      expect(restored.target, 20);
      expect(restored.unit, GoalUnit.count);
      expect(restored.customLabel, isNull);
      expect(restored.customIcon, isNull);
    });

    test('toMap / fromMap round-trip preserves custom label and icon', () {
      final goal = Goal(
        id: 'custom:abc123:Pages Read',
        metricKey: 'custom:abc123:Pages Read',
        frequency: GoalFrequency.monthly,
        target: 300,
        unit: GoalUnit.count,
        customLabel: 'Pages Read',
        customIcon: '📖',
      );
      final restored = Goal.fromMap(goal.toMap());
      expect(restored.customLabel, 'Pages Read');
      expect(restored.customIcon, '📖');
    });

    test('fromMap handles a duration goal with hours unit', () {
      final goal = Goal(
        id: 'prayer',
        metricKey: 'prayer',
        frequency: GoalFrequency.daily,
        target: 90,
        unit: GoalUnit.hours,
      );
      final restored = Goal.fromMap(goal.toMap());
      expect(restored.unit, GoalUnit.hours);
      expect(restored.target, 90);
    });
  });

  group('GoalMetrics.builtIn', () {
    test('contains exactly 9 entries with unique keys', () {
      final keys = GoalMetrics.builtIn.map((m) => m.key).toSet();
      expect(keys.length, 9);
      expect(GoalMetrics.builtIn.length, 9);
    });

    test('contains the 4 legacy metric keys used by migration', () {
      final keys = GoalMetrics.builtIn.map((m) => m.key).toSet();
      expect(keys, containsAll(['bibleChapters', 'prayer', 'evangelismContacts', 'literatureItems']));
    });

    test('duration metrics have baseUnit minutes, count metrics have baseUnit count', () {
      final byKey = {for (final m in GoalMetrics.builtIn) m.key: m};
      expect(byKey['bibleChapters']!.baseUnit, GoalUnit.count);
      expect(byKey['prayer']!.baseUnit, GoalUnit.minutes);
      expect(byKey['evangelismContacts']!.baseUnit, GoalUnit.count);
      expect(byKey['literatureItems']!.baseUnit, GoalUnit.count);
      expect(byKey['ddegTime']!.baseUnit, GoalUnit.minutes);
      expect(byKey['fastingCount']!.baseUnit, GoalUnit.count);
      expect(byKey['churchCount']!.baseUnit, GoalUnit.count);
      expect(byKey['discipleshipTime']!.baseUnit, GoalUnit.minutes);
      expect(byKey['proclamationCount']!.baseUnit, GoalUnit.count);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/goal_model_test.dart`
Expected: FAIL — `lib/models/goal.dart` and `lib/data/goal_metrics.dart` don't exist yet (import errors).

- [ ] **Step 3: Implement `Goal`**

Create `lib/models/goal.dart`:

```dart
enum GoalFrequency { daily, weekly, monthly }
enum GoalUnit { count, minutes, hours }

/// A user-configured target for a trackable metric, scoped to one
/// frequency (daily/weekly/monthly). Multiple goals of different
/// frequencies can target the same metric simultaneously.
class Goal {
  String id;
  String metricKey;
  GoalFrequency frequency;
  int target;
  GoalUnit unit;
  String? customLabel;
  String? customIcon;

  Goal({
    required this.id,
    required this.metricKey,
    required this.frequency,
    required this.target,
    required this.unit,
    this.customLabel,
    this.customIcon,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'metricKey': metricKey,
        'frequency': frequency.name,
        'target': target,
        'unit': unit.name,
        'customLabel': customLabel,
        'customIcon': customIcon,
      };

  factory Goal.fromMap(Map<String, dynamic> m) => Goal(
        id: m['id'] as String,
        metricKey: m['metricKey'] as String,
        frequency: GoalFrequency.values.byName(m['frequency'] as String? ?? 'weekly'),
        target: m['target'] as int? ?? 0,
        unit: GoalUnit.values.byName(m['unit'] as String? ?? 'count'),
        customLabel: m['customLabel'] as String?,
        customIcon: m['customIcon'] as String?,
      );
}
```

- [ ] **Step 4: Implement the metric registry**

Create `lib/data/goal_metrics.dart`:

```dart
import '../models/custom_activity.dart';
import '../models/goal.dart';

class GoalMetric {
  final String key;
  final String Function(dynamic l) label;
  final String icon;
  final GoalUnit baseUnit;

  const GoalMetric({
    required this.key,
    required this.label,
    required this.icon,
    required this.baseUnit,
  });
}

class GoalMetrics {
  GoalMetrics._();

  static const List<GoalMetric> builtIn = [
    GoalMetric(key: 'bibleChapters', label: _lBibleChapters, icon: '📖', baseUnit: GoalUnit.count),
    GoalMetric(key: 'prayer', label: _lPrayer, icon: '🙏', baseUnit: GoalUnit.minutes),
    GoalMetric(key: 'evangelismContacts', label: _lEvangelismContacts, icon: '📢', baseUnit: GoalUnit.count),
    GoalMetric(key: 'literatureItems', label: _lLiteratureItems, icon: '📚', baseUnit: GoalUnit.count),
    GoalMetric(key: 'ddegTime', label: _lDdegTime, icon: '🔥', baseUnit: GoalUnit.minutes),
    GoalMetric(key: 'fastingCount', label: _lFastingCount, icon: '🍽️', baseUnit: GoalUnit.count),
    GoalMetric(key: 'churchCount', label: _lChurchCount, icon: '⛪', baseUnit: GoalUnit.count),
    GoalMetric(key: 'discipleshipTime', label: _lDiscipleshipTime, icon: '👥', baseUnit: GoalUnit.minutes),
    GoalMetric(key: 'proclamationCount', label: _lProclamationCount, icon: '📣', baseUnit: GoalUnit.count),
  ];

  static String _lBibleChapters(dynamic l) => l.goalBibleChapters as String;
  static String _lPrayer(dynamic l) => l.goalPrayerMinutes as String;
  static String _lEvangelismContacts(dynamic l) => l.goalEvangelismContacts as String;
  static String _lLiteratureItems(dynamic l) => l.goalLiteratureItems as String;
  static String _lDdegTime(dynamic l) => l.goalDdegTime as String;
  static String _lFastingCount(dynamic l) => l.goalFastingCount as String;
  static String _lChurchCount(dynamic l) => l.goalChurchCount as String;
  static String _lDiscipleshipTime(dynamic l) => l.goalDiscipleshipTime as String;
  static String _lProclamationCount(dynamic l) => l.goalProclamationCount as String;

  /// One GoalMetric per counter/duration field across all of [activities].
  static List<GoalMetric> fromCustomActivities(List<CustomActivity> activities) {
    final result = <GoalMetric>[];
    for (final activity in activities) {
      for (final field in activity.fields) {
        if (field.type.name != 'counter' && field.type.name != 'duration') continue;
        final key = 'custom:${activity.id}:${field.label}';
        final unit = field.type.name == 'counter' ? GoalUnit.count : GoalUnit.minutes;
        result.add(GoalMetric(
          key: key,
          label: (dynamic l) => '${activity.name} — ${field.label}',
          icon: activity.icon,
          baseUnit: unit,
        ));
      }
    }
    return result;
  }
}
```

Note: `label` uses `dynamic l` (not the generated `S` localization type) deliberately in this task — `lib/data/` files in this codebase should not import `lib/l10n/generated/` to avoid a layering inversion; the built-in labels reference ARB keys that Task 4 adds (`goalDdegTime`, `goalFastingCount`, `goalChurchCount`, `goalDiscipleshipTime`, `goalProclamationCount` — new keys; `goalBibleChapters`/`goalPrayerMinutes`/`goalEvangelismContacts`/`goalLiteratureItems` already exist in the ARB files). These 5 new ARB keys are added in Task 4 alongside the other new Goals-section strings — until Task 4 lands, calling `_lDdegTime(l)` etc. on a real `S` instance will throw a `NoSuchMethodError`, which is expected and acceptable since nothing calls these label functions before Task 4 wires the UI.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/goal_model_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/models/goal.dart lib/data/goal_metrics.dart test/goal_model_test.dart
git commit -m "feat: add Goal model and GoalMetric registry for expanded goals system"
```

---

### Task 2: Extract shared duration parser

**Files:**
- Create: `lib/services/duration_parser.dart`
- Modify: `lib/services/report_service.dart:123-148` (the existing `_parseDurationMinutes` and its call sites)
- Test: `test/duration_parser_test.dart`

**Interfaces:**
- Produces: `int parseDurationMinutes(String s)` — a top-level function (no class), used by Task 3 (`GoalProgressService`) and by the now-updated `ReportService`.

- [ ] **Step 1: Write the failing test**

Create `test/duration_parser_test.dart` — copy the exact test cases that would characterize the existing `_parseDurationMinutes` behavior (read `lib/services/report_service.dart:123-148` first to confirm every branch, then write one test per branch):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/services/duration_parser.dart';

void main() {
  group('parseDurationMinutes', () {
    test('empty string returns 0', () {
      expect(parseDurationMinutes(''), 0);
    });

    test('checkmark returns 0', () {
      expect(parseDurationMinutes('✓'), 0);
    });

    test('"Xh Ym" format', () {
      expect(parseDurationMinutes('1h 30m'), 90);
    });

    test('"XhYm" format with no spaces', () {
      expect(parseDurationMinutes('1h15m'), 75);
    });

    test('"Xh" only', () {
      expect(parseDurationMinutes('2h'), 120);
    });

    test('"Xm" only', () {
      expect(parseDurationMinutes('45m'), 45);
    });

    test('"X minutes" spelled out', () {
      expect(parseDurationMinutes('30 minutes'), 30);
    });

    test('"Xs" seconds-only rounds up to nearest minute', () {
      expect(parseDurationMinutes('90s'), 2); // 90s = 1.5min, ceil to 2
      expect(parseDurationMinutes('30s'), 1); // 30s = 0.5min, ceil to 1
    });

    test('bare number assumed minutes', () {
      expect(parseDurationMinutes('45'), 45);
    });

    test('unparseable string returns 0', () {
      expect(parseDurationMinutes('garbage'), 0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/duration_parser_test.dart`
Expected: FAIL — `lib/services/duration_parser.dart` doesn't exist yet.

- [ ] **Step 3: Implement the shared parser**

Create `lib/services/duration_parser.dart` — move the exact body of `ReportService._parseDurationMinutes` (read it first at `lib/services/report_service.dart:123-148` to copy verbatim, do not paraphrase):

```dart
/// Best-effort parse of duration strings like "45m", "1h 30m", "30 minutes", "1h15m".
int parseDurationMinutes(String s) {
  if (s.isEmpty || s == '✓') return 0;
  // Try "Xh Ym" or "XhYm"
  final hm = RegExp(r'(\d+)\s*h\s*(\d+)\s*m');
  final hmMatch = hm.firstMatch(s);
  if (hmMatch != null) {
    return int.parse(hmMatch.group(1)!) * 60 + int.parse(hmMatch.group(2)!);
  }
  // Try "Xh" only
  final hOnly = RegExp(r'(\d+)\s*h');
  final hMatch = hOnly.firstMatch(s);
  if (hMatch != null) return int.parse(hMatch.group(1)!) * 60;
  // Try "Xm" or "X minutes" or "X min"
  final mOnly = RegExp(r'(\d+)\s*m');
  final mMatch = mOnly.firstMatch(s);
  if (mMatch != null) return int.parse(mMatch.group(1)!);
  // Try "Xs" (seconds only, from timer)
  final sOnly = RegExp(r'^(\d+)\s*s$');
  final sMatch = sOnly.firstMatch(s);
  if (sMatch != null) return (int.parse(sMatch.group(1)!) / 60).ceil();
  // Try bare number (assume minutes)
  final n = int.tryParse(s.trim());
  if (n != null) return n;
  return 0;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/duration_parser_test.dart`
Expected: PASS

- [ ] **Step 5: Update `ReportService` to use the shared function**

In `lib/services/report_service.dart`:
1. Add import: `import 'duration_parser.dart';`
2. Delete the entire `static int _parseDurationMinutes(String s) { ... }` method (lines 123-148 as read in Step 3).
3. Replace every call site of `_parseDurationMinutes(...)` in this file with `parseDurationMinutes(...)` (no leading underscore — it's the shared top-level function now). Search the file for `_parseDurationMinutes(` to find all call sites (there are several inside `computeWeekStats` and `_totalConsecratedMinutes`) and update each one.

- [ ] **Step 6: Run report_service tests to confirm no regression**

Run: `flutter test test/report_service_test.dart`
Expected: PASS — all existing tests unaffected (the function's behavior is identical, just relocated).

- [ ] **Step 7: Run static analysis**

Run: `flutter analyze lib/services/report_service.dart lib/services/duration_parser.dart`
Expected: 0 errors.

- [ ] **Step 8: Commit**

```bash
git add lib/services/duration_parser.dart lib/services/report_service.dart test/duration_parser_test.dart
git commit -m "refactor: extract shared duration parser from ReportService"
```

---

### Task 3: `GoalProgressService`

**Files:**
- Create: `lib/services/goal_progress_service.dart`
- Test: `test/goal_progress_service_test.dart`

**Interfaces:**
- Consumes:
  - `Goal`, `GoalFrequency`, `GoalUnit` from Task 1.
  - `parseDurationMinutes(String)` from Task 2.
  - `ReportService.instance.weekDates(DateTime? ref, int? endWeekday)` → `List<DateTime>` (existing).
  - `ReportCadenceService.instance.getWeeklyDay()` → `Future<int>` (existing).
  - `ReportService.instance.keyFor(DateTime)` → `String` (existing).
  - `StorageService.instance.getLog(String dateKey)` → `Future<DailyLog?>` (existing).
  - `StorageService.instance.getLogsBetween(String start, String end)` → `Future<List<DailyLog>>` (existing).
  - `DailyLog` fields (existing, from `lib/models/daily_log.dart`): `totalBibleChapters` (getter), `evangelismContacts` (String), `literature` (`List<LiteratureEntry>`, each with `.title`), `prayerAloneSessions`/`prayerOthersSessions` (`List<PrayerSession>`, each with `.duration`/`.isNotEmpty`), `prayerAloneDuration`/`prayerOthersDuration` (String legacy fallback), `ddegSessions` (`List<DdegSession>`, each with `.time`/`.isNotEmpty`), `ddegTime` (String legacy fallback), `fastingType`/`fastingDuration` (String), `churchType` (String), `discipleshipDuration` (String), `proclamationCount` (String), `customActivityData` (`Map<String, Map<String, dynamic>>`).
- Produces (used by Tasks 4, 5, 6, 7, 8):
  - `class GoalProgressService { static final instance = GoalProgressService._(); ... }`
  - `Future<int> computeProgress(Goal goal, [DateTime? ref])`
  - `Future<bool> isComplete(Goal goal, [DateTime? ref])`
  - `double periodElapsedFraction(GoalFrequency frequency, [DateTime? ref])`
  - `Future<List<Goal>> justCompletedGoals(DailyLog? before, DailyLog after, List<Goal> goals)` — note the signature includes `goals` explicitly (the caller's active goal list) since this service has no other way to know which goals exist; `before` is nullable to represent "no prior log for this day."

- [ ] **Step 1: Write failing tests for `computeProgress` — count metrics, single day**

Create `test/goal_progress_service_test.dart`. Read `lib/models/daily_log.dart` first to confirm exact constructor parameter names for `DailyLog`, `LiteratureEntry`, `PrayerSession`, `DdegSession` before writing fixtures (these were established in earlier features this session — `DailyLog(dateKey: ..., evangelismContacts: ..., ...)`, `LiteratureEntry(title: ..., amount: ..., unit: ...)`, `PrayerSession(duration: ..., notes: ...)`, `DdegSession(scripture: ..., time: ..., notes: ...)`).

This test file drives `StorageService.instance` directly (not a hand-rolled second DB connection like `test/storage_service_test.dart` uses for its own schema-focused tests — that file deliberately bypasses the singleton, but no existing test file exercises the singleton itself, so this is new ground). `StorageService._init()` calls `sqflite`'s top-level `getDatabasesPath()`/`openDatabase()`, which both respect a global `databaseFactory` override — setting `databaseFactory = databaseFactoryFfi` (from `package:sqflite_common_ffi/sqflite_ffi.dart`, already a dev dependency per `pubspec.yaml:67`) before anything touches `StorageService.instance` makes the real singleton resolve to an FFI-backed database instead of requiring a platform channel. Add this to `main()`, before the first test:

```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  // ... tests below
}
```

**Fallback if this doesn't work as expected:** `StorageService` caches its `Database` in a private instance field (`_db`) for the lifetime of the singleton, so once initialized in the first test, later tests in the same run share that same in-memory database rather than getting a fresh one each time — this is likely fine (each test in the file above uses distinct `dateKey` values, so there's no cross-test collision), but if tests interfere with each other unexpectedly, add a `tearDown` that clears the `logs` table between tests (`await StorageService.instance.database.then((db) => db.delete('logs'))`) rather than trying to reset the singleton itself. If the singleton genuinely cannot be driven this way in this environment (confirm by running Step 2 below and reading the actual failure, not by assuming), fall back to testing `GoalProgressService`'s pure metric-summation logic (`_metricValue`, currently private) by making it `@visibleForTesting` and testing it directly against constructed `DailyLog` objects, skipping the `_logsForPeriod`/storage-integration layer in unit tests — note this as a deviation in the task report if taken.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/models/daily_log.dart';
import 'package:daily_account/models/goal.dart';
import 'package:daily_account/services/goal_progress_service.dart';
import 'package:daily_account/services/storage_service.dart';
// (add whatever sqflite_ffi / SharedPreferences mock imports the existing
// storage_service_test.dart uses, matching its setUpAll/setUp exactly)

void main() {
  // Match test/storage_service_test.dart's exact database-initialization
  // boilerplate here (databaseFactory assignment, SharedPreferences mock).

  final svc = GoalProgressService.instance;

  group('computeProgress — daily, count metrics', () {
    test('bibleChapters sums totalBibleChapters for the single day', () async {
      final today = DateTime(2026, 8, 14);
      final log = DailyLog(dateKey: '2026-08-14', bibleChapters: '5');
      await StorageService.instance.saveLog(log);

      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.daily, target: 3, unit: GoalUnit.count);
      final progress = await svc.computeProgress(goal, today);
      expect(progress, 5);
    });

    test('evangelismContacts parses the stored numeric string', () async {
      final today = DateTime(2026, 8, 15);
      final log = DailyLog(dateKey: '2026-08-15', evangelismContacts: '7');
      await StorageService.instance.saveLog(log);

      final goal = Goal(id: 'evangelismContacts', metricKey: 'evangelismContacts', frequency: GoalFrequency.daily, target: 5, unit: GoalUnit.count);
      final progress = await svc.computeProgress(goal, today);
      expect(progress, 7);
    });

    test('literatureItems counts entries with non-empty title', () async {
      final today = DateTime(2026, 8, 16);
      final log = DailyLog(
        dateKey: '2026-08-16',
        literature: [
          LiteratureEntry(title: 'Book A', amount: '10', unit: 'pages'),
          LiteratureEntry(title: '', amount: '', unit: 'pages'),
          LiteratureEntry(title: 'Book B', amount: '5', unit: 'pages'),
        ],
      );
      await StorageService.instance.saveLog(log);

      final goal = Goal(id: 'literatureItems', metricKey: 'literatureItems', frequency: GoalFrequency.daily, target: 1, unit: GoalUnit.count);
      final progress = await svc.computeProgress(goal, today);
      expect(progress, 2);
    });

    test('no log for the day returns 0', () async {
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.daily, target: 3, unit: GoalUnit.count);
      final progress = await svc.computeProgress(goal, DateTime(2099, 1, 1));
      expect(progress, 0);
    });
  });

  group('computeProgress — daily, duration metrics', () {
    test('prayer sums session-aware alone + together minutes', () async {
      final today = DateTime(2026, 8, 17);
      final log = DailyLog(
        dateKey: '2026-08-17',
        prayerAloneSessions: [PrayerSession(duration: '30m', notes: '')],
        prayerOthersSessions: [PrayerSession(duration: '15m', notes: '')],
      );
      await StorageService.instance.saveLog(log);

      final goal = Goal(id: 'prayer', metricKey: 'prayer', frequency: GoalFrequency.daily, target: 20, unit: GoalUnit.minutes);
      final progress = await svc.computeProgress(goal, today);
      expect(progress, 45);
    });

    test('prayer falls back to legacy duration fields when sessions are empty', () async {
      final today = DateTime(2026, 8, 18);
      final log = DailyLog(dateKey: '2026-08-18', prayerAloneDuration: '1h', prayerOthersDuration: '10m');
      await StorageService.instance.saveLog(log);

      final goal = Goal(id: 'prayer', metricKey: 'prayer', frequency: GoalFrequency.daily, target: 20, unit: GoalUnit.minutes);
      final progress = await svc.computeProgress(goal, today);
      expect(progress, 70);
    });

    test('ddegTime is session-aware with legacy fallback', () async {
      final today = DateTime(2026, 8, 19);
      final log = DailyLog(dateKey: '2026-08-19', ddegSessions: [DdegSession(scripture: 'Ps 23', time: '25m', notes: '')]);
      await StorageService.instance.saveLog(log);

      final goal = Goal(id: 'ddegTime', metricKey: 'ddegTime', frequency: GoalFrequency.daily, target: 10, unit: GoalUnit.minutes);
      final progress = await svc.computeProgress(goal, today);
      expect(progress, 25);
    });

    test('discipleshipTime parses the legacy duration string', () async {
      final today = DateTime(2026, 8, 20);
      final log = DailyLog(dateKey: '2026-08-20', discipleshipDuration: '45m');
      await StorageService.instance.saveLog(log);

      final goal = Goal(id: 'discipleshipTime', metricKey: 'discipleshipTime', frequency: GoalFrequency.daily, target: 30, unit: GoalUnit.minutes);
      final progress = await svc.computeProgress(goal, today);
      expect(progress, 45);
    });
  });

  group('computeProgress — daily, presence-count metrics', () {
    test('fastingCount is 1 when fastingType or fastingDuration is set, 0 otherwise', () async {
      final day1 = DateTime(2026, 8, 21);
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-21', fastingType: 'Full fast'));
      final day2 = DateTime(2026, 8, 22);
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-22'));

      final goal = Goal(id: 'fastingCount', metricKey: 'fastingCount', frequency: GoalFrequency.daily, target: 1, unit: GoalUnit.count);
      expect(await svc.computeProgress(goal, day1), 1);
      expect(await svc.computeProgress(goal, day2), 0);
    });

    test('churchCount is 1 when churchType is set', () async {
      final day = DateTime(2026, 8, 23);
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-23', churchType: 'Sunday service'));
      final goal = Goal(id: 'churchCount', metricKey: 'churchCount', frequency: GoalFrequency.daily, target: 1, unit: GoalUnit.count);
      expect(await svc.computeProgress(goal, day), 1);
    });

    test('proclamationCount parses the stored numeric string', () async {
      final day = DateTime(2026, 8, 24);
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-24', proclamationCount: '3'));
      final goal = Goal(id: 'proclamationCount', metricKey: 'proclamationCount', frequency: GoalFrequency.daily, target: 2, unit: GoalUnit.count);
      expect(await svc.computeProgress(goal, day), 3);
    });
  });

  group('computeProgress — custom activity metrics', () {
    test('counter field sums the stored int value for the day', () async {
      final day = DateTime(2026, 8, 25);
      await StorageService.instance.saveLog(DailyLog(
        dateKey: '2026-08-25',
        customActivityData: {
          'act1': {'done': true, 'fields': {'Push-ups': 20}},
        },
      ));
      final goal = Goal(id: 'custom:act1:Push-ups', metricKey: 'custom:act1:Push-ups', frequency: GoalFrequency.daily, target: 10, unit: GoalUnit.count);
      expect(await svc.computeProgress(goal, day), 20);
    });

    test('duration field parses the stored duration string for the day', () async {
      final day = DateTime(2026, 8, 26);
      await StorageService.instance.saveLog(DailyLog(
        dateKey: '2026-08-26',
        customActivityData: {
          'act2': {'done': true, 'fields': {'Meditation': '20m'}},
        },
      ));
      final goal = Goal(id: 'custom:act2:Meditation', metricKey: 'custom:act2:Meditation', frequency: GoalFrequency.daily, target: 10, unit: GoalUnit.minutes);
      expect(await svc.computeProgress(goal, day), 20);
    });
  });

  group('computeProgress — weekly aggregation', () {
    test('sums a count metric across the cadence-configured week window', () async {
      // Default cadence is Sunday-ending, Monday-start. Seed 3 days within
      // the week containing 2026-08-12 (a Wednesday) with bibleChapters.
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-10', bibleChapters: '2')); // Monday
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-12', bibleChapters: '3')); // Wednesday
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-16', bibleChapters: '1')); // Sunday
      // A day outside this window should not be counted.
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-17', bibleChapters: '99')); // next Monday

      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.weekly, target: 5, unit: GoalUnit.count);
      final progress = await svc.computeProgress(goal, DateTime(2026, 8, 12));
      expect(progress, 6); // 2 + 3 + 1, not the 99 from the following week
    });
  });

  group('computeProgress — monthly aggregation', () {
    test('sums a count metric across the full calendar month', () async {
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-01', evangelismContacts: '2'));
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-31', evangelismContacts: '3'));
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-09-01', evangelismContacts: '99')); // next month excluded

      final goal = Goal(id: 'evangelismContacts', metricKey: 'evangelismContacts', frequency: GoalFrequency.monthly, target: 5, unit: GoalUnit.count);
      final progress = await svc.computeProgress(goal, DateTime(2026, 8, 15));
      expect(progress, 5); // 2 + 3, not the 99 from September
    });
  });

  group('isComplete', () {
    test('true when progress meets or exceeds target', () async {
      final day = DateTime(2026, 8, 27);
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-27', bibleChapters: '5'));
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.daily, target: 5, unit: GoalUnit.count);
      expect(await svc.isComplete(goal, day), true);
    });

    test('false when progress is under target', () async {
      final day = DateTime(2026, 8, 28);
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-28', bibleChapters: '2'));
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.daily, target: 5, unit: GoalUnit.count);
      expect(await svc.isComplete(goal, day), false);
    });
  });

  group('periodElapsedFraction', () {
    test('daily: always 1.0 regardless of time of day (whole-day granularity)', () {
      expect(svc.periodElapsedFraction(GoalFrequency.daily, DateTime(2026, 8, 14, 9)), 1.0);
      expect(svc.periodElapsedFraction(GoalFrequency.daily, DateTime(2026, 8, 14, 23)), 1.0);
    });

    test('weekly: fraction of the 7-day cadence window elapsed so far', () {
      // Default cadence Sunday-ending, week is Mon 8/10 - Sun 8/16.
      // Wednesday 8/12 is the 3rd day (index 2), so 3/7 elapsed.
      final frac = svc.periodElapsedFraction(GoalFrequency.weekly, DateTime(2026, 8, 12));
      expect(frac, closeTo(3 / 7, 0.01));
    });

    test('monthly: fraction of the calendar month elapsed so far', () {
      // August 2026 has 31 days; the 16th is day 16, so 16/31 elapsed.
      final frac = svc.periodElapsedFraction(GoalFrequency.monthly, DateTime(2026, 8, 16));
      expect(frac, closeTo(16 / 31, 0.01));
    });

    test('monthly: handles February in a non-leap year (28 days)', () {
      final frac = svc.periodElapsedFraction(GoalFrequency.monthly, DateTime(2026, 2, 14));
      expect(frac, closeTo(14 / 28, 0.01));
    });
  });

  group('justCompletedGoals', () {
    // justCompletedGoals reads period totals from storage via
    // computeProgress, so `after` must already be saved before calling it
    // (matching the real call site in LogScreen._persist(), which calls
    // this only after StorageService.saveLog(after) has completed).

    test('daily goal: returns a goal that crossed from under-target to at-target', () async {
      final before = DailyLog(dateKey: '2026-08-29', bibleChapters: '2');
      final after = DailyLog(dateKey: '2026-08-29', bibleChapters: '5');
      await StorageService.instance.saveLog(after);
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.daily, target: 5, unit: GoalUnit.count);
      final result = await svc.justCompletedGoals(before, after, [goal]);
      expect(result, [goal]);
    });

    test('daily goal: does not return a goal already complete before the save', () async {
      final before = DailyLog(dateKey: '2026-08-30', bibleChapters: '5');
      final after = DailyLog(dateKey: '2026-08-30', bibleChapters: '6');
      await StorageService.instance.saveLog(after);
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.daily, target: 5, unit: GoalUnit.count);
      final result = await svc.justCompletedGoals(before, after, [goal]);
      expect(result, isEmpty);
    });

    test('daily goal: does not return a goal still under target after the save', () async {
      final before = DailyLog(dateKey: '2026-08-31', bibleChapters: '1');
      final after = DailyLog(dateKey: '2026-08-31', bibleChapters: '2');
      await StorageService.instance.saveLog(after);
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.daily, target: 5, unit: GoalUnit.count);
      final result = await svc.justCompletedGoals(before, after, [goal]);
      expect(result, isEmpty);
    });

    test('daily goal: handles a null "before" (first save of a new day) as zero progress', () async {
      final after = DailyLog(dateKey: '2026-09-01', bibleChapters: '5');
      await StorageService.instance.saveLog(after);
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.daily, target: 5, unit: GoalUnit.count);
      final result = await svc.justCompletedGoals(null, after, [goal]);
      expect(result, [goal]);
    });

    test('weekly goal: completed by CUMULATIVE progress across days, not just today\'s single-day value', () async {
      // Regression test for the period-aware fix: a weekly goal of 10
      // chapters, already at 8 chapters earlier in the week (a day this
      // test seeds directly, simulating "before" days already logged),
      // should complete when today's own save alone is small (2 chapters)
      // but pushes the week's cumulative total to 10.
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-10', bibleChapters: '8')); // Monday, earlier in the week
      final before = DailyLog(dateKey: '2026-08-12', bibleChapters: '0'); // Wednesday, today's prior state
      final after = DailyLog(dateKey: '2026-08-12', bibleChapters: '2'); // Wednesday, today's new state (2 chapters, alone under target)
      await StorageService.instance.saveLog(after);
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.weekly, target: 10, unit: GoalUnit.count);
      final result = await svc.justCompletedGoals(before, after, [goal]);
      expect(result, [goal], reason: 'week total is 8 (Monday) + 2 (today) = 10, meeting target, even though today alone only contributed 2');
    });

    test('weekly goal: does not fire again on a later day if the week was already complete before today\'s save', () async {
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-10', bibleChapters: '15')); // Monday, already over target
      final before = DailyLog(dateKey: '2026-08-13', bibleChapters: '0'); // Thursday, today's prior state
      final after = DailyLog(dateKey: '2026-08-13', bibleChapters: '1'); // Thursday, today's new state
      await StorageService.instance.saveLog(after);
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.weekly, target: 10, unit: GoalUnit.count);
      final result = await svc.justCompletedGoals(before, after, [goal]);
      expect(result, isEmpty, reason: 'week total was already 15 >= 10 before today\'s save, so this is not a fresh completion');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/goal_progress_service_test.dart`
Expected: FAIL — `lib/services/goal_progress_service.dart` doesn't exist.

- [ ] **Step 3: Implement `GoalProgressService`**

Create `lib/services/goal_progress_service.dart`:

```dart
import '../models/daily_log.dart';
import 'duration_parser.dart';
import 'report_cadence_service.dart';
import 'report_service.dart';
import 'storage_service.dart';
import '../models/goal.dart';

/// Computes progress toward any [Goal] over its current period (daily,
/// weekly using the cadence-configured week, or calendar-monthly).
class GoalProgressService {
  static final instance = GoalProgressService._();
  GoalProgressService._();

  Future<int> computeProgress(Goal goal, [DateTime? ref]) async {
    final d = ref ?? DateTime.now();
    final logs = await _logsForPeriod(goal.frequency, d);
    int total = 0;
    for (final log in logs) {
      total += _metricValue(goal.metricKey, log);
    }
    return total;
  }

  Future<bool> isComplete(Goal goal, [DateTime? ref]) async {
    return (await computeProgress(goal, ref)) >= goal.target;
  }

  double periodElapsedFraction(GoalFrequency frequency, [DateTime? ref]) {
    final d = ref ?? DateTime.now();
    switch (frequency) {
      case GoalFrequency.daily:
        return 1.0;
      case GoalFrequency.weekly:
        // Synchronous fallback: use the default Sunday-ending window's
        // weekday index, since this method is sync (called from build
        // methods) and cannot await the configured cadence day. Callers
        // needing the true cadence-aware fraction should prefer computing
        // it from computeProgress's own period resolution; this method is
        // a lightweight approximation for pace-check UI only.
        return (d.weekday) / 7.0;
      case GoalFrequency.monthly:
        final lastDay = DateTime(d.year, d.month + 1, 0).day;
        return d.day / lastDay;
    }
  }

  /// [after] must already be persisted to storage (i.e. call this after
  /// StorageService.saveLog(after) has completed) — computeProgress reads
  /// from storage, so it needs the just-saved day's data to be there.
  Future<List<Goal>> justCompletedGoals(DailyLog? before, DailyLog after, List<Goal> goals) async {
    final completed = <Goal>[];
    final refDate = DateTime.parse(after.dateKey);
    for (final goal in goals) {
      // Period-aware: compare the period's total progress before vs. after
      // this save, not just today's single-day contribution — a weekly or
      // monthly goal can be completed by cumulative logging across several
      // days, not only by what changed today.
      final afterTotal = await computeProgress(goal, refDate);
      final todayAfterVal = _metricValue(goal.metricKey, after);
      final todayBeforeVal = before != null ? _metricValue(goal.metricKey, before) : 0;
      final beforeTotal = afterTotal - (todayAfterVal - todayBeforeVal);
      if (beforeTotal < goal.target && afterTotal >= goal.target) {
        completed.add(goal);
      }
    }
    return completed;
  }

  Future<List<DailyLog>> _logsForPeriod(GoalFrequency frequency, DateTime ref) async {
    final rs = ReportService.instance;
    switch (frequency) {
      case GoalFrequency.daily:
        final log = await StorageService.instance.getLog(rs.keyFor(ref));
        return log != null ? [log] : [];
      case GoalFrequency.weekly:
        final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
        final dates = rs.weekDates(ref, endWeekday);
        return StorageService.instance.getLogsBetween(rs.keyFor(dates.first), rs.keyFor(dates.last));
      case GoalFrequency.monthly:
        final first = DateTime(ref.year, ref.month, 1);
        final last = DateTime(ref.year, ref.month + 1, 0);
        return StorageService.instance.getLogsBetween(rs.keyFor(first), rs.keyFor(last));
    }
  }

  int _metricValue(String metricKey, DailyLog log) {
    if (metricKey.startsWith('custom:')) {
      final parts = metricKey.split(':');
      if (parts.length < 3) return 0;
      final activityId = parts[1];
      final fieldLabel = parts.sublist(2).join(':'); // field labels may contain ':'
      final data = log.customActivityData[activityId];
      if (data == null) return 0;
      final fields = data['fields'] as Map<String, dynamic>? ?? {};
      final raw = fields[fieldLabel];
      if (raw == null) return 0;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return parseDurationMinutes(raw.toString());
    }
    switch (metricKey) {
      case 'bibleChapters':
        return log.totalBibleChapters;
      case 'prayer':
        return _durationField(log.prayerAloneSessions.map((s) => s.duration).toList(),
                log.prayerAloneSessions.any((s) => s.isNotEmpty), log.prayerAloneDuration) +
            _durationField(log.prayerOthersSessions.map((s) => s.duration).toList(),
                log.prayerOthersSessions.any((s) => s.isNotEmpty), log.prayerOthersDuration);
      case 'evangelismContacts':
        return int.tryParse(log.evangelismContacts) ?? 0;
      case 'literatureItems':
        return log.literature.where((e) => e.title.isNotEmpty).length;
      case 'ddegTime':
        return _durationField(log.ddegSessions.map((s) => s.time).toList(),
            log.ddegSessions.any((s) => s.isNotEmpty), log.ddegTime);
      case 'fastingCount':
        return (log.fastingType.isNotEmpty || log.fastingDuration.isNotEmpty) ? 1 : 0;
      case 'churchCount':
        return log.churchType.isNotEmpty ? 1 : 0;
      case 'discipleshipTime':
        return parseDurationMinutes(log.discipleshipDuration);
      case 'proclamationCount':
        return int.tryParse(log.proclamationCount) ?? 0;
      default:
        return 0;
    }
  }

  /// Sums session durations if any session is non-empty, else falls back
  /// to the legacy single-duration field. Mirrors the session-aware
  /// pattern already used throughout report_service.dart.
  int _durationField(List<String> sessionDurations, bool hasNonEmptySession, String legacyDuration) {
    if (hasNonEmptySession) {
      int total = 0;
      for (final d in sessionDurations) {
        total += parseDurationMinutes(d);
      }
      return total;
    }
    return parseDurationMinutes(legacyDuration);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/goal_progress_service_test.dart`
Expected: PASS. If the weekly aggregation test fails because the default cadence isn't actually Sunday-ending in a fresh test environment (no `ReportCadenceService` settings saved), verify `ReportCadenceService.instance.getWeeklyDay()` truly defaults to 7 with no prior `setWeeklyDay` call in this test file's scope — it should, per that service's existing implementation, but confirm before debugging further if this specific test fails.

- [ ] **Step 5: Run static analysis**

Run: `flutter analyze lib/services/goal_progress_service.dart`
Expected: 0 errors.

- [ ] **Step 6: Commit**

```bash
git add lib/services/goal_progress_service.dart test/goal_progress_service_test.dart
git commit -m "feat: add GoalProgressService for computing goal progress across any period"
```

---

### Task 4: Storage, migration, and ARB keys

**Files:**
- Modify: `lib/services/storage_service.dart` (add `getGoals`/`saveGoals`/`migrateGoalsIfNeeded`)
- Modify: `lib/main.dart` (call the migration)
- Modify: `lib/services/backup_service.dart:128-129`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`
- Modify: `lib/l10n/generated/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_fr.dart`
- Test: `test/goal_migration_test.dart`

**Interfaces:**
- Consumes: `Goal`/`GoalFrequency`/`GoalUnit` from Task 1.
- Produces (used by Tasks 5, 6, 7):
  - `Future<List<Goal>> StorageService.getGoals()`
  - `Future<void> StorageService.saveGoals(List<Goal> goals)`
  - `Future<void> StorageService.migrateGoalsIfNeeded()`
  - New ARB/localization getters: `goalsSection`, `addGoal`, `dailyGoalsLabel`, `weeklyGoalsLabel`, `monthlyGoalsLabel`, `selectMetric`, `builtInMetrics`, `yourActivities`, `enterTarget`, `minutesUnit`, `hoursUnit`, `goalCompletedTitle`, `goalCompletedBody`, `behindPaceBannerText`, `goalDdegTime`, `goalFastingCount`, `goalChurchCount`, `goalDiscipleshipTime`, `goalProclamationCount`, `removeGoal`, `noGoalsYetForFrequency`.

- [ ] **Step 1: Write the failing migration test**

Read `test/report_cadence_service_test.dart` first to copy its exact `SharedPreferences.setMockInitialValues` / `TestWidgetsFlutterBinding.ensureInitialized()` boilerplate pattern (established in the prior reporting-cadence feature, in this same codebase).

Create `test/goal_migration_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_account/models/goal.dart';
import 'package:daily_account/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('migrateGoalsIfNeeded', () {
    test('converts old daily-frequency goals into new Goal list', () async {
      SharedPreferences.setMockInitialValues({
        'goalFrequency': 'daily',
        'goalBibleChapters': '3',
        'goalPrayerMinutes': '20',
        'goalEvangelismContacts': '0', // zero — should be excluded
        'goalLiteratureItems': '1',
      });

      await StorageService.instance.migrateGoalsIfNeeded();
      final goals = await StorageService.instance.getGoals();

      expect(goals.length, 3); // evangelismContacts excluded (was 0)
      final byKey = {for (final g in goals) g.metricKey: g};
      expect(byKey['bibleChapters']!.frequency, GoalFrequency.daily);
      expect(byKey['bibleChapters']!.target, 3);
      expect(byKey['prayer']!.target, 20);
      expect(byKey['prayer']!.unit, GoalUnit.minutes);
      expect(byKey['literatureItems']!.target, 1);
      expect(byKey.containsKey('evangelismContacts'), false);
    });

    test('converts old weekly-frequency goals correctly', () async {
      SharedPreferences.setMockInitialValues({
        'goalFrequency': 'weekly',
        'goalBibleChapters': '10',
      });

      await StorageService.instance.migrateGoalsIfNeeded();
      final goals = await StorageService.instance.getGoals();

      expect(goals.length, 1);
      expect(goals.first.frequency, GoalFrequency.weekly);
      expect(goals.first.target, 10);
    });

    test('is idempotent — a second call does not duplicate goals', () async {
      SharedPreferences.setMockInitialValues({
        'goalFrequency': 'daily',
        'goalBibleChapters': '3',
      });

      await StorageService.instance.migrateGoalsIfNeeded();
      await StorageService.instance.migrateGoalsIfNeeded();
      final goals = await StorageService.instance.getGoals();

      expect(goals.length, 1);
    });

    test('a user with no old goal settings migrates to an empty list without error', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.instance.migrateGoalsIfNeeded();
      final goals = await StorageService.instance.getGoals();
      expect(goals, isEmpty);
    });
  });

  group('getGoals / saveGoals round-trip', () {
    test('saving then loading preserves goal data', () async {
      SharedPreferences.setMockInitialValues({});
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.monthly, target: 50, unit: GoalUnit.count);
      await StorageService.instance.saveGoals([goal]);
      final loaded = await StorageService.instance.getGoals();
      expect(loaded.length, 1);
      expect(loaded.first.target, 50);
      expect(loaded.first.frequency, GoalFrequency.monthly);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/goal_migration_test.dart`
Expected: FAIL — `getGoals`/`saveGoals`/`migrateGoalsIfNeeded` don't exist on `StorageService` yet.

- [ ] **Step 3: Implement `getGoals`/`saveGoals`/`migrateGoalsIfNeeded` in `StorageService`**

In `lib/services/storage_service.dart`, add near the existing `_customActivitiesKey` section (read that section first at `storage_service.dart:416-448` to match its exact style):

```dart
  // ── Goals ───────────────────────────────────────────────────

  static const _goalsKey = 'goals';

  Future<List<Goal>> getGoals() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_goalsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Goal.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> saveGoals(List<Goal> goals) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_goalsKey, jsonEncode(goals.map((g) => g.toMap()).toList()));
  }

  /// One-time migration from the old single-frequency 4-goal system to
  /// the new Goal list. No-ops if already migrated (the 'goals' key
  /// already exists, even as an empty list from a prior no-op migration).
  Future<void> migrateGoalsIfNeeded() async {
    final p = await SharedPreferences.getInstance();
    if (p.containsKey(_goalsKey)) return;
    final oldFrequency = p.getString('goalFrequency') ?? 'weekly';
    final freq = oldFrequency == 'daily' ? GoalFrequency.daily : GoalFrequency.weekly;
    final goals = <Goal>[];
    void addIfPositive(String metricKey, String oldKey, GoalUnit unit) {
      final v = int.tryParse(p.getString(oldKey) ?? '0') ?? 0;
      if (v > 0) {
        goals.add(Goal(id: metricKey, metricKey: metricKey, frequency: freq, target: v, unit: unit));
      }
    }
    addIfPositive('bibleChapters', 'goalBibleChapters', GoalUnit.count);
    addIfPositive('prayer', 'goalPrayerMinutes', GoalUnit.minutes);
    addIfPositive('evangelismContacts', 'goalEvangelismContacts', GoalUnit.count);
    addIfPositive('literatureItems', 'goalLiteratureItems', GoalUnit.count);
    await saveGoals(goals);
  }
```

Add the import at the top of `storage_service.dart`: `import '../models/goal.dart';`

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/goal_migration_test.dart`
Expected: PASS

- [ ] **Step 5: Wire the migration into app startup**

In `lib/main.dart`, in the `main()` function, add the migration call alongside the other try/catch-wrapped startup calls (read the existing block at `main.dart:15-29` first to match its exact style — each init call is individually try/caught so one failure doesn't block the others):

```dart
  try { await StorageService.instance.migrateGoalsIfNeeded(); } catch (e) { debugPrint('[main] Goal migration failed: $e'); }
```

Place this after the `NotificationService.instance.init()` block and before `BackgroundTimerService.instance.init()` (no ordering dependency exists between these — this position just keeps storage-related init calls grouped near the top).

- [ ] **Step 6: Add `'goals'` to the backup export list**

In `lib/services/backup_service.dart`, find the list containing `'goalFrequency', 'goalBibleChapters', 'goalPrayerMinutes', 'goalEvangelismContacts', 'goalLiteratureItems'` (around line 128-129) and add `'goals'` to it.

- [ ] **Step 7: Add new ARB keys**

In `lib/l10n/app_en.arb`, near the existing goal-related keys (around line 595-611), add:

```json
  "goalsSection": "Goals",
  "addGoal": "+ Add goal",
  "dailyGoalsLabel": "Daily",
  "weeklyGoalsLabel": "Weekly",
  "monthlyGoalsLabel": "Monthly",
  "selectMetric": "What would you like to track?",
  "builtInMetrics": "Built-in",
  "yourActivities": "Your Activities",
  "enterTarget": "Target",
  "minutesUnit": "Minutes",
  "hoursUnit": "Hours",
  "goalCompletedTitle": "Goal reached! 🎉",
  "goalCompletedBody": "You hit your {goalLabel} goal — well done!",
  "@goalCompletedBody": { "placeholders": { "goalLabel": { "type": "String" } } },
  "behindPaceBannerText": "{count, plural, =1{1 goal could use some attention} other{{count} goals could use some attention}}",
  "@behindPaceBannerText": { "placeholders": { "count": { "type": "int" } } },
  "goalDdegTime": "DDEG time",
  "goalFastingCount": "Fasting days",
  "goalChurchCount": "Church attendance",
  "goalDiscipleshipTime": "Discipleship time",
  "goalProclamationCount": "Proclamation count",
  "removeGoal": "Remove goal",
  "noGoalsYetForFrequency": "No goals yet — tap \"+ Add goal\" to set one."
```

In `lib/l10n/app_fr.arb`, add the French equivalents at the same relative location:

```json
  "goalsSection": "Objectifs",
  "addGoal": "+ Ajouter un objectif",
  "dailyGoalsLabel": "Quotidien",
  "weeklyGoalsLabel": "Hebdomadaire",
  "monthlyGoalsLabel": "Mensuel",
  "selectMetric": "Que souhaitez-vous suivre ?",
  "builtInMetrics": "Intégré",
  "yourActivities": "Vos Activités",
  "enterTarget": "Cible",
  "minutesUnit": "Minutes",
  "hoursUnit": "Heures",
  "goalCompletedTitle": "Objectif atteint ! 🎉",
  "goalCompletedBody": "Vous avez atteint votre objectif {goalLabel} — bravo !",
  "@goalCompletedBody": { "placeholders": { "goalLabel": { "type": "String" } } },
  "behindPaceBannerText": "{count, plural, =1{1 objectif mérite votre attention} other{{count} objectifs méritent votre attention}}",
  "@behindPaceBannerText": { "placeholders": { "count": { "type": "int" } } },
  "goalDdegTime": "Temps RDQD",
  "goalFastingCount": "Jours de jeûne",
  "goalChurchCount": "Présence à l'église",
  "goalDiscipleshipTime": "Temps de discipulat",
  "goalProclamationCount": "Nombre de proclamations",
  "removeGoal": "Supprimer l'objectif",
  "noGoalsYetForFrequency": "Aucun objectif pour l'instant — appuyez sur « + Ajouter un objectif »."
```

- [ ] **Step 8: Add matching getters to the generated localization files**

**Read the file first, and use exactly three forward slashes (`///`) for every doc-comment line** — a prior session in this codebase broke compilation by writing a stray backslash (`\`) instead of `///` in one of these generated files. Verify each new doc comment reads `/// In en, this message translates to:` character-for-character before moving on, and run `flutter analyze` on these three files (Step 9 below) before proceeding to any other file.

In `lib/l10n/generated/app_localizations.dart` (abstract base class), add abstract getters/methods for all 21 new keys from Step 7, matching the exact existing style (read `notifReportTitleWeekly`'s entry from the reporting-cadence feature as a recent, in-codebase example of the doc-comment format for a method with a placeholder, and a plain string getter like `reportCadenceLabel` for the no-placeholder ones).

In `lib/l10n/generated/app_localizations_en.dart`, add the English `@override` implementations (string literals from Step 7's English ARB block; for `goalCompletedBody(String goalLabel)` and `behindPaceBannerText(int count)`, implement the interpolation/plural logic matching the existing `notifReportTitleWeekly`/similar pattern in this same file for a placeholder string, and this file's existing `streakDays`/`importPreview` entries for the ICU plural pattern).

In `lib/l10n/generated/app_localizations_fr.dart`, add the French `@override` implementations similarly.

- [ ] **Step 9: Run static analysis on the l10n files before continuing**

Run: `flutter analyze lib/l10n/generated/app_localizations.dart lib/l10n/generated/app_localizations_en.dart lib/l10n/generated/app_localizations_fr.dart`
Expected: 0 errors. Fix any doc-comment or syntax issue immediately before proceeding — a broken generated l10n file breaks every screen that imports `S`.

- [ ] **Step 10: Run the full test suite to confirm no regressions**

Run: `flutter test`
Expected: All tests pass (existing suite + the new `goal_migration_test.dart`).

- [ ] **Step 11: Run static analysis broadly**

Run: `flutter analyze lib/services/storage_service.dart lib/main.dart lib/services/backup_service.dart`
Expected: 0 new errors.

- [ ] **Step 12: Commit**

```bash
git add lib/services/storage_service.dart lib/main.dart lib/services/backup_service.dart lib/l10n/app_en.arb lib/l10n/app_fr.arb lib/l10n/generated/app_localizations.dart lib/l10n/generated/app_localizations_en.dart lib/l10n/generated/app_localizations_fr.dart test/goal_migration_test.dart
git commit -m "feat: add goal storage, one-time migration from legacy goal settings, and new ARB keys"
```

---

### Task 5: Settings screen — Goals section rework

**Files:**
- Modify: `lib/screens/settings_screen.dart`

**Interfaces:**
- Consumes: `Goal`, `GoalFrequency`, `GoalUnit` (Task 1); `GoalMetrics` (Task 1); `StorageService.instance.getGoals()`/`saveGoals(...)` (Task 4); new ARB keys (Task 4); `CustomActivity` list (existing, via `StorageService.instance.getCustomActivities()`).
- Produces: no new public interface — internal UI state only. This task is what makes goal CRUD actually usable, which Tasks 6-8 depend on for real (non-empty) goal data during manual verification.

- [ ] **Step 1: Read the current Goals section fully before editing**

Read `lib/screens/settings_screen.dart` lines 55-70 (state vars), 120-130 (`_load()`), and 830-865 (the `SectionCard` UI) in full — the exact current line numbers may have shifted from what was seen while writing this plan; re-locate by searching for `_goalFrequency` and the `🎯` (🎯) icon.

- [ ] **Step 2: Replace goal state variables**

Remove:
```dart
String _goalFrequency = 'weekly'; // 'weekly' or 'daily'
int _goalBibleChapters = 0;
int _goalPrayerMinutes = 0;
int _goalEvangelismContacts = 0;
int _goalLiteratureItems = 0;
```

Replace with:
```dart
List<Goal> _goals = [];
List<CustomActivity> _customActivitiesForGoals = [];
```

Add imports: `import '../models/goal.dart';` and `import '../data/goal_metrics.dart';` (the `CustomActivity` import likely already exists in this file for the custom-activity settings elsewhere — confirm before adding a duplicate).

- [ ] **Step 3: Replace goal loading in `_load()`**

Remove the 5 lines reading `goalFrequency`/`goalBibleChapters`/etc. Replace with:
```dart
    _goals = await StorageService.instance.getGoals();
    _customActivitiesForGoals = await StorageService.instance.getCustomActivities();
```

- [ ] **Step 4: Add goal CRUD helper methods**

Add these new private methods near the existing goal-related code (or near `_saveReminders`/similar persistence helpers, matching this file's existing organization):

```dart
  Future<void> _addGoal(GoalFrequency frequency) async {
    final metric = await _pickGoalMetric(frequency);
    if (metric == null) return;
    final result = await _pickGoalTarget(metric);
    if (result == null) return;
    final (target, unit) = result;
    setState(() {
      _goals.add(Goal(
        id: metric.key == 'custom:' ? metric.key : metric.key, // metric.key is already the full stable id for both built-in and custom
        metricKey: metric.key,
        frequency: frequency,
        target: target,
        unit: unit,
      ));
    });
    await StorageService.instance.saveGoals(_goals);
  }

  Future<void> _editGoal(Goal goal) async {
    final metric = _metricFor(goal.metricKey);
    if (metric == null) return;
    final result = await _pickGoalTarget(metric, initialTarget: goal.target, initialUnit: goal.unit);
    if (result == null) return;
    final (target, unit) = result;
    setState(() {
      goal.target = target;
      goal.unit = unit;
    });
    await StorageService.instance.saveGoals(_goals);
  }

  Future<void> _removeGoal(Goal goal) async {
    setState(() => _goals.remove(goal));
    await StorageService.instance.saveGoals(_goals);
  }

  GoalMetric? _metricFor(String metricKey) {
    final all = [...GoalMetrics.builtIn, ...GoalMetrics.fromCustomActivities(_customActivitiesForGoals)];
    for (final m in all) {
      if (m.key == metricKey) return m;
    }
    return null;
  }
```

Note: the `id: metric.key == 'custom:' ? metric.key : metric.key` line above is deliberately just `metric.key` either way (the ternary's two branches are identical) — `Goal.id` and `Goal.metricKey` are always the same value for goals created through this flow (only relevant if a future feature needs a goal to have an `id` independent of its metric, e.g. two goals on the same metric+frequency — which Step 5's picker already prevents, so keep this simple rather than introducing a separate id-generation scheme now). Simplify this line to just `id: metric.key,` when implementing — the ternary was scaffolding for this explanation, not intended final code.

- [ ] **Step 5: Add the metric picker and target-entry bottom sheets**

```dart
  Future<GoalMetric?> _pickGoalMetric(GoalFrequency frequency) async {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final textCol = AppTheme.textColor(context);
    final alreadyGoaled = _goals.where((g) => g.frequency == frequency).map((g) => g.metricKey).toSet();
    final builtIn = GoalMetrics.builtIn.where((m) => !alreadyGoaled.contains(m.key)).toList();
    final custom = GoalMetrics.fromCustomActivities(_customActivitiesForGoals)
        .where((m) => !alreadyGoaled.contains(m.key)).toList();

    return showModalBottomSheet<GoalMetric>(
      context: context,
      backgroundColor: AppTheme.surfaceColor(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.selectMetric, style: AppTheme.display(16, color: accent)),
                const SizedBox(height: 12),
                if (builtIn.isNotEmpty) ...[
                  Text(l.builtInMetrics.toUpperCase(), style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
                  ...builtIn.map((m) => ListTile(
                        leading: Text(m.icon, style: const TextStyle(fontSize: 20)),
                        title: Text(m.label(l), style: AppTheme.serif(14, color: textCol)),
                        onTap: () => Navigator.pop(ctx, m),
                      )),
                ],
                if (custom.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l.yourActivities.toUpperCase(), style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
                  ...custom.map((m) => ListTile(
                        leading: Text(m.icon, style: const TextStyle(fontSize: 20)),
                        title: Text(m.label(l), style: AppTheme.serif(14, color: textCol)),
                        onTap: () => Navigator.pop(ctx, m),
                      )),
                ],
                if (builtIn.isEmpty && custom.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l.noGoalsYetForFrequency, style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<(int, GoalUnit)?> _pickGoalTarget(GoalMetric metric, {int? initialTarget, GoalUnit? initialUnit}) async {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final showUnitToggle = metric.baseUnit == GoalUnit.minutes;
    GoalUnit selectedUnit = initialUnit ?? metric.baseUnit;
    final displayValue = initialTarget != null && selectedUnit == GoalUnit.hours
        ? (initialTarget / 60).toStringAsFixed(1)
        : (initialTarget?.toString() ?? '');
    final controller = TextEditingController(text: displayValue);

    return showModalBottomSheet<(int, GoalUnit)>(
      context: context,
      backgroundColor: AppTheme.surfaceColor(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(metric.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Text(metric.label(l), style: AppTheme.display(16, color: accent)),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.enterTarget),
              ),
              if (showUnitToggle) ...[
                const SizedBox(height: 12),
                Row(children: [
                  ChoiceChip(
                    label: Text(l.minutesUnit),
                    selected: selectedUnit == GoalUnit.minutes,
                    onSelected: (_) => setSheetState(() => selectedUnit = GoalUnit.minutes),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(l.hoursUnit),
                    selected: selectedUnit == GoalUnit.hours,
                    onSelected: (_) => setSheetState(() => selectedUnit = GoalUnit.hours),
                  ),
                ]),
              ],
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  final raw = double.tryParse(controller.text) ?? 0;
                  final minutesOrCount = selectedUnit == GoalUnit.hours ? (raw * 60).round() : raw.round();
                  Navigator.pop(ctx, (minutesOrCount, selectedUnit));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(gradient: AppTheme.goldGradient, borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text(l.saveGoals, style: AppTheme.display(16, color: AppTheme.bg0)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
```

Note: `_pickGoalTarget`'s returned target is always stored in the metric's base unit (minutes if `GoalUnit.minutes`, count if `GoalUnit.count`) even when the user picked "hours" for display — this matches spec §5's "always store in base unit" rule. `Goal.unit` still records `GoalUnit.hours` when the user picked it, purely for redisplaying the field pre-filled in hours next time they edit it (see the `displayValue` computation above).

- [ ] **Step 6: Replace the Goals `SectionCard` UI**

Find the current `SectionCard(icon: '🎯', title: _goalFrequency == 'daily' ? l.dailyGoals : l.weeklyGoals, ...)` block (previously at `settings_screen.dart:835-865`, re-locate by searching for `🎯`) and replace it entirely with:

```dart
        // ── Goals ──
        SectionCard(icon: '🎯', title: l.goalsSection, initiallyExpanded: false, children: [
          _goalFrequencySubsection(GoalFrequency.daily, l.dailyGoalsLabel, l),
          const SizedBox(height: 16),
          _goalFrequencySubsection(GoalFrequency.weekly, l.weeklyGoalsLabel, l),
          const SizedBox(height: 16),
          _goalFrequencySubsection(GoalFrequency.monthly, l.monthlyGoalsLabel, l),
        ]),
```

Add the new `_goalFrequencySubsection` widget method (placed near the other new goal methods from Step 4-5):

```dart
  Widget _goalFrequencySubsection(GoalFrequency frequency, String title, S l) {
    final accent = AppTheme.accentGold(context);
    final textCol = AppTheme.textColor(context);
    final mutedCol = AppTheme.mutedColor(context);
    final goalsForFrequency = _goals.where((g) => g.frequency == frequency).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: AppTheme.label(12, color: accent)),
        const SizedBox(height: 8),
        if (goalsForFrequency.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l.noGoalsYetForFrequency, style: AppTheme.serif(12, color: mutedCol)),
          )
        else
          ...goalsForFrequency.map((goal) => _goalRow(goal, l, accent, textCol, mutedCol)),
        GestureDetector(
          onTap: () => _addGoal(frequency),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: accent.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(l.addGoal, style: AppTheme.label(12, color: accent)),
          ),
        ),
      ],
    );
  }

  Widget _goalRow(Goal goal, S l, Color accent, Color textCol, Color mutedCol) {
    final metric = _metricFor(goal.metricKey);
    final icon = goal.customIcon ?? metric?.icon ?? '✨';
    final label = goal.customLabel ?? metric?.label(l) ?? goal.metricKey;
    final displayTarget = goal.unit == GoalUnit.hours ? '${(goal.target / 60).toStringAsFixed(1)}h' : '${goal.target}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => _editGoal(goal),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: AppTheme.serif(13, color: textCol))),
              Text(displayTarget, style: AppTheme.label(12, color: accent)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _removeGoal(goal),
                child: Icon(Icons.close, size: 16, color: mutedCol),
              ),
            ],
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 7: Remove now-unused `_goalField`/`_frequencyChip` methods**

Search for `Widget _goalField(` and `Widget _frequencyChip(` in `settings_screen.dart` — these built the old 4 fixed fields and the daily/weekly toggle chip respectively. Confirm no other call sites reference them (search the whole file), then delete both methods entirely.

- [ ] **Step 8: Run static analysis**

Run: `flutter analyze lib/screens/settings_screen.dart`
Expected: 0 errors.

- [ ] **Step 9: Manual verification**

If this environment can run the app (`flutter run` with a device/emulator with a visible display — prior tasks in past features found this environment often cannot), verify: Settings → Goals section shows "Goals" as the title (not "Daily/Weekly Goals"), three subsections (Daily/Weekly/Monthly) each with their own "+ Add goal" button, tapping it shows the metric picker grouped Built-in/Your Activities, picking a metric shows the target entry (with a minutes/hours toggle for duration metrics), saving adds a row, tapping a row edits it, tapping the X removes it. If interactive verification isn't possible in this environment, say so honestly in the report rather than claiming it.

- [ ] **Step 10: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: rework Goals settings section for independent daily/weekly/monthly goals"
```

---

### Task 6: Report screen — per-frequency goal cards and completion badges

**Files:**
- Modify: `lib/screens/report_screen.dart`

**Interfaces:**
- Consumes: `Goal`, `GoalFrequency` (Task 1); `GoalMetrics` (Task 1); `GoalProgressService.instance.computeProgress`/`isComplete` (Task 3); `StorageService.instance.getGoals()` (Task 4).
- Produces: no new public interface.

- [ ] **Step 1: Read the current goals/badges code fully**

Re-read `lib/screens/report_screen.dart` around the `_goals`/`_goalFrequency`/`_hasGoals` state (previously lines 50-51, 110-119), `_buildGoalsCard`/`_goalProgressRow` (previously lines 578-658), and `_computeBadges` (previously lines 121-133) — line numbers may have shifted from earlier features touching this file; re-locate by searching for `_goalFrequency` and `_computeBadges`.

- [ ] **Step 2: Replace goal state loading**

Remove:
```dart
  Map<String, int> _goals = {};
  String _goalFrequency = 'weekly';
```
and the `_load()` block reading `goalFrequency`/`goalBibleChapters`/etc.

Add:
```dart
  List<Goal> _goals = [];
  List<CustomActivity> _customActivitiesForGoals = [];
```
In `_refresh()` (or wherever `_load()`'s goal-loading previously ran — confirm the exact method name by reading the file, this codebase's `report_screen.dart` uses `_refresh()` as the main async load method per the reporting-cadence feature's earlier work in this same file), add:
```dart
    _goals = await StorageService.instance.getGoals();
    _customActivitiesForGoals = await StorageService.instance.getCustomActivities();
```

Add imports: `import '../models/goal.dart';`, `import '../data/goal_metrics.dart';`, `import '../models/custom_activity.dart';`, `import '../services/goal_progress_service.dart';`.

- [ ] **Step 3: Replace `_hasGoals`**

Change `bool get _hasGoals => _goals.values.any((v) => v > 0);` to `bool get _hasGoals => _goals.isNotEmpty;`

- [ ] **Step 4: Rewrite `_buildGoalsCard` as frequency-parameterized and async-data-driven**

Replace the entire `_buildGoalsCard` method with:

```dart
  Future<Widget?> _buildGoalsCard(GoalFrequency frequency, String title, S l, Color accent) async {
    final goalsForFrequency = _goals.where((g) => g.frequency == frequency).toList();
    if (goalsForFrequency.isEmpty) return null;

    final items = <(String, String, int, int)>[]; // (icon, label, current, target)
    for (final goal in goalsForFrequency) {
      final metric = _metricFor(goal.metricKey);
      final icon = goal.customIcon ?? metric?.icon ?? '✨';
      final label = goal.customLabel ?? metric?.label(l) ?? goal.metricKey;
      final current = await GoalProgressService.instance.computeProgress(goal, _weekRef);
      items.add((icon, label, current, goal.target));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.isDark(context) ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
            const SizedBox(height: 12),
            ...items.map((item) => _goalProgressRow(item.$1, item.$2, item.$3, item.$4, accent)),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  GoalMetric? _metricFor(String metricKey) {
    final all = [...GoalMetrics.builtIn, ...GoalMetrics.fromCustomActivities(_customActivitiesForGoals)];
    for (final m in all) {
      if (m.key == metricKey) return m;
    }
    return null;
  }
```

Note: this method is now `async` (returns `Future<Widget?>`, `null` when that frequency has no active goals) since `computeProgress` is async — this requires the caller (Step 5) to resolve these futures before laying out the widget tree, since Flutter `build()` methods are synchronous. `_goalProgressRow` itself (the existing per-goal-row renderer) is unchanged — it already takes `(icon, label, current, target)` and needs no modification.

- [ ] **Step 5: Update the call site(s) that render the goals card**

Find where the single old `_buildGoalsCard(l, accent)` call happens inside the main `build()` method's widget list (search for `_buildGoalsCard`). Since `build()` is synchronous and the new method is async, the three cards must be pre-computed as part of the screen's existing async data-loading flow (the same `_refresh()`/`_buildReport()` cycle already used for `_stats`/`_trend`/etc.), not computed inline during `build()`.

Add three new state fields:
```dart
  Widget? _dailyGoalsCard;
  Widget? _weeklyGoalsCard;
  Widget? _monthlyGoalsCard;
```

In `_refresh()` (after `_goals`/`_customActivitiesForGoals` are loaded per Step 2), add:
```dart
    if (mounted) {
      final l = S.of(context);
      final accent = AppTheme.accentGold(context);
      _dailyGoalsCard = await _buildGoalsCard(GoalFrequency.daily, l.dailyGoalsLabel, l, accent);
      _weeklyGoalsCard = await _buildGoalsCard(GoalFrequency.weekly, l.weeklyGoalsLabel, l, accent);
      _monthlyGoalsCard = await _buildGoalsCard(GoalFrequency.monthly, l.monthlyGoalsLabel, l, accent);
    }
```

(Place this alongside the file's existing pattern of computing derived UI state inside `_refresh()` before `setState`/`_buildReport()` runs — read the surrounding method to match exactly where other similar precomputed values are assigned.)

In `build()`, replace the single `if (!_isMonthly && _hasGoals && _stats != null) _buildGoalsCard(l, accent),` line with:
```dart
        if (!_isMonthly && _dailyGoalsCard != null) _dailyGoalsCard!,
        if (!_isMonthly && _weeklyGoalsCard != null) _weeklyGoalsCard!,
        if (!_isMonthly && _monthlyGoalsCard != null) _monthlyGoalsCard!,
```

(Keeping the existing `!_isMonthly` guard — goal cards render on the weekly report view; whether they should also render on the monthly report view is not specified by the spec and is deliberately left as today's existing behavior, i.e. hidden when `_isMonthly` is true, matching the pre-existing single-card behavior exactly.)

- [ ] **Step 6: Add per-goal completion badges to `_computeBadges`**

`_computeBadges` is synchronous today but computing goal completion requires `await GoalProgressService.instance.isComplete(...)`. Change `_computeBadges` to `async` (returning `Future<void>`, still assigning to the existing `_badges` field) and call it with `await` from wherever it's currently invoked (search for `_computeBadges()` call sites — likely inside `_refresh()` alongside the goals-card computation from Step 5).

At the end of the existing badge list construction (after the 6 fixed badges), add:
```dart
    for (final goal in _goals) {
      final complete = await GoalProgressService.instance.isComplete(goal, _weekRef);
      final metric = _metricFor(goal.metricKey);
      final icon = goal.customIcon ?? metric?.icon ?? '✨';
      final label = goal.customLabel ?? metric?.label(l) ?? goal.metricKey;
      _badges.add((icon, '$label — ${l.goalReached}', complete));
    }
```

(Reuses the existing `l.goalReached` ARB string — "Goal reached!" — already present in the codebase, no new key needed here.)

- [ ] **Step 7: Run static analysis**

Run: `flutter analyze lib/screens/report_screen.dart`
Expected: 0 errors.

- [ ] **Step 8: Manual verification**

If interactive verification is possible in this environment: create a daily and a weekly goal in Settings, log enough today to complete the daily one, open the Report tab, confirm both a "Daily" and (if any weekly goals exist) "Weekly" goals card render, and confirm a completion badge appears for the completed goal. If not possible, say so honestly.

- [ ] **Step 9: Commit**

```bash
git add lib/screens/report_screen.dart
git commit -m "feat: report screen renders per-frequency goal cards and completion badges"
```

---

### Task 7: Goal completion — reflection panel + push notification

**Files:**
- Modify: `lib/screens/log_screen.dart`
- Modify: `lib/services/reflection_service.dart`
- Modify: `lib/services/notification_service.dart`

**Interfaces:**
- Consumes: `GoalProgressService.instance.justCompletedGoals` (Task 3); `Goal` (Task 1); `StorageService.instance.getGoals()` (Task 4); `NotificationService.instance` (existing, extended here).
- Produces: `NotificationService.instance.showGoalCompletedNotification(Goal goal, String label)` — used by `LogScreen`, and available for Task 8 if needed (it is not).

- [ ] **Step 1: Add the one-shot completion notification method**

In `lib/services/notification_service.dart`, read the top-of-file ID-range doc comment first (`///  110–120 = Per-discipline reminders`, etc.) and add a new line documenting `130 = Goal completed` to that comment block. Then add this method (placed near other `.show()`-style immediate-display methods if any exist in this file — search for `.show(` vs `.zonedSchedule(` to find the right section; if this file has no existing immediate-`.show()` precedent, add it near `scheduleReportReminder` as a new, clearly-separated section with a `// ── Goal completion ──` header comment):

```dart
  /// Immediately show a one-shot "goal completed" notification (not
  /// scheduled — fires right away when called). Always uses id 130;
  /// if multiple goals complete in the same save, the notifications
  /// overwrite each other on the notification tray, which is an
  /// accepted simplification for a celebratory, non-durable notification.
  Future<void> showGoalCompletedNotification(String title, String body) async {
    await init();
    await _plugin.show(130, title, body, _alarmDetails, payload: 'navigate_report');
  }
```

(Confirm `_alarmDetails` is the correct existing notification-details constant this file already uses for its other `.show()`/`.zonedSchedule()` calls — read a nearby existing call site to match exactly; if this file uses a different details object for immediate vs. scheduled notifications, use whichever one existing code uses for similar celebratory/informational notifications.)

- [ ] **Step 2: Add `completedGoalsToday` to `ReflectionContext`**

In `lib/services/reflection_service.dart`, in the `ReflectionContext` class (read lines 50-76 first), add:
```dart
  final List<Goal> completedGoalsToday;
```
to the field list, and `this.completedGoalsToday = const [],` to the constructor's parameter list (matching the existing pattern where every field has a default). Add the import: `import '../models/goal.dart';`

- [ ] **Step 3: Add the goal-completion encouragement signal**

In `RuleBasedReflectionProvider._buildEncouragement` (read lines 279-283 first to see the `signals` list setup), add near the top of the method, right after `final signals = <(int priority, String text)>[];`:

```dart
    // Goal completion — highest priority, always mentioned first if present
    if (ctx.completedGoalsToday.isNotEmpty) {
      final names = ctx.completedGoalsToday.map((g) => g.customLabel ?? g.metricKey).join(', ');
      signals.add((0, isFr
          ? 'Objectif atteint : $names ! Continuez ainsi.'
          : 'Goal reached: $names! Keep it up.'));
    }
```

(Priority `0` is lower than every existing signal's priority number — 1 through 10 per the existing method — so this sorts first per the method's existing `signals.sort((a, b) => a.$1.compareTo(b.$1))` logic, and will be one of the (up to) 2 signals combined into the final returned text.)

Note: this uses `g.metricKey` as a raw fallback label rather than a localized `GoalMetric.label(l)` lookup, since `ReflectionContext`/`_buildEncouragement` don't currently have access to a `GoalMetric` registry lookup or the custom-activities list needed to resolve custom metric labels. This is an accepted simplification for this task — the metric key (e.g. `bibleChapters`, `custom:abc:Pages Read`) is not perfectly user-friendly in this one text signal, but is still informative and avoids threading additional dependencies into the reflection engine. If a cleaner label is wanted later, `ReflectionContext` could instead carry pre-resolved label strings rather than raw `Goal` objects — out of scope for this task.

- [ ] **Step 4: Wire goal-completion detection into `LogScreen._persist()`**

Read `lib/screens/log_screen.dart` around `_persist()` (line 544-552) and `_buildReflectionContext()`/`_scheduleReflectionUpdate()` (lines 556-591) in full before editing — both need coordinated changes.

Add a new state field to `_LogScreenState`: `List<Goal> _lastCompletedGoals = [];`

Replace `_persist()`:
```dart
  void _persist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 500), () async {
      final before = await StorageService.instance.getLog(_log.dateKey);
      await StorageService.instance.saveLog(_log);
      widget.onChanged();
      ReadingPlanService.instance.autoDetectCompletion(_log);

      final goals = await StorageService.instance.getGoals();
      final completed = await GoalProgressService.instance.justCompletedGoals(before, _log, goals);
      if (completed.isNotEmpty) {
        _lastCompletedGoals = completed;
        for (final goal in completed) {
          final label = goal.customLabel ?? goal.metricKey;
          final title = S.of(context).goalCompletedTitle;
          final body = S.of(context).goalCompletedBody(label);
          await NotificationService.instance.showGoalCompletedNotification(title, body);
        }
      }

      _scheduleReflectionUpdate();
    });
  }
```

Add imports to `log_screen.dart`: `import '../models/goal.dart';`, `import '../services/goal_progress_service.dart';` (`StorageService`/`NotificationService` are almost certainly already imported in this file given its extensive existing use of both — confirm rather than assume, and only add if genuinely missing).

Note: `_scheduleReflectionUpdate()` has exactly one call site inside `_persist()` today (confirmed: `log_screen.dart:550`, the last line of the existing debounce-timer callback; its other two call sites at lines 92 and 97 are inside `_loadLog()`/init-time code, unrelated to `_persist()` and not touched by this task). The rewritten `_persist()` above preserves this — `_scheduleReflectionUpdate()` stays the last call in the callback, now running after the new goal-detection logic instead of immediately after `saveLog`/`widget.onChanged()`/`autoDetectCompletion`.

- [ ] **Step 5: Thread `_lastCompletedGoals` into `_buildReflectionContext`**

In `_buildReflectionContext()` (lines 557-575), add `completedGoalsToday: _lastCompletedGoals,` to the `ReflectionContext(...)` constructor call.

- [ ] **Step 6: Run static analysis**

Run: `flutter analyze lib/screens/log_screen.dart lib/services/reflection_service.dart lib/services/notification_service.dart`
Expected: 0 errors.

- [ ] **Step 7: Run the full test suite**

Run: `flutter test`
Expected: All tests pass — no existing reflection or log-screen tests should be broken by these additive changes (default `completedGoalsToday: const []` preserves old behavior when no goals are completed).

- [ ] **Step 8: Manual verification**

If interactive verification is possible: create a daily goal with a low target, log enough to complete it, confirm a "Goal reached! 🎉" push notification appears immediately and the AI reflection panel's encouragement text mentions the completed goal. If not possible, say so honestly.

- [ ] **Step 9: Commit**

```bash
git add lib/screens/log_screen.dart lib/services/reflection_service.dart lib/services/notification_service.dart
git commit -m "feat: congratulate on goal completion via reflection text and push notification"
```

---

### Task 8: Pace reminders — in-app banner + scheduled push

**Files:**
- Modify: `lib/screens/home_shell.dart`
- Modify: `lib/screens/report_screen.dart`
- Modify: `lib/services/notification_service.dart`
- Modify: `lib/screens/settings_screen.dart`

**Interfaces:**
- Consumes: `GoalProgressService.instance.computeProgress`/`periodElapsedFraction` (Task 3); `Goal`/`GoalFrequency` (Task 1); `ReportCadenceService.instance.getWeeklyDay()` (existing, from the reporting-cadence feature).
- Produces: no new public interface consumed by other tasks (this is the last task).

- [ ] **Step 1: Add the behind-pace computation helper**

In `lib/services/goal_progress_service.dart` (Task 3's file — this is a small addition to that existing service, not a new file), add:

```dart
  /// True if [goal] is past its period's midpoint but under half its
  /// target — a simple, non-continuous pace heuristic (see design spec
  /// §9 for rationale).
  Future<bool> isBehindPace(Goal goal, [DateTime? ref]) async {
    final elapsed = periodElapsedFraction(goal.frequency, ref);
    if (elapsed <= 0.5) return false;
    final progress = await computeProgress(goal, ref);
    if (goal.target <= 0) return false;
    return (progress / goal.target) < 0.5;
  }
```

Add a unit test to `test/goal_progress_service_test.dart` (append to the existing file):
```dart
  group('isBehindPace', () {
    test('false before the period midpoint even with zero progress', () async {
      // Daily goals are always elapsed=1.0 per periodElapsedFraction, so
      // this case is only meaningful for weekly/monthly — use a monthly
      // goal early in the month.
      final earlyMonth = DateTime(2026, 8, 5); // day 5 of 31 = ~16% elapsed
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.monthly, target: 100, unit: GoalUnit.count);
      expect(await GoalProgressService.instance.isBehindPace(goal, earlyMonth), false);
    });

    test('true past the midpoint with under-half progress', () async {
      final day = DateTime(2026, 8, 29);
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-29', bibleChapters: '10'));
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.monthly, target: 100, unit: GoalUnit.count);
      // Past day 15 (midpoint of 31), progress 10 < 50, so behind.
      expect(await GoalProgressService.instance.isBehindPace(goal, day), true);
    });

    test('false past the midpoint with over-half progress', () async {
      final day = DateTime(2026, 8, 29);
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-29', bibleChapters: '60'));
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.monthly, target: 100, unit: GoalUnit.count);
      expect(await GoalProgressService.instance.isBehindPace(goal, day), false);
    });
  });
```

Run: `flutter test test/goal_progress_service_test.dart` — expect PASS.

- [ ] **Step 2: Add the in-app banner check and banner widget to `HomeShell`**

Read `lib/screens/home_shell.dart` around `_checkAutoSend()` (line 358), its call sites in `initState`/`didChangeAppLifecycleState` (lines 52-53, 90-91), the existing `_hasPendingReport` state field (line 40) and its banner (`_pendingReportBanner()` at line 1238, rendered at line 855 inside `build()`'s top-level `Column`) in full before editing.

**Confirmed pattern to follow:** `_hasPendingReport` is NOT threaded into `ReportScreen` — it's a `HomeShell`-owned boolean rendered as a banner directly inside `HomeShell.build()`'s own `Column`, above the tab body, visible regardless of which tab is active (`lib/screens/home_shell.dart:855`: `if (_hasPendingReport) _pendingReportBanner(),`). The goal pace banner follows this exact same pattern — owned and rendered entirely within `HomeShell`, never passed into `ReportScreen`.

Add a new state field: `List<Goal> _behindPaceGoals = [];`

Add a new method, modeled directly on `_checkAutoSend`'s structure:
```dart
  Future<void> _checkGoalPace() async {
    final enabled = (await StorageService.instance.getSetting('goalPaceRemindersEnabled', fallback: 'true')) == 'true';
    if (!enabled) return;
    final goals = await StorageService.instance.getGoals();
    final behind = <Goal>[];
    for (final goal in goals) {
      if (await GoalProgressService.instance.isBehindPace(goal)) behind.add(goal);
    }
    if (mounted) setState(() => _behindPaceGoals = behind);
  }
```

Call `_checkGoalPace();` from the same two places `_checkAutoSend()` is called (`initState`, and the resumed branch of `didChangeAppLifecycleState`).

Add a new banner widget method, styled to match `_pendingReportBanner()` exactly (read it first at `home_shell.dart:1238-1283` to copy its `Container`/margin/padding/border structure precisely rather than approximating):

```dart
  Widget _behindPaceGoalsBanner() {
    final l = S.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.rust.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.rust.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('⏳', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l.behindPaceBannerText(_behindPaceGoals.length),
                style: AppTheme.serif(12, color: AppTheme.rust)),
          ),
          GestureDetector(
            onTap: () => setState(() => _tab = 1), // navigate to the Report tab
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.rust.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(l.viewReport, style: AppTheme.label(10, color: AppTheme.rust)), // existing ARB key, confirmed present at app_en.arb:399 ("View Report")
            ),
          ),
        ],
      ),
    );
  }
```

Add the matching French string to `lib/l10n/app_fr.arb`'s `viewReport` entry only if it's missing there — check first, it likely already exists alongside the English one since `viewReport` is a pre-existing key from before this feature.

`_tab` (confirmed at `home_shell.dart:34`) and tab index `1` for the Report tab (confirmed via existing precedents at `home_shell.dart:63,190,192`, all doing `setState(() => _tab = 1);` to navigate there) are both verified correct — no further re-verification needed.

- [ ] **Step 3: Render the banner in `HomeShell.build()`**

In `build()`, add the banner alongside the existing pending-report banner:
```dart
              if (_hasPendingReport) _pendingReportBanner(),
              if (_behindPaceGoals.isNotEmpty) _behindPaceGoalsBanner(),
```

Add imports to `home_shell.dart`: `import '../models/goal.dart';`, `import '../services/goal_progress_service.dart';`

- [ ] **Step 4: Add the `goalPaceRemindersEnabled` toggle to Settings**

In `lib/screens/settings_screen.dart`, add a new state field `bool _goalPaceRemindersEnabled = true;`, load it in `_load()`:
```dart
    _goalPaceRemindersEnabled = (await s.getSetting('goalPaceRemindersEnabled', fallback: 'true')) == 'true';
```
Add a simple toggle switch near the Goals section (a `SwitchListTile` or matching this file's existing toggle-row style — search for an existing simple bool-setting toggle like `_notificationsEnabled`'s switch for the exact widget pattern to copy) that calls:
```dart
    setState(() => _goalPaceRemindersEnabled = value);
    await StorageService.instance.setSetting('goalPaceRemindersEnabled', value ? 'true' : 'false');
    await NotificationService.instance.scheduleGoalPaceChecks(); // re-arm with the new setting
```

- [ ] **Step 5: Add scheduled pace-check notifications**

In `lib/services/notification_service.dart`, add IDs 140 (daily), 141 (weekly), 142 (monthly) to the top-of-file ID-range doc comment (`///  140-142 = Goal pace-check reminders`).

Add:
```dart
  /// Schedule (or re-schedule) the three goal pace-check reminders. Each
  /// is a one-shot notification whose "is the user actually behind" state
  /// is computed at schedule time (this plugin's zonedSchedule bakes text
  /// in at schedule time, not fire time — see design spec §9) and re-armed
  /// whenever this method runs again (called from rescheduleAll(), i.e.
  /// on every app start/resume).
  Future<void> scheduleGoalPaceChecks() async {
    await init();
    final enabled = (await StorageService.instance.getSetting('goalPaceRemindersEnabled', fallback: 'true')) == 'true';
    for (final id in [140, 141, 142]) {
      await _plugin.cancel(id);
    }
    if (!enabled) return;

    final goals = await StorageService.instance.getGoals();
    final byFrequency = {
      GoalFrequency.daily: goals.where((g) => g.frequency == GoalFrequency.daily).toList(),
      GoalFrequency.weekly: goals.where((g) => g.frequency == GoalFrequency.weekly).toList(),
      GoalFrequency.monthly: goals.where((g) => g.frequency == GoalFrequency.monthly).toList(),
    };

    Future<int> countBehind(List<Goal> list) async {
      int n = 0;
      for (final g in list) {
        if (await GoalProgressService.instance.isBehindPace(g)) n++;
      }
      return n;
    }

    final dailyBehind = await countBehind(byFrequency[GoalFrequency.daily]!);
    if (dailyBehind > 0) {
      await _safeZonedSchedule(140, 'Goals', '$dailyBehind daily goal(s) could use some attention today.',
          _nextInstanceOfTime(15, 0), _alarmDetails);
    }

    final weeklyBehind = await countBehind(byFrequency[GoalFrequency.weekly]!);
    if (weeklyBehind > 0) {
      final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
      final midWeekday = ((endWeekday - 3 - 1) % 7) + 1; // 3 days before the week-ending day, DateTime.weekday convention
      await _safeZonedSchedule(141, 'Goals', '$weeklyBehind weekly goal(s) could use some attention.',
          _nextInstanceOfWeekday(midWeekday, 18, 0), _alarmDetails);
    }

    final monthlyBehind = await countBehind(byFrequency[GoalFrequency.monthly]!);
    if (monthlyBehind > 0) {
      await _safeZonedSchedule(142, 'Goals', '$monthlyBehind monthly goal(s) could use some attention.',
          _nextInstanceOfMonthlyDay((year, month) => 15, 18, 0), _alarmDetails);
    }
  }
```

Note: `_nextInstanceOfMonthlyDay` and `_nextInstanceOfWeekday` are existing private helpers from the reporting-cadence feature (already in this file) — reused here, not reimplemented. `_nextInstanceOfMonthlyDay` takes a `resolveDay` callback per its existing signature from that feature; here it's a constant `15` since goal-period midpoints are fixed per the spec (independent of `reportMonthlyDay`). Add the import `import 'goal_progress_service.dart';` and `import '../models/goal.dart';` to this file if not already present from prior tasks.

Call `scheduleGoalPaceChecks();` from `rescheduleAll()` (alongside the other categories already scheduled there — read that method first to place this call consistently with the others).

- [ ] **Step 6: Run static analysis**

Run: `flutter analyze lib/screens/home_shell.dart lib/screens/report_screen.dart lib/services/notification_service.dart lib/screens/settings_screen.dart lib/services/goal_progress_service.dart`
Expected: 0 errors.

- [ ] **Step 7: Run the full test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 8: Manual verification**

If interactive verification is possible: create a weekly goal, don't log anything toward it, confirm no banner appears before the week's midpoint; this is hard to fully verify live without waiting for the actual midpoint to arrive — as an alternative, verify by code trace (re-read `_checkGoalPace`, `isBehindPace`, and `scheduleGoalPaceChecks` end to end and confirm the logic composes correctly), matching the verification approach used for the equivalent hard-to-live-test auto-send logic in the reporting-cadence feature.

- [ ] **Step 9: Commit**

```bash
git add lib/screens/home_shell.dart lib/screens/report_screen.dart lib/services/notification_service.dart lib/screens/settings_screen.dart lib/services/goal_progress_service.dart test/goal_progress_service_test.dart
git commit -m "feat: add pace reminders (in-app banner + scheduled push) for goals behind mid-period"
```

---

### Task 9: Final verification pass

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: All tests pass, including every new test file from Tasks 1-8.

- [ ] **Step 2: Run full static analysis**

Run: `flutter analyze`
Expected: 0 new errors (pre-existing lint `info`-level suggestions unrelated to this feature are acceptable).

- [ ] **Step 3: Search for any remaining references to the old goal system**

Run: search `lib/` for `goalFrequency`, `_goalBibleChapters`, `_goalPrayerMinutes`, `_goalEvangelismContacts`, `_goalLiteratureItems`, `_goalField(`, `_frequencyChip(`.
Expected: The only remaining references to `'goalFrequency'`/`'goalBibleChapters'`/etc. as string literals should be inside `StorageService.migrateGoalsIfNeeded()` (Task 4) — reading the old keys for one-time migration is correct and expected. No remaining references to the old private state variables or UI helper methods (`_goalField`, `_frequencyChip`) should exist anywhere.

- [ ] **Step 4: Search for any other place in the codebase that computes goal-like progress independently**

Run: search `lib/` for `totalBibleChapters`, `totalPrayerMinutes`, `totalEvangelismContacts`, `litItems` used alongside a hardcoded comparison against a goal-like threshold, OUTSIDE of `GoalProgressService`/`WeekStats`/`MonthStats`'s own definitions — this checks for any leftover ad-hoc goal-progress logic Task 6/7/8 might have missed replacing. This is a "look for the same class of gap the reporting-cadence feature's final review found" check, not an expectation that anything will actually turn up — if nothing does, that's the expected clean result.

- [ ] **Step 5: Manual end-to-end walkthrough (or code-trace if interactive verification isn't possible)**

1. Settings → Goals section shows "Goals" title, three subsections, each independently addable.
2. Add a daily Bible-chapters goal (target 3) and a weekly prayer goal (target 60 min via the hours toggle set to 1h).
3. Log 3+ Bible chapters today → confirm a completion push notification fires, the AI reflection mentions it, and the Report screen shows a completion badge.
4. Confirm the Report screen's Daily goals card shows the Bible goal at/above target, and a separate Weekly goals card shows the prayer goal's progress independently.
5. Confirm removing a goal from Settings removes its card/row everywhere.

- [ ] **Step 6: Final commit if any fixes were needed during verification**

```bash
git add -A
git commit -m "fix: address issues found during final goals system verification"
```

(Only create this commit if Steps 1-5 actually required changes. If everything passed cleanly, skip this step.)

---

## Self-Review Notes

- **Spec coverage:** §1 Goal model → Task 1. §2 Metric registry → Task 1. §3 GoalProgressService → Task 3 (§3a duration parser extraction → Task 2, sequenced first since Task 3 depends on it). §4 Settings rework → Task 5. §5 Unit conversion → folded into Task 5 (target-entry sheet) and Task 1 (base-unit storage rule, a Global Constraint). §6 Report screen cards → Task 6. §7 Migration → Task 4. §8 Congratulations (3 surfaces) → Task 7 (reflection + push) and Task 6 (report badge, since badges are computed alongside the goal cards in that same screen). §9 Pace reminders (2 surfaces) → Task 8. §10 Notification ID allocation → folded into Tasks 7 and 8 at the point each ID range is actually used. Testing section → unit tests embedded in Tasks 1, 2, 3, 4, 8; no widget tests, per spec.
- **Placeholder scan:** No TBD/TODO markers. The one spot with explanatory "note" text about a ternary being scaffolding (Task 5 Step 4) includes the exact simplified code to write, not a vague instruction.
- **Type consistency:** `Goal`/`GoalFrequency`/`GoalUnit` (Task 1), `GoalMetric`/`GoalMetrics` (Task 1), `GoalProgressService` methods (Task 3) are referenced with identical signatures across Tasks 4-8 — cross-checked each task's "Interfaces" block against Task 1/3/4's "Produces" blocks.
- **Task ordering:** 1 (model/registry, no deps) → 2 (duration parser, no deps on 1) → 3 (progress service, needs 1 + 2) → 4 (storage/migration/ARB, needs 1) → 5 (settings UI, needs 1 + 4) → 6 (report UI, needs 1 + 3 + 4) → 7 (congratulations, needs 1 + 3 + 4) → 8 (pace reminders, needs 1 + 3, and extends Task 3's file directly) → 9 (final verification, needs everything). Sequential dispatch (no parallel implementer subagents per the subagent-driven-development skill's own rule) makes this ordering directly usable as the dispatch sequence.
- **Corrections made during self-review** (before dispatch, so these are already reflected in the task text above, not left as open issues): (1) Task 7's goal-completion detection point was redesigned — the original idea of snapshotting `_log` before/after inside `_persist()` doesn't work because `_log` is already mutated by the calling `onChanged` handler before `_persist()` runs; fixed to fetch the last-persisted log from storage instead. (2) Task 3's test plan was corrected after discovering no existing test file drives the `StorageService` singleton directly (`storage_service_test.dart` deliberately uses its own separate DB connection) — added the verified `sqflite_common_ffi` + `databaseFactory` override approach with an explicit fallback. (3) Task 8's pace-reminder banner was redesigned after checking the actual `_hasPendingReport` precedent — that state lives entirely in `HomeShell` and is never threaded into `ReportScreen`; the original plan wrongly assumed a threading mechanism that doesn't exist, now corrected to match the real pattern.
