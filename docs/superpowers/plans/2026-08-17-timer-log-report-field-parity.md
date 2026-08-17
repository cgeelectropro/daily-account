# Timer/Log/Report Field Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Stopwatch timer a first-class way of filling in the Log screen — every field the Log screen shows for an activity gets a corresponding timer prompt (placed at Start or Stop based on when the value is genuinely knowable), every timer completion writes into the same structured session model the Log screen displays (never a parallel legacy scalar), Prayer Alone/Prayer-with-Others gain topic-based multi-session support matching Proclamation's existing pattern, Giving becomes a multi-entry list, and Proclamation's tap-to-count interaction is restored.

**Architecture:** Extend `PrayerSession` with a `title` field and `PrayerSession`-with-others with an additional `peopleCount` field, reusing `ProclamationSession.findMatchingIndex`'s topic-matching pattern (generalized into a shared mixin/static helper). Convert `DailyLog`'s four Giving scalars into `List<GivingEntry>` mirroring the existing `List<LiteratureEntry>` pattern. Restructure `TimerService._writeToDailyLog` so Bible/DDEG/Prayer-Alone/Prayer-Others append into their real session lists (mirroring how Proclamation/Evangelism/Church already do), retire the literature `_mergeLogField` no-ops by writing a real `LiteratureEntry`. Rework `stopwatch_screen.dart`'s per-activity Start/Stop prompts per the spec's table. Restore the tap-to-count Proclamation UI. Extend every report/consistency consumer identically for the newly-titled Prayer sessions and the Giving list, using one shared "has session data OR has legacy scalar" pattern.

**Tech Stack:** Flutter/Dart, sqflite (SQLite, DB version 13 → 14), existing `intl`/ARB localization.

**Spec:** `docs/superpowers/specs/2026-08-17-timer-log-report-field-parity-design.md`

## Global Constraints

- The timer is not a separate input path — it writes into the exact same model the Log screen displays and edits. No new legacy scalar writes anywhere in this plan; new writes always target the real structured field.
- Legacy scalar fields already in the model (`prayerAloneNotes`/`prayerAloneDuration`, `prayerOthersContext`/`prayerOthersDuration`, `givingType`/`givingAmount`/`givingPurpose`, `literatureDuration`, etc.) are never deleted — only new writes stop targeting them, matching this codebase's established deprecation convention.
- Every new SQLite column is added in both the `CREATE TABLE logs` block (fresh installs) and a new `if (oldVersion < N)` block in `onUpgrade` (existing installs). Current DB version is 13 — this plan bumps it to 14.
- Any legacy→session migration written in this plan must be idempotent from the start: the scalar is cleared on the object returned by `fromMap` once migrated, so a second `getLog`→`saveLog` round-trip never re-persists a superseded scalar. This exact bug was found and fixed for `ProclamationSession`'s migration in a prior plan (see `daily_log.dart:628-643`) — do not repeat it.
- Topic/title matching everywhere in this plan (Prayer Alone, Prayer with Others) is case-insensitive and trimmed, using the exact same rule as `ProclamationSession.findMatchingIndex` (`daily_log.dart:183-187`).
- Required-field validation (both at Start and at Stop) keeps the action button (Start/Save) always tappable; an inline error appears under the empty required field; nothing persists/starts until fixed. This mirrors the existing pattern in `_showBibleEndDialog`/`_showLiteratureEndDialog` for structuring a stop-time dialog, extended with actual validation (those dialogs currently have no required-field enforcement — this plan adds it).
- Both `report_service.dart` report builders (`buildMonthlyReport` and `buildFullReport`) contain near-duplicate per-day rendering logic and must receive identical treatment for every change — this is a standing, previously-confirmed trap in this codebase.
- Every "does this day have X" check for a changed field must be updated everywhere it's duplicated: `DailyLog.completeness`, `ReportService._disciplineChecks`, `ReportService.buildCompactReport`'s per-day summary loop, `pdf_report_service.dart`, `goal_progress_service.dart`, `report_intelligence_service.dart`, `reflection_service.dart`. A prior plan's final review found exactly this class of gap in four files after individual tasks each fixed only the file they touched — this plan requires an explicit cross-file audit as its own task, not an incidental side effect.
- `flutter analyze` must stay clean after every task. Full test suite via `flutter test --concurrency=1` (this environment has confirmed flakiness in `test/app_theme_test.dart` under default concurrency, unrelated to any code in this plan — use `--concurrency=1` to avoid false failures, or verify a suspicious failure in isolation before treating it as real).
- Any implementer whose task touches a file another task in this plan also touches must re-read the current state of that file before editing — do not trust this plan's quoted line numbers if an earlier task in the same plan has already landed and shifted them. Where this plan quotes exact code, it was verified against the actual file at planning time; still confirm before editing since multiple tasks in this plan touch the same files sequentially.

---

## Phase A — Data model foundation

### Task 1: Add `title` to `PrayerSession`, add `peopleCount`, generalize the topic-matching helper

**Files:**
- Modify: `lib/models/daily_log.dart`
- Test: `test/daily_log_test.dart`

**Interfaces:**
- Produces: `PrayerSession.title` (String, default `''`), `PrayerSession.peopleCount` (String, default `''` — kept as a string like other numeric-ish fields in this model, e.g. `evangelismContacts`, for consistent free-text-friendly display); a generalized static topic-matching helper usable by both `ProclamationSession` and `PrayerSession`.

- [ ] **Step 1: Write the failing test**

Read the current `test/daily_log_test.dart` first to see existing test group conventions (there should already be `group('ProclamationSession', ...)` and `group('DailyLog proclamation totals', ...)` blocks from a prior plan — mirror their style exactly). Add:

```dart
  group('PrayerSession title', () {
    test('toMap/fromMap round-trip includes title and peopleCount', () {
      final s = PrayerSession(title: 'Healing for Mom', duration: '15min', notes: 'Felt peace', peopleCount: '3');
      final restored = PrayerSession.fromMap(s.toMap());
      expect(restored.title, 'Healing for Mom');
      expect(restored.peopleCount, '3');
    });

    test('findMatchingIndex finds a case-insensitive trimmed title match', () {
      final sessions = [PrayerSession(title: 'Healing for Mom', duration: '10min')];
      final idx = PrayerSession.findMatchingIndex(sessions, '  healing FOR MOM  ');
      expect(idx, 0);
    });

    test('findMatchingIndex returns -1 when no title matches', () {
      final sessions = [PrayerSession(title: 'Healing for Mom', duration: '10min')];
      final idx = PrayerSession.findMatchingIndex(sessions, 'General intercession');
      expect(idx, -1);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/daily_log_test.dart`
Expected: FAIL — `PrayerSession` has no `title`/`peopleCount` constructor params, no `findMatchingIndex` static method.

- [ ] **Step 3: Implement**

In `lib/models/daily_log.dart`, replace the current `PrayerSession` class (lines 128-147) with:

```dart
/// A single prayer session (used for both Prayer Alone and Prayer With
/// Others). `title` is the burden/subject a session is filed under —
/// multiple same-day sessions with the same title (case-insensitive,
/// trimmed) merge into one via `findMatchingIndex`, mirroring
/// `ProclamationSession`'s topic-matching rule exactly.
class PrayerSession {
  String title;
  String duration;
  String notes; // for alone: reflection; for others: unused, superseded by title
  String peopleCount; // Prayer with Others only; optional headcount

  PrayerSession({
    this.title = '',
    this.duration = '',
    this.notes = '',
    this.peopleCount = '',
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'duration': duration,
    'notes': notes,
    'peopleCount': peopleCount,
  };

  factory PrayerSession.fromMap(Map<String, dynamic> m) => PrayerSession(
    title: m['title'] ?? '',
    duration: m['duration'] ?? '',
    notes: m['notes'] ?? '',
    peopleCount: m['peopleCount'] ?? '',
  );

  bool get isEmpty => title.isEmpty && duration.isEmpty && notes.isEmpty && peopleCount.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Find the index of an existing same-day session whose title matches
  /// [title] (case-insensitive, trimmed), or -1 if none exists. Same
  /// matching rule as `ProclamationSession.findMatchingIndex` — kept as a
  /// parallel static method (not shared via inheritance, since these are
  /// small unrelated data classes) so both call sites read identically.
  static int findMatchingIndex(List<PrayerSession> sessions, String title) {
    final normalizedTitle = title.trim().toLowerCase();
    return sessions.indexWhere(
        (s) => s.title.trim().toLowerCase() == normalizedTitle);
  }
}
```

