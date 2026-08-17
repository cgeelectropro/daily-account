import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  // Transient UI-only state (not persisted): last text the user typed into
  // the book fields, kept so an unrecognized book name can still be shown
  // back to the user alongside an inline error, instead of being discarded.
  String startBookRaw;
  String endBookRaw;

  BibleReadingEntry({
    this.startBook = '',
    this.startChapter = 0,
    this.endBook = '',
    this.endChapter = 0,
    this.chaptersRead = 0,
    String? startBookRaw,
    String? endBookRaw,
  })  : startBookRaw = startBookRaw ?? startBook,
        endBookRaw = endBookRaw ?? endBook;

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
    // If the reference can't be resolved (e.g. unknown book), record 0 —
    // never silently guess 1 chapter for data that couldn't be verified.
    chaptersRead = BibleBooks.calculateChapters(startRef, endRef) ?? 0;
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

/// A single DDEG (Daily Dynamic Encounter with God) session.
class DdegSession {
  String scripture;
  String time;
  String notes;

  DdegSession({this.scripture = '', this.time = '', this.notes = ''});

  Map<String, dynamic> toMap() => {
    'scripture': scripture,
    'time': time,
    'notes': notes,
  };

  factory DdegSession.fromMap(Map<String, dynamic> m) => DdegSession(
    scripture: m['scripture'] ?? '',
    time: m['time'] ?? '',
    notes: m['notes'] ?? '',
  );

  bool get isEmpty => scripture.isEmpty && time.isEmpty && notes.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

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

  bool get isEmpty => topic.isEmpty && count == 0 && duration.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Find the index of an existing same-day session whose topic matches
  /// [topic] (case-insensitive, trimmed), or -1 if none exists. Shared by
  /// every write path that records a proclamation (TimerService's stopwatch
  /// flow, the widget's quick-increment tap, and manual log-screen entry)
  /// so there is exactly one topic-matching rule. Callers merge the count
  /// (and, where applicable, accumulate the duration using their own
  /// duration-formatting logic) into the session at the returned index, or
  /// append a new [ProclamationSession] if -1.
  static int findMatchingIndex(List<ProclamationSession> sessions, String topic) {
    final normalizedTopic = topic.trim().toLowerCase();
    return sessions.indexWhere(
        (s) => s.topic.trim().toLowerCase() == normalizedTopic);
  }

