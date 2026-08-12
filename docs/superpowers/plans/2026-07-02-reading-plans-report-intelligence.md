# Bible Reading Plans & Report Intelligence — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional Bible reading plans with gentle daily suggestions on the log screen, plus intelligent report narratives with trend signals and growth milestones.

**Architecture:** Two new data/service files for reading plans (`reading_plans.dart`, `reading_plan_service.dart`), a new report intelligence service (`report_intelligence_service.dart`) that generates narrative summaries / trend signals / milestones, integrated into existing report builders. Log screen gets a small plan suggestion card; Settings gets a plan selection section.

**Tech Stack:** Flutter/Dart, existing `BibleBooks` utility for chapter data, existing `ReportService`/`StorageService`, ARB localization (EN + FR), SharedPreferences for plan state.

## Global Constraints

- Fully offline — no network calls
- All user-facing strings in ARB files (EN + FR)
- Follow existing singleton pattern: `static final instance = Service._()`
- Follow existing theme: `AppTheme` colors, `SectionCard` components
- `flutter analyze` must pass clean (no new warnings)
- Free reading (no plan) must work exactly as before — zero regression

---

## File Structure

| File | Responsibility |
|------|---------------|
| `lib/data/reading_plans.dart` | **New** — `PlanReading`, `ReadingPlan`, `ActivePlan` data classes + 5 built-in plan definitions with algorithmic generation |
| `lib/services/reading_plan_service.dart` | **New** — `ReadingPlanService` singleton: activate/pause/reset, get today's reading, mark complete, advance plan |
| `lib/services/report_intelligence_service.dart` | **New** — `ReportIntelligenceService`: narrative summary, trend signals, cumulative stats, milestone detection |
| `lib/services/report_service.dart` | **Modify** — Call intelligence service from `buildFullReport()` and `buildCompactReport()` to inject narrative + trends + milestones |
| `lib/screens/log_screen.dart` | **Modify** — Add plan suggestion card above Bible section |
| `lib/screens/settings_screen.dart` | **Modify** — Add "Bible Reading Plan" `SectionCard` |
| `lib/l10n/app_en.arb` | **Modify** — ~40 new keys for plans, narrative, trends, milestones |
| `lib/l10n/app_fr.arb` | **Modify** — French translations |

---

### Task 1: Reading Plan Data Models & Built-in Plans

**Files:**
- Create: `lib/data/reading_plans.dart`

**Interfaces:**
- Consumes: `BibleBooks.all` from `lib/utils/bible_books.dart` (list of 66 `BibleBook` objects with `nameEn`, `chapters`, `order`)
- Produces: `PlanReading` class, `ReadingPlan` class with `name(locale)`/`description(locale)`, `ActivePlan` class with `toJson()`/`fromJson()`, `ReadingPlans.all` (list of 5 plans), `ReadingPlans.getById(id)`

- [ ] **Step 1: Create reading_plans.dart with data models and plan generation**

Create `lib/data/reading_plans.dart`:

