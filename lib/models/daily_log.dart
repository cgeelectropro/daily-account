import 'dart:convert';

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

/// The complete daily account for a single date.
class DailyLog {
  String dateKey; // yyyy-MM-dd  (primary key)

  // Bible
  String bibleReference;
  String bibleChapters;

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

  // Other
  String other;

  // AI reflection (cached)
  String aiReflection;

  bool completed;

  DailyLog({
    required this.dateKey,
    this.bibleReference = '',
    this.bibleChapters = '',
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
    this.other = '',
    this.aiReflection = '',
    this.completed = false,
  }) : literature = literature ?? [LiteratureEntry()];

  /// Percentage (0.0–1.0) of how filled the day is — used for progress ring.
  double get completeness {
    final checks = <bool>[
      bibleReference.isNotEmpty,
      literature.any((l) => l.title.isNotEmpty),
      ddegScripture.isNotEmpty || ddegNotes.isNotEmpty,
      prayerAloneDuration.isNotEmpty,
      prayerOthersDuration.isNotEmpty,
      evangelismContacts.isNotEmpty,
      other.isNotEmpty,
    ];
    final filled = checks.where((c) => c).length;
    return filled / checks.length;
  }

  Map<String, dynamic> toMap() => {
        'dateKey': dateKey,
        'bibleReference': bibleReference,
        'bibleChapters': bibleChapters,
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
        'other': other,
        'aiReflection': aiReflection,
        'completed': completed ? 1 : 0,
      };

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

    return DailyLog(
      dateKey: m['dateKey'],
      bibleReference: m['bibleReference'] ?? '',
      bibleChapters: m['bibleChapters'] ?? '',
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
      other: m['other'] ?? '',
      aiReflection: m['aiReflection'] ?? '',
      completed: (m['completed'] ?? 0) == 1,
    );
  }
}