  /// Increment [count] into an existing same-day session matching [topic]
  /// (case-insensitive, trimmed), or append a new one with that topic and
  /// count. Used by write paths that only need a plain +1 increment (no
  /// duration to accumulate) — e.g. the widget's quick-increment tap.
  static void incrementTopic(List<ProclamationSession> sessions, String topic, {int count = 1}) {
    final idx = findMatchingIndex(sessions, topic);
    if (idx != -1) {
      sessions[idx].count += count;
    } else {
      sessions.add(ProclamationSession(topic: topic.trim(), count: count));
    }
  }
}

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
  List<DdegSession> ddegSessions;

  // Prayer
  String prayerAloneDuration;
  String prayerAloneNotes;
  String prayerOthersDuration;
  String prayerOthersContext;
  List<PrayerSession> prayerAloneSessions;
  List<PrayerSession> prayerOthersSessions;

  // Evangelism
  String evangelismContacts;
  String evangelismOutcome;
  String evangelismNotes;
  String evangelismNewBelievers;
  String evangelismBeingDiscipled;
  String evangelismFollowUpNotes;

  // Other
  String other;

  // ── Time-conscious duration fields ──
  String bibleDuration;
  String literatureDuration;
  String evangelismDuration;
  String givingDuration;
  String churchDuration;
  List<TimedSession> evangelismSessions;
  List<TimedSession> churchSessions;

  // ── Custom activity log data (JSON) ──
  Map<String, Map<String, dynamic>> customActivityData;

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
  List<ProclamationSession> proclamationSessions;

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
    List<DdegSession>? ddegSessions,
    this.prayerAloneDuration = '',
    this.prayerAloneNotes = '',
    this.prayerOthersDuration = '',
    this.prayerOthersContext = '',
    List<PrayerSession>? prayerAloneSessions,
    List<PrayerSession>? prayerOthersSessions,
    this.evangelismContacts = '',
    this.evangelismOutcome = '',
    this.evangelismNotes = '',
    this.evangelismNewBelievers = '',
    this.evangelismBeingDiscipled = '',
    this.evangelismFollowUpNotes = '',
    this.other = '',
    this.bibleDuration = '',
    this.literatureDuration = '',
    this.evangelismDuration = '',
    this.givingDuration = '',
    this.churchDuration = '',
    List<TimedSession>? evangelismSessions,
    List<TimedSession>? churchSessions,
    Map<String, Map<String, dynamic>>? customActivityData,
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
    List<ProclamationSession>? proclamationSessions,
    this.voiceNotePath = '',
    this.aiReflection = '',
    this.completed = false,
  }) : bibleSessions = bibleSessions ?? [],
       literature = literature ?? [LiteratureEntry()],
       ddegSessions = ddegSessions ?? [],
       prayerAloneSessions = prayerAloneSessions ?? [],
       prayerOthersSessions = prayerOthersSessions ?? [],
       proclamationSessions = proclamationSessions ?? [],
       evangelismSessions = evangelismSessions ?? [],
       churchSessions = churchSessions ?? [],
       customActivityData = customActivityData ?? {};

  /// Percentage (0.0–1.0) of how filled the day is — used for progress ring.
  /// Based on 10 core CMFI disciplines ("Other" is optional, not counted).
  double get completeness {
    final checks = <bool>[
      bibleReference.isNotEmpty || bibleChapters.isNotEmpty || bibleSessions.any((s) => s.isNotEmpty),
      literature.any((l) => l.title.isNotEmpty),
      ddegSessions.any((s) => s.isNotEmpty) || ddegScripture.isNotEmpty || ddegNotes.isNotEmpty,
      prayerAloneSessions.any((s) => s.isNotEmpty) || prayerAloneDuration.isNotEmpty,
      prayerOthersSessions.any((s) => s.isNotEmpty) || prayerOthersDuration.isNotEmpty,
      evangelismContacts.isNotEmpty || evangelismSessions.isNotEmpty,
      fastingType.isNotEmpty || fastingDuration.isNotEmpty,
      givingType.isNotEmpty,
      churchType.isNotEmpty || churchSessions.isNotEmpty,
      discipleshipWho.isNotEmpty,
      proclamationCount.isNotEmpty || proclamationSessions.isNotEmpty,
    ];
    final filled = checks.where((c) => c).length;

    // Count custom activities that affect completeness.
    // Cap custom activity contribution to avoid diluting the progress ring
    // when many custom activities are defined (max 4 extra sections).
    int customTotal = 0;
    int customFilled = 0;
    for (final entry in customActivityData.values) {
      if (entry['countsForCompleteness'] == true) {
        customTotal++;
        if (entry['done'] == true) customFilled++;
      }
    }
    const maxCustomSections = 4;
    final cappedCustomTotal = customTotal.clamp(0, maxCustomSections);
    final cappedCustomFilled = customFilled.clamp(0, cappedCustomTotal);

    final totalSections = 11 + cappedCustomTotal;
    return totalSections > 0 ? (filled + cappedCustomFilled) / totalSections : 0.0;
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
        'ddegSessions': jsonEncode(ddegSessions.map((s) => s.toMap()).toList()),
        'prayerAloneDuration': prayerAloneDuration,
        'prayerAloneNotes': prayerAloneNotes,
        'prayerOthersDuration': prayerOthersDuration,
        'prayerOthersContext': prayerOthersContext,
        'prayerAloneSessions': jsonEncode(prayerAloneSessions.map((s) => s.toMap()).toList()),
        'prayerOthersSessions': jsonEncode(prayerOthersSessions.map((s) => s.toMap()).toList()),
        'evangelismContacts': evangelismContacts,
        'evangelismOutcome': evangelismOutcome,
        'evangelismNotes': evangelismNotes,
        'evangelismNewBelievers': evangelismNewBelievers,
        'evangelismBeingDiscipled': evangelismBeingDiscipled,
        'evangelismFollowUpNotes': evangelismFollowUpNotes,
        'other': other,
        'bibleDuration': bibleDuration,
        'literatureDuration': literatureDuration,
        'evangelismDuration': evangelismDuration,
        'givingDuration': givingDuration,
        'churchDuration': churchDuration,
        'evangelismSessions': jsonEncode(evangelismSessions.map((s) => s.toMap()).toList()),
        'churchSessions': jsonEncode(churchSessions.map((s) => s.toMap()).toList()),
        'custom_activity_data': jsonEncode(customActivityData),
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
        'proclamationSessions': jsonEncode(proclamationSessions.map((s) => s.toMap()).toList()),
        'voiceNotePath': voiceNotePath,
        'aiReflection': aiReflection,
        'completed': completed ? 1 : 0,
      };

  /// Total chapters from structured sessions.
  int get totalSessionChapters =>
      bibleSessions.fold(0, (sum, s) => sum + s.chaptersRead);

  /// Total bible chapters: sessions if present, else the legacy field.
  /// When sessions exist, `bibleChapters` mirrors their total (see
  /// log_screen.dart's `_recalcSession`), so adding both would double-count.
  int get totalBibleChapters => bibleSessions.isNotEmpty
      ? totalSessionChapters
      : (int.tryParse(bibleChapters) ?? 0);

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

  /// Total proclamation count: sessions if present, else the legacy scalar.
  int get totalProclamationCount => proclamationSessions.isNotEmpty
      ? proclamationSessions.fold(0, (sum, s) => sum + s.count)
      : (int.tryParse(proclamationCount) ?? 0);

  /// Total proclamation minutes across all sessions (0 if none have a duration).
  int get totalProclamationMinutes => proclamationSessions.fold(
      0, (sum, s) => sum + _parseDurationMinutesStatic(s.duration));

  /// Total evangelism minutes: sessions if present, else the legacy scalar.
  int get totalEvangelismMinutes => evangelismSessions.isNotEmpty
      ? evangelismSessions.fold(0, (sum, s) => sum + s.durationSeconds ~/ 60)
      : _parseDurationMinutesStatic(evangelismDuration);

  /// Total church minutes: sessions if present, else the legacy scalar.
  int get totalChurchMinutes => churchSessions.isNotEmpty
      ? churchSessions.fold(0, (sum, s) => sum + s.durationSeconds ~/ 60)
      : _parseDurationMinutesStatic(churchDuration);

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

  factory DailyLog.fromMap(Map<String, dynamic> m) {
    List<LiteratureEntry> lit = [LiteratureEntry()];
    try {
      final raw = m['literature'];
      if (raw != null && raw.toString().isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        lit = decoded.map((e) => LiteratureEntry.fromMap(Map<String, dynamic>.from(e))).toList();
        if (lit.isEmpty) lit = [LiteratureEntry()];
      }
    } catch (e) {
      debugPrint('DailyLog.fromMap: failed to parse literature: $e');
    }

    List<BibleReadingEntry> sessions = [];
    try {
      final rawSessions = m['bibleSessions'];
      if (rawSessions != null && rawSessions.toString().isNotEmpty) {
        final decoded = jsonDecode(rawSessions) as List;
        sessions = decoded.map((e) => BibleReadingEntry.fromMap(Map<String, dynamic>.from(e))).toList();
      }
    } catch (e) {
      debugPrint('DailyLog.fromMap: failed to parse bibleSessions: $e');
    }

    // DDEG sessions
    List<DdegSession> ddegSessions = [];
    try {
      final rawDdeg = m['ddegSessions'];
      if (rawDdeg != null && rawDdeg.toString().isNotEmpty) {
        final decoded = jsonDecode(rawDdeg) as List;
        ddegSessions = decoded
            .map((e) => DdegSession.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint('DailyLog.fromMap: failed to parse ddegSessions: $e');
    }
    // Auto-migrate from old single fields
    if (ddegSessions.isEmpty) {
      final oldScripture = (m['ddegScripture'] ?? '').toString();
      final oldTime = (m['ddegTime'] ?? '').toString();
      final oldNotes = (m['ddegNotes'] ?? '').toString();
      if (oldScripture.isNotEmpty || oldNotes.isNotEmpty) {
        ddegSessions = [DdegSession(
            scripture: oldScripture, time: oldTime, notes: oldNotes)];
      }
    }

    // Prayer alone sessions
    List<PrayerSession> prayerAloneSessions = [];
    try {
      final rawPa = m['prayerAloneSessions'];
      if (rawPa != null && rawPa.toString().isNotEmpty) {
        final decoded = jsonDecode(rawPa) as List;
        prayerAloneSessions = decoded
            .map((e) => PrayerSession.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint('DailyLog.fromMap: failed to parse prayerAloneSessions: $e');
    }
    if (prayerAloneSessions.isEmpty) {
      final oldDuration = (m['prayerAloneDuration'] ?? '').toString();
      final oldNotes = (m['prayerAloneNotes'] ?? '').toString();
      if (oldDuration.isNotEmpty) {
        prayerAloneSessions = [PrayerSession(
            duration: oldDuration, notes: oldNotes)];
      }
    }

    // Prayer with others sessions
    List<PrayerSession> prayerOthersSessions = [];
    try {
      final rawPo = m['prayerOthersSessions'];
      if (rawPo != null && rawPo.toString().isNotEmpty) {
        final decoded = jsonDecode(rawPo) as List;
        prayerOthersSessions = decoded
            .map((e) => PrayerSession.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint('DailyLog.fromMap: failed to parse prayerOthersSessions: $e');
    }
    if (prayerOthersSessions.isEmpty) {
      final oldDuration = (m['prayerOthersDuration'] ?? '').toString();
      final oldContext = (m['prayerOthersContext'] ?? '').toString();
      if (oldDuration.isNotEmpty) {
        prayerOthersSessions = [PrayerSession(
            duration: oldDuration, notes: oldContext)];
      }
    }

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
    // Tracks whether this call synthesized a session from the legacy scalar
    // (as opposed to loading a persisted session list). When true, the
    // scalar fields below are cleared before being handed to the DailyLog
    // constructor so `toMap()` doesn't re-persist a now-superseded scalar
    // alongside the new session — otherwise every getLog→saveLog round-trip
    // after the first would leave two independent counters alive forever.
    bool migratedProclamationFromScalar = false;
    if (proclamationSessions.isEmpty) {
      final oldCount = (m['proclamationCount'] ?? '').toString();
      final oldDuration = (m['proclamationDuration'] ?? '').toString();
      if (oldCount.isNotEmpty && (int.tryParse(oldCount) ?? 0) > 0) {
        proclamationSessions = [ProclamationSession(
            topic: '', count: int.tryParse(oldCount) ?? 0, duration: oldDuration)];
        migratedProclamationFromScalar = true;
      }
    }

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

    Map<String, Map<String, dynamic>> customData = {};
    try {
      final rawCustom = m['custom_activity_data'];
      if (rawCustom != null && rawCustom.toString().isNotEmpty) {
        final decoded = jsonDecode(rawCustom) as Map<String, dynamic>;
        customData = decoded.map((k, v) =>
            MapEntry(k, Map<String, dynamic>.from(v as Map)));
      }
    } catch (e) {
      debugPrint('DailyLog.fromMap: failed to parse custom_activity_data: $e');
    }

    return DailyLog(
      dateKey: m['dateKey'] ?? '',
      bibleReference: m['bibleReference'] ?? '',
      bibleChapters: m['bibleChapters'] ?? '',
      bibleSessions: sessions,
      literature: lit,
      ddegScripture: m['ddegScripture'] ?? '',
      ddegTime: m['ddegTime'] ?? '',
      ddegNotes: m['ddegNotes'] ?? '',
      ddegSessions: ddegSessions,
      prayerAloneDuration: m['prayerAloneDuration'] ?? '',
      prayerAloneNotes: m['prayerAloneNotes'] ?? '',
      prayerOthersDuration: m['prayerOthersDuration'] ?? '',
      prayerOthersContext: m['prayerOthersContext'] ?? '',
      prayerAloneSessions: prayerAloneSessions,
      prayerOthersSessions: prayerOthersSessions,
      evangelismContacts: m['evangelismContacts'] ?? '',
      evangelismOutcome: m['evangelismOutcome'] ?? '',
      evangelismNotes: m['evangelismNotes'] ?? '',
      evangelismNewBelievers: m['evangelismNewBelievers'] ?? '',
      evangelismBeingDiscipled: m['evangelismBeingDiscipled'] ?? '',
      evangelismFollowUpNotes: m['evangelismFollowUpNotes'] ?? '',
      other: m['other'] ?? '',
      bibleDuration: m['bibleDuration'] ?? '',
      literatureDuration: m['literatureDuration'] ?? '',
      evangelismDuration: m['evangelismDuration'] ?? '',
      givingDuration: m['givingDuration'] ?? '',
      churchDuration: m['churchDuration'] ?? '',
      evangelismSessions: evangelismSessions,
      churchSessions: churchSessions,
      customActivityData: customData,
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
      proclamationCount: migratedProclamationFromScalar ? '' : (m['proclamationCount'] ?? ''),
      proclamationDuration: migratedProclamationFromScalar ? '' : (m['proclamationDuration'] ?? ''),
      proclamationSessions: proclamationSessions,
      voiceNotePath: m['voiceNotePath'] ?? '',
      aiReflection: m['aiReflection'] ?? '',
      completed: (m['completed'] ?? 0) == 1,
    );
  }
}