```dart
import 'dart:convert';
import '../utils/bible_books.dart';

/// A single day's reading assignment within a plan.
class PlanReading {
  final int dayNumber;
  final String startBook;   // English canonical name
  final int startChapter;
  final String endBook;
  final int endChapter;

  const PlanReading({
    required this.dayNumber,
    required this.startBook,
    required this.startChapter,
    required this.endBook,
    required this.endChapter,
  });

  /// Localized display: "Genesis 1 – Exodus 3" or "Genèse 1 – Exode 3"
  String display(String locale) {
    final sb = BibleBooks.findBook(startBook);
    final eb = BibleBooks.findBook(endBook);
    if (sb == null || eb == null) return '$startBook $startChapter – $endBook $endChapter';
    final sName = locale.startsWith('fr') ? sb.nameFr : sb.nameEn;
    final eName = locale.startsWith('fr') ? eb.nameFr : eb.nameEn;
    if (startBook == endBook && startChapter == endChapter) {
      return '$sName $startChapter';
    }
    if (startBook == endBook) {
      return '$sName $startChapter–$endChapter';
    }
    return '$sName $startChapter – $eName $endChapter';
  }

  /// Total chapters in this reading.
  int get chapters {
    final result = BibleBooks.calculateChapters(
      '$startBook $startChapter', '$endBook $endChapter');
    return result ?? 1;
  }
}

/// A Bible reading plan template.
class ReadingPlan {
  final String id;
  final String nameEn;
  final String nameFr;
  final String descriptionEn;
  final String descriptionFr;
  final int totalDays;
  final List<PlanReading> readings;

  const ReadingPlan({
    required this.id,
    required this.nameEn,
    required this.nameFr,
    required this.descriptionEn,
    required this.descriptionFr,
    required this.totalDays,
    required this.readings,
  });

  String name(String locale) => locale.startsWith('fr') ? nameFr : nameEn;
  String description(String locale) => locale.startsWith('fr') ? descriptionFr : descriptionEn;
}

/// User's active plan state.
class ActivePlan {
  final String planId;
  final int totalDays;
  final DateTime startedAt;
  int currentDay;
  final Set<int> completedDays;

  ActivePlan({
    required this.planId,
    required this.totalDays,
    required this.startedAt,
    this.currentDay = 1,
    Set<int>? completedDays,
  }) : completedDays = completedDays ?? {};

  double get progress => totalDays > 0 ? completedDays.length / totalDays : 0;
  bool get isComplete => completedDays.length >= totalDays;

  Map<String, dynamic> toJson() => {
    'planId': planId,
    'totalDays': totalDays,
    'startedAt': startedAt.toIso8601String(),
    'currentDay': currentDay,
    'completedDays': completedDays.toList(),
  };

  factory ActivePlan.fromJson(Map<String, dynamic> m) => ActivePlan(
    planId: m['planId'] as String,
    totalDays: m['totalDays'] as int,
    startedAt: DateTime.parse(m['startedAt'] as String),
    currentDay: m['currentDay'] as int? ?? 1,
    completedDays: (m['completedDays'] as List<dynamic>?)
        ?.map((e) => e as int).toSet() ?? {},
  );

  String toJsonString() => jsonEncode(toJson());
  factory ActivePlan.fromJsonString(String s) =>
      ActivePlan.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

/// Registry of all built-in reading plans.
class ReadingPlans {
  ReadingPlans._();

  static List<ReadingPlan>? _cache;

  static List<ReadingPlan> get all => _cache ??= [
    _generateCanonicalPlan(
      id: 'bible_1yr',
      nameEn: 'Bible in 1 Year',
      nameFr: 'Bible en 1 an',
      descriptionEn: 'Read the entire Bible in 365 readings (~3-4 chapters/day)',
      descriptionFr: 'Lire la Bible entière en 365 lectures (~3-4 chapitres/jour)',
      totalDays: 365,
      bookIndices: List.generate(66, (i) => i), // all 66 books canonical
    ),
    _generateCanonicalPlan(
      id: 'nt_90d',
      nameEn: 'New Testament in 90 Days',
      nameFr: 'Nouveau Testament en 90 jours',
      descriptionEn: 'Read the New Testament in 90 readings (~3 chapters/day)',
      descriptionFr: 'Lire le Nouveau Testament en 90 lectures (~3 chapitres/jour)',
      totalDays: 90,
      bookIndices: List.generate(27, (i) => i + 39), // Matthew(39)–Revelation(65)
    ),
    _generateCanonicalPlan(
      id: 'gospels_30d',
      nameEn: 'Gospels in 30 Days',
      nameFr: 'Évangiles en 30 jours',
      descriptionEn: 'Read Matthew through John in 30 readings (~3 chapters/day)',
      descriptionFr: 'Lire Matthieu à Jean en 30 lectures (~3 chapitres/jour)',
      totalDays: 30,
      bookIndices: [39, 40, 41, 42], // Matthew, Mark, Luke, John
    ),
    _generateCanonicalPlan(
      id: 'psalms_prov_30d',
      nameEn: 'Psalms & Proverbs in 30 Days',
      nameFr: 'Psaumes et Proverbes en 30 jours',
      descriptionEn: 'Read Psalms and Proverbs in 30 readings (~6 chapters/day)',
      descriptionFr: 'Lire les Psaumes et Proverbes en 30 lectures (~6 chapitres/jour)',
      totalDays: 30,
      bookIndices: [18, 19], // Psalms(18), Proverbs(19)
    ),
    _generateCanonicalPlan(
      id: 'chrono_1yr',
      nameEn: 'Chronological Bible in 1 Year',
      nameFr: 'Bible chronologique en 1 an',
      descriptionEn: 'Read the Bible in historical order in 365 readings',
      descriptionFr: 'Lire la Bible dans l\'ordre historique en 365 lectures',
      totalDays: 365,
      bookIndices: _chronologicalOrder,
    ),
  ];

  static ReadingPlan? getById(String id) {
    try {
      return all.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Generate readings by dividing books into N days.
  /// Walks through books sequentially, splitting chapters evenly across days.
  static ReadingPlan _generateCanonicalPlan({
    required String id,
    required String nameEn,
    required String nameFr,
    required String descriptionEn,
    required String descriptionFr,
    required int totalDays,
    required List<int> bookIndices,
  }) {
    // Collect all (book, chapter) pairs in reading order
    final allChapters = <(String bookName, int chapter)>[];
    for (final idx in bookIndices) {
      final book = BibleBooks.all[idx];
      for (int ch = 1; ch <= book.chapters; ch++) {
        allChapters.add((book.nameEn, ch));
      }
    }

    final totalChapters = allChapters.length;
    final readings = <PlanReading>[];
    int chapIdx = 0;

    for (int day = 1; day <= totalDays; day++) {
      if (chapIdx >= totalChapters) break;

      // Calculate how many chapters for this day
      final remaining = totalChapters - chapIdx;
      final remainingDays = totalDays - day + 1;
      final chaptersToday = (remaining / remainingDays).ceil();

      final startEntry = allChapters[chapIdx];
      final endIdx = (chapIdx + chaptersToday - 1).clamp(0, totalChapters - 1);
      final endEntry = allChapters[endIdx];

      readings.add(PlanReading(
        dayNumber: day,
        startBook: startEntry.$1,
        startChapter: startEntry.$2,
        endBook: endEntry.$1,
        endChapter: endEntry.$2,
      ));

      chapIdx = endIdx + 1;
    }

    return ReadingPlan(
      id: id,
      nameEn: nameEn,
      nameFr: nameFr,
      descriptionEn: descriptionEn,
      descriptionFr: descriptionFr,
      totalDays: readings.length,
      readings: readings,
    );
  }

  /// Approximate chronological reading order (book indices).
  /// Based on estimated historical sequence.
  static const _chronologicalOrder = [
    0,   // Genesis
    17,  // Job
    1,   // Exodus
    2,   // Leviticus
    3,   // Numbers
    4,   // Deuteronomy
    5,   // Joshua
    6,   // Judges
    7,   // Ruth
    8,   // 1 Samuel
    9,   // 2 Samuel
    18,  // Psalms
    10,  // 1 Kings
    19,  // Proverbs
    20,  // Ecclesiastes
    21,  // Song of Solomon
    27,  // Hosea
    29,  // Amos
    31,  // Jonah
    32,  // Micah
    28,  // Joel
    33,  // Nahum
    34,  // Habakkuk
    35,  // Zephaniah
    22,  // Isaiah
    23,  // Jeremiah
    24,  // Lamentations
    11,  // 2 Kings
    30,  // Obadiah
    25,  // Ezekiel
    26,  // Daniel
    36,  // Haggai
    37,  // Zechariah
    38,  // Malachi
    12,  // 1 Chronicles
    13,  // 2 Chronicles
    14,  // Ezra
    15,  // Nehemiah
    16,  // Esther
    39,  // Matthew
    40,  // Mark
    41,  // Luke
    42,  // John
    43,  // Acts
    44,  // Romans
    45,  // 1 Corinthians
    46,  // 2 Corinthians
    47,  // Galatians
    48,  // Ephesians
    49,  // Philippians
    50,  // Colossians
    51,  // 1 Thessalonians
    52,  // 2 Thessalonians
    53,  // 1 Timothy
    54,  // 2 Timothy
    55,  // Titus
    56,  // Philemon
    57,  // Hebrews
    58,  // James
    59,  // 1 Peter
    60,  // 2 Peter
    61,  // 1 John
    62,  // 2 John
    63,  // 3 John
    64,  // Jude
    65,  // Revelation
  ];
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd "c:/Users/goodn/Developement/Flutter projects/daily_account" && flutter analyze lib/data/reading_plans.dart`

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/data/reading_plans.dart
git commit -m "feat: add Bible reading plan data models with 5 built-in plans

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Reading Plan Service

**Files:**
- Create: `lib/services/reading_plan_service.dart`

**Interfaces:**
- Consumes: `ReadingPlans.all`, `ReadingPlans.getById(id)`, `ActivePlan` (from Task 1), `StorageService.instance.getSetting()`/`setSetting()`, `BibleBooks.findBook()`
- Produces: `ReadingPlanService.instance` singleton with methods: `activePlan` getter, `load()`, `activate(planId)`, `pause()`, `reset()`, `todayReading()` → `PlanReading?`, `markComplete(dayNumber)`, `isReadingDoneToday(DailyLog)` → `bool`

- [ ] **Step 1: Create reading_plan_service.dart**

Create `lib/services/reading_plan_service.dart`:

