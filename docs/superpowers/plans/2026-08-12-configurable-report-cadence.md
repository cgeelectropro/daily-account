# Configurable Reporting Cadence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user choose Weekly (on any day of the week) or Monthly (on a specific day, or the last day of the month) as their reporting cadence, replacing the hardcoded Sunday-only behavior across report generation, the report screen's default view, reminder notifications, and auto-send.

**Architecture:** A new `ReportCadenceService` singleton owns the three new settings and the pure date math (which day is the report day, resolving "last day of month"). `ReportService.weekDates()` gains an optional `endWeekday` parameter so its report-building methods can pass the configured day through without becoming a breaking change for other callers. `NotificationService`'s Sunday-specific scheduling generalizes to accept any weekday or day-of-month. `HomeShell`'s auto-send and `ReportScreen`'s default view read the cadence at the point they already do async setup work.

**Tech Stack:** Flutter/Dart, SharedPreferences (via existing `StorageService`), `flutter_local_notifications` + `timezone` (existing), `flutter_test` for unit tests.

## Global Constraints

- Default behavior for existing users must be unchanged: `reportCadence=weekly`, `reportWeeklyDay=7` (Sunday) reproduces today's Monday→Sunday weekly report and Sunday reminder exactly.
- `reportWeeklyDay` uses Dart's `DateTime.weekday` convention: 1=Monday ... 7=Sunday.
- `reportMonthlyDay` is either a string `"1"`–`"31"` or the literal string `"last"`.
- All new settings are read/written via the existing `StorageService.getSetting`/`setSetting` (SharedPreferences-backed) — no new storage mechanism.
- No widget tests for the new settings UI; unit tests only for pure date-math logic (per spec §Testing).
- New ARB keys must be added to both `lib/l10n/app_en.arb` and `lib/l10n/app_fr.arb`, then the generated localization files (`lib/l10n/generated/app_localizations*.dart`) updated to match — this project's generated l10n files are checked in and hand-editable (see prior session precedent), not solely produced by `flutter gen-l10n`, so update both ARB and generated `.dart` files in the same task.

---

## File Structure

- **Create** `lib/services/report_cadence_service.dart` — new singleton: settings getters/setters, `resolveMonthlyDay`, `isReportDay`.
- **Create** `test/report_cadence_service_test.dart` — unit tests for the above.
- **Modify** `lib/services/report_service.dart` — `weekDates()` gains `endWeekday` param; `computeWeekStats`, `computeTrend`, `buildFullReport`, `buildCompactReport` fetch and pass it through.
- **Modify** `test/report_service_test.dart` — add cases for non-Sunday `endWeekday`.
- **Modify** `lib/services/notification_service.dart` — rename `scheduleSundayReminder`→`scheduleReportReminder`, `cancelSundayFollowUps`→`cancelReportFollowUps`; add `_nextInstanceOfMonthlyDay`; remove redundant `_nextInstanceOfSunday`; `scheduleAutoSendReminder` and `rescheduleAll` become cadence-aware.
- **Modify** `test/notification_service_test.dart` — this file tests `NotificationService`'s private time-math by re-implementing the same algorithms as free functions (see its own top-of-file doc comment) rather than calling the real private methods. Its `nextInstanceOfSunday` shadow function and both groups that use it (`nextInstanceOfSunday — Sunday reminders`, `Sunday reminder follow-up schedule`) test an algorithm identical to the already-covered `nextInstanceOfWeekday` — rename them to drop the Sunday-specific framing (the generic weekday algorithm is what's actually being verified) and add a new `nextInstanceOfMonthlyDay` shadow function + test group mirroring the real service's new `_nextInstanceOfMonthlyDay`.
- **Modify** `lib/screens/report_screen.dart` — `_isMonthly` initializes from cadence; Sunday banner condition becomes cadence-driven cached state.
- **Modify** `lib/screens/home_shell.dart` — `_checkAutoSend` guard and report-building branch on cadence; dedup key generalizes.
- **Modify** `lib/screens/settings_screen.dart` — new cadence picker UI section; `_scheduleAllNotifications`/`_saveReminders` compute dynamic reminder text and pass the configured day through.
- **Modify** `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`, and their generated `.dart` counterparts — new cadence picker labels + dynamic reminder title/body templates; remove now-unused static `notifSundayTitle`/`notifSundayBody` only after nothing references them.

---

### Task 1: `ReportCadenceService` — settings + pure date math

**Files:**
- Create: `lib/services/report_cadence_service.dart`
- Test: `test/report_cadence_service_test.dart`

**Interfaces:**
- Consumes: `StorageService.instance.getSetting(String key, {String fallback})` → `Future<String>`; `StorageService.instance.setSetting(String key, String value)` → `Future<void>` (both already exist in `lib/services/storage_service.dart`).
- Produces (used by Tasks 2, 3, 5, 6, 7):
  - `enum ReportCadence { weekly, monthly }`
  - `ReportCadenceService.instance` (singleton)
  - `Future<ReportCadence> getCadence()`
  - `Future<int> getWeeklyDay()` — returns 1–7
  - `Future<String> getMonthlyDay()` — returns `"1"`–`"31"` or `"last"`
  - `Future<void> setCadence(ReportCadence cadence)`
  - `Future<void> setWeeklyDay(int weekday)`
  - `Future<void> setMonthlyDay(String day)`
  - `int resolveMonthlyDay(int year, int month, String configuredDay)` — pure, sync
  - `Future<bool> isReportDay([DateTime? date])`

- [ ] **Step 1: Write the failing tests for `resolveMonthlyDay`**

Create `test/report_cadence_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/services/report_cadence_service.dart';

void main() {
  final svc = ReportCadenceService.instance;

  group('resolveMonthlyDay', () {
    test('exact day within range returns that day', () {
      expect(svc.resolveMonthlyDay(2026, 3, '15'), 15);
    });

    test('day beyond month length clamps to last day (31 in Feb)', () {
      expect(svc.resolveMonthlyDay(2026, 2, '31'), 28); // 2026 is not a leap year
    });

    test('day beyond month length clamps to last day (31 in April, 30 days)', () {
      expect(svc.resolveMonthlyDay(2026, 4, '31'), 30);
    });

    test('"last" resolves to last day of a 31-day month', () {
      expect(svc.resolveMonthlyDay(2026, 1, 'last'), 31);
    });

    test('"last" resolves to last day of February in a non-leap year', () {
      expect(svc.resolveMonthlyDay(2026, 2, 'last'), 28);
    });

    test('"last" resolves to last day of February in a leap year', () {
      expect(svc.resolveMonthlyDay(2028, 2, 'last'), 29);
    });

    test('day 1 returns 1 in every month', () {
      expect(svc.resolveMonthlyDay(2026, 2, '1'), 1);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/report_cadence_service_test.dart`
Expected: FAIL — `report_cadence_service.dart` doesn't exist yet (import error).

- [ ] **Step 3: Implement `ReportCadenceService` — settings + `resolveMonthlyDay`**

Create `lib/services/report_cadence_service.dart`:

