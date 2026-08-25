import '../utils/bible_books.dart';

// ---------------------------------------------------------------------------
// PlanReading — a single day's reading assignment
// ---------------------------------------------------------------------------

class PlanReading {
  final int dayNumber;
  final String startBook;
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

  /// Human-readable range for the given locale, e.g. "Genesis 1 – Genesis 3".
  String display(String locale) {
    final isFr = locale.startsWith('fr');
    final sb = BibleBooks.findBook(startBook);
    final eb = BibleBooks.findBook(endBook);
    final sName = sb != null ? (isFr ? sb.nameFr : sb.nameEn) : startBook;
    final eName = eb != null ? (isFr ? eb.nameFr : eb.nameEn) : endBook;
    if (startBook == endBook) {
      if (startChapter == endChapter) return '$sName $startChapter';
      return '$sName $startChapter – $endChapter';
    }
    return '$sName $startChapter – $eName $endChapter';
  }

  /// Number of chapters in this day's reading.
  int get chapters {
    final count = BibleBooks.calculateChapters(
      '$startBook $startChapter',
      '$endBook $endChapter',
    );
    return count ?? 0;
  }
}

// ---------------------------------------------------------------------------
// ReadingPlan — metadata + pre-computed day readings
// ---------------------------------------------------------------------------

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

  String name(String locale) =>
      locale.startsWith('fr') ? nameFr : nameEn;

  String description(String locale) =>
      locale.startsWith('fr') ? descriptionFr : descriptionEn;
}

// ---------------------------------------------------------------------------
// ActivePlan — user's in-progress plan state (persisted via JSON)
// ---------------------------------------------------------------------------

class ActivePlan {
  final String planId;
  final int totalDays;
  final DateTime startedAt;
  final int currentDay;
  final Set<int> completedDays;

  const ActivePlan({
    required this.planId,
    required this.totalDays,
    required this.startedAt,
    required this.currentDay,
    required this.completedDays,
  });

  /// Fraction of days completed (0.0 – 1.0).
  double get progress =>
      totalDays == 0 ? 0.0 : completedDays.length / totalDays;

  bool get isComplete => completedDays.length >= totalDays;

  Map<String, dynamic> toJson() => {
        'planId': planId,
        'totalDays': totalDays,
        'startedAt': startedAt.toIso8601String(),
        'currentDay': currentDay,
        'completedDays': completedDays.toList()..sort(),
      };

  factory ActivePlan.fromJson(Map<String, dynamic> json) => ActivePlan(
        planId: json['planId'] as String,
        totalDays: json['totalDays'] as int,
        startedAt: DateTime.parse(json['startedAt'] as String),
        currentDay: json['currentDay'] as int,
        completedDays: Set<int>.from(
          (json['completedDays'] as List<dynamic>).map((e) => e as int),
        ),
      );

  ActivePlan copyWith({
    String? planId,
    int? totalDays,
    DateTime? startedAt,
    int? currentDay,
    Set<int>? completedDays,
  }) =>
      ActivePlan(
        planId: planId ?? this.planId,
        totalDays: totalDays ?? this.totalDays,
        startedAt: startedAt ?? this.startedAt,
        currentDay: currentDay ?? this.currentDay,
        completedDays: completedDays ?? this.completedDays,
      );
}

// ---------------------------------------------------------------------------
// Internal helpers for plan generation
// ---------------------------------------------------------------------------

/// Represents a single (book-index, chapter) pair.
typedef _ChapterRef = ({int bookIdx, int chapter});

/// Build a flat list of all chapter references for the given book indices
/// (in that order).
List<_ChapterRef> _collectChapters(List<int> bookIndices) {
  final refs = <_ChapterRef>[];
  for (final idx in bookIndices) {
    final book = BibleBooks.all[idx];
    for (var c = 1; c <= book.chapters; c++) {
      refs.add((bookIdx: idx, chapter: c));
    }
  }
  return refs;
}

/// Divide [refs] evenly across [totalDays] days using ceiling division,
/// then build [PlanReading] entries.
List<PlanReading> _buildReadings(List<_ChapterRef> refs, int totalDays) {
  final total = refs.length;
  final readings = <PlanReading>[];

  var refOffset = 0;
  for (var day = 1; day <= totalDays; day++) {
    if (refOffset >= total) break;

    final remaining = total - refOffset;
    final remainingDays = totalDays - day + 1;
    final count = (remaining / remainingDays).ceil();

    final startRef = refs[refOffset];
    final endRef = refs[refOffset + count - 1];

    final startBook = BibleBooks.all[startRef.bookIdx];
    final endBook = BibleBooks.all[endRef.bookIdx];

    readings.add(PlanReading(
      dayNumber: day,
      startBook: startBook.nameEn,
      startChapter: startRef.chapter,
      endBook: endBook.nameEn,
      endChapter: endRef.chapter,
    ));

    refOffset += count;
  }

  return readings;
}