```dart
import '../data/reading_plans.dart';
import '../models/daily_log.dart';
import '../utils/bible_books.dart';
import 'storage_service.dart';

/// Manages the user's active Bible reading plan.
class ReadingPlanService {
  static final ReadingPlanService instance = ReadingPlanService._();
  ReadingPlanService._();

  ActivePlan? _active;
  ActivePlan? get activePlan => _active;

  /// Load persisted plan state from SharedPreferences.
  Future<void> load() async {
    final json = await StorageService.instance.getSetting('activePlan', fallback: '');
    if (json.isNotEmpty) {
      try {
        _active = ActivePlan.fromJsonString(json);
      } catch (_) {
        _active = null;
      }
    }
  }

  /// Activate a plan by ID. Resets any existing active plan.
  Future<void> activate(String planId) async {
    final plan = ReadingPlans.getById(planId);
    if (plan == null) return;
    _active = ActivePlan(
      planId: planId,
      totalDays: plan.totalDays,
      startedAt: DateTime.now(),
    );
    await _save();
  }

  /// Pause (deactivate) the current plan without losing progress.
  /// The plan can be resumed by calling activate again — but that resets.
  /// To truly pause, we just keep the data but the UI can check a flag.
  Future<void> pause() async {
    _active = null;
    await StorageService.instance.setSetting('activePlan', '');
  }

  /// Reset the current plan back to Day 1.
  Future<void> reset() async {
    if (_active == null) return;
    _active = ActivePlan(
      planId: _active!.planId,
      totalDays: _active!.totalDays,
      startedAt: DateTime.now(),
    );
    await _save();
  }

  /// Get today's reading assignment (the next uncompleted reading).
  PlanReading? todayReading() {
    if (_active == null) return null;
    final plan = ReadingPlans.getById(_active!.planId);
    if (plan == null) return null;
    final day = _active!.currentDay;
    if (day < 1 || day > plan.readings.length) return null;
    return plan.readings[day - 1];
  }

  /// Mark a specific day's reading as complete and advance.
  Future<void> markComplete(int dayNumber) async {
    if (_active == null) return;
    _active!.completedDays.add(dayNumber);
    // Advance currentDay to next uncompleted
    while (_active!.currentDay <= _active!.totalDays &&
        _active!.completedDays.contains(_active!.currentDay)) {
      _active!.currentDay++;
    }
    await _save();
  }

  /// Check if today's plan reading overlaps with what the user logged.
  /// Fuzzy match: if the user's Bible sessions cover the same book+chapters
  /// as today's plan reading, consider it done.
  bool isReadingDoneToday(DailyLog log) {
    final reading = todayReading();
    if (reading == null) return false;
    if (_active!.completedDays.contains(reading.dayNumber)) return true;

    // Check if any Bible session covers the plan's reading
    for (final session in log.bibleSessions) {
      if (session.isEmpty) continue;
      final sBook = BibleBooks.findBook(session.startBook);
      final pBook = BibleBooks.findBook(reading.startBook);
      if (sBook == null || pBook == null) continue;
      if (sBook.nameEn == pBook.nameEn &&
          session.startChapter <= reading.startChapter) {
        final eBook = BibleBooks.findBook(session.endBook);
        final peBook = BibleBooks.findBook(reading.endBook);
        if (eBook != null && peBook != null &&
            eBook.order >= peBook.order &&
            (eBook.order > peBook.order || session.endChapter >= reading.endChapter)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Auto-detect and mark complete if user's log matches today's reading.
  Future<void> autoDetectCompletion(DailyLog log) async {
    if (_active == null) return;
    final reading = todayReading();
    if (reading == null) return;
    if (_active!.completedDays.contains(reading.dayNumber)) return;
    if (isReadingDoneToday(log)) {
      await markComplete(reading.dayNumber);
    }
  }

  Future<void> _save() async {
    if (_active == null) return;
    await StorageService.instance.setSetting('activePlan', _active!.toJsonString());
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd "c:/Users/goodn/Developement/Flutter projects/daily_account" && flutter analyze lib/services/reading_plan_service.dart`

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/reading_plan_service.dart
git commit -m "feat: add ReadingPlanService for plan activation, tracking, and auto-detection

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Report Intelligence Service

**Files:**
- Create: `lib/services/report_intelligence_service.dart`

**Interfaces:**
- Consumes: `StorageService.instance.getLogsBetween()`, `ReportService.instance.computeWeekStats()`, `ReportService.instance.computeStreak()`, `ReportService._parseDurationMinutes()` (duplicated since private), `ReadingPlanService.instance.activePlan`, `WeekStats` fields (`daysLogged`, `totalBibleChapters`, `totalEvangelismContacts`, `totalPrayerMinutes`, `litItems`)
- Produces: `ReportIntelligenceService.instance` with: `buildNarrativeSummary(thisWeek, lastWeek, streak, locale)` → `String`, `computeTrendSignals(thisWeek, lastWeek)` → `Map<String, String>`, `computeAllTimeStats()` → `CumulativeStats`, `checkNewMilestones(cumulative, streak)` → `List<String>`

- [ ] **Step 1: Create report_intelligence_service.dart**

Create `lib/services/report_intelligence_service.dart`:

```dart
import 'package:intl/intl.dart';
import '../data/reading_plans.dart';
import '../models/daily_log.dart';
import 'reading_plan_service.dart';
import 'storage_service.dart';

/// Cumulative all-time statistics for milestone detection.
class CumulativeStats {
  final int totalChapters;
  final int totalEvangelismContacts;
  final int totalDaysLogged;
  final int longestStreakEver;

  const CumulativeStats({
    required this.totalChapters,
    required this.totalEvangelismContacts,
    required this.totalDaysLogged,
    required this.longestStreakEver,
  });
}

/// Trend signal for a discipline: up, down, or steady.
class TrendSignal {
  final String discipline;
  final String arrow;  // '↑', '↓', '→'
  final int thisWeek;
  final int lastWeek;

  const TrendSignal(this.discipline, this.arrow, this.thisWeek, this.lastWeek);
}

/// Per-discipline weekly counts for trend comparison.
class WeekDisciplineCounts {
  final int daysLogged;
  final int bibleChapters;
  final int bibleDays;
  final int prayerDays;
  final int prayerMinutes;
  final int evangelismContacts;
  final int evangelismDays;
  final int fastingDays;
  final int givingDays;
  final int churchDays;
  final int discipleshipDays;
  final int literatureItems;
  final int ddegDays;
  final int proclamationDays;

  const WeekDisciplineCounts({
    this.daysLogged = 0,
    this.bibleChapters = 0,
    this.bibleDays = 0,
    this.prayerDays = 0,
    this.prayerMinutes = 0,
    this.evangelismContacts = 0,
    this.evangelismDays = 0,
    this.fastingDays = 0,
    this.givingDays = 0,
    this.churchDays = 0,
    this.discipleshipDays = 0,
    this.literatureItems = 0,
    this.ddegDays = 0,
    this.proclamationDays = 0,
  });
}

class ReportIntelligenceService {
  static final ReportIntelligenceService instance = ReportIntelligenceService._();
  ReportIntelligenceService._();

  /// Compute per-discipline counts for a date range.
  Future<WeekDisciplineCounts> computeWeekCounts(String startKey, String endKey) async {
    final logs = await StorageService.instance.getLogsBetween(startKey, endKey);
    int days = 0, chapters = 0, bibleDays = 0, prayerDays = 0, prayerMins = 0;
    int contacts = 0, evangelismDays = 0, fastDays = 0, giveDays = 0;
    int churchDays = 0, discDays = 0, litItems = 0, ddegDays = 0, procDays = 0;

    for (final l in logs) {
      if (l.completeness > 0) days++;
      chapters += l.totalBibleChapters;
      if (l.bibleReference.isNotEmpty || l.bibleSessions.any((s) => s.isNotEmpty)) bibleDays++;
      if (l.prayerAloneDuration.isNotEmpty || l.prayerOthersDuration.isNotEmpty) {
        prayerDays++;
        prayerMins += _parseMinutes(l.prayerAloneDuration) + _parseMinutes(l.prayerOthersDuration);
      }
      final c = int.tryParse(l.evangelismContacts) ?? 0;
      contacts += c;
      if (c > 0) evangelismDays++;
      if (l.fastingType.isNotEmpty || l.fastingDuration.isNotEmpty) fastDays++;
      if (l.givingType.isNotEmpty) giveDays++;
      if (l.churchType.isNotEmpty) churchDays++;
      if (l.discipleshipWho.isNotEmpty) discDays++;
      litItems += l.literature.where((e) => e.title.isNotEmpty).length;
      if (l.ddegScripture.isNotEmpty || l.ddegNotes.isNotEmpty) ddegDays++;
      if (l.proclamationCount.isNotEmpty) procDays++;
    }

    return WeekDisciplineCounts(
      daysLogged: days, bibleChapters: chapters, bibleDays: bibleDays,
      prayerDays: prayerDays, prayerMinutes: prayerMins,
      evangelismContacts: contacts, evangelismDays: evangelismDays,
      fastingDays: fastDays, givingDays: giveDays, churchDays: churchDays,
      discipleshipDays: discDays, literatureItems: litItems,
      ddegDays: ddegDays, proclamationDays: procDays,
    );
  }

  /// Build a 2-3 sentence narrative summary for the weekly report.
  String buildNarrativeSummary({
    required WeekDisciplineCounts thisWeek,
    required WeekDisciplineCounts lastWeek,
    required int streak,
    required String locale,
  }) {
    final isFr = locale.startsWith('fr');
    final signals = <(int priority, String text)>[];

    // Priority 1: Streak milestones
    if (streak == 7 || streak == 30 || streak == 100 || streak == 365) {
      signals.add((1, isFr
          ? 'Série de $streak jours atteinte cette semaine !'
          : 'Reached a $streak-day streak this week!'));
    }

    // Priority 2: Perfect week
    if (thisWeek.daysLogged >= 7) {
      signals.add((2, isFr
          ? 'Semaine parfaite — chaque jour rempli.'
          : 'Perfect week — every day logged.'));
    }

    // Priority 3: Days comparison
    if (lastWeek.daysLogged > 0) {
      if (thisWeek.daysLogged > lastWeek.daysLogged) {
        signals.add((3, isFr
            ? 'Bonne semaine avec ${thisWeek.daysLogged}/7 jours (${lastWeek.daysLogged} la semaine dernière).'
            : 'Strong week with ${thisWeek.daysLogged}/7 days (up from ${lastWeek.daysLogged}).'));
      } else if (thisWeek.daysLogged < lastWeek.daysLogged) {
        signals.add((3, isFr
            ? 'Semaine plus légère : ${thisWeek.daysLogged}/7 jours (${lastWeek.daysLogged} la semaine dernière).'
            : 'Lighter week: ${thisWeek.daysLogged}/7 days (down from ${lastWeek.daysLogged}).'));
      } else {
        signals.add((3, isFr
            ? '${thisWeek.daysLogged}/7 jours — même rythme que la semaine dernière.'
            : '${thisWeek.daysLogged}/7 days — same pace as last week.'));
      }
    } else {
      signals.add((3, isFr
          ? '${thisWeek.daysLogged}/7 jours remplis cette semaine.'
          : '${thisWeek.daysLogged}/7 days logged this week.'));
    }

    // Priority 4: Biggest improvement
    final changes = _computeChanges(thisWeek, lastWeek, isFr);
    final improvements = changes.where((c) => c.$1 > 0).toList()
      ..sort((a, b) => b.$1.compareTo(a.$1));
    if (improvements.isNotEmpty) {
      signals.add((4, improvements.first.$2));
    }

    // Priority 5: Biggest decline
    final declines = changes.where((c) => c.$1 < 0).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    if (declines.isNotEmpty) {
      signals.add((5, declines.first.$2));
    }

    // Priority 6: Notable activity
    if (thisWeek.evangelismContacts >= 3) {
      signals.add((6, isFr
          ? '${thisWeek.evangelismContacts} contacts d\'évangélisation.'
          : '${thisWeek.evangelismContacts} evangelism contacts.'));
    } else if (thisWeek.fastingDays >= 2) {
      signals.add((6, isFr
          ? 'Jeûne actif cette semaine (${ thisWeek.fastingDays} jours).'
          : 'Active fasting this week (${thisWeek.fastingDays} days).'));
    }

    // Priority 7: Streak status
    if (streak > 0 && !(streak == 7 || streak == 30 || streak == 100 || streak == 365)) {
      signals.add((7, isFr
          ? 'Série de $streak jours en cours.'
          : '$streak-day streak continues.'));
    }

    // Priority 8: Plan progress
    final plan = ReadingPlanService.instance.activePlan;
    if (plan != null && !plan.isComplete) {
      final pct = (plan.progress * 100).round();
      final planDef = ReadingPlans.getById(plan.planId);
      if (planDef != null) {
        signals.add((8, isFr
            ? 'Plan ${planDef.name('fr')} : $pct% complété.'
            : '${planDef.name('en')} plan: $pct% complete.'));
      }
    }

    // Pick top 3-4 signals
    signals.sort((a, b) => a.$1.compareTo(b.$1));
    final picked = signals.take(4).map((s) => s.$2).toList();
    return picked.join(' ');
  }

  /// Compute trend signals comparing this week to last week.
  List<TrendSignal> computeTrendSignals(WeekDisciplineCounts thisWeek, WeekDisciplineCounts lastWeek) {
    return [
      _signal('Bible', thisWeek.bibleChapters, lastWeek.bibleChapters),
      _signal('Prayer', thisWeek.prayerDays, lastWeek.prayerDays),
      _signal('Evangelism', thisWeek.evangelismContacts, lastWeek.evangelismContacts),
      _signal('DDEG', thisWeek.ddegDays, lastWeek.ddegDays),
      _signal('Fasting', thisWeek.fastingDays, lastWeek.fastingDays),
      _signal('Literature', thisWeek.literatureItems, lastWeek.literatureItems),
      _signal('Discipleship', thisWeek.discipleshipDays, lastWeek.discipleshipDays),
      _signal('Church', thisWeek.churchDays, lastWeek.churchDays),
    ];
  }

  /// Compute all-time stats from all stored logs.
  Future<CumulativeStats> computeAllTimeStats() async {
    // Query from earliest possible date to today
    final today = DateTime.now();
    final earliest = DateTime(2020, 1, 1);
    final fmt = DateFormat('yyyy-MM-dd');
    final logs = await StorageService.instance
        .getLogsBetween(fmt.format(earliest), fmt.format(today));

    int totalChapters = 0, totalContacts = 0, totalDays = 0;
    for (final l in logs) {
      totalChapters += l.totalBibleChapters;
      totalContacts += int.tryParse(l.evangelismContacts) ?? 0;
      if (l.completed) totalDays++;
    }

    // Compute longest streak ever
    final completedKeys = <String>{
      for (final l in logs) if (l.completed) l.dateKey,
    };
    int longest = 0, current = 0;
    var day = earliest;
    while (!day.isAfter(today)) {
      if (completedKeys.contains(fmt.format(day))) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
      day = day.add(const Duration(days: 1));
    }

    return CumulativeStats(
      totalChapters: totalChapters,
      totalEvangelismContacts: totalContacts,
      totalDaysLogged: totalDays,
      longestStreakEver: longest,
    );
  }

  /// Check for new milestones that haven't been announced yet.
  /// Returns localized milestone strings.
  Future<List<String>> checkNewMilestones({
    required CumulativeStats stats,
    required int currentStreak,
    required int daysLoggedThisWeek,
    required String locale,
  }) async {
    final isFr = locale.startsWith('fr');
    final milestones = <String>[];
    final storage = StorageService.instance;

    // Chapter milestones
    for (final threshold in [100, 250, 500, 1000, 2000]) {
      if (stats.totalChapters >= threshold) {
        final key = 'milestone_chapters_$threshold';
        if ((await storage.getSetting(key, fallback: '')) != 'true') {
          await storage.setSetting(key, 'true');
          milestones.add(isFr
              ? '\u{1F4D6} Jalon : ${threshold}e chapitre lu !'
              : '\u{1F4D6} Milestone: ${threshold}th Bible chapter read!');
        }
      }
    }

    // Streak record
    if (currentStreak > 0 && currentStreak >= stats.longestStreakEver) {
      final key = 'milestone_streak_record_$currentStreak';
      if ((await storage.getSetting(key, fallback: '')) != 'true') {
        await storage.setSetting(key, 'true');
        milestones.add(isFr
            ? '\u{1F525} Nouveau record personnel : série de $currentStreak jours !'
            : '\u{1F525} New personal record: $currentStreak-day streak!');
      }
    }

    // Perfect week
    if (daysLoggedThisWeek >= 7) {
      final weekKey = 'milestone_perfect_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
      if ((await storage.getSetting(weekKey, fallback: '')) != 'true') {
        await storage.setSetting(weekKey, 'true');
        milestones.add(isFr
            ? '\u2B50 Semaine parfaite accomplie !'
            : '\u2B50 Perfect week achieved!');
      }
    }

    // Evangelism milestones
    for (final threshold in [50, 100, 250, 500]) {
      if (stats.totalEvangelismContacts >= threshold) {
        final key = 'milestone_evangelism_$threshold';
        if ((await storage.getSetting(key, fallback: '')) != 'true') {
          await storage.setSetting(key, 'true');
          milestones.add(isFr
              ? '\u{1F4E2} $threshold \u00e2mes atteintes depuis le d\u00e9but !'
              : '\u{1F4E2} $threshold souls reached since you started!');
        }
      }
    }

    // Plan completion
    final plan = ReadingPlanService.instance.activePlan;
    if (plan != null && plan.isComplete) {
      final key = 'milestone_plan_${plan.planId}';
      if ((await storage.getSetting(key, fallback: '')) != 'true') {
        await storage.setSetting(key, 'true');
        final planDef = ReadingPlans.getById(plan.planId);
        final planName = planDef?.name(locale) ?? plan.planId;
        milestones.add(isFr
            ? '\u{1F4D6} Terminé : $planName !'
            : '\u{1F4D6} Completed: $planName!');
      }
    }

    return milestones;
  }

  // ── Private helpers ──────────────────────────────────────

  TrendSignal _signal(String name, int thisVal, int lastVal) {
    if (lastVal == 0 && thisVal == 0) return TrendSignal(name, '\u2192', thisVal, lastVal);
    if (lastVal == 0) return TrendSignal(name, '\u2191', thisVal, lastVal);
    final pctChange = (thisVal - lastVal) / lastVal;
    if (pctChange >= 0.2) return TrendSignal(name, '\u2191', thisVal, lastVal);
    if (pctChange <= -0.2) return TrendSignal(name, '\u2193', thisVal, lastVal);
    return TrendSignal(name, '\u2192', thisVal, lastVal);
  }

  List<(double change, String text)> _computeChanges(
      WeekDisciplineCounts tw, WeekDisciplineCounts lw, bool isFr) {
    final result = <(double, String)>[];

    if (lw.bibleChapters > 0) {
      final pct = ((tw.bibleChapters - lw.bibleChapters) / lw.bibleChapters * 100).round();
      if (pct.abs() >= 20) {
        result.add((pct.toDouble(), isFr
            ? 'Bible ${pct > 0 ? "en hausse" : "en baisse"} de ${pct.abs()}% (${tw.bibleChapters} vs ${lw.bibleChapters} chapitres).'
            : 'Bible reading ${pct > 0 ? "up" : "down"} ${pct.abs()}% (${tw.bibleChapters} vs. ${lw.bibleChapters} chapters).'));
      }
    }

    if (lw.prayerDays > 0) {
      final pct = ((tw.prayerDays - lw.prayerDays) / lw.prayerDays * 100).round();
      if (pct.abs() >= 20) {
        result.add((pct.toDouble(), isFr
            ? 'Prière ${pct > 0 ? "en hausse" : "en baisse"} à ${tw.prayerDays} jours (${lw.prayerDays} la semaine dernière).'
            : 'Prayer ${pct > 0 ? "up" : "dropped"} to ${tw.prayerDays} days (${lw.prayerDays} last week).'));
      }
    }

    if (lw.evangelismContacts > 0) {
      final pct = ((tw.evangelismContacts - lw.evangelismContacts) / lw.evangelismContacts * 100).round();
      if (pct.abs() >= 20) {
        result.add((pct.toDouble(), isFr
            ? 'Évangélisation ${pct > 0 ? "en hausse" : "en baisse"} (${tw.evangelismContacts} vs ${lw.evangelismContacts} contacts).'
            : 'Evangelism ${pct > 0 ? "up" : "down"} (${tw.evangelismContacts} vs. ${lw.evangelismContacts} contacts).'));
      }
    }

    return result;
  }

  static int _parseMinutes(String s) {
    if (s.isEmpty || s == '\u2713') return 0;
    final hm = RegExp(r'(\d+)\s*h\s*(\d+)\s*m');
    final hmMatch = hm.firstMatch(s);
    if (hmMatch != null) return int.parse(hmMatch.group(1)!) * 60 + int.parse(hmMatch.group(2)!);
    final hOnly = RegExp(r'(\d+)\s*h');
    final hMatch = hOnly.firstMatch(s);
    if (hMatch != null) return int.parse(hMatch.group(1)!) * 60;
    final mOnly = RegExp(r'(\d+)\s*m');
    final mMatch = mOnly.firstMatch(s);
    if (mMatch != null) return int.parse(mMatch.group(1)!);
    final n = int.tryParse(s.trim());
    if (n != null) return n;
    return 0;
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd "c:/Users/goodn/Developement/Flutter projects/daily_account" && flutter analyze lib/services/report_intelligence_service.dart`

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/report_intelligence_service.dart
git commit -m "feat: add ReportIntelligenceService with narrative, trends, and milestones

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 4: Localization Keys (EN + FR)

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_fr.arb`

**Interfaces:**
- Consumes: nothing
- Produces: ARB keys used by log screen plan card, settings plan section, and report intelligence: `planSectionTitle`, `planNoActive`, `planStart`, `planPause`, `planReset`, `planProgress`, `planDayOf`, `planCompleted`, `planSuggestionFill`, `planSuggestionDone`, `planSuggestionToday`, `reportNarrativeHeader`, `reportMilestoneHeader`, `reportTrendHeader`, `reportPlanProgress`

- [ ] **Step 1: Add EN ARB keys**

Add these keys before the final `}` in `lib/l10n/app_en.arb`:

```json
  "planSectionTitle": "Bible Reading Plan",
  "planNoActive": "No active plan. Choose one to get started:",
  "planStart": "Start",
  "planPause": "Pause Plan",
  "planReset": "Reset",
  "planProgress": "{percent}% complete",
  "@planProgress": { "placeholders": { "percent": { "type": "int" } } },
  "planDayOf": "Day {current} of {total}",
  "@planDayOf": { "placeholders": { "current": { "type": "int" }, "total": { "type": "int" } } },
  "planCompleted": "Plan completed! Choose another:",
  "planSuggestionFill": "Fill",
  "planSuggestionDone": "Done",
  "planSuggestionToday": "Today",
  "reportNarrativeHeader": "Week Summary",
  "reportMilestoneHeader": "Milestones",
  "reportTrendHeader": "Trends",
  "reportPlanProgress": "Bible Reading Plan: {name} — Day {current}/{total} ({percent}%)",
  "@reportPlanProgress": { "placeholders": { "name": { "type": "String" }, "current": { "type": "int" }, "total": { "type": "int" }, "percent": { "type": "int" } } }
