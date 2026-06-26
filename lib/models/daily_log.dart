import 'dart:convert';
import '../utils/bible_books.dart';

/// A single literature entry — a disciple may read from several books a day.
class LiteratureEntry {
  String title;
  String amount; // numeric as string for easy input
  String unit; // pages | chapters | books

  LiteratureEntry({this.title = '', this.amount = '', this.unit = 'pages'});

  Map<String, dynamic> toMap() => {'title': title, 'amount': amount, 'unit': unit};

  factory LiteratureEntry.fromMap(Map<String, dynamic> m) => LiteratureEntry(
        title: m['title'] ?? '',
        amount: m['amount'] ?? '',
        unit: m['unit'] ?? 'pages',
      );
}

/// A single Bible reading session — start and end reference with auto-calculated chapters.
class BibleReadingEntry {
  String startBook;    // English canonical name (e.g. "Genesis")
  int startChapter;
  String endBook;      // English canonical name (empty = same as startBook)
  int endChapter;
  int chaptersRead;    // auto-calculated

  BibleReadingEntry({
    this.startBook = '',
    this.startChapter = 0,
    this.endBook = '',
    this.endChapter = 0,
    this.chaptersRead = 0,
  });

  Map<String, dynamic> toMap() => {
    'startBook': startBook,
    'startChapter': startChapter,
    'endBook': endBook,
    'endChapter': endChapter,
    'chaptersRead': chaptersRead,
  };

  factory BibleReadingEntry.fromMap(Map<String, dynamic> m) => BibleReadingEntry(
    startBook: m['startBook'] ?? '',
    startChapter: m['startChapter'] ?? 0,
    endBook: m['endBook'] ?? '',
    endChapter: m['endChapter'] ?? 0,
    chaptersRead: m['chaptersRead'] ?? 0,
  );

  /// Recalculate chaptersRead from start/end references.
  void recalculate() {
    if (startBook.isEmpty || startChapter < 1) {
      chaptersRead = 0;
      return;
    }
    final effectiveEndBook = endBook.isEmpty ? startBook : endBook;
    final effectiveEndChapter = endChapter < 1 ? startChapter : endChapter;
    final startRef = '$startBook $startChapter';
    final endRef = '$effectiveEndBook $effectiveEndChapter';
    chaptersRead = BibleBooks.calculateChapters(startRef, endRef) ?? 1;
  }

  /// Localized display string (e.g. "Genèse 1 – Exode 3" in French).
  String localizedDisplay(String locale) {
    if (startBook.isEmpty) return '';
    final sb = BibleBooks.findBook(startBook);
    if (sb == null) return '$startBook $startChapter';
    final startName = locale.startsWith('fr') ? sb.nameFr : sb.nameEn;
    final start = '$startName $startChapter';

    final effectiveEndBook = endBook.isEmpty ? startBook : endBook;
    final effectiveEndChapter = endChapter < 1 ? startChapter : endChapter;

    if (effectiveEndBook == startBook && effectiveEndChapter == startChapter) {
      return start;
    }

    final eb = BibleBooks.findBook(effectiveEndBook);
    if (eb == null) return start;
    final endName = locale.startsWith('fr') ? eb.nameFr : eb.nameEn;
    final end = '$endName $effectiveEndChapter';
    return '$start \u2013 $end';
  }

  bool get isEmpty => startBook.isEmpty;
  bool get isNotEmpty => startBook.isNotEmpty;
}

/// The complete daily account for a single date.
class DailyLog {
  String dateKey; // yyyy-MM-dd  (primary key)

  // Bible
  String bibleReference;
  String bibleChapters;

  // Bible reading sessions (structured — replaces free-text for new entries)
  List<BibleReadingEntry> bibleSessions;

  // Literature (multiple)
  List<LiteratureEntry> literature;

  // Daily Dynamic Encounter with God
  String ddegScripture;
  String ddegTime;
  String ddegNotes;

  // Prayer
  String prayerAloneDuration;
  String prayerAloneNotes;
  String prayerOthersDuration;
  String prayerOthersContext;

  // Evangelism
  String evangelismContacts;
  String evangelismOutcome;
  String evangelismNotes;
  String evangelismNewBelievers;
  String evangelismBeingDiscipled;
  String evangelismFollowUpNotes;