// ---------------------------------------------------------------------------
// ReadingPlans — registry of all built-in plans
// ---------------------------------------------------------------------------

class ReadingPlans {
  ReadingPlans._();

  static List<ReadingPlan>? _cached;

  /// All 5 built-in reading plans (lazy-cached).
  static List<ReadingPlan> get all {
    _cached ??= [
      _bible1yr(),
      _nt90d(),
      _gospels30d(),
      _psalmsProv30d(),
      _chrono1yr(),
    ];
    return _cached!;
  }

  /// Find a plan by its [id], or null if not found.
  static ReadingPlan? getById(String id) {
    for (final plan in all) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  // ---- Plan constructors --------------------------------------------------

  static ReadingPlan _bible1yr() {
    final bookIndices = List<int>.generate(66, (i) => i);
    final refs = _collectChapters(bookIndices);
    return ReadingPlan(
      id: 'bible_1yr',
      nameEn: 'Bible in a Year',
      nameFr: 'Bible en un an',
      descriptionEn: 'Read through all 66 books of the Bible in 365 days.',
      descriptionFr: 'Lire les 66 livres de la Bible en 365 jours.',
      totalDays: 365,
      readings: _buildReadings(refs, 365),
    );
  }

  static ReadingPlan _nt90d() {
    // Books index 39–65: Matthew through Revelation
    final bookIndices = List<int>.generate(27, (i) => 39 + i);
    final refs = _collectChapters(bookIndices);
    return ReadingPlan(
      id: 'nt_90d',
      nameEn: 'New Testament in 90 Days',
      nameFr: 'Nouveau Testament en 90 jours',
      descriptionEn: 'Read the entire New Testament (Matthew–Revelation) in 90 days.',
      descriptionFr: 'Lire tout le Nouveau Testament (Matthieu–Apocalypse) en 90 jours.',
      totalDays: 90,
      readings: _buildReadings(refs, 90),
    );
  }

  static ReadingPlan _gospels30d() {
    // Books 39, 40, 41, 42 — Matthew, Mark, Luke, John
    const bookIndices = [39, 40, 41, 42];
    final refs = _collectChapters(bookIndices);
    return ReadingPlan(
      id: 'gospels_30d',
      nameEn: 'The Gospels in 30 Days',
      nameFr: 'Les Évangiles en 30 jours',
      descriptionEn: 'Read all four Gospels (Matthew–John) in 30 days.',
      descriptionFr: 'Lire les quatre Évangiles (Matthieu–Jean) en 30 jours.',
      totalDays: 30,
      readings: _buildReadings(refs, 30),
    );
  }

  static ReadingPlan _psalmsProv30d() {
    // Books 18 (Psalms) and 19 (Proverbs)
    const bookIndices = [18, 19];
    final refs = _collectChapters(bookIndices);
    return ReadingPlan(
      id: 'psalms_prov_30d',
      nameEn: 'Psalms & Proverbs in 30 Days',
      nameFr: 'Psaumes et Proverbes en 30 jours',
      descriptionEn: 'Read through Psalms and Proverbs in 30 days.',
      descriptionFr: 'Lire les Psaumes et les Proverbes en 30 jours.',
      totalDays: 30,
      readings: _buildReadings(refs, 30),
    );
  }

  static ReadingPlan _chrono1yr() {
    // Chronological order indices
    const bookIndices = [
      0, 17, 1, 2, 3, 4, 5, 6, 7, 8, 9, 18, 10, 19, 20, 21,
      27, 29, 31, 32, 28, 33, 34, 35, 22, 23, 24, 11, 30, 25, 26,
      36, 37, 38, 12, 13, 14, 15, 16,
      39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54,
      55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65,
    ];
    final refs = _collectChapters(bookIndices);
    return ReadingPlan(
      id: 'chrono_1yr',
      nameEn: 'Chronological Bible in a Year',
      nameFr: 'Bible chronologique en un an',
      descriptionEn: 'Read the Bible in chronological order across 365 days.',
      descriptionFr: 'Lire la Bible dans l\'ordre chronologique en 365 jours.',
      totalDays: 365,
      readings: _buildReadings(refs, 365),
    );
  }
}
