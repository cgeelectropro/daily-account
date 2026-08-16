import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/scripture_library.dart';
import '../models/daily_log.dart';
import '../models/goal.dart';
import 'time_totals.dart';

// ═══════════════════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════════════════

/// The structured output of the reflection engine.
class ReflectionResult {
  final String narrative;
  final String encouragement;
  final String suggestion;
  final String? verse;
  final String? verseReference;

  const ReflectionResult({
    required this.narrative,
    required this.encouragement,
    required this.suggestion,
    this.verse,
    this.verseReference,
  });

  String toJsonString() => jsonEncode({
    'narrative': narrative,
    'encouragement': encouragement,
    'suggestion': suggestion,
    'verse': verse,
    'verseReference': verseReference,
  });

  factory ReflectionResult.fromJsonString(String json) {
    final m = jsonDecode(json) as Map<String, dynamic>;
    return ReflectionResult(
      narrative: m['narrative'] ?? '',
      encouragement: m['encouragement'] ?? '',
      suggestion: m['suggestion'] ?? '',
      verse: m['verse'],
      verseReference: m['verseReference'],
    );
  }

  bool get isEmpty => narrative.isEmpty && encouragement.isEmpty;
}

/// Historical context for the reflection engine.
class ReflectionContext {
  final int streak;
  final int weekDaysFilled;
  final double weeklyAvgCompletion;
  final Map<String, double> disciplineRates;
  final Map<String, double> monthRates;
  final String? bestDiscipline;
  final String? weakDiscipline;
  final int totalBibleChaptersThisWeek;
  final int totalEvangelismContactsThisWeek;
  final int totalPrayerMinutesThisWeek;
  final TimeOfDay timeOfDay;
  final List<Goal> completedGoalsToday;

  const ReflectionContext({
    this.streak = 0,
    this.weekDaysFilled = 0,
    this.weeklyAvgCompletion = 0,
    this.disciplineRates = const {},
    this.monthRates = const {},
    this.bestDiscipline,
    this.weakDiscipline,
    this.totalBibleChaptersThisWeek = 0,
    this.totalEvangelismContactsThisWeek = 0,
    this.totalPrayerMinutesThisWeek = 0,
    this.timeOfDay = const TimeOfDay(hour: 12, minute: 0),
    this.completedGoalsToday = const [],
  });
}

// ═══════════════════════════════════════════════════════════
//  PROVIDER INTERFACE
// ═══════════════════════════════════════════════════════════

/// Abstract provider — swap implementations without UI changes.
abstract class ReflectionProvider {
  Future<ReflectionResult> generate(
      DailyLog log, ReflectionContext ctx, String locale);
}

// ═══════════════════════════════════════════════════════════
//  RULE-BASED PROVIDER
// ═══════════════════════════════════════════════════════════

class RuleBasedReflectionProvider implements ReflectionProvider {
  // ── Discipline checks (mirrors ReportService._disciplineChecks) ──
  static const _disciplineNames = [
    'Bible', 'Literature', 'DDEG', 'Prayer', 'Prayer (others)',
    'Evangelism', 'Fasting', 'Giving', 'Church', 'Discipleship', 'Proclamation',
  ];

  static List<bool> _checks(DailyLog l) => [
    l.bibleReference.isNotEmpty || l.bibleChapters.isNotEmpty ||
        l.bibleSessions.any((s) => s.isNotEmpty),
    l.literature.any((e) => e.title.isNotEmpty),
    l.ddegScripture.isNotEmpty || l.ddegNotes.isNotEmpty,
    l.prayerAloneDuration.isNotEmpty,
    l.prayerOthersDuration.isNotEmpty,
    l.evangelismContacts.isNotEmpty || l.evangelismSessions.isNotEmpty,
    l.fastingType.isNotEmpty || l.fastingDuration.isNotEmpty,
    l.givingType.isNotEmpty,
    l.churchType.isNotEmpty || l.churchSessions.isNotEmpty,
    l.discipleshipWho.isNotEmpty,
    l.proclamationCount.isNotEmpty || l.proclamationSessions.isNotEmpty,
  ];