```dart
import 'storage_service.dart';

enum ReportCadence { weekly, monthly }

/// Owns the user's reporting cadence preference (weekly on a chosen weekday,
/// or monthly on a chosen day / the last day of the month) and the pure
/// date math needed to answer "is today the report day?".
class ReportCadenceService {
  static final instance = ReportCadenceService._();
  ReportCadenceService._();

  static const _cadenceKey = 'reportCadence';
  static const _weeklyDayKey = 'reportWeeklyDay';
  static const _monthlyDayKey = 'reportMonthlyDay';

  Future<ReportCadence> getCadence() async {
    final raw = await StorageService.instance.getSetting(_cadenceKey, fallback: 'weekly');
    return raw == 'monthly' ? ReportCadence.monthly : ReportCadence.weekly;
  }

  Future<void> setCadence(ReportCadence cadence) => StorageService.instance
      .setSetting(_cadenceKey, cadence == ReportCadence.monthly ? 'monthly' : 'weekly');

  /// 1-7, DateTime.weekday convention (1=Monday...7=Sunday). Default: 7 (Sunday).
  Future<int> getWeeklyDay() async {
    final raw = await StorageService.instance.getSetting(_weeklyDayKey, fallback: '7');
    final parsed = int.tryParse(raw) ?? 7;
    return (parsed >= 1 && parsed <= 7) ? parsed : 7;
  }

  Future<void> setWeeklyDay(int weekday) =>
      StorageService.instance.setSetting(_weeklyDayKey, '$weekday');

  /// "1".."31" or "last". Default: "last".
  Future<String> getMonthlyDay() =>
      StorageService.instance.getSetting(_monthlyDayKey, fallback: 'last');

  Future<void> setMonthlyDay(String day) =>
      StorageService.instance.setSetting(_monthlyDayKey, day);

  /// Resolves "last" or a numeric day string against [year]/[month],
  /// clamping to that month's actual last day if the configured day
  /// doesn't exist in it (e.g. "31" in February).
  int resolveMonthlyDay(int year, int month, String configuredDay) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    if (configuredDay == 'last') return lastDayOfMonth;
    final parsed = int.tryParse(configuredDay) ?? lastDayOfMonth;
    return parsed.clamp(1, lastDayOfMonth);
  }

  /// True if [date] (default: today) is the configured report/send day.
  Future<bool> isReportDay([DateTime? date]) async {
    final d = date ?? DateTime.now();
    final cadence = await getCadence();
    if (cadence == ReportCadence.weekly) {
      final weeklyDay = await getWeeklyDay();
      return d.weekday == weeklyDay;
    }
    final monthlyDay = await getMonthlyDay();
    return d.day == resolveMonthlyDay(d.year, d.month, monthlyDay);
  }
}
```

- [ ] **Step 4: Run tests to verify `resolveMonthlyDay` passes**

Run: `flutter test test/report_cadence_service_test.dart`
Expected: PASS (all `resolveMonthlyDay` cases)

- [ ] **Step 5: Add failing tests for `isReportDay`, `getCadence`/`setCadence`, `getWeeklyDay`/`setWeeklyDay`, `getMonthlyDay`/`setMonthlyDay`**

Append to `test/report_cadence_service_test.dart` (inside `main()`, after the `resolveMonthlyDay` group). These need `SharedPreferences` test bindings since `StorageService` reads/writes real prefs:

```dart
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('cadence get/set', () {
    test('defaults to weekly', () async {
      expect(await svc.getCadence(), ReportCadence.weekly);
    });

    test('set then get round-trips monthly', () async {
      await svc.setCadence(ReportCadence.monthly);
      expect(await svc.getCadence(), ReportCadence.monthly);
    });

    test('set then get round-trips weekly', () async {
      await svc.setCadence(ReportCadence.monthly);
      await svc.setCadence(ReportCadence.weekly);
      expect(await svc.getCadence(), ReportCadence.weekly);
    });
  });

  group('weekly day get/set', () {
    test('defaults to 7 (Sunday)', () async {
      expect(await svc.getWeeklyDay(), 7);
    });

    test('set then get round-trips', () async {
      await svc.setWeeklyDay(5); // Friday
      expect(await svc.getWeeklyDay(), 5);
    });
  });

  group('monthly day get/set', () {
    test('defaults to "last"', () async {
      expect(await svc.getMonthlyDay(), 'last');
    });

    test('set then get round-trips a specific day', () async {
      await svc.setMonthlyDay('25');
      expect(await svc.getMonthlyDay(), '25');
    });
  });

  group('isReportDay', () {
    test('weekly mode: true only on the configured weekday', () async {
      await svc.setCadence(ReportCadence.weekly);
      await svc.setWeeklyDay(DateTime.friday);
      final friday = DateTime(2026, 8, 14); // a Friday
      final saturday = DateTime(2026, 8, 15);
      expect(await svc.isReportDay(friday), true);
      expect(await svc.isReportDay(saturday), false);
    });

    test('monthly mode with specific day: true only on that day', () async {
      await svc.setCadence(ReportCadence.monthly);
      await svc.setMonthlyDay('25');
      expect(await svc.isReportDay(DateTime(2026, 8, 25)), true);
      expect(await svc.isReportDay(DateTime(2026, 8, 24)), false);
    });

    test('monthly mode with "last": true only on the month\'s last day', () async {
      await svc.setCadence(ReportCadence.monthly);
      await svc.setMonthlyDay('last');
      expect(await svc.isReportDay(DateTime(2026, 2, 28)), true); // Feb 2026, 28 days
      expect(await svc.isReportDay(DateTime(2026, 2, 27)), false);
    });
  });
```

Add the required import at the top of the test file:

```dart
import 'package:shared_preferences/shared_preferences.dart';
```

- [ ] **Step 6: Run tests to verify they fail correctly, then pass**

Run: `flutter test test/report_cadence_service_test.dart`
Expected: All tests PASS (the implementation from Step 3 already covers these — this step confirms it; if any fail, fix `report_cadence_service.dart` until green).

- [ ] **Step 7: Commit**

```bash
git add lib/services/report_cadence_service.dart test/report_cadence_service_test.dart
git commit -m "feat: add ReportCadenceService for configurable weekly/monthly reporting"
```

---

### Task 2: `ReportService.weekDates()` — configurable end-of-week day

**Files:**
- Modify: `lib/services/report_service.dart:76-113, 264-268, 540-541, 668-669`
- Test: `test/report_service_test.dart`

**Interfaces:**
- Consumes: `ReportCadenceService.instance.getWeeklyDay()` → `Future<int>` (from Task 1).
- Produces: `weekDates([DateTime? ref, int? endWeekday])` — unchanged default behavior when `endWeekday` omitted (defaults to `DateTime.sunday` = 7); `computeWeekStats`, `computeTrend`, `buildFullReport`, `buildCompactReport` now read the cadence setting and pass it through, so their *external* signatures (already `[DateTime? ref]`) are unchanged — only their internal `weekDates(ref)` calls change to `weekDates(ref, endWeekday)`.

- [ ] **Step 1: Write the failing test for `weekDates` with a custom `endWeekday`**

Open `test/report_service_test.dart` and find the existing `weekDates` test group (search for `'weekDates'` or `group('weekDates'`). Add these cases inside that group, or create the group if none exists:

```dart
  group('weekDates with endWeekday', () {
    final rs = ReportService.instance;

    test('defaults to Sunday-ending (Monday->Sunday) when endWeekday omitted', () {
      final ref = DateTime(2026, 8, 12); // a Wednesday
      final dates = rs.weekDates(ref);
      expect(dates.first.weekday, DateTime.monday);
      expect(dates.last.weekday, DateTime.sunday);
      expect(dates.length, 7);
    });

    test('Sunday-ending explicit matches default (regression guard)', () {
      final ref = DateTime(2026, 8, 12);
      final withDefault = rs.weekDates(ref);
      final withExplicit = rs.weekDates(ref, DateTime.sunday);
      expect(withExplicit, withDefault);
    });

    test('Friday-ending produces a Saturday->Friday window', () {
      final ref = DateTime(2026, 8, 12); // a Wednesday
      final dates = rs.weekDates(ref, DateTime.friday);
      expect(dates.first.weekday, DateTime.saturday);
      expect(dates.last.weekday, DateTime.friday);
      expect(dates.length, 7);
    });

    test('window always contains the reference date', () {
      final ref = DateTime(2026, 8, 12);
      for (int endDay = 1; endDay <= 7; endDay++) {
        final dates = rs.weekDates(ref, endDay);
        final containsRef = dates.any((d) =>
            d.year == ref.year && d.month == ref.month && d.day == ref.day);
        expect(containsRef, true, reason: 'endWeekday=$endDay should contain $ref');
      }
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/report_service_test.dart`
Expected: FAIL — `weekDates` doesn't accept a second positional argument yet.

- [ ] **Step 3: Implement the `endWeekday` parameter**

In `lib/services/report_service.dart`, replace the `weekDates` method:

```dart
  /// 7-day window ending on [endWeekday] (DateTime.weekday convention,
  /// default DateTime.sunday) that contains [ref] (default today).
  List<DateTime> weekDates([DateTime? ref, int? endWeekday]) {
    final today = ref ?? DateTime.now();
    final end = endWeekday ?? DateTime.sunday;
    // Days to subtract from today's weekday to reach the most recent
    // occurrence of `end` (0 if today already is that weekday).
    final daysSinceEnd = (today.weekday - end + 7) % 7;
    final lastDayOfWindow = today.subtract(Duration(days: daysSinceEnd));
    final start = lastDayOfWindow.subtract(const Duration(days: 6));
    return List.generate(7, (i) => DateTime(start.year, start.month, start.day + i));
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/report_service_test.dart`
Expected: PASS (new `weekDates with endWeekday` group, and all pre-existing `weekDates`-dependent tests still pass since the default behavior is unchanged).

- [ ] **Step 5: Thread the configured weekly day through the four report-building methods**

In `lib/services/report_service.dart`:

1. Add import at the top: `import 'report_cadence_service.dart';`
2. In `computeWeekStats` (around line 85): change

```dart
  Future<WeekStats> computeWeekStats([DateTime? ref]) async {
    final dates = weekDates(ref);
```

to:

```dart
  Future<WeekStats> computeWeekStats([DateTime? ref]) async {
    final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
    final dates = weekDates(ref, endWeekday);
```

3. In `computeTrend` (around line 265): same pattern —

```dart
  Future<TrendData> computeTrend([DateTime? ref]) async {
    final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
    final dates = weekDates(ref, endWeekday);
```

   (Note: `computeTrend` also computes a "last 30 days" window later in the method via `dates.first.subtract(...)` — that logic is unaffected since it derives from `dates`, not from a second `weekDates` call.)

4. In `buildFullReport` (around line 540): same pattern —

```dart
  Future<String> buildFullReport(String name, S l, [DateTime? ref]) async {
    final dates = weekDates(ref);
```

becomes:

```dart
  Future<String> buildFullReport(String name, S l, [DateTime? ref]) async {
    final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
    final dates = weekDates(ref, endWeekday);
```

5. In `buildCompactReport` (around line 668): same pattern.

- [ ] **Step 6: Run the full report_service test file to verify no regressions**

Run: `flutter test test/report_service_test.dart`
Expected: PASS — all existing tests plus the new `weekDates with endWeekday` group.

- [ ] **Step 7: Commit**

```bash
git add lib/services/report_service.dart test/report_service_test.dart
git commit -m "feat: make ReportService weekly window configurable by end-of-week day"
```

---

### Task 3: Notification scheduling — cadence-aware reminders

**Files:**
- Modify: `lib/services/notification_service.dart:683-747, 791-822 (approx), 1047-1072`

**Interfaces:**
- Consumes: `ReportCadenceService.instance.getCadence()`, `.getWeeklyDay()`, `.getMonthlyDay()`, `.resolveMonthlyDay(year, month, day)` (from Task 1).
- Produces: `scheduleReportReminder(hour, minute, {title, body, followUpCount})` (renamed from `scheduleSundayReminder`, same signature); `cancelReportFollowUps()` (renamed from `cancelSundayFollowUps()`, same signature — no params); `_nextInstanceOfMonthlyDay(day, hour, minute)` (new private helper); `scheduleAutoSendReminder` keeps its existing signature `(hour, minute, {title, body})` but its internal next-occurrence computation becomes cadence-aware.

First, read the exact current follow-up cancel/reschedule method to match its structure precisely:

- [ ] **Step 1: Locate and read the current follow-up cancel method**

Run: search `notification_service.dart` for `cancelSundayFollowUps` (already known to exist around line 791-822 based on prior exploration in this session — re-read the file section before editing since exact line numbers may have shifted).

- [ ] **Step 2: Add `_nextInstanceOfMonthlyDay` helper**

In `lib/services/notification_service.dart`, near the existing `_nextInstanceOfWeekday` (around line 1047), add:

```dart
  /// Next occurrence of day-of-month [day] (already resolved — e.g. from
  /// ReportCadenceService.resolveMonthlyDay) at [hour]:[minute]. Walks
  /// forward day-by-day like _nextInstanceOfWeekday, re-resolving [day]
  /// against each candidate month in case the walk crosses into a new
  /// month with a different last-day (for "last day" configurations).
  tz.TZDateTime _nextInstanceOfMonthlyDay(int Function(int year, int month) resolveDay, int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.day != resolveDay(scheduled.year, scheduled.month)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
```

This takes a `resolveDay` callback (rather than a pre-resolved `int day`) so that walking across a month boundary re-resolves "last day of month" correctly for the new month, rather than being stuck comparing against last month's resolved day number.

- [ ] **Step 3: Remove the now-redundant `_nextInstanceOfSunday`**