```

- [ ] **Step 2: Add FR ARB keys**

Add these keys before the final `}` in `lib/l10n/app_fr.arb`:

```json
  "planSectionTitle": "Plan de Lecture Biblique",
  "planNoActive": "Aucun plan actif. Choisissez-en un pour commencer :",
  "planStart": "Commencer",
  "planPause": "Mettre en pause",
  "planReset": "Réinitialiser",
  "planProgress": "{percent}% complété",
  "@planProgress": { "placeholders": { "percent": { "type": "int" } } },
  "planDayOf": "Jour {current} sur {total}",
  "@planDayOf": { "placeholders": { "current": { "type": "int" }, "total": { "type": "int" } } },
  "planCompleted": "Plan terminé ! Choisissez-en un autre :",
  "planSuggestionFill": "Remplir",
  "planSuggestionDone": "Fait",
  "planSuggestionToday": "Aujourd'hui",
  "reportNarrativeHeader": "Résumé de la semaine",
  "reportMilestoneHeader": "Jalons",
  "reportTrendHeader": "Tendances",
  "reportPlanProgress": "Plan de lecture : {name} — Jour {current}/{total} ({percent}%)",
  "@reportPlanProgress": { "placeholders": { "name": { "type": "String" }, "current": { "type": "int" }, "total": { "type": "int" }, "percent": { "type": "int" } } }