  // Other
  String other;

  // ── Fasting ──
  String fastingType;
  String fastingDuration;
  String fastingPrayerFocus;

  // ── Giving & Tithes ──
  String givingType;
  String givingAmount;
  String givingPurpose;

  // ── Church & Fellowship ──
  String churchType;
  String churchNotes;

  // ── Discipleship ──
  String discipleshipWho;
  String discipleshipTopic;
  String discipleshipDuration;

  // ── Proclamation ──
  String proclamationCount; // number of times proclaimed
  String proclamationDuration; // optional duration

  // Voice note (file path)
  String voiceNotePath;

  // AI reflection (cached)
  String aiReflection;

  bool completed;

  DailyLog({
    required this.dateKey,
    this.bibleReference = '',
    this.bibleChapters = '',
    List<BibleReadingEntry>? bibleSessions,
    List<LiteratureEntry>? literature,
    this.ddegScripture = '',
    this.ddegTime = '',
    this.ddegNotes = '',
    this.prayerAloneDuration = '',
    this.prayerAloneNotes = '',
    this.prayerOthersDuration = '',
    this.prayerOthersContext = '',
    this.evangelismContacts = '',
    this.evangelismOutcome = '',
    this.evangelismNotes = '',
    this.evangelismNewBelievers = '',
    this.evangelismBeingDiscipled = '',
    this.evangelismFollowUpNotes = '',
    this.other = '',
    this.fastingType = '',
    this.fastingDuration = '',
    this.fastingPrayerFocus = '',
    this.givingType = '',
    this.givingAmount = '',
    this.givingPurpose = '',
    this.churchType = '',
    this.churchNotes = '',
    this.discipleshipWho = '',
    this.discipleshipTopic = '',
    this.discipleshipDuration = '',
    this.proclamationCount = '',
    this.proclamationDuration = '',
    this.voiceNotePath = '',
    this.aiReflection = '',
    this.completed = false,
  }) : bibleSessions = bibleSessions ?? [],
       literature = literature ?? [LiteratureEntry()];

  /// Percentage (0.0–1.0) of how filled the day is — used for progress ring.
  /// Based on 10 core CMFI disciplines ("Other" is optional, not counted).
  double get completeness {
    final checks = <bool>[
      bibleReference.isNotEmpty || bibleChapters.isNotEmpty || bibleSessions.any((s) => s.isNotEmpty),
      literature.any((l) => l.title.isNotEmpty),
      ddegScripture.isNotEmpty || ddegNotes.isNotEmpty,
      prayerAloneDuration.isNotEmpty,
      prayerOthersDuration.isNotEmpty,
      evangelismContacts.isNotEmpty,
      fastingType.isNotEmpty || fastingDuration.isNotEmpty,
      givingType.isNotEmpty,
      churchType.isNotEmpty,
      discipleshipWho.isNotEmpty,
      proclamationCount.isNotEmpty,
    ];
    final filled = checks.where((c) => c).length;
    return filled / 11;
  }

  Map<String, dynamic> toMap() => {
        'dateKey': dateKey,
        'bibleReference': bibleReference,
        'bibleChapters': bibleChapters,
        'bibleSessions': jsonEncode(bibleSessions.map((s) => s.toMap()).toList()),
        'literature': jsonEncode(literature.map((l) => l.toMap()).toList()),
        'ddegScripture': ddegScripture,
        'ddegTime': ddegTime,
        'ddegNotes': ddegNotes,
        'prayerAloneDuration': prayerAloneDuration,
        'prayerAloneNotes': prayerAloneNotes,
        'prayerOthersDuration': prayerOthersDuration,
        'prayerOthersContext': prayerOthersContext,
        'evangelismContacts': evangelismContacts,
        'evangelismOutcome': evangelismOutcome,
        'evangelismNotes': evangelismNotes,
        'evangelismNewBelievers': evangelismNewBelievers,
        'evangelismBeingDiscipled': evangelismBeingDiscipled,
        'evangelismFollowUpNotes': evangelismFollowUpNotes,
        'other': other,
        'fastingType': fastingType,
        'fastingDuration': fastingDuration,
        'fastingPrayerFocus': fastingPrayerFocus,
        'givingType': givingType,
        'givingAmount': givingAmount,
        'givingPurpose': givingPurpose,
        'churchType': churchType,
        'churchNotes': churchNotes,
        'discipleshipWho': discipleshipWho,
        'discipleshipTopic': discipleshipTopic,
        'discipleshipDuration': discipleshipDuration,
        'proclamationCount': proclamationCount,
        'proclamationDuration': proclamationDuration,
        'voiceNotePath': voiceNotePath,
        'aiReflection': aiReflection,
        'completed': completed ? 1 : 0,
      };

