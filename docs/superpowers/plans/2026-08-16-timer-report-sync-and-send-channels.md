# Timer/Report Sync, Proclamation Topics, and Send-Channel Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix timer/report data-sync bugs (Proclamation overriding instead of accumulating, Bible duration invisible per-day, Evangelism/Church missing session tracking, Fasting duplicated across two systems), add Proclamation topics with daily-reset widget behavior, remove the Giving/Tithe duration field, and add configurable WhatsApp/Gmail auto-send with a generalized offline queue.

**Architecture:** Extend `DailyLog` with new session lists (`ProclamationSession`, and session lists for Evangelism/Church) following the exact pattern already used by `BibleReadingEntry`/`DdegSession`/`PrayerSession` (auto-migration from legacy scalar on `fromMap`, JSON-encoded list column). Move Proclamation onto `TimerService` (replacing its bypassed local-`Stopwatch` implementation) so it gets accumulation, foreground-service, and overlay support for free. Add a shared `TimeTotals` helper to deduplicate report/reflection total-time math. Extend `CloudSyncService`'s existing Google Sign-In with the `gmail.send` scope and a new silent-send method using `package:googleapis/gmail/v1.dart`. Generalize the single-channel offline pending-report queue to a multi-channel list.

**Tech Stack:** Flutter/Dart, sqflite (SQLite), SharedPreferences, `googleapis`/`google_sign_in` (already in pubspec.yaml, no new dependencies needed), Kotlin (Android widget provider), existing `home_widget` package for Flutter↔Android sync.

**Spec:** `docs/superpowers/specs/2026-08-16-timer-report-sync-and-send-channels-design.md`

## Global Constraints

- Every new SQLite column must be added in **two** places: the `CREATE TABLE logs` block (fresh installs) AND a new `if (oldVersion < N)` block in `onUpgrade` (existing installs) in `lib/services/storage_service.dart`. Current DB version is 12 — this plan bumps it to 13.
- Legacy scalar fields (`proclamationCount`, `proclamationDuration`, `givingDuration`, `fastingDuration` on the stopwatch path) are **never deleted** from the model — only new writes stop targeting them. This matches the project's existing deprecation convention (see `evangelismDuration` etc. still present after DDEG/Prayer got session lists).
- All new user-facing strings go through the `S` localization class (`lib/l10n/app_en.arb` + `lib/l10n/app_fr.arb`), never hardcoded English literals in widget code. After editing `.arb` files, regenerate with `flutter gen-l10n` (or `flutter pub get`, which triggers it automatically since `flutter: generate: true` is set in pubspec.yaml).
- Both `buildFullReport` (weekly) and `buildMonthlyReport` (monthly) in `lib/services/report_service.dart` duplicate per-discipline line-construction logic — any report-line change must be applied in **both** places (see exact line numbers in each task).
- Use `StorageService.modifyLog(dateKey, modifier)` (atomic read-modify-write, `storage_service.dart:307-315`) for any new proclamation/session persistence path instead of the racy `getLog` → mutate → `saveLog` pattern the old proclamation counter used.
- `flutter analyze` must stay clean after every task.

---

## Phase A — Data model foundation

### Task 1: Add `ProclamationSession` model and migrate `DailyLog`