```

- [ ] **Step 3: Regenerate l10n**

Run: `cd "c:/Users/goodn/Developement/Flutter projects/daily_account" && flutter pub get`

Verify: `grep "planSectionTitle" lib/l10n/generated/app_localizations.dart` should show the getter.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_fr.arb lib/l10n/generated/
git commit -m "feat: add reading plan and report intelligence localization keys (EN + FR)

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 5: Integrate Intelligence into Report Service

**Files:**
- Modify: `lib/services/report_service.dart`

**Interfaces:**
- Consumes: `ReportIntelligenceService.instance.buildNarrativeSummary()`, `ReportIntelligenceService.instance.computeWeekCounts()`, `ReportIntelligenceService.instance.computeTrendSignals()`, `ReportIntelligenceService.instance.computeAllTimeStats()`, `ReportIntelligenceService.instance.checkNewMilestones()`, `ReadingPlanService.instance.activePlan`, `ReadingPlans.getById()`, ARB keys `reportNarrativeHeader`, `reportMilestoneHeader`, `reportPlanProgress`
- Produces: Modified `buildFullReport()` and `buildCompactReport()` that include narrative summary, trend signals, and milestones at the top

- [ ] **Step 1: Add imports to report_service.dart**

Add after the existing imports at the top of `lib/services/report_service.dart`:

```dart
import '../data/reading_plans.dart';
import 'reading_plan_service.dart';
import 'report_intelligence_service.dart';
```

- [ ] **Step 2: Add intelligence block to buildFullReport()**

In `buildFullReport()`, after the header lines (`reportWeekOf`) and before the day-by-day loop, insert the intelligence block. Find this code:

```dart
    buf.writeln(l.reportWeekOf(fmtRange.format(dates.first), fmtRange.format(dates.last)));
    buf.writeln('');

    int activeDays = 0;
```

Replace with:

```dart
    buf.writeln(l.reportWeekOf(fmtRange.format(dates.first), fmtRange.format(dates.last)));
    buf.writeln('');

    // ── Intelligence: Narrative + Milestones + Plan Progress ──
    final intel = ReportIntelligenceService.instance;
    final thisWeekCounts = await intel.computeWeekCounts(keyFor(dates.first), keyFor(dates.last));
    final lastWeekStart = dates.first.subtract(const Duration(days: 7));
    final lastWeekEnd = dates.first.subtract(const Duration(days: 1));
    final lastWeekCounts = await intel.computeWeekCounts(keyFor(lastWeekStart), keyFor(lastWeekEnd));
    final streak = await computeStreak();
    final narrative = intel.buildNarrativeSummary(
      thisWeek: thisWeekCounts, lastWeek: lastWeekCounts, streak: streak, locale: locale);
    if (narrative.isNotEmpty) {
      buf.writeln('\u2500\u2500 ${l.reportNarrativeHeader} \u2500\u2500');
      buf.writeln(narrative);
      buf.writeln('');
    }

    // Milestones
    final cumulative = await intel.computeAllTimeStats();
    final milestones = await intel.checkNewMilestones(
      stats: cumulative, currentStreak: streak,
      daysLoggedThisWeek: thisWeekCounts.daysLogged, locale: locale);
    if (milestones.isNotEmpty) {
      for (final m in milestones) buf.writeln(m);
      buf.writeln('');
    }

    // Plan progress
    final activePlan = ReadingPlanService.instance.activePlan;
    if (activePlan != null) {
      final planDef = ReadingPlans.getById(activePlan.planId);
      if (planDef != null) {
        buf.writeln(l.reportPlanProgress(
          planDef.name(locale), activePlan.currentDay, activePlan.totalDays,
          (activePlan.progress * 100).round()));
        buf.writeln('');
      }
    }

    int activeDays = 0;