Delete this method (it's identical to `_nextInstanceOfWeekday(DateTime.sunday, hour, minute)`):

```dart
  tz.TZDateTime _nextInstanceOfSunday(int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != DateTime.sunday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
```

Every call site that used `_nextInstanceOfSunday(h, m)` will be replaced with cadence-aware logic in the next step, so no direct callers remain.

- [ ] **Step 4: Add a private cadence-aware next-occurrence helper**

Add this new private method right after `_nextInstanceOfMonthlyDay`:

```dart
  /// Next occurrence of the user's configured report day at [hour]:[minute],
  /// whether that's weekly (a fixed weekday) or monthly (a specific day or
  /// the last day of the month).
  Future<tz.TZDateTime> _nextReportOccurrence(int hour, int minute) async {
    final cadenceSvc = ReportCadenceService.instance;
    final cadence = await cadenceSvc.getCadence();
    if (cadence == ReportCadence.weekly) {
      final weekday = await cadenceSvc.getWeeklyDay();
      return _nextInstanceOfWeekday(weekday, hour, minute);
    }
    final monthlyDay = await cadenceSvc.getMonthlyDay();
    return _nextInstanceOfMonthlyDay(
      (year, month) => cadenceSvc.resolveMonthlyDay(year, month, monthlyDay),
      hour,
      minute,
    );
  }
```

Add the import at the top of `notification_service.dart`:

```dart
import 'report_cadence_service.dart';
```

- [ ] **Step 5: Rename and generalize `scheduleSundayReminder` → `scheduleReportReminder`**

Find the existing method (search for `Future<void> scheduleSundayReminder`) and replace it entirely:

```dart
  /// Schedule the report send reminder + follow-ups, on whichever day the
  /// user's configured cadence (weekly/monthly) lands.
  /// [followUpCount] controls how many follow-ups (0–2), default 2.
  Future<void> scheduleReportReminder(int hour, int minute, {String? title, String? body, int followUpCount = 2}) async {
    await init();

    final t = title ?? 'Time to Send Your Account';
    final cadence = await ReportCadenceService.instance.getCadence();
    final matchComponents = cadence == ReportCadence.weekly
        ? DateTimeComponents.dayOfWeekAndTime
        : null; // no monthly-recurrence equivalent — see plan notes; one-shot only

    // Cancel all existing report notifications
    for (final id in [2, 21, 22]) {
      await _plugin.cancel(id);
    }

    // Primary reminder
    await _safeZonedSchedule(
      2,
      t,
      body ?? 'It\'s time to send your account to your disciple maker.',
      await _nextReportOccurrence(hour, minute),
      _alarmDetails,
      matchDateTimeComponents: matchComponents,
      payload: 'navigate_report',
    );

    // Follow-up #1 — 30 minutes later
    if (followUpCount >= 1) {
      final followUp1 = _addMinutesToTime(hour, minute, 30);
      await _safeZonedSchedule(
        21,
        '⏰ $t',
        'Your disciple maker is waiting! Send your report now.',
        await _nextReportOccurrence(followUp1.hour, followUp1.minute),
        _alarmDetails,
        matchDateTimeComponents: matchComponents,
      );
    }

    // Follow-up #2 — 60 minutes later
    if (followUpCount >= 2) {
      final followUp2 = _addMinutesToTime(hour, minute, 60);
      await _safeZonedSchedule(
        22,
        '⚠️ $t',
        'Last chance today! Send your account before the day ends.',
        await _nextReportOccurrence(followUp2.hour, followUp2.minute),
        _alarmDetails,
        matchDateTimeComponents: matchComponents,
      );
    }
  }
```

- [ ] **Step 6: Generalize `scheduleAutoSendReminder`**

Find the existing method (search for `Future<void> scheduleAutoSendReminder`) and replace its body:

```dart
  Future<void> scheduleAutoSendReminder(int hour, int minute, {String? title, String? body}) async {
    await init();
    await _plugin.cancel(3);
    final cadence = await ReportCadenceService.instance.getCadence();
    await _safeZonedSchedule(
      3,
      title ?? 'Time to Send Your Account',
      body ?? 'Your report is ready. Tap to review and send it now.',
      await _nextReportOccurrence(hour, minute),
      _alarmDetails,
      matchDateTimeComponents:
          cadence == ReportCadence.weekly ? DateTimeComponents.dayOfWeekAndTime : null,
      payload: 'navigate_report',
    );
  }
```

- [ ] **Step 7: Rename and generalize `cancelSundayFollowUps` → `cancelReportFollowUps`**

Find the existing method (search for `Future<void> cancelSundayFollowUps`). Rename it to `cancelReportFollowUps` and replace every internal call to `_nextInstanceOfSunday(h, m)` with `await _nextReportOccurrence(h, m)`. Also replace the settings keys it reads (`sundayFollowUps`, `notifSundayTitle`, `notifSundayBody` — these setting **key names** stay as-is per the spec, only the *method name* and *scheduling logic* change). After editing, the method should read the same settings as before but compute occurrences via `_nextReportOccurrence` instead of `_nextInstanceOfSunday`, and use `matchDateTimeComponents: cadence == ReportCadence.weekly ? DateTimeComponents.dayOfWeekAndTime : null` on its `_safeZonedSchedule` calls (fetch `cadence` once at the top of the method the same way Step 5 does).

- [ ] **Step 8: Update `rescheduleAll()` call sites**

Find `rescheduleAll()` (around line 384) and update:
- `await scheduleSundayReminder(18, 0);` → `await scheduleReportReminder(18, 0);` (first-launch default path)
- `await scheduleSundayReminder(sh, sm, ...)` → `await scheduleReportReminder(sh, sm, ...)` (saved-preferences path)

Leave the setting key names (`sundayHour`, `sundayMin`, `sundayFollowUps`, `notifSundayTitle`, `notifSundayBody`) unchanged in this file — only the method name changes, matching the spec's decision to not rename settings keys.

- [ ] **Step 9: Search for any remaining callers of the renamed methods**

Run: search the whole `lib/` directory for `scheduleSundayReminder`, `cancelSundayFollowUps`, `_nextInstanceOfSunday` to confirm no stale references remain outside `notification_service.dart` itself (Task 4 will update `settings_screen.dart`'s callers — for this task, just confirm via search that you've caught every call site *within* `notification_service.dart`).

- [ ] **Step 10: Update `test/notification_service_test.dart` — rename the Sunday-specific shadow tests and add monthly-day coverage**

This test file verifies `NotificationService`'s private time-math by re-implementing the same algorithms as free functions at the top of the file (see its doc comment) rather than calling the real private methods directly (they're private and the plugin dependency makes widget-testing the real service impractical). The `nextInstanceOfSunday` shadow function and its two test groups exercise an algorithm identical to `nextInstanceOfWeekday` (already covered), so rename rather than duplicate; then add real new coverage for the new `_nextInstanceOfMonthlyDay` algorithm.