  /// Parse duration strings like "45m", "1h 30m", "30 minutes".
  static int _parseMinutes(String s) {
    if (s.isEmpty || s == '\u2713') return 0;
    final hm = RegExp(r'(\d+)\s*h\s*(\d+)\s*m');
    final hmMatch = hm.firstMatch(s);
    if (hmMatch != null) {
      return int.parse(hmMatch.group(1)!) * 60 + int.parse(hmMatch.group(2)!);
    }
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

  @override
  Future<ReflectionResult> generate(
      DailyLog log, ReflectionContext ctx, String locale) async {
    final checks = _checks(log);
    final filled = checks.where((c) => c).length;
    final isMorning = ctx.timeOfDay.hour < 12;
    final isEvening = ctx.timeOfDay.hour >= 18;
    final seed = log.dateKey.hashCode;
    final rng = Random(seed);

    final narrative = _buildNarrative(log, ctx, checks, filled, isMorning, isEvening, rng, locale);
    final encouragement = _buildEncouragement(log, ctx, checks, filled, rng, locale);
    final suggestion = _buildSuggestion(log, ctx, checks, filled, isMorning, isEvening, locale);
    final verseResult = _pickVerse(log, ctx, checks, filled, isMorning, isEvening, log.dateKey, locale);

    return ReflectionResult(
      narrative: narrative,
      encouragement: encouragement,
      suggestion: suggestion,
      verse: verseResult?.$1,
      verseReference: verseResult?.$2,
    );
  }

  // ── NARRATIVE ─────────────────────────────────────────────

  String _buildNarrative(DailyLog log, ReflectionContext ctx,
      List<bool> checks, int filled, bool isMorning, bool isEvening,
      Random rng, String locale) {
    final isFr = locale.startsWith('fr');

    // Pick main narrative based on priority
    String main;
    if (ctx.streak >= 30) {
      main = _pick(rng, isFr ? [
        'Jour ${ctx.streak} de fidélité ininterrompue — vous bâtissez quelque chose d\'éternel.',
        '${ctx.streak} jours sans interruption. Votre persévérance honore Dieu.',
        'Quelle constance ! ${ctx.streak} jours de marche fidèle avec Dieu.',
      ] : [
        'Day ${ctx.streak} of unbroken faithfulness — you are building something eternal.',
        '${ctx.streak} days without interruption. Your perseverance honors God.',
        'What consistency! ${ctx.streak} days of faithful walk with God.',
      ]);
    } else if (ctx.streak >= 7) {
      main = _pick(rng, isFr ? [
        'Une semaine complète de régularité ! ${ctx.streak} jours et ça continue.',
        '${ctx.streak} jours d\'affilée — votre discipline porte du fruit.',
        'Série de ${ctx.streak} jours ! La constance est le secret de la croissance.',
      ] : [
        'A full week of consistency! ${ctx.streak} days and counting.',
        '${ctx.streak} days in a row — your discipline is bearing fruit.',
        '${ctx.streak}-day streak! Consistency is the secret to growth.',
      ]);
    } else if (ctx.streak <= 1 && ctx.weekDaysFilled > 0 && filled > 0) {
      main = _pick(rng, isFr ? [
        'Bon retour. Chaque nouveau jour est un nouveau départ avec Dieu.',
        'Vous êtes de retour ! La grâce de Dieu est nouvelle chaque matin.',
        'Un nouveau commencement aujourd\'hui. Le passé est derrière, avancez.',
      ] : [
        'Welcome back. Every new day is a fresh start with God.',
        'You\'re back! God\'s grace is new every morning.',
        'A fresh beginning today. The past is behind — press forward.',
      ]);
    } else if (filled >= 9) {
      main = _pick(rng, isFr ? [
        'Une journée extraordinaire — $filled disciplines couvertes. Vous marchez dans la plénitude.',
        '$filled disciplines aujourd\'hui ! Votre autel brûle intensément.',
        'Quel engagement ! $filled disciplines montrent un cœur entièrement dévoué.',
      ] : [
        'An extraordinary day — $filled disciplines covered. You\'re walking in fullness.',
        '$filled disciplines today! Your altar is burning brightly.',
        'What commitment! $filled disciplines show a heart fully devoted.',
      ]);
    } else if (filled >= 6) {
      main = _pick(rng, isFr ? [
        'Bonne journée avec $filled disciplines. Votre régularité grandit.',
        '$filled disciplines — un solide fondement pour la journée.',
        'Bon effort avec $filled disciplines. Vous construisez de bonnes habitudes.',
      ] : [
        'Solid day with $filled disciplines. Your consistency is growing.',
        '$filled disciplines — a strong foundation for the day.',
        'Good effort with $filled disciplines. You\'re building solid habits.',
      ]);
    } else if (filled >= 3) {
      main = _pick(rng, isFr ? [
        'Vous avez bien commencé avec $filled disciplines. Il reste du temps pour en ajouter.',
        '$filled disciplines jusqu\'ici. Chaque pas compte dans votre marche.',
        'Un début prometteur avec $filled disciplines. Continuez sur cette lancée.',
      ] : [
        'You\'ve started well with $filled disciplines. There\'s still time to add more.',
        '$filled disciplines so far. Every step counts in your walk.',
        'A promising start with $filled disciplines. Keep the momentum going.',
      ]);
    } else if (filled >= 1) {
      main = _pick(rng, isFr ? [
        'Chaque pas compte. Vous en avez fait $filled aujourd\'hui — continuez.',
        'Un pas est un pas. $filled discipline enregistrée — la graine est plantée.',
        'Vous avez commencé. C\'est ce qui compte. Ajoutez-en une autre quand vous pouvez.',
      ] : [
        'Every step matters. You\'ve taken $filled today — keep going.',
        'A step is a step. $filled discipline logged — the seed is planted.',
        'You\'ve started. That\'s what matters. Add another when you can.',
      ]);
    } else if (isMorning) {
      main = isFr
          ? 'Bonjour ! Une page blanche attend votre fidélité aujourd\'hui.'
          : 'Good morning! A blank page awaits your faithfulness today.';
    } else if (isEvening) {
      main = isFr
          ? 'La journée n\'est pas finie. Même une seule discipline est une graine plantée.'
          : 'The day isn\'t over yet. Even one discipline logged is a seed planted.';
    } else {
      main = isFr
          ? 'Ouvrez votre cœur aux disciplines d\'aujourd\'hui. Commencez par une.'
          : 'Open your heart to today\'s disciplines. Start with one.';
    }

    // Modifiers
    final weekAvgFilled = ctx.weeklyAvgCompletion * 11;
    if (filled > 0 && filled > weekAvgFilled + 1) {
      main += isFr
          ? ' C\'est au-dessus de votre moyenne — vous progressez.'
          : ' That\'s above your weekly average — you\'re pushing higher.';
    }

    // First-time-this-week detection
    for (int i = 0; i < 11; i++) {
      if (checks[i] && (ctx.disciplineRates[_disciplineNames[i]] ?? 0) == 0) {
        main += isFr
            ? ' Première fois cette semaine pour ${_disciplineNames[i]} — bravo !'
            : ' First time this week for ${_disciplineNames[i]} — well done!';
        break; // Only mention one
      }
    }

    if (filled == 11) {
      main += isFr
          ? ' Une journée parfaite. Chaque discipline touchée. L\'autel brûle pleinement.'
          : ' A perfect day. Every discipline touched. The altar is fully ablaze.';
    }

    return main;
  }

  // ── ENCOURAGEMENT ─────────────────────────────────────────

  String _buildEncouragement(DailyLog log, ReflectionContext ctx,
      List<bool> checks, int filled, Random rng, String locale) {
    final isFr = locale.startsWith('fr');
    final signals = <(int priority, String text)>[];

    // Goal completion — highest priority, always mentioned first if present
    if (ctx.completedGoalsToday.isNotEmpty) {
      final names = ctx.completedGoalsToday.map((g) => g.customLabel ?? g.metricKey).join(', ');
      signals.add((0, isFr
          ? 'Objectif atteint : $names ! Continuez ainsi.'
          : 'Goal reached: $names! Keep it up.'));
    }

    // Bible content
    final bibleRef = log.combinedBibleReference(locale);
    if (bibleRef.isNotEmpty) {
      signals.add((1, isFr
          ? 'Lecture de $bibleRef aujourd\'hui — la Parole est un terrain fertile pour la croissance.'
          : 'Reading $bibleRef today — the Word is rich ground for growth.'));
    }
    if (log.totalBibleChapters >= 5) {
      signals.add((2, isFr
          ? '${log.totalBibleChapters} chapitres aujourd\'hui — vous dévorez la Parole !'
          : '${log.totalBibleChapters} chapters today — you\'re devouring the Word!'));
    }

    // DDEG depth (check sessions first, fall back to legacy)
    final ddegNotesLen = log.ddegSessions.isNotEmpty
        ? log.ddegSessions.fold(0, (sum, s) => sum + s.notes.length)
        : log.ddegNotes.length;
    if (ddegNotesLen > 50) {
      signals.add((3, isFr
          ? 'Vos notes RDQD montrent une réflexion profonde. Dieu parle à ceux qui écoutent.'
          : 'Your DDEG notes show deep reflection. God speaks to those who listen.'));
    }

    // Prayer duration (session-aware)
    int prayerMin = 0;
    if (log.prayerAloneSessions.any((s) => s.isNotEmpty)) {
      for (final s in log.prayerAloneSessions) {
        prayerMin += _parseMinutes(s.duration);
      }
    } else {
      prayerMin += _parseMinutes(log.prayerAloneDuration);
    }
    if (log.prayerOthersSessions.any((s) => s.isNotEmpty)) {
      for (final s in log.prayerOthersSessions) {
        prayerMin += _parseMinutes(s.duration);
      }
    } else {
      prayerMin += _parseMinutes(log.prayerOthersDuration);
    }
    if (prayerMin >= 30) {
      final avgPrayer = ctx.totalPrayerMinutesThisWeek ~/
          max(1, ctx.weekDaysFilled);
      final comparison = prayerMin > avgPrayer
          ? (isFr ? 'au-dessus de votre moyenne' : 'above your average')
          : (isFr ? 'un investissement constant' : 'a consistent investment');
      signals.add((4, isFr
          ? '$prayerMin minutes en prière — $comparison.'
          : '$prayerMin minutes in prayer — $comparison.'));
    }

    // Evangelism contacts
    final contacts = int.tryParse(log.evangelismContacts) ?? 0;
    if (contacts >= 2) {
      signals.add((5, isFr
          ? '$contacts âmes atteintes aujourd\'hui. Le champ de la moisson répond.'
          : '$contacts souls reached today. The harvest field is responding.'));
    }

    // Fasting
    if (log.fastingType.isNotEmpty && log.fastingType != '\u2713') {
      signals.add((6, isFr
          ? 'Jeûne aujourd\'hui — renoncer à la chair pour nourrir l\'esprit.'
          : 'Fasting today — denying the flesh to feed the spirit.'));
    }

    // Literature
    final litTitles = log.literature
        .where((l) => l.title.isNotEmpty && l.title != '\u2713')
        .map((l) => l.title)
        .toList();
    if (litTitles.isNotEmpty) {
      final title = litTitles.first;
      signals.add((7, isFr
          ? 'Lecture de « $title » — nourrir l\'esprit aux côtés de l\'âme.'
          : 'Reading \'$title\' — feeding your mind alongside your spirit.'));
    }

    // Discipleship
    if (log.discipleshipWho.isNotEmpty && log.discipleshipWho != '\u2713') {
      signals.add((8, isFr
          ? 'Investir dans ${log.discipleshipWho} — la multiplication est le cœur de la CMFI.'
          : 'Pouring into ${log.discipleshipWho} — multiplication is the heart of CMFI.'));
    }

    // Proclamation
    final procCount = log.totalProclamationCount;
    if (procCount >= 3) {
      signals.add((9, isFr
          ? '$procCount proclamations aujourd\'hui — déclarer les promesses de Dieu avec audace.'
          : '$procCount proclamations today — declaring God\'s promises with boldness.'));
    }

    // Total time
    final totalMin = TimeTotals.consecratedMinutes(log);
    if (totalMin >= 60) {
      final hours = totalMin ~/ 60;
      final mins = totalMin % 60;
      final timeStr = hours > 0 && mins > 0 ? '${hours}h${mins}m'
          : hours > 0 ? '${hours}h' : '${mins}m';
      signals.add((10, isFr
          ? '$timeStr de temps consacré aujourd\'hui. C\'est de la dévotion.'
          : '$timeStr of consecrated time today. That\'s devotion.'));
    }

    if (signals.isEmpty) {
      return isFr
          ? 'Chaque discipline que vous touchez, même brièvement, est une graine plantée dans la bonne terre.'
          : 'Every discipline you touch, however briefly, is a seed planted in good soil.';
    }

    // Sort by priority (lower = higher priority)
    signals.sort((a, b) => a.$1.compareTo(b.$1));

    if (signals.length >= 2) {
      return '${signals[0].$2} ${signals[1].$2}';
    }
    return signals[0].$2;
  }

  // ── SUGGESTION ────────────────────────────────────────────

  String _buildSuggestion(DailyLog log, ReflectionContext ctx,
      List<bool> checks, int filled, bool isMorning, bool isEvening,
      String locale) {
    final isFr = locale.startsWith('fr');

    // Find missing disciplines
    final missing = <String>[];
    for (int i = 0; i < 11; i++) {
      if (!checks[i]) missing.add(_disciplineNames[i]);
    }

    // Priority 1: Weakest monthly discipline is missing today
    if (ctx.weakDiscipline != null && missing.contains(ctx.weakDiscipline)) {
      final d = ctx.weakDiscipline!;
      return isFr
          ? 'Votre $d a été calme dernièrement — même un petit pas aujourd\'hui créerait un élan.'
          : 'Your $d has been quiet lately — even a small step today would build momentum.';
    }

    // Priority 2: A discipline done 0 times this week and missing today
    for (final m in missing) {
      if ((ctx.disciplineRates[m] ?? 0) == 0) {
        return isFr
            ? 'Vous n\'avez pas touché $m cette semaine. Aujourd\'hui pourrait être le jour.'
            : 'You haven\'t touched $m this week. Today could be the day.';
      }
    }

    // Priority 3: Filled < 6 and before evening
    if (filled < 6 && !isEvening && missing.isNotEmpty) {
      return isFr
          ? 'Il vous reste du temps — essayez d\'ajouter ${missing.first} avant la fin de la journée.'
          : 'You still have time — try adding ${missing.first} before the day ends.';
    }

    // Priority 4: Almost perfect
    if (filled >= 9 && filled < 11) {
      final left = missing.length == 1 ? missing.first : '${missing.length} disciplines';
      return isFr
          ? 'Vous êtes si proche d\'une journée parfaite ! Il ne reste que $left.'
          : 'You\'re so close to a perfect day! Just $left left.';
    }

    // Priority 5: All 11 filled
    if (filled == 11) {
      final weak = ctx.weakDiscipline ?? 'prayer';
      return isFr
          ? 'Toutes les disciplines couvertes ! Demain, essayez d\'approfondir $weak.'
          : 'All disciplines covered! Tomorrow, try going deeper in $weak.';
    }

    // Priority 6: Morning, nothing yet
    if (isMorning && filled == 0) {
      final strong = ctx.bestDiscipline ?? 'Bible';
      return isFr
          ? 'Commencez par $strong — construisez l\'élan à partir de votre force.'
          : 'Start with $strong — build momentum from strength.';
    }

    // Default
    return isFr
        ? 'Choisissez une discipline et consacrez-y quelques minutes. Chaque petit pas compte.'
        : 'Pick one discipline and give it a few minutes. Every small step counts.';
  }

  // ── VERSE SELECTION ───────────────────────────────────────

  (String, String)? _pickVerse(DailyLog log, ReflectionContext ctx,
      List<bool> checks, int filled, bool isMorning, bool isEvening,
      String dateKey, String locale) {
    // Determine the best tag based on today's strongest signal
    String tag;

    // Map discipline indices to verse tags
    const indexToTag = [
      'bible', 'literature', 'ddeg', 'prayer', 'prayer',
      'evangelism', 'fasting', 'giving', 'church', 'discipleship', 'proclamation',
    ];

    // Find the discipline with the richest content today
    if (log.ddegNotes.length > 50) {
      tag = 'ddeg';
    } else if (log.totalBibleChapters >= 3) {
      tag = 'bible';
    } else if ((int.tryParse(log.evangelismContacts) ?? 0) >= 2) {
      tag = 'evangelism';
    } else if (_parseMinutes(log.prayerAloneDuration) >= 20) {
      tag = 'prayer';
    } else if (log.fastingType.isNotEmpty && log.fastingType != '\u2713') {
      tag = 'fasting';
    } else if (log.discipleshipWho.isNotEmpty && log.discipleshipWho != '\u2713') {
      tag = 'discipleship';
    } else if (ctx.streak >= 7) {
      tag = 'streak';
    } else if (ctx.streak <= 1 && filled > 0 && ctx.weekDaysFilled > 0) {
      tag = 'comeback';
    } else if (filled >= 7) {
      tag = 'balanced';
    } else if (filled > 0) {
      // Pick tag of the first completed discipline
      tag = isMorning ? 'morning' : isEvening ? 'evening' : 'bible';
      for (int i = 0; i < 11; i++) {
        if (checks[i]) {
          tag = indexToTag[i];
          break;
        }
      }
    } else {
      tag = isMorning ? 'morning' : isEvening ? 'evening' : 'bible';
    }

    final verse = ScriptureLibrary.pickFromTag(tag, dateKey);
    if (verse == null) return null;
    return (verse.text(locale), verse.reference);
  }

  // ── HELPERS ───────────────────────────────────────────────

  String _pick(Random rng, List<String> options) =>
      options[rng.nextInt(options.length)];
}

// ═══════════════════════════════════════════════════════════
//  SERVICE SINGLETON
// ═══════════════════════════════════════════════════════════

class ReflectionService {
  static final ReflectionService instance = ReflectionService._();
  ReflectionService._();

  ReflectionProvider _provider = RuleBasedReflectionProvider();

  /// Swap the provider (for future AI integration).
  void setProvider(ReflectionProvider provider) => _provider = provider;

  /// Generate a reflection for the given log and context.
  Future<ReflectionResult> generate(
      DailyLog log, ReflectionContext ctx, String locale) {
    return _provider.generate(log, ctx, locale);
  }
}