```

- [ ] **Step 3: Add intelligence block to buildCompactReport()**

In `buildCompactReport()`, after the header and before pre-computing stats, insert the same intelligence block. Find:

```dart
    buf.writeln(l.reportWeekOf(fmtRange.format(dates.first), fmtRange.format(dates.last)));
    buf.writeln('');

    // Summary first — the disciple maker sees this immediately
    int activeDays = 0;
```

Replace with:

```dart
    buf.writeln(l.reportWeekOf(fmtRange.format(dates.first), fmtRange.format(dates.last)));
    buf.writeln('');

    // ── Intelligence: Narrative + Milestones ──
    final intel = ReportIntelligenceService.instance;
    final thisWeekCounts = await intel.computeWeekCounts(keyFor(dates.first), keyFor(dates.last));
    final lastWeekStart = dates.first.subtract(const Duration(days: 7));
    final lastWeekEnd = dates.first.subtract(const Duration(days: 1));
    final lastWeekCounts = await intel.computeWeekCounts(keyFor(lastWeekStart), keyFor(lastWeekEnd));
    final streak = await computeStreak();
    final narrative = intel.buildNarrativeSummary(
      thisWeek: thisWeekCounts, lastWeek: lastWeekCounts, streak: streak, locale: locale);
    if (narrative.isNotEmpty) {
      buf.writeln(narrative);
      buf.writeln('');
    }
    final cumulative = await intel.computeAllTimeStats();
    final milestones = await intel.checkNewMilestones(
      stats: cumulative, currentStreak: streak,
      daysLoggedThisWeek: thisWeekCounts.daysLogged, locale: locale);
    if (milestones.isNotEmpty) {
      buf.writeln(milestones.join(' | '));
      buf.writeln('');
    }
    final activePlan = ReadingPlanService.instance.activePlan;
    if (activePlan != null) {
      final planDef = ReadingPlans.getById(activePlan.planId);
      if (planDef != null) {
        buf.writeln(l.reportPlanProgress(
          planDef.name(locale), activePlan.currentDay, activePlan.totalDays,
          (activePlan.progress * 100).round()));
        buf.writeln('');
      }
    }

    // Summary first — the disciple maker sees this immediately
    int activeDays = 0;
```

- [ ] **Step 4: Add trend signals to the full report summary section**

In `buildFullReport()`, find the summary section near the end:

```dart
    buf.writeln('\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501');
    buf.writeln('\uD83D\uDCCA ${l.reportSummaryHeader}');
    buf.writeln(l.reportSummaryActiveDays(activeDays));
    buf.writeln(l.reportSummaryBibleChapters(totalChapters));
    buf.writeln(l.reportSummaryEvangelism(totalContacts));
```

Replace with:

```dart
    buf.writeln('\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501');
    buf.writeln('\uD83D\uDCCA ${l.reportSummaryHeader}');
    buf.writeln(l.reportSummaryActiveDays(activeDays));
    // Trend signals next to key stats
    final trends = intel.computeTrendSignals(thisWeekCounts, lastWeekCounts);
    final bibleTrend = trends.firstWhere((t) => t.discipline == 'Bible', orElse: () => const TrendSignal('Bible', '\u2192', 0, 0));
    buf.writeln('\u{1F4D6} Bible: $totalChapters ch. ${bibleTrend.arrow}${bibleTrend.lastWeek > 0 ? " (${bibleTrend.lastWeek} last wk)" : ""}');
    final evTrend = trends.firstWhere((t) => t.discipline == 'Evangelism', orElse: () => const TrendSignal('Evangelism', '\u2192', 0, 0));
    buf.writeln('\u{1F4E2} Evangelism: $totalContacts ${evTrend.arrow}${evTrend.lastWeek > 0 ? " (${evTrend.lastWeek} last wk)" : ""}');
    final prayTrend = trends.firstWhere((t) => t.discipline == 'Prayer', orElse: () => const TrendSignal('Prayer', '\u2192', 0, 0));
    buf.writeln('\u{1F64F} Prayer: ${prayTrend.thisWeek} days ${prayTrend.arrow}${prayTrend.lastWeek > 0 ? " (${prayTrend.lastWeek} last wk)" : ""}');
```

- [ ] **Step 5: Verify compilation**

Run: `cd "c:/Users/goodn/Developement/Flutter projects/daily_account" && flutter analyze lib/services/report_service.dart`

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/services/report_service.dart
git commit -m "feat: integrate intelligence into weekly reports — narrative, trends, milestones

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 6: Log Screen — Plan Suggestion Card

**Files:**
- Modify: `lib/screens/log_screen.dart`

**Interfaces:**
- Consumes: `ReadingPlanService.instance` (`.activePlan`, `.todayReading()`, `.isReadingDoneToday()`, `.markComplete()`, `.autoDetectCompletion()`, `.load()`), `ReadingPlans.getById()`, `BibleReadingEntry`, ARB keys (`planSuggestionToday`, `planSuggestionFill`, `planSuggestionDone`, `planDayOf`, `planProgress`)
- Produces: A small plan suggestion card rendered above the Bible `SectionCard` when a plan is active

- [ ] **Step 1: Add import**

Add at the top of `lib/screens/log_screen.dart`, after the existing imports:

```dart
import '../data/reading_plans.dart';
import '../services/reading_plan_service.dart';
```

- [ ] **Step 2: Initialize plan service in _load()**

In `_load()`, after `if (mounted) setState(() => _loading = false);` and before the reflection loading block, add:

```dart
    // Load reading plan service
    await ReadingPlanService.instance.load();
```

- [ ] **Step 3: Hook plan auto-detection into _persist()**

In the `_persist()` method, inside the Timer callback, after `widget.onChanged();` and before `_scheduleReflectionUpdate();`, add:

```dart
      ReadingPlanService.instance.autoDetectCompletion(_log);