**Files:**
- Modify: `lib/models/daily_log.dart`
- Test: `test/daily_log_test.dart` (create if it doesn't exist)

**Interfaces:**
- Produces: `class ProclamationSession { String topic; String duration; int count; ... toMap()/fromMap() }`, `DailyLog.proclamationSessions: List<ProclamationSession>`, `DailyLog.totalProclamationCount` (int getter, sum of session counts, falls back to legacy `proclamationCount` when sessions empty), `DailyLog.totalProclamationMinutes` (int getter, sum of session durations parsed via same duration format as elsewhere).

- [ ] **Step 1: Write the failing test**

Create `test/daily_log_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/models/daily_log.dart';

void main() {
  group('ProclamationSession', () {
    test('toMap/fromMap round-trip', () {
      final s = ProclamationSession(topic: 'Healing', count: 3, duration: '12min');
      final restored = ProclamationSession.fromMap(s.toMap());
      expect(restored.topic, 'Healing');
      expect(restored.count, 3);
      expect(restored.duration, '12min');
    });

    test('isEmpty/isNotEmpty', () {
      expect(ProclamationSession().isEmpty, true);
      expect(ProclamationSession(topic: 'Salvation').isNotEmpty, true);
    });
  });

  group('DailyLog proclamation totals', () {
    test('totalProclamationCount sums sessions when present', () {
      final log = DailyLog(dateKey: '2026-08-16', proclamationSessions: [
        ProclamationSession(topic: 'Healing', count: 3, duration: '12min'),
        ProclamationSession(topic: 'Salvation', count: 1, duration: '5min'),
      ]);
      expect(log.totalProclamationCount, 4);
    });

    test('totalProclamationCount falls back to legacy scalar when no sessions', () {
      final log = DailyLog(dateKey: '2026-08-16', proclamationCount: '7');
      expect(log.totalProclamationCount, 7);
    });

    test('toMap/fromMap round-trips proclamationSessions', () {
      final log = DailyLog(dateKey: '2026-08-16', proclamationSessions: [
        ProclamationSession(topic: 'Healing', count: 3, duration: '12min'),
      ]);
      final restored = DailyLog.fromMap(log.toMap());
      expect(restored.proclamationSessions.length, 1);
      expect(restored.proclamationSessions.first.topic, 'Healing');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/daily_log_test.dart`
Expected: FAIL — `ProclamationSession` undefined, `proclamationSessions` undefined.

- [ ] **Step 3: Implement `ProclamationSession` and wire it into `DailyLog`**

In `lib/models/daily_log.dart`, add after the `PrayerSession` class (after line 147, before `class DailyLog`):

```dart
/// A single proclamation session — a topic proclaimed some number of times
/// over some duration. Multiple sessions with the same topic (case-insensitive,
/// trimmed) on the same day are merged rather than duplicated — see
/// TimerService's topic-matching logic.
class ProclamationSession {
  String topic;
  int count;
  String duration; // e.g. "12min", same format as other duration fields

  ProclamationSession({this.topic = '', this.count = 0, this.duration = ''});

  Map<String, dynamic> toMap() => {
    'topic': topic,
    'count': count,
    'duration': duration,
  };

  factory ProclamationSession.fromMap(Map<String, dynamic> m) => ProclamationSession(
    topic: m['topic'] ?? '',
    count: m['count'] ?? 0,
    duration: m['duration'] ?? '',
  );

  bool get isEmpty => topic.isEmpty && count == 0;
  bool get isNotEmpty => !isEmpty;
}
```

In `DailyLog`, add the field declaration right after `proclamationDuration` (after line 219):

```dart
  String proclamationDuration; // optional duration
  List<ProclamationSession> proclamationSessions;
```

Add to the constructor parameter list, right after `this.proclamationDuration = '',` (after line 270):

```dart
    this.proclamationDuration = '',
    List<ProclamationSession>? proclamationSessions,
```

Add to the constructor's initializer list (the `: bibleSessions = ... ,` block starting at line 274), alongside the other list initializers:

```dart
  }) : bibleSessions = bibleSessions ?? [],
       literature = literature ?? [LiteratureEntry()],
       ddegSessions = ddegSessions ?? [],
       prayerAloneSessions = prayerAloneSessions ?? [],
       prayerOthersSessions = prayerOthersSessions ?? [],
       proclamationSessions = proclamationSessions ?? [],
       customActivityData = customActivityData ?? {};
```

Add two getters right after `combinedBibleReference` (after line 385, before `factory DailyLog.fromMap`):

```dart
  /// Total proclamation count: sessions if present, else the legacy scalar.
  int get totalProclamationCount => proclamationSessions.isNotEmpty
      ? proclamationSessions.fold(0, (sum, s) => sum + s.count)
      : (int.tryParse(proclamationCount) ?? 0);

  /// Total proclamation minutes across all sessions (0 if none have a duration).
  int get totalProclamationMinutes => proclamationSessions.fold(
      0, (sum, s) => sum + _parseDurationMinutesStatic(s.duration));

  static int _parseDurationMinutesStatic(String s) {
    if (s.isEmpty) return 0;
    final cleaned = s.trim().toLowerCase();
    final hm = RegExp(r'(\d+)\s*h\w*\s*(\d+)?\s*m?\w*');
    final hmMatch = hm.firstMatch(cleaned);
    if (hmMatch != null) {
      final h = int.tryParse(hmMatch.group(1)!) ?? 0;
      final m = int.tryParse(hmMatch.group(2) ?? '0') ?? 0;
      return h * 60 + m;
    }
    final mOnly = RegExp(r'(\d+)\s*m(?:in(?:ute)?s?)?$');
    final mMatch = mOnly.firstMatch(cleaned);
    if (mMatch != null) return int.tryParse(mMatch.group(1)!) ?? 0;
    final hOnly = RegExp(r'(\d+)\s*h(?:ours?)?$');
    final hMatch = hOnly.firstMatch(cleaned);
    if (hMatch != null) return (int.tryParse(hMatch.group(1)!) ?? 0) * 60;
    return int.tryParse(cleaned) ?? 0;
  }
```

Add to `toMap()`, right after the `'proclamationDuration': proclamationDuration,` line (after line 359):

```dart
        'proclamationDuration': proclamationDuration,
        'proclamationSessions': jsonEncode(proclamationSessions.map((s) => s.toMap()).toList()),
```

Add parsing logic in `fromMap()`, following the exact pattern used for `prayerOthersSessions` (lines 458-477). Insert right before `Map<String, Map<String, dynamic>> customData = {};` (before line 479):

```dart
    // Proclamation sessions
    List<ProclamationSession> proclamationSessions = [];
    try {
      final rawProc = m['proclamationSessions'];
      if (rawProc != null && rawProc.toString().isNotEmpty) {
        final decoded = jsonDecode(rawProc) as List;
        proclamationSessions = decoded
            .map((e) => ProclamationSession.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint('DailyLog.fromMap: failed to parse proclamationSessions: $e');
    }
    if (proclamationSessions.isEmpty) {
      final oldCount = (m['proclamationCount'] ?? '').toString();
      final oldDuration = (m['proclamationDuration'] ?? '').toString();
      if (oldCount.isNotEmpty && (int.tryParse(oldCount) ?? 0) > 0) {
        proclamationSessions = [ProclamationSession(
            topic: '', count: int.tryParse(oldCount) ?? 0, duration: oldDuration)];
      }
    }
```

Add `proclamationSessions: proclamationSessions,` to the returned `DailyLog(...)` constructor call in `fromMap`, right after `proclamationDuration: m['proclamationDuration'] ?? '',` (after line 532).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/daily_log_test.dart`
Expected: PASS (all 5 tests).

- [ ] **Step 5: Run full analyzer**

Run: `flutter analyze`
Expected: No new errors/warnings.

- [ ] **Step 6: Commit**

```bash
git add lib/models/daily_log.dart test/daily_log_test.dart
git commit -m "feat: add ProclamationSession model with auto-migration from legacy scalar"
```

---

### Task 2: Add Evangelism/Church session lists to `DailyLog`

**Files:**
- Modify: `lib/models/daily_log.dart`
- Test: `test/daily_log_test.dart`

**Interfaces:**
- Consumes: nothing new from Task 1 (parallel model, same pattern).
- Produces: `class TimedSession { DateTime start; DateTime end; int durationSeconds; toMap()/fromMap(); String get formattedDuration }`, `DailyLog.evangelismSessions: List<TimedSession>`, `DailyLog.churchSessions: List<TimedSession>`, `DailyLog.totalEvangelismMinutes`, `DailyLog.totalChurchMinutes` (both: sum of sessions if present, else parse legacy scalar).

- [ ] **Step 1: Write the failing test**

Append to `test/daily_log_test.dart`, inside a new `group`:

```dart
  group('TimedSession', () {
    test('toMap/fromMap round-trip', () {
      final start = DateTime(2026, 8, 16, 9, 0);
      final end = DateTime(2026, 8, 16, 9, 45);
      final s = TimedSession(start: start, end: end, durationSeconds: 2700);
      final restored = TimedSession.fromMap(s.toMap());
      expect(restored.durationSeconds, 2700);
      expect(restored.start, start);
      expect(restored.end, end);
    });
  });

  group('DailyLog evangelism/church sessions', () {
    test('totalEvangelismMinutes sums sessions when present', () {
      final log = DailyLog(dateKey: '2026-08-16', evangelismSessions: [
        TimedSession(start: DateTime(2026,8,16,9), end: DateTime(2026,8,16,9,30), durationSeconds: 1800),
        TimedSession(start: DateTime(2026,8,16,14), end: DateTime(2026,8,16,14,15), durationSeconds: 900),
      ]);
      expect(log.totalEvangelismMinutes, 45);
    });

    test('totalChurchMinutes falls back to legacy scalar when no sessions', () {
      final log = DailyLog(dateKey: '2026-08-16', churchDuration: '1h 30min');
      expect(log.totalChurchMinutes, 90);
    });

    test('toMap/fromMap round-trips evangelismSessions', () {
      final log = DailyLog(dateKey: '2026-08-16', evangelismSessions: [
        TimedSession(start: DateTime(2026,8,16,9), end: DateTime(2026,8,16,9,30), durationSeconds: 1800),
      ]);
      final restored = DailyLog.fromMap(log.toMap());
      expect(restored.evangelismSessions.length, 1);
      expect(restored.evangelismSessions.first.durationSeconds, 1800);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/daily_log_test.dart`
Expected: FAIL — `TimedSession` undefined.

- [ ] **Step 3: Implement `TimedSession` and wire it into `DailyLog`**

In `lib/models/daily_log.dart`, add `TimedSession` class right after `ProclamationSession` (added in Task 1):

```dart
/// A single timed session for activities without richer per-session data
/// (Evangelism, Church). Multiple sessions in a day accumulate here rather
/// than overwriting a single scalar duration field.
class TimedSession {
  DateTime start;
  DateTime end;
  int durationSeconds;

  TimedSession({required this.start, required this.end, required this.durationSeconds});

  Map<String, dynamic> toMap() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'durationSeconds': durationSeconds,
  };

  factory TimedSession.fromMap(Map<String, dynamic> m) => TimedSession(
    start: DateTime.parse(m['start'] as String),
    end: DateTime.parse(m['end'] as String),
    durationSeconds: m['durationSeconds'] as int,
  );

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final h = m ~/ 60;
    final remM = m % 60;
    if (h > 0 && remM > 0) return '${h}h ${remM}min';
    if (h > 0) return '${h}h';
    return '$remM min';
  }
}
```

Add field declarations in `DailyLog`, right after `String churchDuration;` (after line 193):

```dart
  String churchDuration;
  List<TimedSession> evangelismSessions;
  List<TimedSession> churchSessions;
```

Add to constructor parameters, right after `this.churchDuration = '',` (after line 256):

```dart
    this.churchDuration = '',
    List<TimedSession>? evangelismSessions,
    List<TimedSession>? churchSessions,
```

Add to the initializer list, alongside `proclamationSessions` added in Task 1:

```dart
       proclamationSessions = proclamationSessions ?? [],
       evangelismSessions = evangelismSessions ?? [],
       churchSessions = churchSessions ?? [],
       customActivityData = customActivityData ?? {};
```

Add getters right after the proclamation totals getters added in Task 1:

```dart
  /// Total evangelism minutes: sessions if present, else the legacy scalar.
  int get totalEvangelismMinutes => evangelismSessions.isNotEmpty
      ? evangelismSessions.fold(0, (sum, s) => sum + s.durationSeconds ~/ 60)
      : _parseDurationMinutesStatic(evangelismDuration);

  /// Total church minutes: sessions if present, else the legacy scalar.
  int get totalChurchMinutes => churchSessions.isNotEmpty
      ? churchSessions.fold(0, (sum, s) => sum + s.durationSeconds ~/ 60)
      : _parseDurationMinutesStatic(churchDuration);
```

Add to `toMap()`, right after `'churchDuration': churchDuration,` (after line 345):

```dart
        'churchDuration': churchDuration,
        'evangelismSessions': jsonEncode(evangelismSessions.map((s) => s.toMap()).toList()),
        'churchSessions': jsonEncode(churchSessions.map((s) => s.toMap()).toList()),
```

Add parsing in `fromMap()`, right before the `Map<String, Map<String, dynamic>> customData = {};` line (same insertion point as Task 1's proclamation parsing — put this block before it):

```dart
    List<TimedSession> evangelismSessions = [];
    try {
      final raw = m['evangelismSessions'];
      if (raw != null && raw.toString().isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        evangelismSessions = decoded.map((e) => TimedSession.fromMap(Map<String, dynamic>.from(e))).toList();
      }
    } catch (e) {
      debugPrint('DailyLog.fromMap: failed to parse evangelismSessions: $e');
    }

    List<TimedSession> churchSessions = [];
    try {
      final raw = m['churchSessions'];
      if (raw != null && raw.toString().isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        churchSessions = decoded.map((e) => TimedSession.fromMap(Map<String, dynamic>.from(e))).toList();
      }
    } catch (e) {
      debugPrint('DailyLog.fromMap: failed to parse churchSessions: $e');
    }
```

Add `evangelismSessions: evangelismSessions,` and `churchSessions: churchSessions,` to the returned `DailyLog(...)` in `fromMap`, right after `churchDuration: m['churchDuration'] ?? '',` (after line 518, exact position depends on Task 1's edits — place both new params there).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/daily_log_test.dart`
Expected: PASS (all 8 tests).

- [ ] **Step 5: Run full analyzer**

Run: `flutter analyze`
Expected: No new errors/warnings.

- [ ] **Step 6: Commit**

```bash
git add lib/models/daily_log.dart test/daily_log_test.dart
git commit -m "feat: add TimedSession model for evangelism/church multi-session tracking"
```

---

### Task 3: SQLite migration — persist new session columns, bump DB version to 13

**Files:**
- Modify: `lib/services/storage_service.dart`
- Test: `test/storage_service_test.dart` (check if exists; if not, create)

**Interfaces:**
- Consumes: `DailyLog.toMap()`/`DailyLog.fromMap()` from Tasks 1-2 (already include the new JSON columns).
- Produces: DB schema version 13 with `proclamationSessions`, `evangelismSessions`, `churchSessions` TEXT columns.

- [ ] **Step 1: Write the failing test**

Check for an existing storage test file first:

```bash
find test -iname "*storage*"
```

If `test/storage_service_test.dart` exists, add a new test to it; otherwise create it following the pattern of other tests in the repo (check `test/activity_timer_test.dart` for the sqflite_common_ffi setup pattern used for DB tests). Add:

```dart
test('saveLog and getLog round-trip proclamationSessions/evangelismSessions/churchSessions', () async {
  final log = DailyLog(
    dateKey: '2026-08-16',
    proclamationSessions: [ProclamationSession(topic: 'Healing', count: 2, duration: '10min')],
    evangelismSessions: [TimedSession(start: DateTime(2026,8,16,9), end: DateTime(2026,8,16,9,30), durationSeconds: 1800)],
    churchSessions: [TimedSession(start: DateTime(2026,8,16,10), end: DateTime(2026,8,16,11), durationSeconds: 3600)],
  );
  await StorageService.instance.saveLog(log);
  final restored = await StorageService.instance.getLog('2026-08-16');
  expect(restored!.proclamationSessions.length, 1);
  expect(restored.evangelismSessions.length, 1);
  expect(restored.churchSessions.length, 1);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/storage_service_test.dart`
Expected: FAIL — sqflite throws "no such column: proclamationSessions" (or similar), since the DB schema doesn't have the column yet.

- [ ] **Step 3: Add the schema migration**

In `lib/services/storage_service.dart`:

1. Change the version number (currently `version: 12`, line 31) to `version: 13`.
2. In the `CREATE TABLE logs` block, add three new columns (put them near the other session columns like `bibleSessions`):

```dart
proclamationSessions TEXT DEFAULT '',
evangelismSessions TEXT DEFAULT '',
churchSessions TEXT DEFAULT '',
```

3. In `onUpgrade`, add a new block right after the `if (oldVersion < 12) { ... }` block (after line 171, before the closing `});` of the transaction at line 172):

```dart
          if (oldVersion < 13) {
            for (final col in [
              'proclamationSessions', 'evangelismSessions', 'churchSessions',
            ]) {
              await txn.execute("ALTER TABLE logs ADD COLUMN $col TEXT DEFAULT ''");
            }
          }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/storage_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Run full test suite + analyzer**

Run: `flutter test && flutter analyze`
Expected: All pass, no new warnings.

- [ ] **Step 6: Commit**

```bash
git add lib/services/storage_service.dart test/storage_service_test.dart
git commit -m "feat: migrate DB to v13, add session columns for proclamation/evangelism/church"
```

---

## Phase B — Timer engine: Proclamation moves onto TimerService, Fasting removed from grid

### Task 4: Add topic-matching helper and session-append branch to `TimerService`

**Files:**
- Modify: `lib/services/timer_service.dart`
- Test: `test/timer_service_test.dart` (create if it doesn't exist — check first)

**Interfaces:**
- Consumes: `DailyLog.proclamationSessions`, `ProclamationSession` (Task 1); `DailyLog.evangelismSessions`/`churchSessions`, `TimedSession` (Task 2).
- Produces: `TimerService._writeToDailyLog` gains proclamation-topic-matching and evangelism/church session-append branches. New field convention: `TimerSession.fields['proclamationTopic']` carries the topic entered at start time (mirrors the existing `fields['bibleStartRef']` convention).

- [ ] **Step 1: Write the failing test**

```bash
find test -iname "*timer_service*"
```

Create `test/timer_service_test.dart` if absent (check `test/activity_timer_test.dart` for the SharedPreferences/sqflite_common_ffi mock setup convention used in this repo, and mirror it). Write:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_account/models/activity_timer.dart';
import 'package:daily_account/models/daily_log.dart';
import 'package:daily_account/services/storage_service.dart';
import 'package:daily_account/services/timer_service.dart';

// (mirror whatever DB-in-memory setup activity_timer_test.dart uses)

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('stopping a proclamation timer with a new topic appends a session', () async {
    final key = TimerKey.builtIn(ActivityType.proclamation);
    TimerService.instance.start(key, fields: {'proclamationTopic': 'Healing'});
    await TimerService.instance.stop(key);
    final log = await StorageService.instance.getLog(
        DateFormat('yyyy-MM-dd').format(DateTime.now()));
    expect(log!.proclamationSessions.length, 1);
    expect(log.proclamationSessions.first.topic, 'Healing');
  });

  test('stopping a second proclamation timer with the same topic (case-insensitive) merges into the existing session', () async {
    final key = TimerKey.builtIn(ActivityType.proclamation);
    TimerService.instance.start(key, fields: {'proclamationTopic': 'healing'});
    await TimerService.instance.stop(key);
    final log = await StorageService.instance.getLog(
        DateFormat('yyyy-MM-dd').format(DateTime.now()));
    expect(log!.proclamationSessions.length, 1); // still 1, merged not appended
    expect(log.proclamationSessions.first.count, 2);
  });
}
```

(Note: exact test scaffolding — DB reset between tests, imports — must match whatever `test/activity_timer_test.dart` already establishes in this repo; read that file first and mirror its `setUp`/`tearDown` pattern exactly.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/timer_service_test.dart`
Expected: FAIL — proclamation still writes to `proclamationCount`/`proclamationDuration` scalars, not `proclamationSessions`.

- [ ] **Step 3: Implement topic-matching and session-append logic**

In `lib/services/timer_service.dart`, replace the `case 'proclamationDuration':` branch inside `_writeToDailyLog`'s builtin-activity switch (lines 474-476) — remove it from the scalar-accumulation switch entirely (Proclamation no longer accumulates via the scalar path), and instead handle Proclamation as a special case before the switch. Restructure the start of `_writeToDailyLog`'s builtin branch (lines 443-478):

```dart
    if (session.key.isBuiltIn) {
      final builtInType = session.key.builtIn!;

      if (builtInType == ActivityType.proclamation) {
        _appendProclamationSession(log, session, durationStr);
      } else if (builtInType == ActivityType.evangelism) {
        _appendTimedSession(log.evangelismSessions, session, durationStr);
      } else if (builtInType == ActivityType.church) {
        _appendTimedSession(log.churchSessions, session, durationStr);
      } else {
        // Accumulate duration field (add to existing) if the activity has one
        final field = session.key.builtIn!.logDurationField;
        if (field != null) {
          switch (field) {
            case 'bibleDuration':
              log.bibleDuration = _accumulateDuration(log.bibleDuration, durationStr);
            case 'literatureDuration':
              log.literatureDuration = _accumulateDuration(log.literatureDuration, durationStr);
            case 'ddegTime':
              log.ddegTime = _accumulateDuration(log.ddegTime, durationStr);
            case 'prayerAloneDuration':
              log.prayerAloneDuration = _accumulateDuration(log.prayerAloneDuration, durationStr);
            case 'prayerOthersDuration':
              log.prayerOthersDuration = _accumulateDuration(log.prayerOthersDuration, durationStr);
            case 'fastingDuration':
              log.fastingDuration = _accumulateDuration(log.fastingDuration, durationStr);
            case 'discipleshipDuration':
              log.discipleshipDuration = _accumulateDuration(log.discipleshipDuration, durationStr);
          }
        }
      }

      // Merge extra fields captured before start (accumulate, don't overwrite)
      for (final entry in session.fields.entries) {
        if (entry.key == 'bibleChapters' && !_hasBibleReference(session.fields, log)) {
          continue;
        }
        if (entry.key == 'proclamationTopic') continue; // consumed above, not a log field
        _mergeLogField(log, entry.key, entry.value);
      }
    } else {
```

Add two new private helper methods right after `_writeToDailyLog` (after line 525, before `_parseDurationMinutes`):

```dart
  /// Append a proclamation session, merging into an existing same-day
  /// session if the topic matches (case-insensitive, trimmed) instead of
  /// creating a duplicate.
  void _appendProclamationSession(DailyLog log, TimerSession session, String durationStr) {
    final topic = (session.fields['proclamationTopic'] ?? '').trim();
    final normalizedTopic = topic.toLowerCase();
    final existingIndex = log.proclamationSessions.indexWhere(
        (s) => s.topic.trim().toLowerCase() == normalizedTopic);

    if (existingIndex != -1) {
      final existing = log.proclamationSessions[existingIndex];
      existing.count += 1;
      existing.duration = _accumulateDuration(existing.duration, durationStr);
    } else {
      log.proclamationSessions.add(ProclamationSession(
        topic: topic,
        count: 1,
        duration: durationStr,
      ));
    }
  }

  /// Append a new timed session (Evangelism/Church) to the given list.
  void _appendTimedSession(List<TimedSession> sessions, TimerSession session, String durationStr) {
    final end = DateTime.now();
    final start = end.subtract(session.currentElapsed);
    sessions.add(TimedSession(
      start: start,
      end: end,
      durationSeconds: session.currentElapsed.inSeconds,
    ));
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/timer_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Run full test suite + analyzer**

Run: `flutter test && flutter analyze`
Expected: All pass. Note `test/activity_timer_test.dart` may have assertions about `logDurationField` returning `'proclamationDuration'` for `ActivityType.proclamation` — that mapping is untouched (still used as a fallback/legacy reference), so those tests should remain green. If any existing test asserts the *scalar* `proclamationDuration` gets written by `TimerService.stop()`, that assertion will now correctly fail and must be updated to assert `proclamationSessions` instead — update it, don't delete it.

- [ ] **Step 6: Commit**

```bash
git add lib/services/timer_service.dart test/timer_service_test.dart
git commit -m "feat: TimerService writes proclamation topics as sessions, evangelism/church as sessions"
```

---

### Task 5: Replace `_openProclamationCounter` with a topic-picker + TimerService flow; remove Fasting tile

**Files:**
- Modify: `lib/screens/stopwatch_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`

**Interfaces:**
- Consumes: `TimerService.instance.start(key, fields: {...})` (existing, `timer_service.dart:170`), `TimerService.instance.stop(key)` (existing), `TimerKey.builtIn(ActivityType.proclamation)`, `DailyLog.proclamationSessions` (Task 1) for populating the "recent topics" chips, `StorageService.instance.getLog()` (existing).
- Produces: `_showProclamationTopicPicker()` method (replaces `_openProclamationCounter()`), reusable by both the in-app grid tile tap and (in Task 9) the widget deep-link handler. Route/method must be reachable via a public entry point on `StopwatchScreen`'s state or extracted so `home_shell.dart` can trigger it from the deep link — expose as `static void showProclamationTopicPicker(BuildContext context, {VoidCallback? onDone})` at file-top level or as a routed screen; simplest approach: make it a route pushed via `Navigator`, not a bottom sheet tied to `StopwatchScreen`'s State, so the deep-link handler in `home_shell.dart` can push it directly. Use a new dedicated file `lib/screens/proclamation_topic_screen.dart` exporting `class ProclamationTopicScreen extends StatefulWidget`.

- [ ] **Step 1: Add ARB strings for the new topic picker**

In `lib/l10n/app_en.arb`, add near the existing `proclamationCounter`/`proclamationSubtitle` entries (around line 466-470):

```json
"proclamationTopicPrompt": "What are you proclaiming?",
"proclamationTopicHint": "e.g. Healing, Salvation, Victory",
"proclamationRecentTopics": "Recent topics today",
"proclamationStartButton": "Start Proclaiming",
```

Add the matching French translations to `lib/l10n/app_fr.arb` (check existing neighboring French entries for `proclamationCounter` etc. to match tone/style):

```json
"proclamationTopicPrompt": "Que proclamez-vous ?",
"proclamationTopicHint": "ex. Guérison, Salut, Victoire",
"proclamationRecentTopics": "Sujets récents aujourd'hui",
"proclamationStartButton": "Commencer la Proclamation",
```

Remove `proclamationTap` and `proclamationSave` if no longer referenced anywhere else after this task (grep first — check Step 4).

Run: `flutter pub get` (regenerates localization getters via `flutter: generate: true`).

- [ ] **Step 2: Create the topic-picker screen**

Create `lib/screens/proclamation_topic_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/activity_timer.dart';
import '../services/storage_service.dart';
import '../services/timer_service.dart';
import '../theme/app_theme.dart';

/// Prompts for a proclamation topic before starting the timer.
/// Reused both from the Stopwatch grid tile and from the home-screen
/// widget's "+" tap (via deep link), so it's a standalone routed screen
/// rather than a bottom sheet tied to StopwatchScreen's state.
class ProclamationTopicScreen extends StatefulWidget {
  const ProclamationTopicScreen({super.key});

  @override
  State<ProclamationTopicScreen> createState() => _ProclamationTopicScreenState();
}

class _ProclamationTopicScreenState extends State<ProclamationTopicScreen> {
  final _controller = TextEditingController();
  List<String> _recentTopics = [];
  String? _selected;

  @override
  void initState() {
    super.initState();
    _loadRecentTopics();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecentTopics() async {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final log = await StorageService.instance.getLog(todayKey);
    if (log == null || !mounted) return;
    setState(() {
      _recentTopics = log.proclamationSessions
          .map((s) => s.topic)
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();
    });
  }

  void _start() {
    final topic = (_selected ?? _controller.text).trim();
    Navigator.of(context).pop();
    TimerService.instance.start(
      TimerKey.builtIn(ActivityType.proclamation),
      fields: {'proclamationTopic': topic},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l.proclamationTopicPrompt, style: AppTheme.display(18, color: accent)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              onChanged: (v) => setState(() => _selected = null),
              style: AppTheme.serif(16, color: AppTheme.textColor(context)),
              decoration: InputDecoration(
                hintText: l.proclamationTopicHint,
                hintStyle: AppTheme.serif(14, color: AppTheme.faintColor(context)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent.withValues(alpha: 0.3))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
              ),
            ),
            if (_recentTopics.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(l.proclamationRecentTopics,
                  style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentTopics.map((topic) {
                  final selected = _selected == topic;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selected = topic;
                      _controller.text = topic;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? accent : accent.withValues(alpha: 0.3)),
                      ),
                      child: Text(topic, style: AppTheme.serif(13, color: AppTheme.textColor(context))),
                    ),
                  );
                }).toList(),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _start,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(l.proclamationStartButton,
                      style: AppTheme.display(16, color: AppTheme.bg0)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

(If `AppTheme.bgColor`/`AppTheme.faintColor`/`AppTheme.label` don't exist with those exact names, check `lib/theme/app_theme.dart` and use the actual matching static members — other screens in this codebase already use `AppTheme.faintColor(context)` and `AppTheme.label(...)`, confirmed from the settings_screen.dart excerpts read during planning, e.g. `AppTheme.label(11, color: accent.withValues(alpha: 0.7))` at settings_screen.dart:1710.)

- [ ] **Step 2b: Verify it compiles standalone**

Run: `flutter analyze lib/screens/proclamation_topic_screen.dart`
Expected: No errors (new unreferenced file is fine at this point).

- [ ] **Step 3: Wire the Stopwatch grid tile to push the new screen; remove the old counter and Fasting tile**

In `lib/screens/stopwatch_screen.dart`:

1. Add the import: `import 'proclamation_topic_screen.dart';`
2. In `_activityTile` (around line 297-304), replace the proclamation branch:

```dart
              if (!isRunning && !isPaused)
                _tileButton(Icons.play_arrow_rounded, AppTheme.green, () {
                  if (activity == ActivityType.proclamation) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProclamationTopicScreen()),
                    );
                  } else {
                    _showFieldsAndStart(activity);
                  }
                }),
```

3. Delete the entire `_openProclamationCounter()` method (lines 1062-1233 per the extraction — verify exact current line numbers before deleting, since Tasks 1-4 didn't touch this file).
4. In `_activityGrid` (around line 221-222), filter out Fasting from the built-in grid:

```dart
  Widget _activityGrid(S l, TimerService ts, Color accent) {
    final builtIn = ActivityType.values.where((a) => a != ActivityType.fasting).toList();
    final totalCount = builtIn.length + _customActivities.length + 1;
```

(The rest of `_activityGrid`'s `itemBuilder` already indexes into `builtIn`, so no further change needed there — just confirm it reads `builtIn[i]` not `ActivityType.values[i]` directly, which it does per the earlier extraction at line 237.)

5. Grep the file for any other reference to `ActivityType.fasting` in this file (e.g. in `_label`, `_fieldsFor`) — leave those switch cases in place (they must remain exhaustive since `ActivityType.fasting` still exists in the enum), just confirm nothing else tries to render a fasting tile.

- [ ] **Step 4: Grep for now-orphaned ARB keys and remove if unused**

```bash
grep -rn "proclamationTap\|proclamationSave\|proclamationCounter\b" lib/
```

If `proclamationTap`/`proclamationSave`/`proclamationCounter` are no longer referenced anywhere in `lib/`, remove their entries from both `lib/l10n/app_en.arb` and `lib/l10n/app_fr.arb`. If `proclamationSubtitle` (the hardcoded "Jesus Christ is the Lord" text) is also now unused in Dart code, leave it for Task 10 (Android widget) to address separately — it's also used there via the native string resource, not this ARB key, so check carefully whether this specific ARB key has any remaining Dart reference before deleting.

- [ ] **Step 5: Manual verification (no automated UI test for this bottom-sheet-to-screen change)**

Run: `flutter analyze`
Expected: Clean.

Run the app (`flutter run`), navigate to Stopwatch tab, tap Proclamation's play button — verify it opens `ProclamationTopicScreen`, typing/selecting a topic and tapping "Start Proclaiming" starts a normal timer (visible in the active-timer hero), stopping it writes a `ProclamationSession`. Verify the Fasting tile no longer appears in the grid.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/stopwatch_screen.dart lib/screens/proclamation_topic_screen.dart lib/l10n/app_en.arb lib/l10n/app_fr.arb
git commit -m "feat: proclamation timer asks for topic first, remove fasting stopwatch tile"
```

---

## Phase C — Report generation fixes

### Task 6: Add shared `TimeTotals` helper, consolidate report + reflection total-time logic

**Files:**
- Create: `lib/services/time_totals.dart`
- Modify: `lib/services/report_service.dart`
- Modify: `lib/services/reflection_service.dart`
- Test: `test/time_totals_test.dart`

**Interfaces:**
- Consumes: `DailyLog` fields (`bibleDuration`, `literatureDuration`, `evangelismDuration`/`totalEvangelismMinutes`, `givingDuration` — **excluded** per spec, `churchDuration`/`totalChurchMinutes`, `discipleshipDuration`, `proclamationDuration`/`totalProclamationMinutes`, `prayerAloneDuration`, `prayerOthersDuration`, `ddegTime`).
- Produces: `TimeTotals.consecratedMinutes(DailyLog log) -> int` — single source of truth for "total time consecrated" used by both `ReportService` and `ReflectionService`.

- [ ] **Step 1: Write the failing test**

Create `test/time_totals_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/models/daily_log.dart';
import 'package:daily_account/services/time_totals.dart';

void main() {
  test('consecratedMinutes sums duration fields, excluding givingDuration', () {
    final log = DailyLog(
      dateKey: '2026-08-16',
      bibleDuration: '30 minutes',
      literatureDuration: '15 minutes',
      discipleshipDuration: '1h',
      churchDuration: '2h',
      givingDuration: '99 minutes', // must NOT be counted
    );
    // 30 + 15 + 60 + 120 = 225
    expect(TimeTotals.consecratedMinutes(log), 225);
  });

  test('consecratedMinutes uses session totals for evangelism/church when present', () {
    final log = DailyLog(
      dateKey: '2026-08-16',
      evangelismSessions: [TimedSession(start: DateTime(2026,8,16,9), end: DateTime(2026,8,16,9,30), durationSeconds: 1800)],
    );
    expect(TimeTotals.consecratedMinutes(log), 30);
  });

  test('consecratedMinutes uses proclamation session totals when present', () {
    final log = DailyLog(
      dateKey: '2026-08-16',
      proclamationSessions: [ProclamationSession(topic: 'Healing', count: 1, duration: '12min')],
    );
    expect(TimeTotals.consecratedMinutes(log), 12);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/time_totals_test.dart`
Expected: FAIL — `lib/services/time_totals.dart` doesn't exist.

- [ ] **Step 3: Implement `TimeTotals`**

Create `lib/services/time_totals.dart`:

```dart
import '../models/daily_log.dart';

/// Single source of truth for "total time consecrated" — used by both the
/// weekly/monthly report footer and the AI reflection text, which
/// previously had two divergent implementations of the same calculation.
class TimeTotals {
  TimeTotals._();

  static int consecratedMinutes(DailyLog log) {
    return _parseDurationMinutes(log.discipleshipDuration) +
        log.totalProclamationMinutes +
        _parseDurationMinutes(log.bibleDuration) +
        _parseDurationMinutes(log.literatureDuration) +
        log.totalEvangelismMinutes +
        log.totalChurchMinutes +
        _parseDurationMinutes(log.prayerAloneDuration) +
        _parseDurationMinutes(log.prayerOthersDuration) +
        _parseDurationMinutes(log.ddegTime);
  }

  /// Parse duration strings like "45m", "1h 30m", "30 minutes", "1h 30min".
  static int _parseDurationMinutes(String s) {
    if (s.isEmpty || s == '✓') return 0;
    final cleaned = s.trim().toLowerCase();
    final hm = RegExp(r'(\d+)\s*h\w*\s*(\d+)?\s*m?\w*');
    final hmMatch = hm.firstMatch(cleaned);
    if (hmMatch != null) {
      final h = int.tryParse(hmMatch.group(1)!) ?? 0;
      final m = int.tryParse(hmMatch.group(2) ?? '0') ?? 0;
      return h * 60 + m;
    }
    final mOnly = RegExp(r'(\d+)\s*m(?:in(?:ute)?s?)?$');
    final mMatch = mOnly.firstMatch(cleaned);
    if (mMatch != null) return int.tryParse(mMatch.group(1)!) ?? 0;
    final hOnly = RegExp(r'(\d+)\s*h(?:ours?)?$');
    final hMatch = hOnly.firstMatch(cleaned);
    if (hMatch != null) return (int.tryParse(hMatch.group(1)!) ?? 0) * 60;
    return int.tryParse(cleaned) ?? 0;
  }
}
```

Note: `discipleshipDuration`, `bibleDuration`, `literatureDuration`, `prayerAloneDuration`, `prayerOthersDuration`, `ddegTime` remain scalar-only per the spec (no session lists added for those in this plan) — they're parsed directly. `evangelismDuration`/`churchDuration` are superseded by `totalEvangelismMinutes`/`totalChurchMinutes` (Task 2), which already fall back to the legacy scalar internally, so don't double-count by also calling `_parseDurationMinutes` on the raw scalar for those two.

- [ ] **Step 4: Replace `ReportService._totalConsecratedMinutes` with a call to `TimeTotals`**

In `lib/services/report_service.dart`, add `import 'time_totals.dart';` to the imports. Read the current body of `_totalConsecratedMinutes` (lines 125-179) — replace its per-log summation logic (wherever it loops over week logs and sums duration fields per log) to call `TimeTotals.consecratedMinutes(log)` per log instead of inlining the field list. Keep the outer loop/weekly-aggregation structure intact — only replace the per-log field-summing portion with the shared helper. Ensure `givingDuration` is not summed anywhere in this method after the change (it wasn't part of the original per-spec list to keep — confirm the diff removes it if it was previously included).

- [ ] **Step 5: Replace `ReflectionService._parseMinutes`-based total with `TimeTotals`**

In `lib/services/reflection_service.dart`, add `import 'time_totals.dart';`. Replace lines 387-394 (the `totalMin = _parseMinutes(...) + ...` block) with:

```dart
    // Total time
    final totalMin = TimeTotals.consecratedMinutes(log);
```

Leave `_parseMinutes` (lines 117-134) in place only if it's used elsewhere in the file (grep first: `grep -n "_parseMinutes" lib/services/reflection_service.dart`); if this was its only call site, delete the now-dead private method.

- [ ] **Step 6: Run tests to verify everything passes**

Run: `flutter test && flutter analyze`
Expected: All pass, including any pre-existing tests on `ReportService`/`ReflectionService` total-time output (values should be equal or more accurate than before — if an existing test hardcodes an expected total that excluded evangelism/church/giving inconsistently, update the expected value to match the new consistent calculation, not the old one).

- [ ] **Step 7: Commit**

```bash
git add lib/services/time_totals.dart lib/services/report_service.dart lib/services/reflection_service.dart test/time_totals_test.dart
git commit -m "refactor: consolidate total-time calculation into shared TimeTotals helper"
```

---

### Task 7: Show Bible duration per-day, session-aware Evangelism/Church lines, topic-aware Proclamation line, remove Giving duration from reports

**Files:**
- Modify: `lib/services/report_service.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`
- Test: `test/report_service_test.dart` (check if exists; create if not, following patterns from `test/report_cadence_service_test.dart`)

**Interfaces:**
- Consumes: `TimeTotals` (Task 6), `DailyLog.totalEvangelismMinutes`/`totalChurchMinutes` (Task 2), `DailyLog.proclamationSessions` (Task 1).
- Produces: updated `reportBible` ARB placeholder signature (gains a duration parameter), new `reportEvangelismSessions`/`reportChurchSessions` ARB strings for the session-aware rendering path, new `reportProclamationSessions` ARB string for multi-topic rendering.

- [ ] **Step 1: Add/update ARB strings**

In `lib/l10n/app_en.arb`, find `reportBible` and update its placeholder structure to add a duration parameter (check the existing `@reportBible` metadata block for the exact current placeholder names before editing — likely `reference` and `chapters`). Update to:

```json
"reportBible": "{reference} ({chapters} chapters, {duration})",
"@reportBible": {
  "placeholders": {
    "reference": { "type": "String" },
    "chapters": { "type": "String" },
    "duration": { "type": "String" }
  }
}
```

If the original didn't have a `duration` placeholder, this is a breaking signature change to the generated `S.reportBible(...)` method — every call site must be updated in Step 2. Add a fallback-safe variant instead if you'd rather not touch the existing 2-arg signature: add a **new** key `reportBibleWithDuration` instead of modifying `reportBible`, and call the new one only when `log.bibleDuration.isNotEmpty`, keeping `reportBible` as todav for logs with no duration:

```json
"reportBibleWithDuration": "{reference} ({chapters} chapters, {duration})",
"@reportBibleWithDuration": {
  "placeholders": {
    "reference": { "type": "String" },
    "chapters": { "type": "String" },
    "duration": { "type": "String" }
  }
}
```

(Prefer the additive approach — less risk of missing a call site.) Add matching French translation to `app_fr.arb`.

Add new session-aware report strings:

```json
"reportEvangelismSessions": "Evangelism: {sessionCount} sessions, {duration} total",
"@reportEvangelismSessions": {
  "placeholders": {
    "sessionCount": { "type": "String" },
    "duration": { "type": "String" }
  }
},
"reportChurchSessions": "{sessionCount} sessions, {duration} total",
"@reportChurchSessions": {
  "placeholders": {
    "sessionCount": { "type": "String" },
    "duration": { "type": "String" }
  }
}
```

French equivalents in `app_fr.arb`:

```json
"reportEvangelismSessions": "Évangélisation : {sessionCount} séances, {duration} au total",
"reportChurchSessions": "{sessionCount} séances, {duration} au total"
```

Run: `flutter pub get` to regenerate.

- [ ] **Step 2: Update Bible report line in both `buildMonthlyReport` and `buildFullReport`**

In `lib/services/report_service.dart`, at the monthly-loop Bible block (around line 408-410 per the extraction):

```dart
      final bibleRef = log.combinedBibleReference(l.localeName);
      if (bibleRef.isNotEmpty || log.totalBibleChapters > 0) {
        final ref = bibleRef.isNotEmpty ? bibleRef : log.bibleReference;
        final chapters = '${log.totalBibleChapters}';
        if (log.bibleDuration.isNotEmpty) {
          buf.writeln('📖 ${l.reportBibleWithDuration(ref, chapters, log.bibleDuration)}');
        } else {
          buf.writeln('📖 ${l.reportBible(ref, chapters)}');
        }
      }
```

Apply the identical change at the weekly-loop Bible block (around line 573-576).

- [ ] **Step 3: Update Evangelism/Church lines to be session-aware in both report builders**

At the monthly-loop Evangelism block (lines 416-427), change the opening condition and first line:

```dart
      final hasEvangelismData = log.evangelismContacts.isNotEmpty || log.evangelismSessions.isNotEmpty;
      if (hasEvangelismData) {
        if (log.evangelismSessions.isNotEmpty) {
          final mins = log.totalEvangelismMinutes;
          final durationStr = mins >= 60 ? '${mins ~/ 60}h ${mins % 60}min' : '${mins}min';
          buf.writeln('📢 ${l.reportEvangelismSessions('${log.evangelismSessions.length}', durationStr)}');
        } else if (log.evangelismContacts.isNotEmpty) {
          buf.writeln('📢 ${l.reportEvangelism(log.evangelismContacts, log.evangelismOutcome, log.evangelismNotes)}');
        }
        if (log.evangelismNewBelievers.isNotEmpty || log.evangelismBeingDiscipled.isNotEmpty) {
          final parts = <String>[];
          if (log.evangelismNewBelievers.isNotEmpty) parts.add('${l.evangelismNewBelievers}: ${log.evangelismNewBelievers}');
          if (log.evangelismBeingDiscipled.isNotEmpty) parts.add('${l.evangelismBeingDiscipled}: ${log.evangelismBeingDiscipled}');
          buf.writeln('   🌱 ${parts.join(' | ')}');
        }
        if (log.evangelismFollowUpNotes.isNotEmpty) {
          buf.writeln('   📝 ${log.evangelismFollowUpNotes}');
        }
      }
```

Apply the identical restructure at the weekly-loop block (lines 583-594).

At the monthly-loop Church block (lines 438-440):

```dart
      if (log.churchType.isNotEmpty || log.churchSessions.isNotEmpty) {
        if (log.churchSessions.isNotEmpty) {
          final mins = log.totalChurchMinutes;
          final durationStr = mins >= 60 ? '${mins ~/ 60}h ${mins % 60}min' : '${mins}min';
          buf.writeln('⛪ ${l.reportChurchSessions('${log.churchSessions.length}', durationStr)}');
        } else {
          buf.writeln('⛪ ${l.reportChurch(log.churchType, log.churchNotes)}');
        }
      }
```

Apply identically at the weekly-loop block (lines 605-607).

- [ ] **Step 4: Update Proclamation line to list topics in both report builders**

At the monthly-loop Proclamation block (lines 444-446):

```dart
      if (log.proclamationSessions.isNotEmpty) {
        final parts = log.proclamationSessions.map((s) {
          final label = s.topic.isNotEmpty ? s.topic : l.sectionProclamation;
          final dur = s.duration.isNotEmpty ? s.duration : '-';
          return '$label (${s.count}x, $dur)';
        }).join(', ');
        buf.writeln('📣 $parts');
      } else if (log.proclamationCount.isNotEmpty) {
        buf.writeln('📣 ${l.reportProclamation(log.proclamationCount, log.proclamationDuration.isNotEmpty ? log.proclamationDuration : "-")}');
      }
```

Apply identically at the weekly-loop block (lines 611-613).

- [ ] **Step 5: Remove `givingDuration` from any report text (verify it wasn't already shown)**

Grep to confirm `givingDuration` isn't rendered anywhere in report_service.dart's per-day text blocks:

```bash
grep -n "givingDuration" lib/services/report_service.dart
```

Per the earlier investigation, `givingDuration` was never shown per-day (only fed the removed aggregate in Task 6) — if this grep returns nothing beyond what Task 6 already removed, no further change needed here. If it does appear in the giving report line, remove it from the interpolation.

- [ ] **Step 6: Write/update tests**

Add to `test/report_service_test.dart` (create following `test/report_cadence_service_test.dart`'s setup pattern if this file doesn't exist):

```dart
test('buildFullReport shows Bible duration per-day when present', () async {
  // Arrange a DailyLog with bibleDuration set, save it, call buildFullReport,
  // assert the returned string contains the duration text.
});

test('buildFullReport shows session-aware evangelism line when sessions exist', () async {
  // Arrange a log with evangelismSessions, assert the report contains
  // the session-count/duration text, not the old contacts-only line.
});

test('buildFullReport lists each proclamation topic separately', () async {
  // Arrange a log with two ProclamationSessions with different topics,
  // assert both topic labels appear in the output.
});
```

(Exact assertions depend on reading the actual current test file structure and `S`/localization instantiation pattern used elsewhere in this repo's tests — mirror it precisely.)

- [ ] **Step 7: Run tests**

Run: `flutter test && flutter analyze`
Expected: All pass.

- [ ] **Step 8: Commit**

```bash
git add lib/services/report_service.dart lib/l10n/app_en.arb lib/l10n/app_fr.arb test/report_service_test.dart
git commit -m "fix: show bible duration per-day, session-aware evangelism/church/proclamation report lines"
```

---

## Phase D — Giving/Tithe duration field removal

### Task 8: Remove the time-conscious duration field from the Giving & Tithes section

**Files:**
- Modify: `lib/screens/log_screen.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: no behavioral interface change — purely UI removal. `DailyLog.givingDuration` field itself stays in the model (per Global Constraints — legacy field retained, just no longer written).

- [ ] **Step 1: Remove the duration field from the Giving & Tithes SectionCard**

In `lib/screens/log_screen.dart`, remove the `if (_timeConscious) GoldField(...)` block for `givingDuration` (lines 1230-1236 per the extraction):

```dart
            GoldField(
              label: t.givingPurposeLabel,
              hint: t.givingPurposeHint,
              value: _log.givingPurpose,
              onChanged: (v) { _log.givingPurpose = v; _persist(); },
            ),
          ],
        ).animate().fadeIn(delay: 360.ms),
```

(i.e. delete the `if (_timeConscious) GoldField(...)` block entirely, leaving the `givingPurpose` field as the last child before the closing `],`.)

- [ ] **Step 2: Verify no other UI writes to `givingDuration`**

```bash
grep -rn "givingDuration" lib/
```

Confirm the only remaining references are: the model field declaration/toMap/fromMap (kept per constraints), and the storage_service.dart column definition (kept). If `settings_screen.dart` or any other screen also surfaces it, remove that too — the earlier investigation found only this one UI location.

- [ ] **Step 3: Manual verification**

Run: `flutter analyze`
Expected: Clean.

Run the app, enable time-conscious mode in Settings, open the Log screen's Giving & Tithes section — verify no duration field appears (only type/amount/purpose).

- [ ] **Step 4: Commit**

```bash
git add lib/screens/log_screen.dart
git commit -m "fix: remove unnecessary duration field from Giving and Tithes section"
```

---

## Phase E — Android widget: daily reset + customizable title

### Task 9: Add date-aware reset to the proclamation widget counter

**Files:**
- Modify: `android/app/src/main/kotlin/com/jilengineering/dailyaccount/ProclamationWidgetProvider.kt`
- Modify: `lib/screens/home_shell.dart`

**Interfaces:**
- Consumes: existing `WidgetHelper.getWidgetPrefs(context)` (Kotlin, existing), existing `HomeWidget.saveWidgetData`/`getWidgetData` (Dart, existing).
- Produces: new SharedPreferences key `proclamation_date` (String, `yyyy-MM-dd`), written by `home_shell.dart` alongside `proclamation_count`, read by `ProclamationWidgetProvider.kt`'s `incrementCount()` to decide whether to reset the counter to 1 instead of incrementing.

- [ ] **Step 1: Update `home_shell.dart` to write the date key alongside the count**

In `lib/screens/home_shell.dart`, find the block that writes `proclamation_count` (around line 679 per the extraction):

```dart
      final dbProcCount = int.tryParse(log?.proclamationCount ?? '0') ?? 0;
      final widgetProcCount = int.tryParse(
          await HomeWidget.getWidgetData<String>('proclamation_count') ?? '0') ?? 0;
      final maxProcCount = dbProcCount > widgetProcCount ? dbProcCount : widgetProcCount;
      await HomeWidget.saveWidgetData('proclamation_count', '$maxProcCount');
      await HomeWidget.saveWidgetData('proclamation_date', _key(DateTime.now()));
```

(`_key(DateTime.now())` reuses the existing `'yyyy-MM-dd'` formatter method already defined in this file, confirmed present via `_key(DateTime.now())` used elsewhere in `_syncWidgetChangesToDb`.)

- [ ] **Step 2: Update `_syncWidgetChangesToDb` to be date-aware**

In the same file, update the proclamation-count sync block (around line 114-121):

```dart
      // Sync proclamation count — only trust the widget's count if it was
      // recorded today; a stale prior-day count must not leak into today's log.
      final widgetProcDate = await HomeWidget.getWidgetData<String>('proclamation_date') ?? '';
      final todayKey = _key(DateTime.now());
      if (widgetProcDate == todayKey) {
        final widgetProcCount = await HomeWidget.getWidgetData<String>('proclamation_count') ?? '0';
        final widgetCount = int.tryParse(widgetProcCount) ?? 0;
        final dbCount = int.tryParse(log.proclamationCount) ?? 0;
        if (widgetCount > dbCount) {
          log.proclamationCount = '$widgetCount';
          changed = true;
        }
      }
```

- [ ] **Step 3: Update `ProclamationWidgetProvider.kt` to reset on a new day**

In `android/app/src/main/kotlin/com/jilengineering/dailyaccount/ProclamationWidgetProvider.kt`, update `incrementCount` (lines 27-37):

```kotlin
    private fun incrementCount(context: Context) {
        val prefs = WidgetHelper.getWidgetPrefs(context)
        val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
            .format(java.util.Date())
        val storedDate = prefs.getString("proclamation_date", "")
        val current = if (storedDate == today) {
            prefs.getString("proclamation_count", "0")?.toIntOrNull() ?: 0
        } else {
            0 // new day — reset before incrementing
        }
        val newCount = current + 1
        prefs.edit()
            .putString("proclamation_count", "$newCount")
            .putString("proclamation_date", today)
            .apply()

        // Refresh all proclamation widgets
        WidgetHelper.updateAllWidgets(context, ProclamationWidgetProvider::class.java)
        // Also refresh Full Altar widgets (they may show proclamation data)
        WidgetHelper.updateAllWidgets(context, FullAltarWidgetProvider::class.java)
    }
```

Also update the display-read site in `onUpdate` (around line 51-52) to show 0 for a stale date rather than the raw stored count:

```kotlin
                val storedDate = widgetData.getString("proclamation_date", "")
                val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
                    .format(java.util.Date())
                val count = if (storedDate == today) {
                    widgetData.getString("proclamation_count", "0") ?: "0"
                } else {
                    "0"
                }
                views.setTextViewText(R.id.proclamation_count, count)
```

- [ ] **Step 4: Manual verification**

This requires an on-device/emulator test since it's native Android code with no Dart unit test coverage:

Run: `flutter build apk --debug` to confirm the Kotlin compiles cleanly as part of the build.

On a device/emulator: add the Proclamation widget to the home screen, tap "+" a few times, confirm the count increases. Manually change the device date forward by one day (Settings → Date & Time → disable automatic, set to tomorrow), tap "+" again, confirm the widget shows `1` (not `previous_count + 1`). Restore automatic date/time afterward.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/jilengineering/dailyaccount/ProclamationWidgetProvider.kt lib/screens/home_shell.dart
git commit -m "fix: proclamation widget counter resets at midnight instead of persisting stale count"
```

---

### Task 10: Customizable widget title setting

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/screens/home_shell.dart`
- Modify: `android/app/src/main/kotlin/com/jilengineering/dailyaccount/WidgetHelper.kt`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`

**Interfaces:**
- Consumes: `StorageService.instance.getSetting`/`setSetting` (existing), `HomeWidget.saveWidgetData` (existing).
- Produces: new setting key `widgetTitle` (String, SharedPreferences via `StorageService`), pushed to `HomeWidgetPreferences` as `widget_title`, read by `WidgetHelper.getScripture()` in place of the hardcoded `R.string.widget_proclamation_text` resource when non-empty.

- [ ] **Step 1: Add ARB strings**

In `lib/l10n/app_en.arb`:

```json
"widgetTitleSection": "Home Widget",
"widgetTitleLabel": "Proclamation Title",
"widgetTitleHint": "e.g. Jesus Christ is the Lord",
"widgetTitleDescription": "Customize the declaration shown on your home-screen widget."
```

French in `app_fr.arb`:

```json
"widgetTitleSection": "Widget d'accueil",
"widgetTitleLabel": "Titre de la proclamation",
"widgetTitleHint": "ex. Jésus-Christ est le Seigneur",
"widgetTitleDescription": "Personnalisez la déclaration affichée sur votre widget d'écran d'accueil."
```

Run: `flutter pub get`.

- [ ] **Step 2: Add the setting field + UI section to Settings screen**

In `lib/screens/settings_screen.dart`, add a state var near `_email`/`_whatsapp` (around line 30):

```dart
  String _widgetTitle = '';
```

In the `_load()` method (wherever `_email`/`_whatsapp` are loaded, near line 88), add:

```dart
    _widgetTitle = await s.getSetting('widgetTitle');
```

Add a new `SectionCard` — place it near the existing Disciple Maker section (after line 865):

```dart
        // ── Home Widget ──
        SectionCard(icon: '\u{1F3E0}', title: l.widgetTitleSection, children: [
          GoldField(
            label: l.widgetTitleLabel,
            hint: l.widgetTitleHint,
            value: _widgetTitle,
            onChanged: (v) async {
              _widgetTitle = v;
              await StorageService.instance.setSetting('widgetTitle', v);
              await HomeWidget.saveWidgetData('widget_title', v);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              l.widgetTitleDescription,
              style: AppTheme.serif(11, color: AppTheme.mutedColor(context).withValues(alpha: 0.7)),
            ),
          ),
        ]),
```

Add `import 'package:home_widget/home_widget.dart';` to the top of `settings_screen.dart` if not already imported (check the existing import list first).

- [ ] **Step 3: Push the current value to the widget on app startup**

In `lib/screens/home_shell.dart`, in `_updateHomeWidget` (near the `ddeg_scripture` push at line 682-683), add:

```dart
      final widgetTitle = await StorageService.instance.getSetting('widgetTitle');
      if (widgetTitle.isNotEmpty) {
        await HomeWidget.saveWidgetData('widget_title', widgetTitle);
      }
```

- [ ] **Step 4: Update `WidgetHelper.kt` to prefer the custom title**

In `android/app/src/main/kotlin/com/jilengineering/dailyaccount/WidgetHelper.kt`, update `getScripture()` (lines 92-97) to check for a custom title first:

```kotlin
        // Afternoon/evening → proclamation
        if (hour in 12..21) {
            val customTitle = widgetData.getString("widget_title", "") ?: ""
            val text = if (customTitle.isNotEmpty()) {
                customTitle
            } else {
                getLocalizedString(context, locale, R.string.widget_proclamation_text)
            }
            val label = getLocalizedString(context, locale, R.string.widget_proclamation_label)
            return Triple(text, "", label)
        }
```

- [ ] **Step 5: Manual verification**

Run: `flutter analyze` and `flutter build apk --debug` to confirm both Dart and Kotlin compile.

On-device: set a custom widget title in Settings, background the app, check the home-screen widget between 12:00-21:00 device time shows the custom text instead of the default. Clear the setting, confirm it falls back to the default hardcoded string.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/settings_screen.dart lib/screens/home_shell.dart android/app/src/main/kotlin/com/jilengineering/dailyaccount/WidgetHelper.kt lib/l10n/app_en.arb lib/l10n/app_fr.arb
git commit -m "feat: make home-widget proclamation title customizable in Settings"
```

---

## Phase F — Auto-send channel configuration (WhatsApp / Gmail / Both)

### Task 11: Extend Google Sign-In with `gmail.send` scope and add a silent Gmail send method

**Files:**
- Modify: `lib/services/cloud_sync_service.dart`
- Test: manual (OAuth flows can't be meaningfully unit-tested without live Google infrastructure — see Step 4)

**Interfaces:**
- Consumes: `google-services.json` already in place at `android/app/google-services.json` (confirmed present, registered against `com.jilengineering.dailyaccount` with both release/debug SHA-1s, `gmail.send` scope already added to the OAuth consent screen's Data Access config — done during brainstorming).
- Produces: `CloudSyncService.instance.sendEmailSilently({required String toEmail, required String subject, required String body}) -> Future<bool>`, `CloudSyncService.instance.hasGmailSendScope -> Future<bool>` (checks whether the current sign-in grant includes `gmail.send`, since the existing Drive-only scope list won't include it for already-signed-in users until they re-consent).

- [ ] **Step 1: Add the `gmail.send` scope**

In `lib/services/cloud_sync_service.dart`, update the `GoogleSignIn` scopes list (lines 20-22):

```dart
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
      'https://www.googleapis.com/auth/gmail.send',
    ],
  );
```

- [ ] **Step 2: Add `hasGmailSendScope` and `sendEmailSilently`**

Add `import 'package:googleapis/gmail/v1.dart' as gmail;` and `import 'dart:convert';` (for base64url encoding the MIME message) to the top of the file if not already present.

Add these methods, following the same `authHeaders` → `_GoogleAuthClient` → typed API client pattern already used for `_getDriveApi()` (the file's existing Drive API construction, per the earlier extraction lines 76-103):

```dart
  /// Whether the current sign-in grant includes the gmail.send scope.
  /// Users who signed in before this scope was added will need to
  /// re-authenticate (call signIn() again) to grant it.
  Future<bool> hasGmailSendScope() async {
    if (_currentUser == null) return false;
    try {
      return await _googleSignIn.canAccessScopes(
        ['https://www.googleapis.com/auth/gmail.send'],
      );
    } catch (_) {
      return false;
    }
  }

  /// Send an email fully silently via the Gmail API — no external app
  /// opens, unlike the mailto:-based sendByEmail in ReportService.
  Future<bool> sendEmailSilently({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    if (_currentUser == null) {
      final restored = await silentSignIn();
      if (!restored) return false;
    }
    try {
      final headers = await _currentUser!.authHeaders;
      final client = _GoogleAuthClient(headers);
      final gmailApi = gmail.GmailApi(client);

      final message = _buildMimeMessage(
        from: _currentUser!.email,
        to: toEmail,
        subject: subject,
        body: body,
      );

      await gmailApi.users.messages.send(
        gmail.Message(raw: message),
        'me',
      );
      return true;
    } catch (e, st) {
      dev.log('CloudSync: sendEmailSilently failed: $e', name: 'CloudSync');
      dev.log('$st', name: 'CloudSync');
      return false;
    }
  }

  String _buildMimeMessage({
    required String from,
    required String to,
    required String subject,
    required String body,
  }) {
    final mime = 'From: $from\r\n'
        'To: $to\r\n'
        'Subject: =?UTF-8?B?${base64.encode(utf8.encode(subject))}?=\r\n'
        'MIME-Version: 1.0\r\n'
        'Content-Type: text/plain; charset="UTF-8"\r\n\r\n'
        '$body';
    return base64Url.encode(utf8.encode(mime)).replaceAll('=', '');
  }
```

(`_GoogleAuthClient` is the existing private `http.BaseClient` subclass already defined at the bottom of this file per the earlier extraction, lines 252-269 — reused here exactly as `_getDriveApi()` does.)

- [ ] **Step 3: Run analyzer**

Run: `flutter analyze`
Expected: Clean. (`googleapis: ^13.2.0` already includes `gmail/v1.dart` — no pubspec change needed, confirmed from pubspec.yaml read during planning.)

- [ ] **Step 4: Manual verification**

This cannot be meaningfully unit-tested without a live Google account and network access. On-device: sign in with Google in Settings' Cloud Backup section (this will now also prompt for the Gmail send permission since the scope list changed — existing signed-in users will need to re-authenticate once). Call `sendEmailSilently` with a real address (e.g. your own) via a temporary debug button or by wiring it into Task 12 before final verification, confirm the email arrives without any external app opening.

- [ ] **Step 5: Commit**

```bash
git add lib/services/cloud_sync_service.dart
git commit -m "feat: extend Google Sign-In with gmail.send scope, add silent email send"
```

---

### Task 12: Add `autoSendChannel` setting with validation-gated UI

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`

**Interfaces:**
- Consumes: `CloudSyncService.instance.isSignedIn`, `CloudSyncService.instance.hasGmailSendScope()` (Task 11), `StorageService.instance.getSetting`/`setSetting`.
- Produces: setting key `autoSendChannel` (String: `'whatsapp'` | `'email'` | `'both'`, default `'whatsapp'`).

- [ ] **Step 1: Add ARB strings**

```json
"autoSendChannelLabel": "Send via",
"autoSendChannelWhatsApp": "WhatsApp",
"autoSendChannelEmail": "Email",
"autoSendChannelBoth": "Both",
"autoSendEmailDisabledHint": "Connect Google & set a valid email to enable"
```

French equivalents added to `app_fr.arb`.

- [ ] **Step 2: Add state and validation to `settings_screen.dart`**

Add state vars near `_autoSendEnabled` (around line 35):

```dart
  String _autoSendChannel = 'whatsapp';
  bool _gmailSendReady = false;
```

In `_load()`, add:

```dart
    _autoSendChannel = await s.getSetting('autoSendChannel', fallback: 'whatsapp');
    _gmailSendReady = CloudSyncService.instance.isSignedIn &&
        await CloudSyncService.instance.hasGmailSendScope();
```

(Add `import 'services/cloud_sync_service.dart';` if not already imported — check existing imports first, since the Cloud Sync section of this screen likely already imports it.)

Add an email-validity check helper (private method):

```dart
  bool get _hasValidEmail {
    final email = _email.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  bool get _canUseEmailChannel => _hasValidEmail && _gmailSendReady;
```

- [ ] **Step 3: Add the channel picker UI to the Auto-Send section**

In the Auto-Send `SectionCard` (lines 1251-1259), add the channel picker after the enabled toggle:

```dart
        SectionCard(icon: '\u{1F4E4}', title: l.autoSendSection, children: [
          _switchRow(l.autoSendEnabled, _autoSendEnabled, _toggleAutoSend),
          if (_autoSendEnabled) ...[
            const SizedBox(height: 8),
            _timeRow(l.autoSendTime, _autoSendTime, _pickAutoSendTime),
            const SizedBox(height: 12),
            Text(l.autoSendChannelLabel.toUpperCase(),
                style: AppTheme.label(11, color: AppTheme.accentGold(context).withValues(alpha: 0.7))),
            const SizedBox(height: 6),
            Row(
              children: [
                _channelButton(l.autoSendChannelWhatsApp, 'whatsapp', enabled: true),
                const SizedBox(width: 8),
                _channelButton(l.autoSendChannelEmail, 'email', enabled: _canUseEmailChannel),
                const SizedBox(width: 8),
                _channelButton(l.autoSendChannelBoth, 'both', enabled: _canUseEmailChannel),
              ],
            ),
            if (!_canUseEmailChannel) ...[
              const SizedBox(height: 6),
              Text(l.autoSendEmailDisabledHint,
                  style: AppTheme.serif(11, color: AppTheme.mutedColor(context))),
            ],
            const SizedBox(height: 8),
            Text(l.autoSendDescription, style: AppTheme.serif(12, color: mutedCol)),
          ],
        ]),
```

Add the `_channelButton` helper (mirrors the existing `_cadencePicker`'s `segButton` shape, lines 1688-1705):

```dart
  Widget _channelButton(String label, String value, {required bool enabled}) {
    final accent = AppTheme.accentGold(context);
    final mutedCol = AppTheme.mutedColor(context);
    final selected = _autoSendChannel == value;
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? () async {
          setState(() => _autoSendChannel = value);
          await StorageService.instance.setSetting('autoSendChannel', value);
        } : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? accent : accent.withValues(alpha: 0.2)),
            ),
            alignment: Alignment.center,
            child: Text(label, style: AppTheme.label(12, color: selected ? accent : mutedCol)),
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 4: Guard against an invalid channel being persisted if email becomes unavailable later**

In `_load()`, right after computing `_gmailSendReady` and `_hasValidEmail`-dependent `_canUseEmailChannel`, add a fallback:

```dart
    if ((_autoSendChannel == 'email' || _autoSendChannel == 'both') && !_canUseEmailChannel) {
      _autoSendChannel = 'whatsapp';
      await s.setSetting('autoSendChannel', 'whatsapp');
    }
```

- [ ] **Step 5: Manual verification**

Run: `flutter analyze`
Expected: Clean.

Run the app: with no Google sign-in and no email set, confirm Email/Both buttons are visibly disabled with the hint text shown. Sign in with Google and set a valid email, confirm they become enabled and selectable.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/settings_screen.dart lib/l10n/app_en.arb lib/l10n/app_fr.arb
git commit -m "feat: add auto-send channel picker (WhatsApp/Email/Both) gated on valid config"
```

---

### Task 13: Generalize the offline pending-report queue to support multiple channels

**Files:**
- Modify: `lib/services/storage_service.dart`
- Modify: `lib/screens/home_shell.dart`
- Test: `test/storage_service_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `StorageService.queuePendingReport({required String fullReport, required String compactReport, required List<String> channels, String? whatsapp, String? email})` (replaces the old 2-positional-arg signature), `StorageService.getPendingReport() -> Map<String, dynamic>?` (now includes a `channels` list and per-channel `sentChannels` tracking), `StorageService.markPendingChannelSent(String channel)`, `StorageService.clearPendingReport()` (unchanged signature, clears only once all channels sent).

- [ ] **Step 1: Write the failing test**

Add to `test/storage_service_test.dart`:

```dart
test('queuePendingReport supports multiple channels, clears only when all sent', () async {
  await StorageService.instance.queuePendingReport(
    fullReport: 'Full report text',
    compactReport: 'Compact report text',
    channels: ['whatsapp', 'email'],
    whatsapp: '1234567890',
    email: 'disciple@example.com',
  );

  var pending = await StorageService.instance.getPendingReport();
  expect(pending, isNotNull);
  expect(pending!['channels'], containsAll(['whatsapp', 'email']));

  await StorageService.instance.markPendingChannelSent('whatsapp');
  pending = await StorageService.instance.getPendingReport();
  expect(pending, isNotNull); // still pending — email not sent yet

  await StorageService.instance.markPendingChannelSent('email');
  pending = await StorageService.instance.getPendingReport();
  expect(pending, isNull); // both channels sent — queue cleared
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/storage_service_test.dart`
Expected: FAIL — current `queuePendingReport(String compactReport, String whatsapp)` signature doesn't match.

- [ ] **Step 3: Rewrite the pending-report queue methods**

In `lib/services/storage_service.dart`, replace `queuePendingReport`/`getPendingReport`/`clearPendingReport` (lines 495-516 per the extraction):

```dart
  /// Queue a report to be sent via one or more channels when connectivity
  /// is available. Persists until every requested channel has succeeded —
  /// no time-based expiry, so a report sends whenever connectivity returns
  /// regardless of how long the device stayed offline.
  Future<void> queuePendingReport({
    required String fullReport,
    required String compactReport,
    required List<String> channels,
    String? whatsapp,
    String? email,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_pendingReportKey, jsonEncode({
      'fullReport': fullReport,
      'compactReport': compactReport,
      'channels': channels,
      'sentChannels': <String>[],
      if (whatsapp != null) 'whatsapp': whatsapp,
      if (email != null) 'email': email,
      'queuedAt': DateTime.now().toIso8601String(),
    }));
  }

  /// Get the pending report (null if none queued or all channels sent).
  Future<Map<String, dynamic>?> getPendingReport() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_pendingReportKey);
    if (raw == null || raw.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  /// Mark one channel as successfully sent. Clears the whole queue entry
  /// once every requested channel has been sent.
  Future<void> markPendingChannelSent(String channel) async {
    final pending = await getPendingReport();
    if (pending == null) return;
    final sent = List<String>.from(pending['sentChannels'] as List? ?? []);
    if (!sent.contains(channel)) sent.add(channel);
    final channels = List<String>.from(pending['channels'] as List? ?? []);
    if (channels.every((c) => sent.contains(c))) {
      await clearPendingReport();
      return;
    }
    pending['sentChannels'] = sent;
    final p = await SharedPreferences.getInstance();
    await p.setString(_pendingReportKey, jsonEncode(pending));
  }

  /// Clear the pending report entirely (all channels considered done).
  Future<void> clearPendingReport() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_pendingReportKey);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/storage_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Update call sites in `home_shell.dart`**

In `lib/screens/home_shell.dart`, add `import 'services/cloud_sync_service.dart';` if not already present, then rewrite `_trySendPending()` (lines 342-359) to use the new multi-channel API. The email subject reuses the exact localized expression from `report_service.dart:749-752` (`l.reportEmailSubject(name, date)`), computed once per call rather than per channel:

```dart
  /// Retry sending any still-pending report channels (from a previous
  /// offline attempt). Retries whichever channels haven't succeeded yet.
  Future<void> _trySendPending() async {
    final s = StorageService.instance;
    final pending = await s.getPendingReport();
    if (pending == null) return;

    if (!await _hasConnectivity()) return; // still offline, try next time

    final channels = List<String>.from(pending['channels'] as List? ?? []);
    final sentChannels = List<String>.from(pending['sentChannels'] as List? ?? []);
    final compactReport = pending['compactReport'] as String;
    final fullReport = pending['fullReport'] as String;
    final name = await s.getSetting('myName');
    final l = await _getReportLocalizations();
    final subject = '📖 ${l.reportEmailSubject(
      name.isEmpty ? "Disciple" : name,
      DateFormat('MMM d, y', l.localeName).format(DateTime.now()),
    )}';

    for (final channel in channels) {
      if (sentChannels.contains(channel)) continue;
      bool ok = false;
      if (channel == 'whatsapp') {
        final whatsapp = pending['whatsapp'] as String? ?? '';
        if (whatsapp.isNotEmpty) {
          ok = await ReportService.instance.sendByWhatsApp(whatsapp, compactReport);
        }
      } else if (channel == 'email') {
        final email = pending['email'] as String? ?? '';
        if (email.isNotEmpty) {
          ok = await CloudSyncService.instance.sendEmailSilently(
            toEmail: email,
            subject: subject,
            body: fullReport,
          );
        }
      }
      if (ok) {
        await s.markPendingChannelSent(channel);
        final periodKey = await ReportCadenceService.instance.currentPeriodKey();
        await s.setSetting('lastAutoSend', periodKey);
      }
    }
    _checkPendingReport();
  }
```

Rewrite `_checkAutoSend()`'s send portion (lines 384-440, i.e. everything from where `name`/`l` are computed through the end of the method) to branch per configured channel and queue whichever fail. The method already computes `name` (line 390) and `l` (line 392) before this point — reuse those bindings rather than recomputing:

```dart
    final subject = '📖 ${l.reportEmailSubject(
      name.isEmpty ? "Disciple" : name,
      DateFormat('MMM d, y', l.localeName).format(DateTime.now()),
    )}';
    final channelSetting = await s.getSetting('autoSendChannel', fallback: 'whatsapp');
    final channels = channelSetting == 'both' ? ['whatsapp', 'email'] : [channelSetting];
    final email = await s.getSetting('discipleEmail');

    // Check connectivity
    if (!await _hasConnectivity()) {
      // Queue for later
      await s.queuePendingReport(
        fullReport: fullReport,
        compactReport: compactReport,
        channels: channels,
        whatsapp: whatsapp,
        email: email,
      );
      return;
    }

    // Send now — use the full detailed report for both channels
    final sentChannels = <String>[];
    for (final channel in channels) {
      bool ok = false;
      if (channel == 'whatsapp') {
        ok = await ReportService.instance.sendByWhatsApp(whatsapp, fullReport);
      } else if (channel == 'email' && email.isNotEmpty) {
        ok = await CloudSyncService.instance.sendEmailSilently(
          toEmail: email,
          subject: subject,
          body: fullReport,
        );
      }
      if (ok) sentChannels.add(channel);
    }

    if (sentChannels.isNotEmpty) {
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
        sentVia: sentChannels.join(' + '),
      );
    }

    final failedChannels = channels.where((c) => !sentChannels.contains(c)).toList();
    if (failedChannels.isNotEmpty) {
      await s.queuePendingReport(
        fullReport: fullReport,
        compactReport: compactReport,
        channels: failedChannels,
        whatsapp: whatsapp,
        email: email,
      );
    }
```

This preserves the original archive-saving logic (unchanged from lines 416-436 of the source) but gates it on `sentChannels.isNotEmpty` instead of the old single `ok` bool, and records which channels actually succeeded in `sentVia` instead of the hardcoded `'whatsapp (auto)'` string.

- [ ] **Step 6: Run tests**

Run: `flutter test && flutter analyze`
Expected: All pass.

- [ ] **Step 7: Manual verification**

Enable auto-send with "Both" channels configured, a valid WhatsApp number and email, Google signed in. Trigger conditions to fire `_checkAutoSend` (or temporarily lower the auto-send time check for testing). Turn off network before the send fires, confirm the report queues; turn network back on, confirm both channels send on the next `_trySendPending` call (app resume) and the queue clears.

- [ ] **Step 8: Commit**

```bash
git add lib/services/storage_service.dart lib/screens/home_shell.dart test/storage_service_test.dart
git commit -m "feat: generalize offline report queue to support multiple send channels"
```

---

## Phase G — Final verification

### Task 14: Full-suite regression pass

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: All tests pass, including pre-existing tests (`test/activity_timer_test.dart`, `test/report_cadence_service_test.dart`) and all tests added in this plan.

- [ ] **Step 2: Run the analyzer**

Run: `flutter analyze`
Expected: Zero issues.

- [ ] **Step 3: Manual end-to-end walkthrough**

Run the app (`flutter run`) and verify, in order:
1. Start and stop a Bible reading timer twice in one day — confirm the report shows the accumulated duration per-day (not just in a hidden aggregate).
2. Start a Proclamation timer, enter topic "Healing", stop it. Start another, pick "Healing" from recents, stop it. Confirm the report shows one "Healing" entry with count 2, not two separate entries.
3. Confirm Fasting no longer appears as a stopwatch tile, and the existing multi-day fasting tracker in the Log screen still works.
4. Start/stop an Evangelism timer twice — confirm the report shows "2 sessions, X min total".
5. Open Log screen, enable time-conscious mode, confirm no duration field appears under Giving & Tithes.
6. In Settings, confirm the report cadence picker reflects a non-Sunday day if changed, and the reminder title text updates accordingly.
7. Configure auto-send to "Both", confirm Email option only enables with a valid email + Google sign-in.
8. On the home-screen widget, confirm the title reflects a custom setting if configured, and the proclamation count resets after a simulated day change.

- [ ] **Step 4: No commit for this task** — it's verification-only. If any issue is found, return to the relevant task above, fix, and commit there.