Note: `notes` stays on the class (used by Prayer Alone as the Stop-time reflection field, per Task 7) but is no longer used by Prayer with Others (which now uses `title` as its primary field, per the spec — `prayerOthersContext`'s role is fully replaced by `title`, not kept as a second field, per the user's explicit confirmation during brainstorming).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/daily_log_test.dart`
Expected: PASS. Note this will also break any EXISTING test in this file that constructs `PrayerSession(notes: ...)` expecting it to represent "who/where" for prayer-with-others — search for such tests and update them to construct with `title:` instead, updating the assertion to match the new field's role, not deleting the test.

- [ ] **Step 5: Update `toMap`/`fromMap` call sites**

Since `PrayerSession`'s field set changed (added `title`/`peopleCount`, kept `notes`), no other code needs to change in this task — `toMap()`/`fromMap()` are used identically. Confirm via `flutter analyze` that no other file constructs `PrayerSession` with a positional argument or a removed named argument (none should — the class only ever had named `duration`/`notes` params, both kept).

- [ ] **Step 6: Run full analyzer**

Run: `flutter analyze`
Expected: Errors will appear at every call site that reads `session.notes` expecting it to mean "who/where" for prayer-with-others — do NOT fix those yet, they're addressed in Task 7 (Log screen UI) and Task 10 (report consumers). If `flutter analyze` shows only warnings/infos (not errors) at this stage, that's expected — Dart doesn't error on an unused-but-still-valid field read. If it shows compile ERRORS (e.g. a removed field being referenced), note them in your report but do not fix files outside this task's scope — those are Task 7/10's job.

- [ ] **Step 7: Commit**

```bash
git add lib/models/daily_log.dart test/daily_log_test.dart
git commit -m "feat: add title/peopleCount to PrayerSession, generalize topic-matching"
```

---

### Task 2: Add `GivingEntry` model, convert `DailyLog.giving` to a list

**Files:**
- Modify: `lib/models/daily_log.dart`
- Test: `test/daily_log_test.dart`

**Interfaces:**
- Consumes: nothing new from Task 1.
- Produces: `class GivingEntry { String type; String amount; String purpose; toMap()/fromMap() }`, `DailyLog.giving: List<GivingEntry>` (mirrors `List<LiteratureEntry>` exactly — defaults to `[GivingEntry()]`, one empty entry, when constructed fresh).

- [ ] **Step 1: Write the failing test**

```dart
  group('GivingEntry', () {
    test('toMap/fromMap round-trip', () {
      final g = GivingEntry(type: 'Tithe', amount: '50000 XAF', purpose: 'General fund');
      final restored = GivingEntry.fromMap(g.toMap());
      expect(restored.type, 'Tithe');
      expect(restored.amount, '50000 XAF');
      expect(restored.purpose, 'General fund');
    });
  });

  group('DailyLog giving list', () {
    test('constructor defaults to one empty GivingEntry', () {
      final log = DailyLog(dateKey: '2026-08-17');
      expect(log.giving.length, 1);
      expect(log.giving.first.type, '');
    });

    test('toMap/fromMap round-trips multiple giving entries', () {
      final log = DailyLog(dateKey: '2026-08-17', giving: [
        GivingEntry(type: 'Tithe', amount: '50000 XAF'),
        GivingEntry(type: 'Offering', amount: '5000 XAF', purpose: 'Missions'),
      ]);
      final restored = DailyLog.fromMap(log.toMap());
      expect(restored.giving.length, 2);
      expect(restored.giving[1].purpose, 'Missions');
    });

    test('migrates legacy givingType/givingAmount/givingPurpose into one GivingEntry, idempotently', () {
      final map = {
        'dateKey': '2026-08-17',
        'givingType': 'Tithe',
        'givingAmount': '50000 XAF',
        'givingPurpose': '',
        'giving': '', // no persisted list yet
      };
      final log = DailyLog.fromMap(map);
      expect(log.giving.length, 1);
      expect(log.giving.first.type, 'Tithe');
      // Second round-trip must not double the entry or resurrect the scalar
      final secondRoundTrip = DailyLog.fromMap(log.toMap());
      expect(secondRoundTrip.giving.length, 1);
      expect(secondRoundTrip.giving.first.type, 'Tithe');
      expect(secondRoundTrip.givingType, ''); // scalar cleared, not re-persisted
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/daily_log_test.dart`
Expected: FAIL — `GivingEntry` undefined, `DailyLog.giving` undefined.

- [ ] **Step 3: Implement `GivingEntry`**

In `lib/models/daily_log.dart`, add after the `LiteratureEntry` class (after line 20, before `BibleReadingEntry`):

```dart
/// A single giving/tithe entry — a disciple may record several distinct
/// gifts in a day (e.g. a tithe and a separate offering).
class GivingEntry {
  String type;
  String amount;
  String purpose;

  GivingEntry({this.type = '', this.amount = '', this.purpose = ''});

  Map<String, dynamic> toMap() => {'type': type, 'amount': amount, 'purpose': purpose};

  factory GivingEntry.fromMap(Map<String, dynamic> m) => GivingEntry(
        type: m['type'] ?? '',
        amount: m['amount'] ?? '',
        purpose: m['purpose'] ?? '',
      );

  bool get isEmpty => type.isEmpty && amount.isEmpty && purpose.isEmpty;
  bool get isNotEmpty => !isEmpty;
}
```

- [ ] **Step 4: Wire `giving` into `DailyLog`**

Add the field declaration right after `List<LiteratureEntry> literature;` (after line 247):

```dart
  List<LiteratureEntry> literature;
  List<GivingEntry> giving;
```

Add to the constructor parameter list, right after `List<LiteratureEntry>? literature,` (after line 323):

```dart
    List<LiteratureEntry>? literature,
    List<GivingEntry>? giving,
```

Add to the initializer list, alongside `literature = literature ?? [LiteratureEntry()],` (after line 367):

```dart
       literature = literature ?? [LiteratureEntry()],
       giving = giving ?? [GivingEntry()],
```

Add to `toMap()`, right after `'literature': jsonEncode(literature.map((l) => l.toMap()).toList()),` (after line 418):

```dart
        'literature': jsonEncode(literature.map((l) => l.toMap()).toList()),
        'giving': jsonEncode(giving.map((g) => g.toMap()).toList()),
```

- [ ] **Step 5: Add migration parsing in `fromMap`**

In `fromMap`, add parsing logic mirroring the `literature` parsing block (lines 524-534) — insert right after that block:

```dart
    List<GivingEntry> givingList = [];
    bool migratedGivingFromScalar = false;
    try {
      final raw = m['giving'];
      if (raw != null && raw.toString().isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        givingList = decoded.map((e) => GivingEntry.fromMap(Map<String, dynamic>.from(e))).toList();
      }
    } catch (e) {
      debugPrint('DailyLog.fromMap: failed to parse giving: $e');
    }
    if (givingList.isEmpty) {
      final oldType = (m['givingType'] ?? '').toString();
      final oldAmount = (m['givingAmount'] ?? '').toString();
      final oldPurpose = (m['givingPurpose'] ?? '').toString();
      if (oldType.isNotEmpty || oldAmount.isNotEmpty || oldPurpose.isNotEmpty) {
        givingList = [GivingEntry(type: oldType, amount: oldAmount, purpose: oldPurpose)];
        migratedGivingFromScalar = true;
      } else {
        givingList = [GivingEntry()];
      }
    }
```

- [ ] **Step 6: Wire into the returned `DailyLog(...)` call**

Add `giving: givingList,` to the constructor call in `fromMap` (near `literature: lit,`, currently at line 684). Change the scalar reads for `givingType`/`givingAmount`/`givingPurpose` (currently lines 713-715: `givingType: m['givingType'] ?? '',` etc.) to be cleared when migration happened, matching the exact pattern already used for Proclamation (lines 721-722):

```dart
      givingType: migratedGivingFromScalar ? '' : (m['givingType'] ?? ''),
      givingAmount: migratedGivingFromScalar ? '' : (m['givingAmount'] ?? ''),
      givingPurpose: migratedGivingFromScalar ? '' : (m['givingPurpose'] ?? ''),
```

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/daily_log_test.dart`
Expected: PASS (all new tests, including the idempotency round-trip).

- [ ] **Step 8: Run full analyzer**

Run: `flutter analyze`
Expected: No new errors in `daily_log.dart` itself. Errors/references in `log_screen.dart`/`report_service.dart` etc. that still read `_log.givingType` directly as if it were the only giving field are expected here — NOT this task's job to fix (Task 8 and Task 10 handle those). Note them in your report.

- [ ] **Step 9: Commit**

```bash
git add lib/models/daily_log.dart test/daily_log_test.dart
git commit -m "feat: add GivingEntry model, convert DailyLog.giving to a list"
```

---

### Task 3: SQLite migration — persist `giving` list column (PrayerSession's new fields reuse existing columns), bump DB version to 14

**Files:**
- Modify: `lib/services/storage_service.dart`
- Test: `test/storage_service_test.dart`

**Interfaces:**
- Consumes: `DailyLog.toMap()`/`fromMap()` from Tasks 1-2 (already include the new `giving` JSON column; `prayerAloneSessions`/`prayerOthersSessions` columns already exist from a prior plan and don't need a new column — `PrayerSession.toMap()` just serializes more fields into the same JSON blob).
- Produces: DB schema version 14 with a `giving` TEXT column.

- [ ] **Step 1: Write the failing test**

Read the current `test/storage_service_test.dart` first — there should be an `openTestDb()` helper building an in-memory schema and a `group('Migration simulation', ...)` test from a prior plan; mirror its exact conventions. Add:

```dart
test('saveLog and getLog round-trip a multi-entry giving list', () async {
  final log = DailyLog(
    dateKey: '2026-08-17',
    giving: [
      GivingEntry(type: 'Tithe', amount: '50000 XAF'),
      GivingEntry(type: 'Offering', amount: '5000 XAF', purpose: 'Missions'),
    ],
  );
  await StorageService.instance.saveLog(log);
  final restored = await StorageService.instance.getLog('2026-08-17');
  expect(restored!.giving.length, 2);
  expect(restored.giving[1].purpose, 'Missions');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/storage_service_test.dart`
Expected: FAIL — sqflite throws "no such column: giving" (or the insert silently drops the unknown key, depending on how this codebase's `db.insert` is configured — check the actual failure mode and report it).

- [ ] **Step 3: Add the schema migration**

In `lib/services/storage_service.dart`:
1. Change `version: 13` (line 31) to `version: 14`.
2. In the `CREATE TABLE logs` block, add `giving TEXT DEFAULT ''` near the other JSON-list columns (e.g. near `literature`).
3. In `onUpgrade`, add a new block after the existing `if (oldVersion < 13) { ... }` block (after line ~180, before the closing of the transaction):

```dart
          if (oldVersion < 14) {
            await txn.execute("ALTER TABLE logs ADD COLUMN giving TEXT DEFAULT ''");
          }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/storage_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Run full test suite + analyzer**

Run: `flutter test --concurrency=1 && flutter analyze`
Expected: Storage tests pass. Analyzer may still show pre-existing scalar-read errors elsewhere (see Tasks 1-2's notes) — not this task's concern.

- [ ] **Step 6: Commit**

```bash
git add lib/services/storage_service.dart test/storage_service_test.dart
git commit -m "feat: migrate DB to v14, add giving column for multi-entry list"
```

---

## Phase B — Timer write path: session-first, not scalar-first

### Task 4: Fix Literature — write a real `LiteratureEntry`, not a no-op

**Files:**
- Modify: `lib/services/timer_service.dart`
- Test: `test/timer_service_test.dart`

**Interfaces:**
- Consumes: `LiteratureEntry` (existing, `daily_log.dart:6-20`, untouched by Tasks 1-3).
- Produces: `TimerService._writeToDailyLog` correctly constructs/updates a `LiteratureEntry` in `log.literature` from `session.fields['literatureTitle']` when a Literature timer stops. (Note: this task only fixes the CURRENT literatureTitle-at-Start-only flow's write path; Task 6 restructures WHEN literature's amount is asked, moving it properly into a Stop-time flow — this task's job is narrower: stop the write from being a no-op.)

- [ ] **Step 1: Write the failing test**

Read `test/timer_service_test.dart`'s existing conventions first (should already have `group('TimerService — untouched scalar-accumulating activities still work', ...)` or similar from a prior plan). Add:

```dart
  group('TimerService — literature writes a real entry', () {
    test('stopping a literature timer with a title creates a LiteratureEntry, not a no-op', () async {
      final key = TimerKey.builtIn(ActivityType.literature);
      TimerService.instance.start(key, fields: {'literatureTitle': 'Mere Christianity'});
      await TimerService.instance.stop(key);
      final log = await StorageService.instance.getLog(
          DateFormat('yyyy-MM-dd').format(DateTime.now()));
      expect(log!.literature.any((l) => l.title == 'Mere Christianity'), true);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/timer_service_test.dart`
Expected: FAIL — `log.literature` has no entry with that title (the `literatureTitle` field is silently discarded by the current no-op).

- [ ] **Step 3: Implement**

In `lib/services/timer_service.dart`, `_mergeLogField` (lines 639-690), replace the two no-op cases (lines 685-688):

```dart
      case 'literatureTitle':
        break;
      case 'literatureAmount':
        break;
```

with a real write. Since `literatureTitle` and `literatureAmount` may arrive as two separate calls to `_mergeLogField` (once per entry in `session.fields`, per the loop at lines 484-494) rather than together, handle them by finding-or-creating a `LiteratureEntry` keyed by matching title (mirroring the same find-or-append idiom already used by `ProclamationSession`/`PrayerSession`):

```dart
      case 'literatureTitle':
        _upsertLiteratureEntry(log, title: value);
      case 'literatureAmount':
        _upsertLiteratureEntry(log, amount: value);
```

Add a new private helper method right after `_mergeLogField` (after line 690, before the closing brace of the class):

```dart
  /// Find-or-create a `LiteratureEntry` for the current write. If the log's
  /// literature list is just the default single empty entry, fill that one
  /// in rather than appending a second — mirrors how the Log screen itself
  /// treats a fresh single empty entry (see log_screen.dart's literature
  /// section) so a timer-completed entry doesn't leave an extra blank card.
  void _upsertLiteratureEntry(DailyLog log, {String? title, String? amount}) {
    if (log.literature.length == 1 && log.literature.first.isEmpty) {
      if (title != null) log.literature.first.title = title;
      if (amount != null) log.literature.first.amount = amount;
      return;
    }
    // Otherwise, find an entry still missing the field being set (the
    // in-progress entry from this same timer session), or append new.
    final idx = title != null
        ? log.literature.indexWhere((l) => l.title.isEmpty)
        : log.literature.indexWhere((l) => l.amount.isEmpty && l.title.isNotEmpty);
    if (idx != -1) {
      if (title != null) log.literature[idx].title = title;
      if (amount != null) log.literature[idx].amount = amount;
    } else {
      log.literature.add(LiteratureEntry(title: title ?? '', amount: amount ?? ''));
    }
  }
```

You will need `LiteratureEntry.isEmpty`/`isNotEmpty` — check if these already exist on the class (they do not currently, per the model read in Task 2's exploration — `LiteratureEntry` at `daily_log.dart:6-20` has no `isEmpty` getter). Add them:

```dart
  bool get isEmpty => title.isEmpty && amount.isEmpty;
  bool get isNotEmpty => !isEmpty;
```

Add these two getters to the `LiteratureEntry` class in `lib/models/daily_log.dart` (this touches a file from Tasks 1-2 — confirm current state before editing, since this task runs after those).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/timer_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Run full test suite + analyzer**

Run: `flutter test --concurrency=1 && flutter analyze`
Expected: Green.

- [ ] **Step 6: Commit**

```bash
git add lib/services/timer_service.dart lib/models/daily_log.dart test/timer_service_test.dart
git commit -m "fix: literature timer writes a real LiteratureEntry instead of discarding the title"
```

---

### Task 5: Bible/DDEG/Prayer-Alone/Prayer-Others — write into real session lists, not legacy scalars

**Files:**
- Modify: `lib/services/timer_service.dart`
- Test: `test/timer_service_test.dart`

**Interfaces:**
- Consumes: `BibleReadingEntry`, `DdegSession`, `PrayerSession` (with Task 1's `title`/`peopleCount`).
- Produces: `TimerService._writeToDailyLog` appends/merges into `log.bibleSessions`/`log.ddegSessions`/`log.prayerAloneSessions`/`log.prayerOthersSessions` for these four activities, instead of writing `bibleDuration`/`ddegTime`/`prayerAloneDuration`/`prayerOthersDuration` scalars. This is the core "timer writes the same model the Log screen shows" fix.

**Important design note for the implementer:** this task changes WHERE the duration lands, but NOT the field-collection flow itself (that's Task 6, which restructures the Start/Stop dialogs to ask for the right fields at the right time, including the new Prayer titles). This task is purely about the write target. After this task, `_showBibleEndDialog`/`_showDdegEndDialog` (which currently write to `log.bibleReference`/`log.ddegScripture` etc. directly, bypassing `_writeToDailyLog` entirely for those specific fields) will need corresponding updates in Task 6 to also target the session list — but this task's job is `_writeToDailyLog`'s duration-only accumulation path (the part that currently does `log.bibleDuration = _accumulateDuration(...)` etc. for a plain stop with no end-dialog data yet merged).

- [ ] **Step 1: Read current state carefully**

Before writing any code, re-read `lib/services/timer_service.dart`'s current `_writeToDailyLog` (the exact body is quoted in this plan's "Context" section below, verified at planning time — but Tasks 1-4 in this same plan already modified this file, so re-read it fresh).

**Context — `_writeToDailyLog`'s builtin-activity branch, as verified at planning time (BEFORE Task 4's edit to `_mergeLogField`, which is a different method — this method itself is unaffected by Task 4):**

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
              log.bibleDuration =
                  _accumulateDuration(log.bibleDuration, durationStr);
            case 'literatureDuration':
              log.literatureDuration =
                  _accumulateDuration(log.literatureDuration, durationStr);
            case 'ddegTime':
              log.ddegTime = _accumulateDuration(log.ddegTime, durationStr);
            case 'prayerAloneDuration':
              log.prayerAloneDuration =
                  _accumulateDuration(log.prayerAloneDuration, durationStr);
            case 'prayerOthersDuration':
              log.prayerOthersDuration =
                  _accumulateDuration(log.prayerOthersDuration, durationStr);
            case 'fastingDuration':
              log.fastingDuration =
                  _accumulateDuration(log.fastingDuration, durationStr);
            case 'discipleshipDuration':
              log.discipleshipDuration =
                  _accumulateDuration(log.discipleshipDuration, durationStr);
          }
        }
      }
```

- [ ] **Step 2: Write the failing tests**

```dart
  group('TimerService — DDEG/Prayer session writes', () {
    test('stopping a ddeg timer appends a DdegSession, not just ddegTime scalar', () async {
      final key = TimerKey.builtIn(ActivityType.ddeg);
      TimerService.instance.start(key, fields: {'ddegScripture': 'Psalm 23'});
      await TimerService.instance.stop(key);
      final log = await StorageService.instance.getLog(
          DateFormat('yyyy-MM-dd').format(DateTime.now()));
      expect(log!.ddegSessions.any((s) => s.scripture == 'Psalm 23'), true);
    });

    test('stopping a prayer-alone timer with a title appends a PrayerSession under that title', () async {
      final key = TimerKey.builtIn(ActivityType.prayerAlone);
      TimerService.instance.start(key, fields: {'prayerAloneTitle': 'Healing for Mom'});
      await TimerService.instance.stop(key);
      final log = await StorageService.instance.getLog(
          DateFormat('yyyy-MM-dd').format(DateTime.now()));
      expect(log!.prayerAloneSessions.any((s) => s.title == 'Healing for Mom'), true);
    });

    test('a second prayer-alone timer with the same title merges duration into the existing session', () async {
      final key = TimerKey.builtIn(ActivityType.prayerAlone);
      TimerService.instance.start(key, fields: {'prayerAloneTitle': 'healing for mom'});
      await TimerService.instance.stop(key);
      final log = await StorageService.instance.getLog(
          DateFormat('yyyy-MM-dd').format(DateTime.now()));
      final matching = log!.prayerAloneSessions.where((s) => s.title.toLowerCase() == 'healing for mom');
      expect(matching.length, 1); // merged, not duplicated
    });

    test('stopping a prayer-with-others timer with a title appends a PrayerSession under that title', () async {
      final key = TimerKey.builtIn(ActivityType.prayerOthers);
      TimerService.instance.start(key, fields: {'prayerOthersTitle': 'Cell group intercession'});
      await TimerService.instance.stop(key);
      final log = await StorageService.instance.getLog(
          DateFormat('yyyy-MM-dd').format(DateTime.now()));
      expect(log!.prayerOthersSessions.any((s) => s.title == 'Cell group intercession'), true);
    });
  });
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/timer_service_test.dart`
Expected: FAIL — sessions lists don't get the new entries; only the legacy scalars do.

- [ ] **Step 4: Implement**

Replace the builtin-activity branch's `else` block (the `logDurationField` switch) with special cases for `bibleReading`, `ddeg`, `prayerAlone`, `prayerOthers` BEFORE the generic switch, mirroring exactly how Proclamation/Evangelism/Church are special-cased:

```dart
      if (builtInType == ActivityType.proclamation) {
        _appendProclamationSession(log, session, durationStr);
      } else if (builtInType == ActivityType.evangelism) {
        _appendTimedSession(log.evangelismSessions, session, durationStr);
      } else if (builtInType == ActivityType.church) {
        _appendTimedSession(log.churchSessions, session, durationStr);
      } else if (builtInType == ActivityType.bibleReading) {
        _appendBibleSession(log, session, durationStr);
      } else if (builtInType == ActivityType.ddeg) {
        _appendDdegSession(log, session, durationStr);
      } else if (builtInType == ActivityType.prayerAlone) {
        _appendPrayerSession(log.prayerAloneSessions, session, durationStr, 'prayerAloneTitle');
      } else if (builtInType == ActivityType.prayerOthers) {
        _appendPrayerSession(log.prayerOthersSessions, session, durationStr, 'prayerOthersTitle');
      } else {
        // Accumulate duration field (add to existing) if the activity has one
        final field = session.key.builtIn!.logDurationField;
        if (field != null) {
          switch (field) {
            case 'literatureDuration':
              log.literatureDuration =
                  _accumulateDuration(log.literatureDuration, durationStr);
            case 'fastingDuration':
              log.fastingDuration =
                  _accumulateDuration(log.fastingDuration, durationStr);
            case 'discipleshipDuration':
              log.discipleshipDuration =
                  _accumulateDuration(log.discipleshipDuration, durationStr);
          }
        }
      }
```

`bibleDuration`/`ddegTime`/`prayerAloneDuration`/`prayerOthersDuration` cases are REMOVED from the switch (Bible/DDEG/Prayer are now fully handled by the session-append branches above). `literatureDuration` is KEPT in the switch and stays a scalar — Task 4 only redirected `literatureTitle`/`literatureAmount` into a real `LiteratureEntry` via `_mergeLogField`; the timer's own duration (from `logDurationField`) is a separate write happening in this switch, unrelated to `_mergeLogField`, and continues accumulating into the legacy `literatureDuration` scalar exactly as it does today. This is intentional, not a gap: Literature's Log-screen section (per the spec's field catalog) only surfaces `literatureDuration` when time-conscious mode is on, and it was never part of the report-visibility bug this plan fixes (Literature's report gate was already fixed to check `log.literature.any(title.isNotEmpty)`, which Task 4 makes reachable) — so `literatureDuration` doesn't need a session-list home in this plan.

Add four new private helper methods after `_appendTimedSession` (which currently ends before `_parseDurationMinutes`):

```dart
  /// Append a Bible reading session using the start/end reference fields
  /// captured by the timer's start/stop dialogs (see stopwatch_screen.dart's
  /// _showBibleEndDialog, updated in a later task to populate these field
  /// keys instead of the legacy bibleReference/bibleChapters scalars).
  void _appendBibleSession(DailyLog log, TimerSession session, String durationStr) {
    final startBook = session.fields['bibleStartBook'] ?? '';
    final startChapterStr = session.fields['bibleStartChapter'] ?? '';
    final endBook = session.fields['bibleEndBook'] ?? '';
    final endChapterStr = session.fields['bibleEndChapter'] ?? '';
    if (startBook.isEmpty) return; // nothing to record without a start reference
    final entry = BibleReadingEntry(
      startBook: startBook,
      startChapter: int.tryParse(startChapterStr) ?? 0,
      endBook: endBook,
      endChapter: int.tryParse(endChapterStr) ?? 0,
    );
    entry.recalculate();
    log.bibleSessions.add(entry);
  }

  /// Append a DDEG session from the scripture/notes fields captured by the
  /// timer's start/stop dialogs.
  void _appendDdegSession(DailyLog log, TimerSession session, String durationStr) {
    final scripture = session.fields['ddegScripture'] ?? '';
    final notes = session.fields['ddegNotes'] ?? '';
    log.ddegSessions.add(DdegSession(
      scripture: scripture,
      time: durationStr,
      notes: notes,
    ));
  }

  /// Append or merge a Prayer session (Alone or Others) by title match,
  /// mirroring _appendProclamationSession's merge-or-append rule exactly.
  void _appendPrayerSession(List<PrayerSession> sessions, TimerSession session,
      String durationStr, String titleFieldKey) {
    final title = (session.fields[titleFieldKey] ?? '').trim();
    final peopleCount = session.fields['prayerPeopleCount'] ?? '';
    final notes = session.fields['prayerNotes'] ?? '';
    final existingIndex = PrayerSession.findMatchingIndex(sessions, title);

    if (existingIndex != -1) {
      final existing = sessions[existingIndex];
      existing.duration = _accumulateDuration(existing.duration, durationStr);
      if (notes.isNotEmpty) existing.notes = _appendText(existing.notes, notes);
      if (peopleCount.isNotEmpty) existing.peopleCount = peopleCount;
    } else {
      sessions.add(PrayerSession(
        title: title,
        duration: durationStr,
        notes: notes,
        peopleCount: peopleCount,
      ));
    }
  }
```

Note the field keys used here (`bibleStartBook`, `bibleStartChapter`, `bibleEndBook`, `bibleEndChapter`, `prayerAloneTitle`, `prayerOthersTitle`, `prayerPeopleCount`, `prayerNotes`) are NEW field-key conventions this plan introduces — they do not exist yet in `stopwatch_screen.dart`'s current dialogs (which use `bibleStartRef`/`bibleReference`/`bibleChapters` as free text, and don't have title fields for Prayer at all). Task 6 is responsible for updating `stopwatch_screen.dart` to populate these exact keys. This task's job is only to make `_writeToDailyLog` correctly consume them once Task 6 provides them — the tests in Step 2 above already use these exact key names, confirming the contract Task 6 must satisfy.

Also replace the merge-loop entirely (currently lines 484-494, containing the old `if (entry.key == 'bibleChapters' && !_hasBibleReference(...))` conditional and the `proclamationTopic` skip) with a single unconditional skip-list covering every field key now consumed by a session-append helper — Bible no longer touches the legacy `bibleReference`/`bibleChapters` scalars at all via this path (Task 6 stops writing `bibleReference`/`bibleChapters` into `session.fields` entirely, writing only `bibleStartBook`/`bibleStartChapter`/`bibleEndBook`/`bibleEndChapter`), so the old conditional (which existed to avoid recording an orphan chapter count with no reference) is no longer reachable and should be removed rather than kept as dead code:

```dart
      for (final entry in session.fields.entries) {
        if ([
          'proclamationTopic',
          'bibleStartBook', 'bibleStartChapter', 'bibleEndBook', 'bibleEndChapter',
          'ddegScripture', 'ddegNotes',
          'prayerAloneTitle', 'prayerOthersTitle', 'prayerPeopleCount', 'prayerNotes',
        ].contains(entry.key)) {
          continue; // consumed by the session-append helpers above, not a legacy scalar merge
        }
        _mergeLogField(log, entry.key, entry.value);
      }
```

Since `_hasBibleReference` (currently a private static helper at `timer_service.dart:631-637`) is no longer called anywhere after this change, remove it too — confirm via `flutter analyze` that no other call site references it before deleting (none should; it was only ever used by the conditional just removed).

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/timer_service_test.dart`
Expected: PASS.

- [ ] **Step 6: Run full test suite + analyzer**

Run: `flutter test --concurrency=1 && flutter analyze`
Expected: Existing tests that assert the OLD scalar-write behavior for Bible/DDEG/Prayer (if any exist from before this plan) will now fail — find and update them to assert the new session-list behavior instead, per this plan's Global Constraints (never silently delete a test, update its assertion).

- [ ] **Step 7: Commit**

```bash
git add lib/services/timer_service.dart test/timer_service_test.dart
git commit -m "feat: Bible/DDEG/Prayer timers write into real session lists, not legacy scalars"
```

---

## Phase C — Stopwatch UI: correct Start/Stop prompts per activity

### Task 6: Restructure Bible/DDEG/Literature Start+Stop prompts to match the new field keys

**Files:**
- Modify: `lib/screens/stopwatch_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`

**Interfaces:**
- Consumes: the field-key contract from Task 5 (`bibleStartBook`/`bibleStartChapter`/`bibleEndBook`/`bibleEndChapter`, `ddegScripture`/`ddegNotes`), `_upsertLiteratureEntry` from Task 4.
- Produces: `_showBibleEndDialog` writes structured start/end book+chapter fields (not a free-text reference string) with required-field validation at both Start and Stop; `_showDdegEndDialog` continues writing scripture at Start (required) and notes at Stop (optional, unchanged position — DDEG's placement was already correct per the field catalog); Literature's Start prompt (title, required) and a NEW Stop dialog requirement enforcement (amount, required — the dialog already exists, this task adds validation to it).

**Read current state first:** `stopwatch_screen.dart` is a 1808-line file and Tasks 4-5 didn't touch it (only `timer_service.dart` and `daily_log.dart` were touched), so its content should match this plan's quoted excerpts exactly — but confirm before editing.

- [ ] **Step 1: Add ARB strings for structured Bible fields and validation errors**

Add to `lib/l10n/app_en.arb` (and matching French to `app_fr.arb`):

```json
"bibleStartBookLabel": "Starting book",
"bibleStartChapterLabel": "Starting chapter",
"bibleEndBookLabel": "Ending book",
"bibleEndChapterLabel": "Ending chapter",
"fieldRequiredError": "This field is required"
```

Run `flutter pub get` to regenerate.

- [ ] **Step 2: Replace Bible's pre-start field with structured book+chapter inputs, required**

In `_fieldsFor` (lines 858-898), Bible's case currently returns a single free-text field:
```dart
      case ActivityType.bibleReading:
        return [('bibleStartRef', l.bibleStartRef, l.bibleStartHint)];
```
This task changes Bible's Start flow to use a DEDICATED bottom sheet (not the generic `_showFieldsAndStart`/`_fieldsFor` mechanism, since it needs a book-name autocomplete PLUS a numeric chapter field PLUS required-field validation — the generic mechanism only supports single free-text fields). Remove Bible's case from `_fieldsFor` entirely (Bible will no longer flow through `_showFieldsAndStart`):

```dart
      case ActivityType.bibleReading:
        return []; // Bible uses a dedicated start dialog — see _showBibleStartDialog
```

In `_activityTile` (around line 298-307), change the routing so Bible, like Proclamation, bypasses `_showFieldsAndStart`:

```dart
              if (!isRunning && !isPaused)
                _tileButton(Icons.play_arrow_rounded, AppTheme.green, () {
                  if (activity == ActivityType.proclamation) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProclamationTopicScreen()),
                    );
                  } else if (activity == ActivityType.bibleReading) {
                    _showBibleStartDialog();
                  } else {
                    _showFieldsAndStart(activity);
                  }
                }),
```

Add a new method `_showBibleStartDialog()` after `_showFieldsAndStart` (after line 1062), modeled on `_showBibleEndDialog`'s autocomplete pattern but for the START book/chapter, with required-field validation (Start button disabled/shows inline error until both book and chapter are filled):

```dart
  /// Show a dedicated start dialog for Bible reading — collects the
  /// starting book/chapter (required) before the timer begins, since a
  /// Bible entry is meaningless without a reference to attach it to.
  void _showBibleStartDialog() {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final bookCtrl = TextEditingController();
    final chapterCtrl = TextEditingController();
    final locale = Localizations.localeOf(context).languageCode;
    final bookNames = BibleBooks.bookNames(locale);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          String? errorText;
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(ActivityType.bibleReading.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(l.sectionBible,
                            style: AppTheme.display(18, color: accent))),
                  ],
                ),
                const SizedBox(height: 16),
                Autocomplete<String>(
                  optionsBuilder: (v) {
                    if (v.text.isEmpty) return const [];
                    final input = v.text.toLowerCase();
                    return bookNames.where((n) => n.toLowerCase().contains(input));
                  },
                  fieldViewBuilder: (ctx2, controller, focusNode, onSubmitted) {
                    controller.addListener(() => bookCtrl.text = controller.text);
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: AppTheme.serif(14, color: AppTheme.textColor(context)),
                      decoration: InputDecoration(
                        labelText: l.bibleStartBookLabel,
                        hintText: l.bibleStartHint,
                        labelStyle: AppTheme.serif(12, color: accent),
                        errorText: errorText,
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: accent.withValues(alpha: 0.3))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: chapterCtrl,
                  keyboardType: TextInputType.number,
                  style: AppTheme.serif(14, color: AppTheme.textColor(context)),
                  decoration: InputDecoration(
                    labelText: l.bibleStartChapterLabel,
                    labelStyle: AppTheme.serif(12, color: accent),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: accent.withValues(alpha: 0.3))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      if (bookCtrl.text.trim().isEmpty) {
                        setSheetState(() => errorText = l.fieldRequiredError);
                        return;
                      }
                      Navigator.pop(ctx);
                      TimerService.instance.start(
                        TimerKey.builtIn(ActivityType.bibleReading),
                        fields: {
                          'bibleStartBook': bookCtrl.text.trim(),
                          'bibleStartChapter': chapterCtrl.text.trim(),
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(l.startTimer, style: AppTheme.display(16, color: AppTheme.bg0)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
```

- [ ] **Step 3: Update `_showBibleEndDialog` to write structured fields and require the end reference**

In `_showBibleEndDialog` (lines 1314-1473), the current save handler (lines 1431-1454) writes `session.fields['bibleReference']`/`session.fields['bibleChapters']` as free text, with no required-field check. This step adds an `errorText` state variable to the dialog's existing `StatefulBuilder` (which already holds `calculatedChapters`, declared at line 1337 as `int? calculatedChapters;` inside the `builder:` closure — add `errorText` as a sibling local variable in that same closure scope, NOT inside `setSheetState`'s callback), wires it into the end-reference `Autocomplete` field's `errorText:` decoration, and requires `endRef` before proceeding.

First, locate the `Autocomplete<String>` block for the end reference (lines 1371-1411) and add `errorText: errorText,` to its inner `TextField`'s `InputDecoration` (right after `hintText: l.bibleEndHint,`):

```dart
                      decoration: InputDecoration(
                        labelText: l.bibleEndRef,
                        hintText: l.bibleEndHint,
                        errorText: errorText,
                        labelStyle: AppTheme.serif(12, color: accent),
```

Then locate the outer `builder: (ctx, setSheetState) => Padding(` closure (line 1338) and add the new local variable right after `int? calculatedChapters;` (line 1337):

```dart
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
```
becomes (adding the declaration one line above, inside the `builder:` function body before its `return`):
```dart
        int? calculatedChapters;
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
```

Then replace the `onTap` handler (line 1431):

```dart
                    onTap: () async {
                      final endRef = endRefCtrl.text.trim();
                      if (endRef.isEmpty) {
                        setSheetState(() => errorText = l.fieldRequiredError);
                        return;
                      }

                      // Parse endRef into book/chapter for the structured
                      // session. The end field remains a single free-text
                      // Autocomplete (unlike the start dialog's split
                      // book+chapter inputs), so split on the last space
                      // and treat the trailing token as the chapter number
                      // when it parses as one; otherwise treat the whole
                      // string as the book name with chapter 0.
                      final lastSpace = endRef.lastIndexOf(' ');
                      String endBook = endRef;
                      int endChapterNum = 0;
                      if (lastSpace > 0) {
                        final trailing = endRef.substring(lastSpace + 1);
                        final parsedChapter = int.tryParse(trailing);
                        if (parsedChapter != null) {
                          endBook = endRef.substring(0, lastSpace).trim();
                          endChapterNum = parsedChapter;
                        }
                      }
                      final resolvedBook = BibleBooks.findBook(endBook)?.nameEn ?? endBook;
                      session.fields['bibleEndBook'] = resolvedBook;
                      session.fields['bibleEndChapter'] = '$endChapterNum';
                      // Deliberately NOT writing session.fields['bibleChapters']
                      // here — `calculatedChapters` was only ever a live
                      // preview for this dialog's UI. The structured
                      // BibleReadingEntry built by _appendBibleSession (Task 5)
                      // recalculates chaptersRead itself from the start/end
                      // book+chapter fields via entry.recalculate(), so a
                      // separate scalar write would be a second, redundant
                      // source of truth — exactly the parallel-write-path
                      // problem this plan exists to eliminate.

                      Navigator.pop(ctx);
                      await ts.stop(TimerKey.builtIn(ActivityType.bibleReading));
                    },
```

Before finalizing this parsing logic, read `BibleBooks.findBook`'s actual signature/behavior in `lib/utils/bible_books.dart` — confirm it accepts a bare book name (not "Book Chapter" combined) and returns `null` gracefully for an unrecognized name, matching how the split-on-last-space logic above assumes it will be called. Verify manually by testing a real Bible timer stop end-to-end after implementing (e.g. typing "John 3" as the end reference should split into book "John", chapter 3).

- [ ] **Step 4: Add validation to Literature's Stop dialog**

In `_showLiteratureEndDialog` (lines 1476-1636), the save handler (lines 1589-1617) currently allows an empty `amount`. Add a required-field check mirroring Bible's pattern — `amount` must be non-empty before the Done button proceeds (add a `String? errorText` StatefulBuilder variable, show it on the amount TextField's `errorText:` property, block `Navigator.pop`/`ts.stop` until filled).

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze`
Expected: Clean for this file's changes (other files may still show pre-existing errors from Tasks 1-2/1-5's cross-file impact — not this task's concern).

- [ ] **Step 6: Manual verification**

No automated widget tests exist for this UI in this codebase (confirmed absent in prior plans) — verify via `flutter run` on a device/emulator: start a Bible timer, confirm the start dialog requires a book, stop it, confirm the end dialog requires an end reference and the resulting `bibleSessions` entry (visible in the Log screen) has the correct start/end book/chapter.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/stopwatch_screen.dart lib/l10n/app_en.arb lib/l10n/app_fr.arb
git commit -m "feat: Bible timer collects structured start/end reference with required-field validation"
```

---

### Task 7: Restructure Prayer Alone/Prayer Others — title at Start (required), reflection/peopleCount at Stop (optional)

**Files:**
- Modify: `lib/screens/stopwatch_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`

**Interfaces:**
- Consumes: the `prayerAloneTitle`/`prayerOthersTitle`/`prayerPeopleCount`/`prayerNotes` field-key contract from Task 5.
- Produces: a shared topic-picker screen for Prayer (mirroring `ProclamationTopicScreen` exactly, parameterized by activity type), plus new Stop-time dialogs for Prayer Alone (reflection notes, optional) and Prayer with Others (people count, optional).

- [ ] **Step 1: Read `lib/screens/proclamation_topic_screen.dart` in full as your template**

This file (136 lines, unmodified by any task so far in this plan) is the exact pattern to generalize: text field + recent-topic chips loaded from today's log + Start button. Read it fully before writing this task's code.

- [ ] **Step 2: Add ARB strings**

```json
"prayerTitlePrompt": "What are you praying for?",
"prayerTitleHint": "e.g. Healing, Provision, Guidance",
"prayerRecentTitles": "Recent today",
"prayerStartButton": "Start Praying",
"prayerAloneReflectionPrompt": "How was your prayer time?",
"prayerPeopleCountLabel": "Number of people (optional)",
"prayerPeopleCountHint": "e.g. 5"
```

(French equivalents in `app_fr.arb`, matching the tone of the existing `proclamationTopicPrompt` etc.)

- [ ] **Step 3: Create a shared Prayer topic-picker screen**

Create `lib/screens/prayer_topic_screen.dart`, generalizing `ProclamationTopicScreen` to take an `ActivityType` (either `prayerAlone` or `prayerOthers`) so one file serves both:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/activity_timer.dart';
import '../models/daily_log.dart';
import '../services/storage_service.dart';
import '../services/timer_service.dart';
import '../theme/app_theme.dart';

/// Prompts for a prayer title/burden before starting the timer — same
/// pattern as ProclamationTopicScreen, parameterized for Prayer Alone or
/// Prayer with Others (both use PrayerSession.title with identical
/// case-insensitive/trimmed merge rules).
class PrayerTopicScreen extends StatefulWidget {
  final ActivityType activityType; // prayerAlone or prayerOthers

  const PrayerTopicScreen({super.key, required this.activityType});

  @override
  State<PrayerTopicScreen> createState() => _PrayerTopicScreenState();
}

class _PrayerTopicScreenState extends State<PrayerTopicScreen> {
  final _controller = TextEditingController();
  List<String> _recentTitles = [];
  String? _selected;
  String? _errorText;

  bool get _isAlone => widget.activityType == ActivityType.prayerAlone;

  @override
  void initState() {
    super.initState();
    _loadRecentTitles();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecentTitles() async {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final log = await StorageService.instance.getLog(todayKey);
    if (log == null || !mounted) return;
    final sessions = _isAlone ? log.prayerAloneSessions : log.prayerOthersSessions;
    setState(() {
      _recentTitles = sessions.map((s) => s.title).where((t) => t.isNotEmpty).toSet().toList();
    });
  }

  void _start() {
    final title = (_selected ?? _controller.text).trim();
    if (title.isEmpty) {
      setState(() => _errorText = S.of(context).fieldRequiredError);
      return;
    }
    Navigator.of(context).pop();
    TimerService.instance.start(
      TimerKey.builtIn(widget.activityType),
      fields: {_isAlone ? 'prayerAloneTitle' : 'prayerOthersTitle': title},
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
        title: Text(l.prayerTitlePrompt, style: AppTheme.display(18, color: accent)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              onChanged: (v) => setState(() { _selected = null; _errorText = null; }),
              style: AppTheme.serif(16, color: AppTheme.textColor(context)),
              decoration: InputDecoration(
                hintText: l.prayerTitleHint,
                errorText: _errorText,
                hintStyle: AppTheme.serif(14, color: AppTheme.faintColor(context)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent.withValues(alpha: 0.3))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
              ),
            ),
            if (_recentTitles.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(l.prayerRecentTitles,
                  style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentTitles.map((title) {
                  final selected = _selected == title;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selected = title;
                      _controller.text = title;
                      _errorText = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? accent : accent.withValues(alpha: 0.3)),
                      ),
                      child: Text(title, style: AppTheme.serif(13, color: AppTheme.textColor(context))),
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
                  child: Text(l.prayerStartButton, style: AppTheme.display(16, color: AppTheme.bg0)),
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

- [ ] **Step 4: Wire the grid tile to route Prayer Alone/Others to this screen**

In `stopwatch_screen.dart`'s `_activityTile`, extend the routing condition from Step 2 of Task 6:

```dart
              if (!isRunning && !isPaused)
                _tileButton(Icons.play_arrow_rounded, AppTheme.green, () {
                  if (activity == ActivityType.proclamation) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProclamationTopicScreen()),
                    );
                  } else if (activity == ActivityType.bibleReading) {
                    _showBibleStartDialog();
                  } else if (activity == ActivityType.prayerAlone || activity == ActivityType.prayerOthers) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PrayerTopicScreen(activityType: activity)),
                    );
                  } else {
                    _showFieldsAndStart(activity);
                  }
                }),
```

Add `import 'prayer_topic_screen.dart';` to the top of `stopwatch_screen.dart`.

Remove Prayer Alone and Prayer Others from `_fieldsFor` (lines 866-874) since they no longer flow through `_showFieldsAndStart`:

```dart
      case ActivityType.prayerAlone:
        return []; // uses PrayerTopicScreen — see _activityTile
      case ActivityType.prayerOthers:
        return []; // uses PrayerTopicScreen — see _activityTile
```

- [ ] **Step 5: Add Stop-time dialogs**

In `_stopTimer` (lines 1289-1311), add branches for Prayer Alone (reflection notes) and Prayer Others (people count):

```dart
    if (key.isBuiltIn) {
      if (key.builtIn == ActivityType.bibleReading) {
        await _showBibleEndDialog(session);
      } else if (key.builtIn == ActivityType.literature) {
        await _showLiteratureEndDialog(session);
      } else if (key.builtIn == ActivityType.ddeg) {
        await _showDdegEndDialog(session);
      } else if (key.builtIn == ActivityType.prayerAlone) {
        await _showPrayerAloneEndDialog(session);
      } else if (key.builtIn == ActivityType.prayerOthers) {
        await _showPrayerOthersEndDialog(session);
      } else {
        await ts.stop(key);
      }
    } else {
```

Add two new methods after `_showDdegEndDialog` (after line 1769), modeled closely on `_showDdegEndDialog`'s shape (pause, show a simple optional-field dialog, write into `session.fields`, then `ts.stop`):

```dart
  /// Show optional reflection prompt after a Prayer Alone timer stops.
  Future<void> _showPrayerAloneEndDialog(TimerSession session) async {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final ts = TimerService.instance;
    ts.pause(session.key);
    final duration = session.formattedDuration;
    final notesCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(ActivityType.prayerAlone.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(child: Text(l.sectionPrayerAlone, style: AppTheme.display(18, color: accent))),
            ]),
            const SizedBox(height: 8),
            Text(l.timerStoppedDuration(duration),
                style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
            const SizedBox(height: 16),
            TextField(
              controller: notesCtrl,
              autofocus: true,
              maxLines: 4,
              style: AppTheme.serif(14, color: AppTheme.textColor(context)),
              decoration: InputDecoration(
                labelText: l.prayerAloneReflectionPrompt,
                labelStyle: AppTheme.serif(12, color: accent),
                alignLabelWithHint: true,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: accent.withValues(alpha: 0.3))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: accent)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () async {
                  final notes = notesCtrl.text.trim();
                  if (notes.isNotEmpty) session.fields['prayerNotes'] = notes;
                  Navigator.pop(ctx);
                  await ts.stop(TimerKey.builtIn(ActivityType.prayerAlone));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(l.done, style: AppTheme.display(16, color: AppTheme.bg0)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show optional people-count prompt after a Prayer with Others timer stops.
  Future<void> _showPrayerOthersEndDialog(TimerSession session) async {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final ts = TimerService.instance;
    ts.pause(session.key);
    final duration = session.formattedDuration;
    final countCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(ActivityType.prayerOthers.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(child: Text(l.sectionPrayerOthers, style: AppTheme.display(18, color: accent))),
            ]),
            const SizedBox(height: 8),
            Text(l.timerStoppedDuration(duration),
                style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
            const SizedBox(height: 16),
            TextField(
              controller: countCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: AppTheme.serif(14, color: AppTheme.textColor(context)),
              decoration: InputDecoration(
                labelText: l.prayerPeopleCountLabel,
                hintText: l.prayerPeopleCountHint,
                labelStyle: AppTheme.serif(12, color: accent),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent.withValues(alpha: 0.3))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () async {
                  final count = countCtrl.text.trim();
                  if (count.isNotEmpty) session.fields['prayerPeopleCount'] = count;
                  Navigator.pop(ctx);
                  await ts.stop(TimerKey.builtIn(ActivityType.prayerOthers));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(l.done, style: AppTheme.display(16, color: AppTheme.bg0)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 6: Run analyzer**

Run: `flutter analyze`
Expected: Clean for `stopwatch_screen.dart`/`prayer_topic_screen.dart`.

- [ ] **Step 7: Manual verification**

Run the app, start a Prayer Alone timer, confirm the title prompt (required) appears, stop it, confirm the reflection prompt (optional) appears, confirm the resulting `PrayerSession` in the Log screen has the right title/notes/duration. Repeat for Prayer with Others (title required, people-count optional at stop).

- [ ] **Step 8: Commit**

```bash
git add lib/screens/stopwatch_screen.dart lib/screens/prayer_topic_screen.dart lib/l10n/app_en.arb lib/l10n/app_fr.arb
git commit -m "feat: Prayer Alone/Others collect a title at start (like Proclamation), optional reflection/headcount at stop"
```

---

### Task 8: Evangelism/Church — move all fields to Stop (per user's explicit correction), Church gains a notes prompt

**Files:**
- Modify: `lib/screens/stopwatch_screen.dart`

**Interfaces:**
- Consumes: existing `evangelismSessions`/`churchSessions` (`TimedSession`, unmodified by this plan) — these don't carry the scalar fields (`evangelismContacts` etc.), which remain plain `DailyLog` scalars per the spec (Evangelism/Church were confirmed NOT to need session-list conversion, only re-timed prompts).

**Context reminder:** per the user's explicit correction during brainstorming, Evangelism's contacts/outcome/notes are ALL only knowable after the outreach — nothing is prompted at Start. Church's type IS knowable beforehand (correctly already at Start) — only its notes field needs to move from "never asked" to "asked at Stop."

- [ ] **Step 1: Add ARB strings for the newly-prompted fields**

```json
"evangelismOutcomeLabel": "People reached by the gospel",
"evangelismOutcomeHint": "e.g. 3",
"churchNotesStopLabel": "Key lessons, word received"
```

(Check `evangelismOutcomeLabel`/`churchNotesLabel`/`churchNotesHint` don't already exist under different names in the ARB — the Log screen already has fields for these per the earlier catalog; reuse the EXISTING `evangelismOutcomeLabel`/`evangelismOutcomeHint`/`churchNotesLabel`/`churchNotesHint` ARB keys from the Log screen's existing fields rather than creating duplicates, if they exist. Grep `lib/l10n/app_en.arb` for these exact key names before adding anything new.)

- [ ] **Step 2: Remove Evangelism's pre-start fields, add a Stop dialog**

In `_fieldsFor` (lines 875-880), Evangelism currently returns:
```dart
      case ActivityType.evangelism:
        return [
          ('evangelismContacts', l.evangelismContactsLabel, l.evangelismContactsHint),
          ('evangelismNotes', l.evangelismNotesLabel, l.evangelismNotesHint),
        ];
```
Change to:
```dart
      case ActivityType.evangelism:
        return []; // all fields are only knowable after — see _showEvangelismEndDialog
```

In `_stopTimer` (lines 1289-1311), add a branch routing Evangelism to a new `_showEvangelismEndDialog`:

```dart
      } else if (key.builtIn == ActivityType.evangelism) {
        await _showEvangelismEndDialog(session);
      } else if (key.builtIn == ActivityType.church) {
        await _showChurchEndDialog(session);
      } else {
```

(Insert these two new `else if` branches before the existing final `else { await ts.stop(key); }` branch, alongside the existing `bibleReading`/`literature`/`ddeg` branches.)

Add `_showEvangelismEndDialog` as a new method after `_showDdegEndDialog` (after line 1769), with contacts and outcome required, notes optional:

```dart
  /// Show dialog after Evangelism timer stops — every field here is only
  /// knowable once the outreach is complete, so nothing is asked at start.
  Future<void> _showEvangelismEndDialog(TimerSession session) async {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final ts = TimerService.instance;
    ts.pause(session.key);
    final duration = session.formattedDuration;

    final contactsCtrl = TextEditingController();
    final outcomeCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String? contactsError;
        String? outcomeError;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(ActivityType.evangelism.icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l.sectionEvangelism, style: AppTheme.display(18, color: accent))),
                ]),
                const SizedBox(height: 8),
                Text(l.timerStoppedDuration(duration),
                    style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
                const SizedBox(height: 16),
                TextField(
                  controller: contactsCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  style: AppTheme.serif(14, color: AppTheme.textColor(context)),
                  decoration: InputDecoration(
                    labelText: l.evangelismContactsLabel,
                    hintText: l.evangelismContactsHint,
                    errorText: contactsError,
                    labelStyle: AppTheme.serif(12, color: accent),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: accent.withValues(alpha: 0.3))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: outcomeCtrl,
                  keyboardType: TextInputType.number,
                  style: AppTheme.serif(14, color: AppTheme.textColor(context)),
                  decoration: InputDecoration(
                    labelText: l.evangelismOutcomeLabel,
                    hintText: l.evangelismOutcomeHint,
                    errorText: outcomeError,
                    labelStyle: AppTheme.serif(12, color: accent),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: accent.withValues(alpha: 0.3))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  style: AppTheme.serif(14, color: AppTheme.textColor(context)),
                  decoration: InputDecoration(
                    labelText: l.evangelismNotesLabel,
                    hintText: l.evangelismNotesHint,
                    labelStyle: AppTheme.serif(12, color: accent),
                    alignLabelWithHint: true,
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: accent.withValues(alpha: 0.3))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: accent)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () async {
                      final contacts = contactsCtrl.text.trim();
                      final outcome = outcomeCtrl.text.trim();
                      bool hasError = false;
                      if (contacts.isEmpty) {
                        contactsError = l.fieldRequiredError;
                        hasError = true;
                      }
                      if (outcome.isEmpty) {
                        outcomeError = l.fieldRequiredError;
                        hasError = true;
                      }
                      if (hasError) {
                        setSheetState(() {});
                        return;
                      }
                      session.fields['evangelismContacts'] = contacts;
                      session.fields['evangelismOutcome'] = outcome;
                      final notes = notesCtrl.text.trim();
                      if (notes.isNotEmpty) session.fields['evangelismNotes'] = notes;
                      Navigator.pop(ctx);
                      await ts.stop(TimerKey.builtIn(ActivityType.evangelism));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(l.done, style: AppTheme.display(16, color: AppTheme.bg0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
```

These field keys (`evangelismContacts`, `evangelismOutcome`, `evangelismNotes`) already flow correctly through `_mergeLogField`'s existing cases (confirmed present at `timer_service.dart:654-659`) — no `_writeToDailyLog` changes needed for Evangelism, only this UI-side prompt-timing change.

- [ ] **Step 3: Add Church's Stop-time notes prompt**

Church's Start field (lines 893-894, `churchType`) stays as-is (already correctly at Start). Add `_showChurchEndDialog` as a new method after `_showEvangelismEndDialog`, with a single optional notes field (no required-field validation needed, since Church's only required field — `churchType` — is already correctly collected at Start):

```dart
  /// Show optional notes prompt after a Church timer stops.
  Future<void> _showChurchEndDialog(TimerSession session) async {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final ts = TimerService.instance;
    ts.pause(session.key);
    final duration = session.formattedDuration;
    final notesCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(ActivityType.church.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(child: Text(l.sectionChurch, style: AppTheme.display(18, color: accent))),
            ]),
            const SizedBox(height: 8),
            Text(l.timerStoppedDuration(duration),
                style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
            const SizedBox(height: 16),
            TextField(
              controller: notesCtrl,
              autofocus: true,
              maxLines: 4,
              style: AppTheme.serif(14, color: AppTheme.textColor(context)),
              decoration: InputDecoration(
                labelText: l.churchNotesLabel,
                hintText: l.churchNotesHint,
                labelStyle: AppTheme.serif(12, color: accent),
                alignLabelWithHint: true,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: accent.withValues(alpha: 0.3))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: accent)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () async {
                  final notes = notesCtrl.text.trim();
                  if (notes.isNotEmpty) session.fields['churchNotes'] = notes;
                  Navigator.pop(ctx);
                  await ts.stop(TimerKey.builtIn(ActivityType.church));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(l.done, style: AppTheme.display(16, color: AppTheme.bg0)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
```

`churchNotes` already flows through `_mergeLogField`'s existing case (`timer_service.dart:676-677`) — no `_writeToDailyLog` changes needed.

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze`
Expected: Clean.

- [ ] **Step 5: Manual verification**

Start an Evangelism timer (confirm no pre-start prompt appears), stop it, confirm the three-field dialog appears with contacts/outcome required. Start a Church timer (confirm the type prompt still appears), stop it, confirm the optional notes prompt appears.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/stopwatch_screen.dart lib/l10n/app_en.arb lib/l10n/app_fr.arb
git commit -m "feat: move Evangelism fields to stop-time (all retrospective), add Church notes prompt at stop"
```

---

### Task 9: Restore Proclamation's tap-to-count interaction

**Files:**
- Modify: `lib/screens/proclamation_topic_screen.dart`

**Interfaces:**
- Consumes: `TimerService.instance` is NOT used by this task's new flow — the counter writes directly to storage on Save, exactly like the ORIGINAL pre-regression implementation (`_openProclamationCounter`, whose full body is preserved in git history at commit `63b494b^:lib/screens/stopwatch_screen.dart:1062-1233`, already read in full during this plan's brainstorming phase), adapted to write into `ProclamationSession` (topic-aware) instead of the old scalar fields.
- Produces: after picking/entering a topic, `ProclamationTopicScreen` navigates to (or transforms into) a tap-to-count screen — large circle, tap = +1, background stopwatch auto-starts on first tap, Save persists topic+count+duration via `ProclamationSession.findMatchingIndex`'s merge-or-append rule.

- [ ] **Step 1: Read the current `ProclamationTopicScreen` in full**

Already read in full during this plan's Task 7 preparation (136 lines) — re-confirm current state, since Task 7 didn't touch this file but confirm no other task in this plan has.

- [ ] **Step 2: Add ARB strings for the counter screen (reuse existing where possible)**

Check `lib/l10n/app_en.arb` for `proclamationTap`/`proclamationSave` (confirmed to still exist from a prior plan, used by `_openCustomCounterModal`) — reuse these exact keys rather than duplicating.

- [ ] **Step 3: Restructure `ProclamationTopicScreen`'s `_start()` to open a counter, not a timer**

Replace the current `_start()` method (which calls `TimerService.instance.start(...)`) with logic that navigates to a new counter view. The cleanest implementation: turn `ProclamationTopicScreen` into a two-stage widget — Stage 1 (topic picker, current UI) transitions to Stage 2 (counter) via `setState`, rather than a second route push, so the topic remains in scope without needing to pass it through navigation arguments.

Add state to `_ProclamationTopicScreenState`:

```dart
  bool _counting = false;
  String _chosenTopic = '';
  int _count = 0;
  final Stopwatch _stopwatch = Stopwatch();
```

Replace `_start()`:

```dart
  void _start() {
    final topic = (_selected ?? _controller.text).trim();
    setState(() {
      _chosenTopic = topic;
      _counting = true;
    });
  }

  void _tapCount() {
    setState(() => _count++);
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
      _tickCounter();
    }
  }

  void _tickCounter() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_stopwatch.isRunning) return;
      setState(() {});
      _tickCounter();
    });
  }

  Future<void> _save() async {
    _stopwatch.stop();
    if (_count == 0) {
      Navigator.of(context).pop();
      return;
    }
    final durationStr = _formatStopwatchDuration(_stopwatch.elapsed);
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final log = await StorageService.instance.getLog(todayKey) ?? DailyLog(dateKey: todayKey);
    final idx = ProclamationSession.findMatchingIndex(log.proclamationSessions, _chosenTopic);
    if (idx != -1) {
      log.proclamationSessions[idx].count += _count;
      log.proclamationSessions[idx].duration =
          _accumulateDurationStrings(log.proclamationSessions[idx].duration, durationStr);
    } else {
      log.proclamationSessions.add(ProclamationSession(
        topic: _chosenTopic,
        count: _count,
        duration: durationStr,
      ));
    }
    await StorageService.instance.saveLog(log);
    if (mounted) Navigator.of(context).pop();
  }

  String _formatStopwatchDuration(Duration d) {
    if (d.inMinutes <= 0) return '';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m}min' : '${m}min';
  }

  /// Mirrors TimerService's private _accumulateDuration — duplicated here
  /// since this screen intentionally bypasses TimerService entirely (the
  /// counter is not a stopwatch-style timed activity in the TimerService
  /// sense; it's its own self-contained interaction, same as the original
  /// pre-regression implementation).
  String _accumulateDurationStrings(String existing, String added) {
    int parseMin(String s) {
      if (s.isEmpty) return 0;
      final hm = RegExp(r'(\d+)h\s*(\d+)?min?').firstMatch(s);
      if (hm != null) return (int.tryParse(hm.group(1)!) ?? 0) * 60 + (int.tryParse(hm.group(2) ?? '0') ?? 0);
      final mOnly = RegExp(r'(\d+)min').firstMatch(s);
      if (mOnly != null) return int.tryParse(mOnly.group(1)!) ?? 0;
      return 0;
    }
    final total = parseMin(existing) + parseMin(added);
    if (total <= 0) return '';
    final h = total ~/ 60;
    final m = total % 60;
    return h > 0 ? '${h}h ${m}min' : '${m}min';
  }
```

- [ ] **Step 4: Replace `build()` to render the counter stage when `_counting` is true**

Replace the entire `build()` method with a version that branches on `_counting`, keeping the existing topic-picker body (Stage 1) unchanged and adding the tap-to-count body (Stage 2) as a sibling branch:

```dart
  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);

    if (_counting) {
      final elapsed = _stopwatch.elapsed;
      final h = elapsed.inHours;
      final m = elapsed.inMinutes % 60;
      final s = elapsed.inSeconds % 60;
      final timerDisplay = h > 0
          ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
          : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

      return Scaffold(
        backgroundColor: AppTheme.bgColor(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _save, // saves if count > 0, else just pops — see _save
          ),
          title: Text(_chosenTopic.isEmpty ? l.sectionProclamation : _chosenTopic,
              style: AppTheme.display(18, color: accent)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$_count', style: AppTheme.display(72, color: accent)),
              const SizedBox(height: 8),
              Text(l.proclamationTap,
                  style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _tapCount,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.goldGradient,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                      child: Icon(Icons.add, color: AppTheme.bg0, size: 48)),
                ),
              ),
              const SizedBox(height: 16),
              if (_stopwatch.elapsed > Duration.zero)
                Text(timerDisplay,
                    style: AppTheme.display(20, color: AppTheme.mutedColor(context))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(l.proclamationSave,
                        style: AppTheme.display(16, color: AppTheme.bg0)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Stage 1: topic picker (unchanged from the existing implementation)
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
```

The Stage 1 body above is copied verbatim from the CURRENT `build()` method (already read in full earlier in this plan) — no changes to it, only the addition of the Stage 2 branch and the `if (_counting) { ... }` guard at the top. The `leading: IconButton` close action in Stage 2 reuses `_save` directly, since `_save` already contains the "pop without persisting if `_count == 0`" guard from Step 3, matching the original counter's `if (count > 0)` behavior (`stopwatch_screen.dart:1189` in the pre-regression implementation).

Note: `_tickCounter`'s recursive `Future.delayed` scheduling (added in Step 3) will keep calling `setState` once per second while `_counting` is true — this only matters once `build()` actually renders the Stage 2 branch that reads `_stopwatch.elapsed`, which is now wired up above.

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze`
Expected: Clean.

- [ ] **Step 6: Manual verification**

Run the app, tap Proclamation, enter/pick a topic, tap Start — confirm the counter screen appears (NOT a stopwatch elapsed-time display with pause/stop controls), tap the circle several times, confirm the count increments and a background timer runs automatically, tap Save, confirm the Log screen shows a `ProclamationSession` with the right topic/count/duration. Repeat with the SAME topic a second time same day, confirm it merges into the existing session (count adds, duration accumulates) rather than creating a duplicate.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/proclamation_topic_screen.dart
git commit -m "fix: restore proclamation's tap-to-count interaction after topic selection"
```

---

### Task 10: Log screen — Proclamation topic field, Prayer title/peopleCount fields, Giving multi-entry list

**Files:**
- Modify: `lib/screens/log_screen.dart`

**Interfaces:**
- Consumes: `PrayerSession.title`/`peopleCount`/`findMatchingIndex` (Task 1), `GivingEntry`/`DailyLog.giving` (Task 2), `ProclamationSession.findMatchingIndex` (existing).
- Produces: the Log screen's manual-entry UI reaches full parity with the timer for all three activities — this is the direct expression of the spec's core principle for the Log screen side.

**Read current state first:** confirm the exact current line numbers for the Proclamation section (around lines 1348-1370), Prayer Alone/Others session-widget methods (`_prayerAloneSessionWidgets`/`_prayerOthersSessionWidgets`, around lines 2798-2972, already read in full during this plan's exploration and quoted below), and the Giving section (around lines 1265-1290, already read in full and quoted above) — Tasks 1-9 did not touch `log_screen.dart`, so these should be unchanged, but confirm before editing since this is a very large file (2900+ lines).

- [ ] **Step 1: Add a topic field to the Proclamation section**

The current Proclamation section (`log_screen.dart:1348-1370`) has count and duration fields writing to the untitled (empty-topic) session via `_proclamationCountFieldValue`/`_setProclamationCount`/etc. (lines 564-604). Add a topic field ABOVE the count field. Since the current implementation is single-session (always the empty-topic session), and the timer now supports multiple named topics, this task upgrades the Log screen's Proclamation section to a multi-session card list, mirroring `_prayerAloneSessionWidgets`'s exact structure (add/remove session cards, one card per topic).

Add new helper methods near `_prayerAloneSessionWidgets` (after line 2972, before `_unitDropdown`):

```dart
  // ── Proclamation sessions (multi-session, topic-based) ─────

  void _ensureProclamationSession() {
    if (_log.proclamationSessions.isEmpty) {
      _log.proclamationSessions = [ProclamationSession()];
    }
  }

  List<Widget> _proclamationSessionWidgets(S t) {
    _ensureProclamationSession();
    final accent = AppTheme.accentGold(context);
    final dark = AppTheme.isDark(context);

    return [
      ..._log.proclamationSessions.asMap().entries.map((entry) {
        final i = entry.key;
        final session = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: dark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GoldField(
                label: t.proclamationTopicLabel,
                hint: t.proclamationTopicHint,
                value: session.topic,
                onChanged: (v) {
                  setState(() => session.topic = v);
                  _persist();
                },
              ),
              GoldField(
                label: t.proclamationCountLabel,
                hint: t.proclamationCountHint,
                value: session.count > 0 ? '${session.count}' : '',
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  setState(() => session.count = int.tryParse(v) ?? 0);
                  _persist();
                },
              ),
              DurationQuickPick(
                label: t.proclamationDurationLabel,
                customLabel: t.durationCustom,
                value: session.duration,
                onChanged: (v) {
                  setState(() => session.duration = v);
                  _persist();
                },
              ),
              if (_log.proclamationSessions.length > 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => _log.proclamationSessions.removeAt(i));
                      _persist();
                    },
                    icon: const Icon(Icons.remove_circle_outline, size: 16, color: AppTheme.rust),
                    label: Text(t.removeSession, style: AppTheme.serif(12, color: AppTheme.rust)),
                  ),
                ),
            ],
          ),
        );
      }),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            setState(() => _log.proclamationSessions.add(ProclamationSession()));
          },
          icon: Icon(Icons.add_circle_outline, size: 18, color: accent),
          label: Text(t.addProclamationSession, style: AppTheme.serif(13, color: accent)),
        ),
      ),
    ];
  }
```

Note: this REPLACES the merge-into-untitled-session behavior of `_setProclamationCount`/`_setProclamationDuration`/`_proclamationCountFieldValue`/`_proclamationDurationFieldValue` (lines 564-605) — those methods become dead code once the section below is updated to use `_proclamationSessionWidgets` instead of the single `GoldField`+`DurationQuickPick` pair. DELETE those four methods (lines 564-605) as part of this task — this is a deliberate removal of now-superseded code, not an oversight; leaving them would be dead code with no caller.

Replace the Proclamation `SectionCard`'s `children:` (lines 1355-1369):

```dart
        SectionCard(
          icon: '\u{1F4E3}',
          title: t.sectionProclamation,
          initiallyExpanded: _log.proclamationCount.isNotEmpty ||
              _log.proclamationDuration.isNotEmpty ||
              _log.proclamationSessions.any((s) => s.isNotEmpty),
          children: _proclamationSessionWidgets(t),
        ).animate().fadeIn(delay: 480.ms),
```

Add ARB key `proclamationTopicLabel`/`proclamationTopicHint`/`addProclamationSession` if not already present (check first — `proclamationTopicPrompt`/`proclamationTopicHint` already exist from the timer screen per a prior plan; reuse `proclamationTopicHint`, add only `proclamationTopicLabel` and `addProclamationSession` as new keys).

- [ ] **Step 2: Update Prayer Alone/Others session widgets to show `title` first, replace `notes`-as-context for Others**

For **Prayer Alone** (`_prayerAloneSessionWidgets`, lines 2798-2876), add a `title` `GoldField` as the FIRST field in each session card (before the existing `DurationQuickPick`), and update `_syncPrayerAloneLegacy` to also consider whether syncing legacy scalars still makes sense — per the spec, Prayer Alone's legacy `prayerAloneDuration`/`prayerAloneNotes` scalars stay in the model but are no longer the primary write target; keep `_syncPrayerAloneLegacy`'s existing behavior unchanged (it's harmless legacy-mirroring, matches the deprecation convention) but confirm it doesn't need to also sync `title` (it doesn't — there's no legacy title scalar to sync to).

```dart
              GoldField(
                label: t.prayerTitleLabel,
                hint: t.prayerTitleHint,
                value: session.title,
                onChanged: (v) {
                  session.title = v;
                  _syncPrayerAloneLegacy();
                },
              ),
              if (_log.prayerAloneSessions.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${t.sectionPrayerAlone} ${i + 1}',
                      style: AppTheme.label(10, color: AppTheme.mutedColor(context))),
                ),
              DurationQuickPick(
```

(Add this new `GoldField` right after the existing `if (_log.prayerAloneSessions.length > 1)` numbering label block, or before it — place the title field as the visually first element per the spec's "first, most prominent field" requirement, so move the numbering label to AFTER the title field as shown above.)

For **Prayer with Others** (`_prayerOthersSessionWidgets`, lines 2895-2972), replace the existing `GoldField` for `prayerOthersContextLabel`/`prayerOthersContextHint` (currently bound to `session.notes`) with a `title` field, and add a new optional `peopleCount` field:

```dart
              GoldField(
                label: t.prayerTitleLabel,
                hint: t.prayerTitleHint,
                value: session.title,
                onChanged: (v) {
                  session.title = v;
                  _syncPrayerOthersLegacy();
                },
              ),
              if (_log.prayerOthersSessions.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${t.sectionPrayerOthers} ${i + 1}',
                      style: AppTheme.label(10, color: AppTheme.mutedColor(context))),
                ),
              DurationQuickPick(
                label: t.durationLabel,
                customLabel: t.durationCustom,
                value: session.duration,
                onChanged: (v) {
                  session.duration = v;
                  _syncPrayerOthersLegacy();
                },
              ),
              GoldField(
                label: t.prayerPeopleCountLabel,
                hint: t.prayerPeopleCountHint,
                value: session.peopleCount,
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  session.peopleCount = v;
                  _persist();
                },
              ),
```

(Remove the old `GoldField` bound to `prayerOthersContextLabel`/`session.notes` entirely — `notes` is no longer used by Prayer with Others per the spec.) Update `_syncPrayerOthersLegacy` (lines 2886-2893) — it currently syncs `first.notes` into `prayerOthersContext`; since `title` now plays that role, change it to sync `first.title` instead:

```dart
  void _syncPrayerOthersLegacy() {
    if (_log.prayerOthersSessions.isNotEmpty) {
      final first = _log.prayerOthersSessions.first;
      _log.prayerOthersDuration = first.duration;
      _log.prayerOthersContext = first.title;
    }
    _persist();
  }
```

Add ARB keys `prayerTitleLabel`/`prayerTitleHint` (can reuse the timer screen's `prayerTitlePrompt`/`prayerTitleHint` wording style if a Log-screen-specific label reads better, but a shared key is fine — check for naming collisions first).

- [ ] **Step 3: Convert the Giving section to a multi-entry list**

Replace the current single-entry Giving `SectionCard` (lines 1265-1290) with a multi-entry pattern mirroring the Literature section's existing "+ Add another" UI (find and read Literature's section in `log_screen.dart` — it should have an analogous `_literatureEntries`-style widget list method; mirror its exact structure). Add a new helper method:

```dart
  List<Widget> _givingEntryWidgets(S t) {
    if (_log.giving.isEmpty) _log.giving = [GivingEntry()];
    final accent = AppTheme.accentGold(context);
    final dark = AppTheme.isDark(context);

    return [
      ..._log.giving.asMap().entries.map((entry) {
        final i = entry.key;
        final g = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: dark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GoldField(
                label: t.givingTypeLabel,
                hint: t.givingTypeHint,
                value: g.type,
                onChanged: (v) { setState(() => g.type = v); _persist(); },
              ),
              GoldField(
                label: t.givingAmountLabel,
                hint: t.givingAmountHint,
                value: g.amount,
                onChanged: (v) { setState(() => g.amount = v); _persist(); },
              ),
              GoldField(
                label: t.givingPurposeLabel,
                hint: t.givingPurposeHint,
                value: g.purpose,
                onChanged: (v) { setState(() => g.purpose = v); _persist(); },
              ),
              if (_log.giving.length > 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => _log.giving.removeAt(i));
                      _persist();
                    },
                    icon: const Icon(Icons.remove_circle_outline, size: 16, color: AppTheme.rust),
                    label: Text(t.removeSession, style: AppTheme.serif(12, color: AppTheme.rust)),
                  ),
                ),
            ],
          ),
        );
      }),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _log.giving.add(GivingEntry())),
          icon: Icon(Icons.add_circle_outline, size: 18, color: accent),
          label: Text(t.addGivingEntry, style: AppTheme.serif(13, color: accent)),
        ),
      ),
    ];
  }
```

Replace the Giving `SectionCard`'s `children:`:

```dart
        SectionCard(
          icon: '\u{1F4B0}',
          title: t.sectionGiving,
          initiallyExpanded: _log.giving.any((g) => g.isNotEmpty),
          children: _givingEntryWidgets(t),
        ).animate().fadeIn(delay: 360.ms),
```

Add ARB key `addGivingEntry` (e.g. "Add another gift").

- [ ] **Step 4: Update the missing-disciplines checklist**

Around line 1940 (`('💰', t.sectionGiving, _log.givingType.isNotEmpty)`), update to check the list: `_log.giving.any((g) => g.isNotEmpty)`. Around lines 1936-1937 (Prayer entries), confirm these already check sessions correctly (they do, per the earlier grep — `_log.prayerAloneSessions.any((s) => s.isNotEmpty) || _log.prayerAloneDuration.isNotEmpty` — no change needed there, `PrayerSession.isEmpty` already accounts for the new fields via the updated `isEmpty` getter from Task 1). Around line 1943 (Proclamation), no change needed (already checks sessions).

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze`
Expected: Clean.

- [ ] **Step 6: Manual verification**

Open the Log screen, confirm: Proclamation section shows topic+count+duration per session with add/remove; Prayer Alone shows title as the first field; Prayer with Others shows title (not "who/where") as the first field plus an optional people-count; Giving section supports multiple entries with a working "+ Add another gift."

- [ ] **Step 7: Commit**

```bash
git add lib/screens/log_screen.dart lib/l10n/app_en.arb lib/l10n/app_fr.arb
git commit -m "feat: Log screen gains topic-based Proclamation/Prayer sessions and multi-entry Giving, matching the timer"
```

---

## Phase D — Reporting: extend every consumer identically

### Task 11: Report generation — Prayer titles and Giving list in both report builders

**Files:**
- Modify: `lib/services/report_service.dart`
- Test: `test/report_service_test.dart`

**Interfaces:**
- Consumes: `PrayerSession.title` (Task 1), `DailyLog.giving`/`GivingEntry` (Task 2).
- Produces: per-day report lines for Prayer Alone/Others list each title with session count + summed duration (mirroring Proclamation's existing per-topic rendering exactly); Giving's per-day line lists each entry.

**Read current state first — this file was NOT touched by Tasks 1-10**, so the following (verified at planning time) should still be accurate, but confirm:
- `_writePrayerAloneSessions`/`_writePrayerOthersSessions` at lines 478-508 (approximately — re-verify exact bounds).
- Giving's per-day line inside both `buildMonthlyReport`/`buildFullReport` (search for `givingType`).
- `_disciplineChecks` at lines 185-197 (already includes `prayerAloneSessions.any`/`prayerOthersSessions.any` checks — these need no further change since `PrayerSession.isEmpty` from Task 1 already covers the new fields; ONLY the Giving line at line 193 — `l.givingType.isNotEmpty` — needs updating to `l.giving.any((g) => g.isNotEmpty)`).

- [ ] **Step 1: Read `_writeDdegSessions`/`_writePrayerAloneSessions`/`_writePrayerOthersSessions` in full**

These are shared helper functions called identically from both `buildMonthlyReport` and `buildFullReport` (confirmed at planning time — lines 372-374 and 572-574), so fixing them once fixes both report formats — this is the SAFE case, unlike Proclamation's per-day line which was inlined separately in each builder in a prior plan (creating the duplication risk this plan's Global Constraints warn about). Read these three methods' current bodies before editing.

- [ ] **Step 2: Write the failing test**

```dart
test('buildFullReport lists each prayer-alone title separately with duration', () async {
  // Arrange a DailyLog with two PrayerSessions under different titles,
  // save it, call buildFullReport, assert both titles appear with
  // their respective durations in the output.
});

test('buildFullReport lists multiple giving entries per day', () async {
  // Arrange a DailyLog with two GivingEntry objects (Tithe, Offering),
  // save it, call buildFullReport, assert both appear in the output.
});
```

(Follow this file's existing test conventions exactly — read `test/report_service_test.dart`'s current structure first, mirror its `StorageService`/`SharedPreferences` setup boilerplate and its existing Proclamation-topic-listing test as the direct template for these two new tests, since the assertion shape is nearly identical.)

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/report_service_test.dart`
Expected: FAIL — report text shows only the old single-title/single-entry format.

- [ ] **Step 4: Implement**

Update `_writePrayerAloneSessions`/`_writePrayerOthersSessions` to render each session's title alongside its duration when sessions have titles, mirroring the exact per-topic pattern already used for Proclamation in both report builders (`log.proclamationSessions.map((s) { final label = s.topic.isNotEmpty ? s.topic : l.sectionProclamation; ... })`). Since these are single shared helpers (not duplicated per-builder), implement once here.

Update BOTH `buildMonthlyReport` and `buildFullReport`'s Giving line (search each for `givingType`) to iterate `log.giving` instead of reading the scalar directly — since this one IS inlined separately in each builder (confirmed via the original investigation of this file before this plan), apply the identical fix in both places:

```dart
      for (final g in log.giving.where((e) => e.isNotEmpty)) {
        final givingDetail = [
          if (g.amount.isNotEmpty) g.amount,
          if (g.purpose.isNotEmpty) g.purpose,
        ].join(' — ');
        buf.writeln('💰 ${l.reportGiving(g.type, givingDetail)}');
      }
```

Update `_disciplineChecks` (line 193): `l.givingType.isNotEmpty,` → `l.giving.any((g) => g.isNotEmpty),`.

Update `buildCompactReport`'s per-day summary loop (search for `givingType` again — there's a third occurrence in this file per the compact-report pattern established in a prior plan): `if (log.givingType.isNotEmpty) parts.add(...)` → `if (log.giving.any((g) => g.isNotEmpty)) parts.add(...)`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/report_service_test.dart`
Expected: PASS.

- [ ] **Step 6: Run full test suite + analyzer**

Run: `flutter test --concurrency=1 && flutter analyze`
Expected: Green. Watch for any pre-existing test asserting the OLD single-giving-scalar report line format — update its expected string, don't delete the test.

- [ ] **Step 7: Commit**

```bash
git add lib/services/report_service.dart test/report_service_test.dart
git commit -m "feat: report shows per-title prayer sessions and multi-entry giving in both report builders"
```

---

### Task 12: Cross-file audit — completeness/goals/PDF/reflection/intelligence for Prayer titles and Giving list

**Files:**
- Modify: `lib/models/daily_log.dart` (only the `completeness` getter — already touched by Tasks 1-2 for field additions, this task only touches the `completeness` GETTER body itself, a different part of the file)
- Modify: `lib/services/goal_progress_service.dart`
- Modify: `lib/services/report_intelligence_service.dart`
- Modify: `lib/services/reflection_service.dart`
- Modify: `lib/services/pdf_report_service.dart`
- Test: relevant test files for each (`test/daily_log_test.dart`, and any existing test files for the four services — check which exist first; not all services in this codebase have dedicated test files, confirmed by this plan's own exploration finding `test/report_cadence_service_test.dart` exists but no `test/goal_progress_service_test.dart` was confirmed present — GREP for existing test files before assuming, and only add tests to files that already exist, following this plan's Global Constraint about not inventing new test infrastructure beyond what's needed).

**Interfaces:**
- Consumes: everything from Tasks 1-2.
- Produces: every "does this day have Prayer / Giving content" check across the whole codebase uses the same up-to-date logic — this is the explicit cross-file audit task the Global Constraints require, learning directly from the previous plan's final-review finding that this exact class of gap slips through when each task only fixes the file it happens to touch.

- [ ] **Step 1: Grep for every remaining consumer**

Run these searches yourself (the implementer) and enumerate every hit before editing anything:

```bash
grep -rn "givingType\|givingAmount\|givingPurpose" lib/ --include=*.dart | grep -v daily_log.dart
grep -rn "prayerAloneDuration\|prayerAloneNotes\|prayerOthersDuration\|prayerOthersContext" lib/ --include=*.dart | grep -v daily_log.dart
grep -rn "prayerAloneSessions\|prayerOthersSessions" lib/ --include=*.dart | grep -v daily_log.dart
```

For each hit, determine: does this consumer need to also check the new `title`-aware `PrayerSession` state or the `List<GivingEntry>`, or is it a genuinely unrelated read (e.g. a distinct manually-entered count field that Task 1's brainstorming already confirmed should stay untouched, like `evangelismContacts`)? Do not blindly change every hit — judge each on whether it's actually stale relative to Tasks 1-2's changes.

- [ ] **Step 2: Fix `DailyLog.completeness`**

In `lib/models/daily_log.dart`'s `completeness` getter (lines 378-391), the Giving check (line 387, `givingType.isNotEmpty`) needs updating to `giving.any((g) => g.isNotEmpty)`. The Prayer checks (lines 383-384) already correctly check `prayerAloneSessions.any((s) => s.isNotEmpty)` — confirm `PrayerSession.isEmpty` (updated in Task 1) correctly returns `false` for a session with only a `title` set (it does — `isEmpty` checks all four fields including `title`), so no further change needed there.

- [ ] **Step 3: Fix each of the four service files per the audit**

For each file the Step 1 grep surfaces as genuinely needing an update, apply the minimal fix: widen a boolean presence check to also cover the new field, or update a sum/list-iteration to read `log.giving` instead of the old scalars. Since this plan cannot enumerate every exact line without having freshly grepped this session (the codebase has moved since this plan's exploration phase completed), the implementer must:
1. Run the greps in Step 1 fresh.
2. For each hit, read ~10 lines of surrounding context.
3. Apply the same "OR in the new check" pattern already established throughout this plan and the prior plan's final-review fix wave (`lib/services/goal_progress_service.dart`'s existing `_durationField` helper, if still present, is the established template for this pattern — check whether a prior plan's fix already added it, per this plan's earlier note that it exists at time of the last plan's final review).

- [ ] **Step 4: Write/update tests**

For each file that already has a test file, add a test constructing a title-only Prayer session (or multi-entry Giving list) with no legacy scalar populated, and assert the consumer correctly registers it as "has content." Follow this plan's Global Constraint: do not invent a new test file for a service that doesn't already have one — note in your report which services lack test coverage entirely (this is a pre-existing gap, not something to fix as a side effect of this task).

- [ ] **Step 5: Run full test suite + analyzer**

Run: `flutter test --concurrency=1 && flutter analyze`
Expected: Green.

- [ ] **Step 6: Commit**

```bash
git add lib/models/daily_log.dart lib/services/goal_progress_service.dart lib/services/report_intelligence_service.dart lib/services/reflection_service.dart lib/services/pdf_report_service.dart
git commit -m "fix: extend completeness/goals/intelligence/reflection/PDF checks to Prayer titles and Giving list"
```

---

## Phase E — Cleanup and final verification

### Task 13: Remove Fasting's dead stopwatch pre-start-field code

**Files:**
- Modify: `lib/screens/stopwatch_screen.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: no behavioral change (this code is confirmed unreachable) — pure dead-code removal.

- [ ] **Step 1: Confirm unreachability**

Re-verify `_activityGrid` (around line 223, `ActivityType.values.where((a) => a != ActivityType.fasting)`) still excludes Fasting from the grid, and that no other code path calls `_showFieldsAndStart(ActivityType.fasting)` or `_fieldsFor(ActivityType.fasting)` (grep to confirm).

- [ ] **Step 2: Remove the dead case**

In `_fieldsFor`, remove the `case ActivityType.fasting:` block (currently returning `fastingType`/`fastingPrayerFocus` fields). Since `_fieldsFor`'s switch must remain exhaustive over `ActivityType` (Dart requires this), replace it with an empty-list return rather than deleting the case entirely:

```dart
      case ActivityType.fasting:
        return []; // Fasting is never timed via the stopwatch — see the
                   // multi-day FastingPeriod tracker in the Log screen instead
```

- [ ] **Step 3: Run analyzer**

Run: `flutter analyze`
Expected: Clean.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/stopwatch_screen.dart
git commit -m "chore: remove unreachable fasting pre-start-field code from stopwatch"
```

---

### Task 14: Full-suite regression pass

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `flutter test --concurrency=1`
Expected: All tests pass, including every test added across Tasks 1-13.

- [ ] **Step 2: Run the analyzer**

Run: `flutter analyze`
Expected: Zero new issues relative to this plan's starting baseline (re-run `flutter analyze` on the pre-Task-1 commit if needed to establish the exact baseline count, per this codebase's established convention of ~75 pre-existing info/warning lints).

- [ ] **Step 3: Manual end-to-end walkthrough**

Run the app and verify, in order:
1. Time a Bible reading with a starting book/chapter (required — try leaving it empty, confirm a validation error blocks Start), stop it, enter an ending reference (required, same validation), confirm the Log screen shows a real `BibleReadingEntry` and the report shows the reference AND chapters read.
2. Time Literature with a title (required at start) and amount (required at stop), confirm both appear correctly in the Log screen and report.
3. Time DDEG with a scripture (required at start), optional notes at stop.
4. Time Prayer Alone: title required at start (try the existing-topic chips), optional reflection at stop. Time it TWICE with the same title same day — confirm it merges into one session in the Log screen, not two.
5. Time Prayer with Others: title required at start, optional people-count at stop.
6. Time Evangelism: confirm NO pre-start prompt appears, confirm contacts+outcome are required at stop, notes optional.
7. Time Church: type required at start, notes optional at stop.
8. Time Proclamation: topic required, then confirm the COUNTER interaction (tap circle, count increments, background timer, Save) — not a generic stopwatch.
9. In the Log screen, manually add a second Giving entry (Tithe + separate Offering), confirm both appear as separate cards and both appear in the generated report.
10. Confirm Fasting has no Stopwatch tile (unchanged from before this plan).

- [ ] **Step 4: No commit for this task** — verification-only. If any issue is found, return to the relevant task above, fix, and commit there.