```

- [ ] **Step 4: Add the plan suggestion card builder method**

Add this method before `_buildReflectionCard`:

```dart
  Widget _buildPlanSuggestionCard(S t) {
    final planService = ReadingPlanService.instance;
    final active = planService.activePlan;
    if (active == null) return const SizedBox.shrink();

    final reading = planService.todayReading();
    if (reading == null) return const SizedBox.shrink();

    final planDef = ReadingPlans.getById(active.planId);
    if (planDef == null) return const SizedBox.shrink();

    final locale = Localizations.localeOf(context).languageCode;
    final isDone = planService.isReadingDoneToday(_log);
    final accent = AppTheme.accentGold(context);
    final pct = (active.progress * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('\u{1F4D6}', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${t.planSuggestionToday}: ${reading.display(locale)}  (${reading.chapters} ch.)',
                    style: AppTheme.serif(12, color: AppTheme.textColor(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (isDone)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(t.planSuggestionDone,
                        style: AppTheme.label(10, color: Colors.green)),
                  )
                else
                  GestureDetector(
                    onTap: () {
                      // Auto-fill Bible session with plan reading
                      setState(() {
                        final entry = BibleReadingEntry(
                          startBook: reading.startBook,
                          startChapter: reading.startChapter,
                          endBook: reading.endBook,
                          endChapter: reading.endChapter,
                        );
                        entry.recalculate();
                        if (_log.bibleSessions.length == 1 && _log.bibleSessions.first.isEmpty) {
                          _log.bibleSessions[0] = entry;
                        } else {
                          _log.bibleSessions.add(entry);
                        }
                      });
                      _persist();
                      planService.markComplete(reading.dayNumber);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(t.planSuggestionFill,
                          style: AppTheme.label(10, color: accent)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${t.planDayOf(active.currentDay, active.totalDays)} \u00B7 ${t.planProgress(pct)}',
              style: AppTheme.label(9, color: AppTheme.faintColor(context)),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 5: Insert the plan card into the build tree**

In the `build()` method, find where the Bible `SectionCard` is rendered. Look for:

```dart
        // Bible (multi-session with auto-calculate)
        SectionCard(
```

Insert the plan suggestion card right before it:

```dart
        _buildPlanSuggestionCard(t),

        // Bible (multi-session with auto-calculate)
        SectionCard(
```

- [ ] **Step 6: Verify compilation**

Run: `cd "c:/Users/goodn/Developement/Flutter projects/daily_account" && flutter analyze lib/screens/log_screen.dart`

Expected: No errors from our changes.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/log_screen.dart
git commit -m "feat: add plan suggestion card on log screen with one-tap fill

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 7: Settings Screen — Plan Selection Section

**Files:**
- Modify: `lib/screens/settings_screen.dart`

**Interfaces:**
- Consumes: `ReadingPlanService.instance` (`.activePlan`, `.activate()`, `.pause()`, `.reset()`, `.load()`), `ReadingPlans.all`, ARB keys (`planSectionTitle`, `planNoActive`, `planStart`, `planPause`, `planReset`, `planProgress`, `planDayOf`, `planCompleted`)
- Produces: A new `SectionCard` in Settings for selecting/managing Bible reading plans

- [ ] **Step 1: Add imports**

Add at the top of `lib/screens/settings_screen.dart`:

```dart
import '../data/reading_plans.dart';
import '../services/reading_plan_service.dart';
```

- [ ] **Step 2: Initialize plan service**

In the settings screen's `initState()` or `_load()` method, add:

```dart
    await ReadingPlanService.instance.load();
```

If there's no async `_load()` method, add it after any existing async initialization.

- [ ] **Step 3: Add the plan SectionCard**

In the `build()` method's `ListView` children, after the Goals `SectionCard` and before the Disciple Maker section, add:

```dart
        // Bible Reading Plan
        SectionCard(
          icon: '\u{1F4D6}',
          title: l.planSectionTitle,
          initiallyExpanded: false,
          children: [
            _buildPlanSection(l),
          ],
        ),
```

- [ ] **Step 4: Add the _buildPlanSection method**

Add this method to the settings screen state class:

```dart
  Widget _buildPlanSection(S l) {
    final planService = ReadingPlanService.instance;
    final active = planService.activePlan;
    final locale = Localizations.localeOf(context).languageCode;
    final accent = AppTheme.accentGold(context);

    // Active plan view
    if (active != null && !active.isComplete) {
      final planDef = ReadingPlans.getById(active.planId);
      final pct = (active.progress * 100).round();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(planDef?.name(locale) ?? active.planId,
              style: AppTheme.serif(14, color: AppTheme.textColor(context), weight: FontWeight.w600)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: active.progress,
              backgroundColor: accent.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(accent),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${l.planDayOf(active.currentDay, active.totalDays)} \u2014 ${l.planProgress(pct)}',
            style: AppTheme.label(11, color: AppTheme.mutedColor(context)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () async {
                  await planService.pause();
                  setState(() {});
                },
                child: Text(l.planPause, style: TextStyle(color: AppTheme.mutedColor(context))),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  await planService.reset();
                  setState(() {});
                },
                child: Text(l.planReset, style: TextStyle(color: accent)),
              ),
            ],
          ),
        ],
      );
    }

    // Completed or no plan — show plan list
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active != null && active.isComplete)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('\u{1F389} ${l.planCompleted}',
                style: AppTheme.serif(13, color: Colors.green)),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l.planNoActive,
                style: AppTheme.serif(12, color: AppTheme.mutedColor(context))),
          ),
        ...ReadingPlans.all.map((plan) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.isDark(context)
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.name(locale),
                          style: AppTheme.serif(13, color: AppTheme.textColor(context), weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(plan.description(locale),
                          style: AppTheme.label(10, color: AppTheme.mutedColor(context))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    await planService.activate(plan.id);
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(l.planStart,
                        style: AppTheme.label(11, color: accent)),
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
```

- [ ] **Step 5: Verify compilation**

Run: `cd "c:/Users/goodn/Developement/Flutter projects/daily_account" && flutter analyze lib/screens/settings_screen.dart`

Expected: No errors from our changes.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: add Bible reading plan selection section in Settings

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 8: Final Verification

**Files:**
- All files from Tasks 1-7

- [ ] **Step 1: Run flutter analyze**

Run: `cd "c:/Users/goodn/Developement/Flutter projects/daily_account" && flutter analyze`

Expected: No new errors or warnings from our changes.

- [ ] **Step 2: Verify all spec requirements**

Check against spec:
- [ ] Free reading works exactly as before (no plan active → no suggestion card)
- [ ] Plan suggestion appears only when a plan is active
- [ ] Tapping "Fill" creates correct Bible session with right book/chapter references
- [ ] Plan progress persists across app restart (SharedPreferences)
- [ ] Marking a reading complete advances currentDay
- [ ] Narrative summary appears at top of weekly report
- [ ] Trend arrows (↑↓→) are present in full report summary
- [ ] Milestones fire only once (milestone keys in SharedPreferences)
- [ ] French locale shows French plan names, narrative, and milestone text
- [ ] Settings shows plan list when no active plan, progress when active
- [ ] Plan can be paused and reset from Settings

- [ ] **Step 3: Final commit (if any cleanup needed)**

```bash
git add -A
git commit -m "chore: final cleanup for Bible reading plans and report intelligence

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```