  /// Total chapters from structured sessions.
  int get totalSessionChapters =>
      bibleSessions.fold(0, (sum, s) => sum + s.chaptersRead);

  /// Total bible chapters: sessions + legacy field.
  int get totalBibleChapters =>
      totalSessionChapters + (int.tryParse(bibleChapters) ?? 0);

  /// Combined reference display for reports.
  String combinedBibleReference(String locale) {
    final parts = <String>[];
    for (final s in bibleSessions) {
      final display = s.localizedDisplay(locale);
      if (display.isNotEmpty) parts.add(display);
    }
    if (parts.isEmpty && bibleReference.isNotEmpty) parts.add(bibleReference);
    return parts.join('; ');
  }

  factory DailyLog.fromMap(Map<String, dynamic> m) {
    List<LiteratureEntry> lit = [LiteratureEntry()];
    try {
      final raw = m['literature'];
      if (raw != null && raw.toString().isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        lit = decoded.map((e) => LiteratureEntry.fromMap(Map<String, dynamic>.from(e))).toList();
        if (lit.isEmpty) lit = [LiteratureEntry()];
      }
    } catch (_) {}

    List<BibleReadingEntry> sessions = [];
    try {
      final rawSessions = m['bibleSessions'];
      if (rawSessions != null && rawSessions.toString().isNotEmpty) {
        final decoded = jsonDecode(rawSessions) as List;
        sessions = decoded.map((e) => BibleReadingEntry.fromMap(Map<String, dynamic>.from(e))).toList();
      }
    } catch (_) {}

    return DailyLog(
      dateKey: m['dateKey'],
      bibleReference: m['bibleReference'] ?? '',
      bibleChapters: m['bibleChapters'] ?? '',
      bibleSessions: sessions,
      literature: lit,
      ddegScripture: m['ddegScripture'] ?? '',
      ddegTime: m['ddegTime'] ?? '',
      ddegNotes: m['ddegNotes'] ?? '',
      prayerAloneDuration: m['prayerAloneDuration'] ?? '',
      prayerAloneNotes: m['prayerAloneNotes'] ?? '',
      prayerOthersDuration: m['prayerOthersDuration'] ?? '',
      prayerOthersContext: m['prayerOthersContext'] ?? '',
      evangelismContacts: m['evangelismContacts'] ?? '',
      evangelismOutcome: m['evangelismOutcome'] ?? '',
      evangelismNotes: m['evangelismNotes'] ?? '',
      evangelismNewBelievers: m['evangelismNewBelievers'] ?? '',
      evangelismBeingDiscipled: m['evangelismBeingDiscipled'] ?? '',
      evangelismFollowUpNotes: m['evangelismFollowUpNotes'] ?? '',
      other: m['other'] ?? '',
      fastingType: m['fastingType'] ?? '',
      fastingDuration: m['fastingDuration'] ?? '',
      fastingPrayerFocus: m['fastingPrayerFocus'] ?? '',
      givingType: m['givingType'] ?? '',
      givingAmount: m['givingAmount'] ?? '',
      givingPurpose: m['givingPurpose'] ?? '',
      churchType: m['churchType'] ?? '',
      churchNotes: m['churchNotes'] ?? '',
      discipleshipWho: m['discipleshipWho'] ?? '',
      discipleshipTopic: m['discipleshipTopic'] ?? '',
      discipleshipDuration: m['discipleshipDuration'] ?? '',
      proclamationCount: m['proclamationCount'] ?? '',
      proclamationDuration: m['proclamationDuration'] ?? '',
      voiceNotePath: m['voiceNotePath'] ?? '',
      aiReflection: m['aiReflection'] ?? '',
      completed: (m['completed'] ?? 0) == 1,
    );
  }
}