Read `test/notification_service_test.dart` first to find current exact line numbers (they may have shifted from what's shown below if the file was touched since this plan was written).

1. Remove the `nextInstanceOfSunday` free function (lines ~37-43):

```dart
tz.TZDateTime nextInstanceOfSunday(int hour, int minute, {tz.TZDateTime? now}) {
  var scheduled = nextInstanceOfTime(hour, minute, now: now);
  while (scheduled.weekday != DateTime.sunday) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}
```

2. Add a `nextInstanceOfMonthlyDay` free function in its place, mirroring the real service's new `_nextInstanceOfMonthlyDay` from Step 2:

```dart
int _lastDayOf(int year, int month) => DateTime(year, month + 1, 0).day;

tz.TZDateTime nextInstanceOfMonthlyDay(String configuredDay, int hour, int minute, {tz.TZDateTime? now}) {
  var scheduled = nextInstanceOfTime(hour, minute, now: now);
  int resolve(int year, int month) {
    if (configuredDay == 'last') return _lastDayOf(year, month);
    final parsed = int.tryParse(configuredDay) ?? _lastDayOf(year, month);
    return parsed.clamp(1, _lastDayOf(year, month));
  }
  while (scheduled.day != resolve(scheduled.year, scheduled.month)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}
```

3. Find the group `'nextInstanceOfSunday — Sunday reminders'` (lines ~143-186) and rename it to `'nextInstanceOfWeekday — generic weekday targeting (Sunday case)'`, replacing every `nextInstanceOfSunday(h, m, now: now)` call with `nextInstanceOfWeekday(DateTime.sunday, h, m, now: now)`:

```dart
  group('nextInstanceOfWeekday — generic weekday targeting (Sunday case)', () {
    test('returns this Sunday if today is before Sunday and time is ahead', () {
      // Tuesday July 1, 2026 at 10:00 → schedule for Sunday July 5 at 18:00
      final now = tz.TZDateTime(tz.local, 2026, 7, 1, 10, 0);
      // July 1, 2026 is a Wednesday. Next Sunday is July 5.
      final result = nextInstanceOfWeekday(DateTime.sunday, 18, 0, now: now);

      expect(result.weekday, DateTime.sunday);
      expect(result.hour, 18);
      expect(result.minute, 0);
      expect(result.isAfter(now), isTrue);
    });

    test('returns next Sunday if today is Sunday but time passed', () {
      // Sunday at 19:00, schedule for 18:00 → next Sunday
      // Find a known Sunday: July 5, 2026
      final now = tz.TZDateTime(tz.local, 2026, 7, 5, 19, 0);
      final result = nextInstanceOfWeekday(DateTime.sunday, 18, 0, now: now);

      expect(result.weekday, DateTime.sunday);
      expect(result.isAfter(now), isTrue);
      // Should be 7 days later
      expect(result.difference(now).inDays, greaterThanOrEqualTo(6));
    });

    test('returns this Sunday if today is Sunday and time is ahead', () {
      // Sunday at 10:00, schedule for 18:00 → same Sunday
      final now = tz.TZDateTime(tz.local, 2026, 7, 5, 10, 0);
      final result = nextInstanceOfWeekday(DateTime.sunday, 18, 0, now: now);

      expect(result.weekday, DateTime.sunday);
      expect(result.day, 5);
      expect(result.hour, 18);
    });

    test('result is always a Sunday when targeting Sunday', () {
      final now = tz.TZDateTime(tz.local, 2026, 7, 1, 10, 0);
      for (int h = 0; h < 24; h++) {
        final result = nextInstanceOfWeekday(DateTime.sunday, h, 30, now: now);
        expect(result.weekday, DateTime.sunday,
            reason: 'Schedule for $h:30 should be on Sunday');
      }
    });
  });
```

4. Find the group `'Sunday reminder follow-up schedule'` (lines ~349-372) and rename it to `'Report reminder follow-up schedule'`, replacing `nextInstanceOfSunday` calls with `nextInstanceOfWeekday(DateTime.sunday, ...)`:

```dart
  group('Report reminder follow-up schedule', () {
    test('primary + 2 follow-ups all land on the configured weekday (Sunday case)', () {
      final now = tz.TZDateTime(tz.local, 2026, 7, 1, 10, 0); // Wednesday

      const primaryHour = 18;
      const primaryMinute = 0;

      final primary = nextInstanceOfWeekday(DateTime.sunday, primaryHour, primaryMinute, now: now);
      expect(primary.weekday, DateTime.sunday);
      expect(primary.hour, 18);

      final f1Time = addMinutesToTime(primaryHour, primaryMinute, 30);
      final f1 = nextInstanceOfWeekday(DateTime.sunday, f1Time.hour, f1Time.minute, now: now);
      expect(f1.weekday, DateTime.sunday);
      expect(f1.hour, 18);
      expect(f1.minute, 30);

      final f2Time = addMinutesToTime(primaryHour, primaryMinute, 60);
      final f2 = nextInstanceOfWeekday(DateTime.sunday, f2Time.hour, f2Time.minute, now: now);
      expect(f2.weekday, DateTime.sunday);
      expect(f2.hour, 19);
      expect(f2.minute, 0);
    });

    test('primary + 2 follow-ups all land on the configured day of month', () {
      final now = tz.TZDateTime(tz.local, 2026, 7, 1, 10, 0); // July 1

      const primaryHour = 18;
      const primaryMinute = 0;

      final primary = nextInstanceOfMonthlyDay('25', primaryHour, primaryMinute, now: now);
      expect(primary.day, 25);
      expect(primary.hour, 18);

      final f1Time = addMinutesToTime(primaryHour, primaryMinute, 30);
      final f1 = nextInstanceOfMonthlyDay('25', f1Time.hour, f1Time.minute, now: now);
      expect(f1.day, 25);
      expect(f1.hour, 18);
      expect(f1.minute, 30);
    });
  });
```

5. Add a new test group after the renamed group from Step 3, verifying `nextInstanceOfMonthlyDay` directly:

```dart
  group('nextInstanceOfMonthlyDay — monthly reminders', () {
    test('returns this month\'s day if it hasn\'t passed yet', () {
      final now = tz.TZDateTime(tz.local, 2026, 7, 1, 10, 0); // July 1
      final result = nextInstanceOfMonthlyDay('15', 18, 0, now: now);
      expect(result.day, 15);
      expect(result.month, 7);
      expect(result.hour, 18);
    });

    test('rolls to next month if the configured day already passed', () {
      final now = tz.TZDateTime(tz.local, 2026, 7, 20, 10, 0); // July 20
      final result = nextInstanceOfMonthlyDay('15', 18, 0, now: now);
      expect(result.day, 15);
      expect(result.month, 8);
    });

    test('"last" resolves to each month\'s actual last day, including February', () {
      final now = tz.TZDateTime(tz.local, 2026, 1, 1, 10, 0); // Jan 1, 2026 (not a leap year)
      final result = nextInstanceOfMonthlyDay('last', 18, 0, now: now);
      expect(result.day, 31);
      expect(result.month, 1);
    });

    test('a day beyond the month length clamps to that month\'s last day', () {
      // Configured day "31" but starting search in February (28 days in 2026)
      final now = tz.TZDateTime(tz.local, 2026, 2, 1, 10, 0);
      final result = nextInstanceOfMonthlyDay('31', 18, 0, now: now);
      expect(result.day, 28);
      expect(result.month, 2);
    });

    test('result is always in the future', () {
      final now = tz.TZDateTime(tz.local, 2026, 7, 1, 10, 0);
      final result = nextInstanceOfMonthlyDay('15', 18, 0, now: now);
      expect(result.isAfter(now), isTrue);
    });
  });
```

- [ ] **Step 11: Run the notification service test file**

Run: `flutter test test/notification_service_test.dart`
Expected: All tests PASS (renamed groups pass under their new names verifying the same behavior; new `nextInstanceOfMonthlyDay` group passes).

- [ ] **Step 12: Run static analysis**

Run: `flutter analyze lib/services/notification_service.dart test/notification_service_test.dart`
Expected: 0 errors. (Callers in `settings_screen.dart` will show errors until Task 4 updates them — that's expected and fixed in the next task, not this one. If you want a clean intermediate state, do a quick grep-and-rename pass on `settings_screen.dart`'s two call sites now as part of this task instead of leaving analyze red between tasks — either ordering is fine as long as the final state after Task 4 is clean.)

- [ ] **Step 13: Commit**

```bash
git add lib/services/notification_service.dart test/notification_service_test.dart
git commit -m "feat: generalize report reminder scheduling to any weekly/monthly cadence"
```

---

### Task 4: Settings screen — cadence picker UI

**Files:**
- Modify: `lib/screens/settings_screen.dart`

**Interfaces:**
- Consumes: `ReportCadenceService.instance` (all methods, from Task 1); `NotificationService.instance.scheduleReportReminder(...)`, `.cancelReportFollowUps()` (renamed in Task 3).
- Produces: no new public interface (UI-only task) — but this task is what makes `reportCadence`/`reportWeeklyDay`/`reportMonthlyDay` actually user-editable, which Tasks 5 and 6 depend on having real data behind.

- [ ] **Step 1: Add new state variables**

In `lib/screens/settings_screen.dart`, in `_SettingsScreenState`, add near the other reminder-related state (after `int _sundayFollowUps = 2;`):

```dart
  ReportCadence _reportCadence = ReportCadence.weekly;
  int _reportWeeklyDay = DateTime.sunday; // 7
  String _reportMonthlyDay = 'last';
```

Add the import at the top:

```dart
import '../services/report_cadence_service.dart';
```

- [ ] **Step 2: Load cadence settings in `_load()`**

In the `_load()` method, after the line `_sundayFollowUps = int.tryParse(await s.getSetting('sundayFollowUps', fallback: '2')) ?? 2;`, add:

```dart
    _reportCadence = await ReportCadenceService.instance.getCadence();
    _reportWeeklyDay = await ReportCadenceService.instance.getWeeklyDay();
    _reportMonthlyDay = await ReportCadenceService.instance.getMonthlyDay();
```

- [ ] **Step 3: Add two new localized ARB keys for the dynamic reminder text templates**

In `lib/l10n/app_en.arb`, near the existing `notifSundayTitle`/`notifSundayBody` keys, add:

```json
  "notifReportTitleWeekly": "{day} — Send Your Account",
  "@notifReportTitleWeekly": { "placeholders": { "day": { "type": "String" } } },
  "notifReportTitleMonthlyDay": "The {day} — Send Your Account",
  "@notifReportTitleMonthlyDay": { "placeholders": { "day": { "type": "String" } } },
  "notifReportTitleMonthlyLast": "Month-end — Send Your Account",
  "notifReportBody": "It's time to send your account to your disciple maker. Tap to review & send.",
  "reportCadenceLabel": "Reporting cadence",
  "reportCadenceWeekly": "Weekly",
  "reportCadenceMonthly": "Monthly",
  "reportWeeklyDayLabel": "Report day",
  "reportMonthlyDayLabel": "Report day of month",
  "reportMonthlyDayLast": "Last day of month",
```

In `lib/l10n/app_fr.arb`, add the French equivalents at the same relative location:

```json
  "notifReportTitleWeekly": "{day} — Envoyez votre compte",
  "@notifReportTitleWeekly": { "placeholders": { "day": { "type": "String" } } },
  "notifReportTitleMonthlyDay": "Le {day} — Envoyez votre compte",
  "@notifReportTitleMonthlyDay": { "placeholders": { "day": { "type": "String" } } },
  "notifReportTitleMonthlyLast": "Fin de mois — Envoyez votre compte",
  "notifReportBody": "Il est temps d'envoyer votre compte à votre formateur. Appuyez pour vérifier et envoyer.",
  "reportCadenceLabel": "Fréquence des comptes",
  "reportCadenceWeekly": "Hebdomadaire",
  "reportCadenceMonthly": "Mensuel",
  "reportWeeklyDayLabel": "Jour du compte",
  "reportMonthlyDayLabel": "Jour du mois pour le compte",
  "reportMonthlyDayLast": "Dernier jour du mois",
```

- [ ] **Step 4: Add matching getters to the generated localization files**

In `lib/l10n/generated/app_localizations.dart` (the abstract base class), find the existing `notifSundayTitle` getter declaration and add these nearby, matching its exact doc-comment style:

```dart
  /// No description provided for @notifReportTitleWeekly.
  ///
  /// In en, this message translates to:
  /// **'{day} — Send Your Account'**
  String notifReportTitleWeekly(String day);

  /// No description provided for @notifReportTitleMonthlyDay.
  ///
  /// In en, this message translates to:
  /// **'The {day} — Send Your Account'**
  String notifReportTitleMonthlyDay(String day);

  /// No description provided for @notifReportTitleMonthlyLast.
  ///
  /// In en, this message translates to:
  /// **'Month-end — Send Your Account'**
  String get notifReportTitleMonthlyLast;

  /// No description provided for @notifReportBody.
  ///
  /// In en, this message translates to:
  /// **'It\'s time to send your account to your disciple maker. Tap to review & send.'**
  String get notifReportBody;

  /// No description provided for @reportCadenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Reporting cadence'**
  String get reportCadenceLabel;

  /// No description provided for @reportCadenceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get reportCadenceWeekly;

  /// No description provided for @reportCadenceMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get reportCadenceMonthly;

  /// No description provided for @reportWeeklyDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Report day'**
  String get reportWeeklyDayLabel;

  /// No description provided for @reportMonthlyDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Report day of month'**
  String get reportMonthlyDayLabel;

  /// No description provided for @reportMonthlyDayLast.
  ///
  /// In en, this message translates to:
  /// **'Last day of month'**
  String get reportMonthlyDayLast;
```

**IMPORTANT:** Use `///` (three slashes) for every doc-comment line — do not use a bare backslash (`\`) before "In en, this message translates to:". A prior session in this codebase introduced a `\ In en...` typo by mis-copying a Read-tool rendering artifact, which broke compilation (`expected_class_member` error at the exact line). Verify each doc comment reads `/// In en, this message translates to:` character-for-character before moving on.

In `lib/l10n/generated/app_localizations_en.dart`, find the `notifSundayTitle` implementation and add nearby:

```dart
  @override
  String notifReportTitleWeekly(String day) {
    return '$day — Send Your Account';
  }

  @override
  String notifReportTitleMonthlyDay(String day) {
    return 'The $day — Send Your Account';
  }

  @override
  String get notifReportTitleMonthlyLast => 'Month-end — Send Your Account';

  @override
  String get notifReportBody => 'It\'s time to send your account to your disciple maker. Tap to review & send.';

  @override
  String get reportCadenceLabel => 'Reporting cadence';

  @override
  String get reportCadenceWeekly => 'Weekly';

  @override
  String get reportCadenceMonthly => 'Monthly';

  @override
  String get reportWeeklyDayLabel => 'Report day';

  @override
  String get reportMonthlyDayLabel => 'Report day of month';

  @override
  String get reportMonthlyDayLast => 'Last day of month';
```

In `lib/l10n/generated/app_localizations_fr.dart`, add the French equivalents:

```dart
  @override
  String notifReportTitleWeekly(String day) {
    return '$day — Envoyez votre compte';
  }

  @override
  String notifReportTitleMonthlyDay(String day) {
    return 'Le $day — Envoyez votre compte';
  }

  @override
  String get notifReportTitleMonthlyLast => 'Fin de mois — Envoyez votre compte';

  @override
  String get notifReportBody => 'Il est temps d\'envoyer votre compte à votre formateur. Appuyez pour vérifier et envoyer.';

  @override
  String get reportCadenceLabel => 'Fréquence des comptes';

  @override
  String get reportCadenceWeekly => 'Hebdomadaire';

  @override
  String get reportCadenceMonthly => 'Mensuel';

  @override
  String get reportWeeklyDayLabel => 'Jour du compte';

  @override
  String get reportMonthlyDayLabel => 'Jour du mois pour le compte';

  @override
  String get reportMonthlyDayLast => 'Dernier jour du mois';
```

- [ ] **Step 5: Run static analysis on the l10n files before continuing**

Run: `flutter analyze lib/l10n/generated/app_localizations.dart lib/l10n/generated/app_localizations_en.dart lib/l10n/generated/app_localizations_fr.dart`
Expected: 0 errors. Fix any doc-comment or syntax issues immediately (see the `\` vs `///` warning in Step 4) before proceeding — a broken generated l10n file breaks every screen that imports `S`.

- [ ] **Step 6: Add a helper to compute the dynamic reminder title/body**

In `lib/screens/settings_screen.dart`, add a new private method (near `_scheduleAllNotifications`):

```dart
  /// Compute the localized reminder title text for the current cadence
  /// setting, e.g. "Friday — Send Your Account" or "The 25th — Send Your
  /// Account" or "Month-end — Send Your Account".
  String _reportReminderTitle(S l) {
    if (_reportCadence == ReportCadence.weekly) {
      final dayName = DateFormat('EEEE', l.localeName).format(
        DateTime(2026, 1, 4 + _reportWeeklyDay), // 2026-01-05 is a Monday (weekday=1); offset gives each weekday 1-7
      );
      return l.notifReportTitleWeekly(dayName);
    }
    if (_reportMonthlyDay == 'last') {
      return l.notifReportTitleMonthlyLast;
    }
    return l.notifReportTitleMonthlyDay(_reportMonthlyDay);
  }
```

Add the import at the top if not already present: `import 'package:intl/intl.dart';`

**Verify the date-math comment**: `DateTime(2026, 1, 4 + _reportWeeklyDay)` — confirm `2026-01-05` is genuinely a Monday before relying on this; if not, adjust the base date to a confirmed Monday and update the comment. (Check with `DateTime(2026, 1, 5).weekday` — expected `1`.)

- [ ] **Step 7: Update `_scheduleAllNotifications` to use dynamic text and renamed methods**

Find `_scheduleAllNotifications()` and replace the Sunday-specific block:

```dart
    await s.setSetting('notifSundayTitle', l.notifSundayTitle);
    await s.setSetting('notifSundayBody', l.notifSundayBody);
```

with:

```dart
    await s.setSetting('notifSundayTitle', _reportReminderTitle(l));
    await s.setSetting('notifSundayBody', l.notifReportBody);
```

(Setting *key* `notifSundayTitle`/`notifSundayBody` stays the same per the spec's decision not to rename storage keys — only the *value* computed is now dynamic.)

Then replace:

```dart
    await NotificationService.instance.scheduleSundayReminder(
      _sundayTime.hour, _sundayTime.minute,
      title: l.notifSundayTitle,
      body: l.notifSundayBody,
      followUpCount: _sundayFollowUps,
    );
    if (_autoSendEnabled) {
      await NotificationService.instance.scheduleAutoSendReminder(
        _autoSendTime.hour, _autoSendTime.minute,
        title: l.notifSundayTitle,
        body: l.notifSundayBody,
      );
    }
```

with:

```dart
    await NotificationService.instance.scheduleReportReminder(
      _sundayTime.hour, _sundayTime.minute,
      title: _reportReminderTitle(l),
      body: l.notifReportBody,
      followUpCount: _sundayFollowUps,
    );
    if (_autoSendEnabled) {
      await NotificationService.instance.scheduleAutoSendReminder(
        _autoSendTime.hour, _autoSendTime.minute,
        title: _reportReminderTitle(l),
        body: l.notifReportBody,
      );
    }
```

- [ ] **Step 8: Add cadence persistence + reschedule methods**

Add new methods near `_saveReminders`:

```dart
  Future<void> _setCadence(ReportCadence cadence) async {
    setState(() => _reportCadence = cadence);
    await ReportCadenceService.instance.setCadence(cadence);
    if (_notificationsEnabled) await _scheduleAllNotifications();
  }

  Future<void> _setWeeklyDay(int weekday) async {
    setState(() => _reportWeeklyDay = weekday);
    await ReportCadenceService.instance.setWeeklyDay(weekday);
    if (_notificationsEnabled) await _scheduleAllNotifications();
  }

  Future<void> _setMonthlyDay(String day) async {
    setState(() => _reportMonthlyDay = day);
    await ReportCadenceService.instance.setMonthlyDay(day);
    if (_notificationsEnabled) await _scheduleAllNotifications();
  }
```

- [ ] **Step 9: Build the cadence picker UI widget**

Add a new private build method (near `_timeRow`/`_followUpSlider`):

```dart
  Widget _cadencePicker(S l) {
    final accent = AppTheme.accentGold(context);
    final textCol = AppTheme.textColor(context);
    final mutedCol = AppTheme.mutedColor(context);

    Widget segButton(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? accent : accent.withValues(alpha: 0.2)),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: AppTheme.label(12, color: selected ? accent : mutedCol)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.reportCadenceLabel.toUpperCase(),
            style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
        const SizedBox(height: 6),
        Row(
          children: [
            segButton(l.reportCadenceWeekly, _reportCadence == ReportCadence.weekly,
                () => _setCadence(ReportCadence.weekly)),
            const SizedBox(width: 8),
            segButton(l.reportCadenceMonthly, _reportCadence == ReportCadence.monthly,
                () => _setCadence(ReportCadence.monthly)),
          ],
        ),
        const SizedBox(height: 12),
        if (_reportCadence == ReportCadence.weekly) ...[
          Text(l.reportWeeklyDayLabel, style: AppTheme.serif(13, color: textCol)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (i) {
              final weekday = i + 1; // 1=Monday..7=Sunday
              final dayName = DateFormat('EEE', l.localeName)
                  .format(DateTime(2026, 1, 4 + weekday));
              final selected = _reportWeeklyDay == weekday;
              return GestureDetector(
                onTap: () => _setWeeklyDay(weekday),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: selected ? accent : accent.withValues(alpha: 0.2)),
                  ),
                  child: Text(dayName,
                      style: AppTheme.label(12, color: selected ? accent : mutedCol)),
                ),
              );
            }),
          ),
        ] else ...[
          Text(l.reportMonthlyDayLabel, style: AppTheme.serif(13, color: textCol)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...List.generate(31, (i) {
                final day = '${i + 1}';
                final selected = _reportMonthlyDay == day;
                return GestureDetector(
                  onTap: () => _setMonthlyDay(day),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: selected ? accent : accent.withValues(alpha: 0.2)),
                    ),
                    child: Text(day,
                        style: AppTheme.label(11, color: selected ? accent : mutedCol)),
                  ),
                );
              }),
              GestureDetector(
                onTap: () => _setMonthlyDay('last'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _reportMonthlyDay == 'last'
                        ? accent.withValues(alpha: 0.18) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _reportMonthlyDay == 'last' ? accent : accent.withValues(alpha: 0.2)),
                  ),
                  child: Text(l.reportMonthlyDayLast,
                      style: AppTheme.label(11,
                          color: _reportMonthlyDay == 'last' ? accent : mutedCol)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
```

- [ ] **Step 10: Insert `_cadencePicker` into the settings layout**

Find the line `_timeRow(l.sundayReminder, _sundayTime, () => _pickTime(false)),` (in the reminders `SectionCard`). Insert the cadence picker immediately before it:

```dart
            _cadencePicker(l),
            const SizedBox(height: 14),
            _timeRow(l.sundayReminder, _sundayTime, () => _pickTime(false)),
```

- [ ] **Step 11: Run static analysis**

Run: `flutter analyze lib/screens/settings_screen.dart`
Expected: 0 errors.

- [ ] **Step 12: Manual verification**

Run the app (`flutter run`), navigate to Settings, confirm:
- A "Reporting cadence" section appears with Weekly/Monthly segmented buttons.
- Selecting Weekly shows 7 day chips (Mon–Sun); tapping one selects it (highlighted).
- Selecting Monthly shows day chips 1–31 plus "Last day of month"; tapping one selects it.
- No crashes, no visual overflow.

- [ ] **Step 13: Commit**

```bash
git add lib/screens/settings_screen.dart lib/l10n/app_en.arb lib/l10n/app_fr.arb lib/l10n/generated/app_localizations.dart lib/l10n/generated/app_localizations_en.dart lib/l10n/generated/app_localizations_fr.dart
git commit -m "feat: add reporting cadence picker to settings screen"
```

---

### Task 5: Report screen — cadence-driven default view

**Files:**
- Modify: `lib/screens/report_screen.dart:32, 54-58, 74-89, 421-422 (approx — re-check exact line after Task 1-4 edits elsewhere haven't touched this file)`

**Interfaces:**
- Consumes: `ReportCadenceService.instance.getCadence()` → `Future<ReportCadence>`; `ReportCadenceService.instance.isReportDay()` → `Future<bool>` (from Task 1).
- Produces: no new public interface — internal state only.

- [ ] **Step 1: Add a cached `_isReportDay` state field**

In `lib/screens/report_screen.dart`, in `_ReportScreenState`, add near `bool _isMonthly = false;`:

```dart
  bool _isReportDay = false;
```

Add the import at the top: `import '../services/report_cadence_service.dart';`

- [ ] **Step 2: Initialize `_isMonthly` from the configured cadence and compute `_isReportDay`, in `_refresh()`**

Find `_refresh()` (around line 74) and change:

```dart
  Future<void> _refresh() async {
    final s = StorageService.instance;
    _name = await s.getSetting('myName');
```

to:

```dart
  Future<void> _refresh() async {
    final s = StorageService.instance;
    final cadenceSvc = ReportCadenceService.instance;
    _isMonthly = await cadenceSvc.getCadence() == ReportCadence.monthly;
    _isReportDay = await cadenceSvc.isReportDay();
    _name = await s.getSetting('myName');
```

**Important:** `_refresh()` is only called from `initState()` — the manual toggle button (`_toggleReportMode`) does NOT call `_refresh()`, it calls `_buildReport()` directly and flips `_isMonthly` itself. Verify this by re-reading `_toggleReportMode` before this step — if `_refresh()` were called again on every toggle, it would reset `_isMonthly` right back to the cadence default, defeating the manual override. Confirm the toggle method stays untouched (it does, per the spec).

- [ ] **Step 3: Replace the hardcoded Sunday banner condition**

Find (around line 421-422):

```dart
        // Sunday banner
        if (!_isMonthly && _isCurrentWeek && DateTime.now().weekday == DateTime.sunday)
```

Replace with:

```dart
        // Report-day banner
        if (!_isMonthly && _isCurrentWeek && _isReportDay)
```

- [ ] **Step 4: Run static analysis**

Run: `flutter analyze lib/screens/report_screen.dart`
Expected: 0 errors.

- [ ] **Step 5: Manual verification**

Run the app, open the Report tab:
- With cadence set to Weekly/Sunday (default) on a non-Sunday day, confirm no banner shows.
- Change cadence in Settings to Weekly with today's actual weekday selected, return to Report tab (pull to refresh or re-navigate to trigger `initState`), confirm the banner now shows.
- Confirm the weekly/monthly toggle button still works independently (tap it, view flips, tap again, flips back) regardless of the cadence setting.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/report_screen.dart
git commit -m "feat: report screen defaults to configured cadence and report-day banner"
```

---

### Task 6: Auto-send — cadence-aware trigger and report building

**Files:**
- Modify: `lib/screens/home_shell.dart:355-410 (approx)`

**Interfaces:**
- Consumes: `ReportCadenceService.instance.isReportDay(DateTime)` → `Future<bool>`, `.getCadence()` → `Future<ReportCadence>` (from Task 1); `ReportService.instance.buildMonthlyReport(name, l, year, month)` (existing, unchanged signature).
- Produces: no new public interface.

- [ ] **Step 1: Read the full current `_checkAutoSend` method**

Re-read `lib/screens/home_shell.dart` around lines 355-412 in the current file state before editing (line numbers may have shifted slightly from earlier edits in this session, though this file hasn't been touched by Tasks 1-5).

- [ ] **Step 2: Replace the Sunday-only guard**

Find:

```dart
  Future<void> _checkAutoSend() async {
    final now = DateTime.now();
    if (now.weekday != DateTime.sunday) return;
```

Replace with:

```dart
  Future<void> _checkAutoSend() async {
    final now = DateTime.now();
    if (!await ReportCadenceService.instance.isReportDay(now)) return;
```

Add the import at the top: `import '../services/report_cadence_service.dart';`

- [ ] **Step 3: Generalize the dedup key and report building**

Find:

```dart
    // Check if we already auto-sent this week
    final weekKey = _key(_mondayOf(now));
    final alreadySent = await s.getSetting('lastAutoSend', fallback: '');
    if (alreadySent == weekKey) return;
```

Replace with:

```dart
    // Check if we already auto-sent this period (week or month)
    final cadence = await ReportCadenceService.instance.getCadence();
    final periodKey = cadence == ReportCadence.monthly
        ? '${now.year}-${now.month.toString().padLeft(2, '0')}'
        : _key(_mondayOf(now));
    final alreadySent = await s.getSetting('lastAutoSend', fallback: '');
    if (alreadySent == periodKey) return;
```

Find:

```dart
    // Build the report in the user's preferred report language
    final name = await s.getSetting('myName');
    if (!mounted) return;
    final l = await _getReportLocalizations();
    final fullReport = await ReportService.instance.buildFullReport(name, l);
    final compactReport = await ReportService.instance.buildCompactReport(name, l);
```

Replace with:

```dart
    // Build the report in the user's preferred report language
    final name = await s.getSetting('myName');
    if (!mounted) return;
    final l = await _getReportLocalizations();
    final String fullReport;
    final String compactReport;
    if (cadence == ReportCadence.monthly) {
      final monthly = await ReportService.instance.buildMonthlyReport(name, l, now.year, now.month);
      fullReport = monthly;
      compactReport = monthly; // monthly cadence has one report format
    } else {
      fullReport = await ReportService.instance.buildFullReport(name, l);
      compactReport = await ReportService.instance.buildCompactReport(name, l);
    }
```

Find:

```dart
    if (ok) {
      await s.setSetting('lastAutoSend', weekKey);
      // Also save to archive
      final dates = ReportService.instance.weekDates();
      await s.saveReport(
        weekStart: ReportService.instance.keyFor(dates.first),
        weekEnd: ReportService.instance.keyFor(dates.last),
        fullReport: fullReport,
        compactReport: compactReport,
        sentVia: 'whatsapp (auto)',
      );
```

Replace with:

```dart
    if (ok) {
      await s.setSetting('lastAutoSend', periodKey);
      // Also save to archive
      final String archiveStart;
      final String archiveEnd;
      if (cadence == ReportCadence.monthly) {
        final firstOfMonth = DateTime(now.year, now.month, 1);
        final lastOfMonth = DateTime(now.year, now.month + 1, 0);
        archiveStart = ReportService.instance.keyFor(firstOfMonth);
        archiveEnd = ReportService.instance.keyFor(lastOfMonth);
      } else {
        final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
        final dates = ReportService.instance.weekDates(now, endWeekday);
        archiveStart = ReportService.instance.keyFor(dates.first);
        archiveEnd = ReportService.instance.keyFor(dates.last);
      }
      await s.saveReport(
        weekStart: archiveStart,
        weekEnd: archiveEnd,
        fullReport: fullReport,
        compactReport: compactReport,
        sentVia: 'whatsapp (auto)',
      );
```

- [ ] **Step 4: Check the queue-for-later path is unaffected**

Re-read the `if (!await _hasConnectivity())` block just above the send call — it queues `fullReport` (already correctly built per-cadence from Step 3) via `s.queuePendingReport(fullReport, whatsapp)`. No change needed there; confirm by reading it, don't edit it.

- [ ] **Step 5: Run static analysis**

Run: `flutter analyze lib/screens/home_shell.dart`
Expected: 0 errors.

- [ ] **Step 6: Manual verification**

This is hard to test live without waiting for the actual report day/time, so verify by code review instead:
- Re-read the final `_checkAutoSend` method top to bottom and confirm: weekly cadence reproduces the exact original behavior when `reportWeeklyDay=7` (Sunday) — same guard semantics, same report builders, same dedup key format (`_key(_mondayOf(now))`, unchanged for weekly).
- Confirm monthly cadence builds via `buildMonthlyReport`, dedups via a `yyyy-MM` key, and archives with correct month-start/month-end dates.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/home_shell.dart
git commit -m "feat: auto-send follows configured reporting cadence (weekly or monthly)"
```

---

### Task 7: Final verification pass

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: All tests pass, including the new `test/report_cadence_service_test.dart` and the additions to `test/report_service_test.dart`. If the local environment is memory-constrained (has been an issue in this project before — check free RAM with `Get-CimInstance Win32_OperatingSystem` on Windows if the run hangs or crashes with "Out of memory"), close unnecessary background processes/apps before retrying rather than concluding the code is broken.

- [ ] **Step 2: Run full static analysis**

Run: `flutter analyze`
Expected: 0 new errors (pre-existing lint `info`-level suggestions unrelated to this feature are acceptable — this codebase had 12 such pre-existing infos before this feature; don't fix unrelated ones as part of this task).

- [ ] **Step 3: Search for any remaining hardcoded Sunday references**

Run: search `lib/` for `DateTime.sunday`, `_nextInstanceOfSunday`, `scheduleSundayReminder`, `cancelSundayFollowUps`.
Expected: The only remaining `DateTime.sunday` reference should be `ReportCadenceService`'s own default fallback (`fallback: '7'` in `getWeeklyDay()`, which is Sunday's numeric value — not a literal `DateTime.sunday` reference, so this should actually find zero matches for `DateTime.sunday` outside of test files that intentionally construct a Sunday date for a test case, e.g. `test/notification_service_test.dart`'s renamed groups still legitimately use `DateTime.sunday` as a *parameter value* to the generic `nextInstanceOfWeekday`). Every renamed method should have zero remaining old-name references. Also search `test/notification_service_test.dart` specifically for `nextInstanceOfSunday(` (the free-function shadow, not the real service method) to confirm Task 3 Step 10 fully renamed its call sites.

- [ ] **Step 4: Manual end-to-end walkthrough**

Run the app:
1. Settings → confirm cadence defaults to Weekly, day defaults to Sunday (matches pre-feature behavior).
2. Change cadence to Weekly, day to today's actual weekday.
3. Navigate to Report tab → confirm the report-day banner now appears (if `_isCurrentWeek` and not monthly).
4. Back to Settings → switch cadence to Monthly, day to "Last day of month".
5. Navigate to Report tab → confirm it now shows the monthly view by default (toggle button still present and functional).
6. Back to Settings → tap "Reschedule All" (existing diagnostic button) → confirm no crash, check "tap to see pending" shows notifications still scheduled under their existing display names.

- [ ] **Step 5: Final commit if any fixes were needed during verification**

```bash
git add -A
git commit -m "fix: address issues found during final cadence feature verification"
```

(Only create this commit if Steps 1-4 actually required changes. If everything passed cleanly, skip this step — don't create an empty commit.)

---

## Self-Review Notes

- **Spec coverage:** §1 Settings → Task 1. §2 ReportCadenceService → Task 1. §3 ReportService → Task 2. §4 Report screen → Task 5. §5 Notifications → Task 3. §6 Auto-send → Task 6. §7 Settings screen → Task 4. Testing section → Tasks 1, 2 (unit tests) + Task 7 (full suite + manual). All spec sections have a corresponding task.
- **Placeholder scan:** No TBD/TODO markers; every step has literal code or an exact command.
- **Type consistency:** `ReportCadence` enum, `ReportCadenceService.instance` methods, and `weekDates(ref, endWeekday)` signatures are used identically across Tasks 2, 3, 5, 6 — verified by re-reading each task's "Interfaces" block against where it's consumed downstream.
- **Task ordering:** Task 1 (service) has no dependencies. Task 2 (ReportService) depends only on Task 1. Task 3 (notifications) depends only on Task 1. Task 4 (settings UI) depends on Tasks 1 and 3 (calls the renamed notification methods). Tasks 5 and 6 depend only on Task 1 (they don't call notification methods or `weekDates` with the new param directly — Task 6 does call `ReportService.instance.weekDates(now, endWeekday)`, which requires Task 2's signature change). Correct order: 1 → 2, 3 (parallel-safe) → 4 (needs 3) → 5, 6 (parallel-safe, both need 1; 6 also needs 2) → 7.
