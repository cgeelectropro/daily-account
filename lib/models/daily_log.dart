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
    this.aiReflection = '',
    this.completed = false,
  }) : literature = literature ?? [LiteratureEntry()];

  /// Percentage (0.0–1.0) of how filled the day is — used for progress ring.
  /// Based on 10 core CMFI disciplines ("Other" is optional, not counted).
  double get completeness {
    final checks = <bool>[
      bibleReference.isNotEmpty || bibleChapters.isNotEmpty,
      literature.any((l) => l.title.isNotEmpty),
      ddegScripture.isNotEmpty || ddegNotes.isNotEmpty,
      prayerAloneDuration.isNotEmpty,
      prayerOthersDuration.isNotEmpty,
      evangelismContacts.isNotEmpty,
      fastingType.isNotEmpty || fastingDuration.isNotEmpty,
      givingType.isNotEmpty,
      churchType.isNotEmpty,
      discipleshipWho.isNotEmpty,
    ];
    final filled = checks.where((c) => c).length;
    return filled / 10;
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
      aiReflection: m['aiReflection'] ?? '',
      completed: (m['completed'] ?? 0) == 1,
    );
  }
}
