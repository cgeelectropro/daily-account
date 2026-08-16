import 'package:intl/intl.dart';
import '../data/reading_plans.dart';
import 'reading_plan_service.dart';
import 'storage_service.dart';

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

/// All-time cumulative statistics for a disciple's journey.
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

/// A single trend arrow for one discipline.
class TrendSignal {
  /// Discipline label (e.g. 'Bible', 'Prayer').
  final String discipline;

  /// '↑', '↓', or '→'
  final String arrow;

  /// Raw count this week.
  final int thisWeek;

  /// Raw count last week.
  final int lastWeek;

  const TrendSignal({
    required this.discipline,
    required this.arrow,
    required this.thisWeek,
    required this.lastWeek,
  });
}

/// Aggregated counts for all tracked disciplines in a single week.
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
    required this.daysLogged,
    required this.bibleChapters,
    required this.bibleDays,
    required this.prayerDays,
    required this.prayerMinutes,
    required this.evangelismContacts,
    required this.evangelismDays,
    required this.fastingDays,
    required this.givingDays,
    required this.churchDays,
    required this.discipleshipDays,
    required this.literatureItems,
    required this.ddegDays,
    required this.proclamationDays,
  });

  static const WeekDisciplineCounts zero = WeekDisciplineCounts(
    daysLogged: 0,
    bibleChapters: 0,
    bibleDays: 0,
    prayerDays: 0,
    prayerMinutes: 0,
    evangelismContacts: 0,
    evangelismDays: 0,
    fastingDays: 0,
    givingDays: 0,
    churchDays: 0,
    discipleshipDays: 0,
    literatureItems: 0,
    ddegDays: 0,
    proclamationDays: 0,
  );
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Generates narrative summaries, trend signals, and milestone detection
/// for weekly spiritual-accountability reports.
class ReportIntelligenceService {
  static final ReportIntelligenceService instance =
      ReportIntelligenceService._();
  ReportIntelligenceService._();

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Parse duration strings into minutes.
  /// Handles: "30 minutes", "1h 30m", "1h15m", "45m", "2h", plain numbers,
  /// "Xs" (seconds from timer). Returns 0 for empty / unrecognised.
  int _parseMinutes(String s) {
    if (s.isEmpty || s == '✓') return 0;

    // "Xh Ym" or "XhYm"
    final hm = RegExp(r'(\d+)\s*h\s*(\d+)\s*m', caseSensitive: false);
    final hmMatch = hm.firstMatch(s);
    if (hmMatch != null) {
      return int.parse(hmMatch.group(1)!) * 60 +
          int.parse(hmMatch.group(2)!);
    }

    // "Xh" only
    final hOnly = RegExp(r'(\d+)\s*h', caseSensitive: false);
    final hMatch = hOnly.firstMatch(s);
    if (hMatch != null) return int.parse(hMatch.group(1)!) * 60;

    // "Xm" or "X minutes" or "X min"
    final mOnly = RegExp(r'(\d+)\s*m(?:in(?:utes?)?)?', caseSensitive: false);
    final mMatch = mOnly.firstMatch(s);
    if (mMatch != null) return int.parse(mMatch.group(1)!);

    // "Xs" — seconds only (from stopwatch timer)
    final sOnly = RegExp(r'^(\d+)\s*s$', caseSensitive: false);
    final sMatch = sOnly.firstMatch(s.trim());
    if (sMatch != null) return (int.parse(sMatch.group(1)!) / 60).ceil();

    // Plain number — assume minutes
    final n = int.tryParse(s.trim());
    if (n != null) return n;

    return 0;
  }

  /// Produce a TrendSignal: ↑ if ≥20% increase, ↓ if ≥20% decrease, → otherwise.
  TrendSignal _signal(String discipline, int thisWeek, int lastWeek) {
    String arrow;
    if (lastWeek == 0) {
      arrow = thisWeek > 0 ? '↑' : '→';
    } else {
      final change = (thisWeek - lastWeek) / lastWeek;
      if (change >= 0.20) {
        arrow = '↑';
      } else if (change <= -0.20) {
        arrow = '↓';
      } else {
        arrow = '→';
      }
    }
    return TrendSignal(
      discipline: discipline,
      arrow: arrow,
      thisWeek: thisWeek,
      lastWeek: lastWeek,
    );
  }

  /// Compute percentage change between two values (returns null when lastWeek == 0).
  double? _computeChangePct(int thisWeek, int lastWeek) {
    if (lastWeek == 0) return null;
    return (thisWeek - lastWeek) / lastWeek;
  }

  // ── Core computations ────────────────────────────────────────────────────

  /// Iterate logs between [startKey] and [endKey] and tally all disciplines.
  Future<WeekDisciplineCounts> computeWeekCounts(
      String startKey, String endKey) async {
    final logs =
        await StorageService.instance.getLogsBetween(startKey, endKey);

    int daysLogged = 0;
    int bibleChapters = 0;
    int bibleDays = 0;
    int prayerDays = 0;
    int prayerMinutes = 0;
    int evangelismContacts = 0;
    int evangelismDays = 0;
    int fastingDays = 0;
    int givingDays = 0;
    int churchDays = 0;
    int discipleshipDays = 0;
    int literatureItems = 0;
    int ddegDays = 0;
    int proclamationDays = 0;

    for (final log in logs) {
      // A day is "logged" if it has any content at all.
      if (log.completeness > 0) daysLogged++;

      // Bible
      final hasBible = log.bibleReference.isNotEmpty ||
          log.bibleChapters.isNotEmpty ||
          log.bibleSessions.any((s) => s.isNotEmpty);
      if (hasBible) bibleDays++;
      bibleChapters += log.totalBibleChapters;

      // Prayer (session-aware)
      final hasPrayer = log.prayerAloneSessions.any((s) => s.isNotEmpty) ||
          log.prayerOthersSessions.any((s) => s.isNotEmpty) ||
          log.prayerAloneDuration.isNotEmpty ||
          log.prayerOthersDuration.isNotEmpty;
      if (hasPrayer) prayerDays++;
      if (log.prayerAloneSessions.any((s) => s.isNotEmpty)) {
        for (final s in log.prayerAloneSessions) {
          prayerMinutes += _parseMinutes(s.duration);
        }
      } else {
        prayerMinutes += _parseMinutes(log.prayerAloneDuration);
      }
      if (log.prayerOthersSessions.any((s) => s.isNotEmpty)) {
        for (final s in log.prayerOthersSessions) {
          prayerMinutes += _parseMinutes(s.duration);
        }
      } else {
        prayerMinutes += _parseMinutes(log.prayerOthersDuration);
      }

      // Evangelism
      final contactCount = int.tryParse(log.evangelismContacts) ?? 0;
      evangelismContacts += contactCount;
      if (log.evangelismContacts.isNotEmpty || log.evangelismSessions.isNotEmpty) evangelismDays++;

      // Fasting
      if (log.fastingType.isNotEmpty || log.fastingDuration.isNotEmpty) {
        fastingDays++;
      }

      // Giving
      if (log.givingType.isNotEmpty) givingDays++;

      // Church
      if (log.churchType.isNotEmpty || log.churchSessions.isNotEmpty) churchDays++;

      // Discipleship
      if (log.discipleshipWho.isNotEmpty) discipleshipDays++;

      // Literature
      literatureItems +=
          log.literature.where((e) => e.title.isNotEmpty).length;

      // DDEG (session-aware)
      if (log.ddegSessions.any((s) => s.isNotEmpty) ||
          log.ddegScripture.isNotEmpty || log.ddegNotes.isNotEmpty) {
        ddegDays++;
      }

      // Proclamation
      if (log.proclamationCount.isNotEmpty || log.proclamationSessions.isNotEmpty) proclamationDays++;
    }

    return WeekDisciplineCounts(
      daysLogged: daysLogged,
      bibleChapters: bibleChapters,
      bibleDays: bibleDays,
      prayerDays: prayerDays,
      prayerMinutes: prayerMinutes,
      evangelismContacts: evangelismContacts,
      evangelismDays: evangelismDays,
      fastingDays: fastingDays,
      givingDays: givingDays,
      churchDays: churchDays,
      discipleshipDays: discipleshipDays,
      literatureItems: literatureItems,
      ddegDays: ddegDays,
      proclamationDays: proclamationDays,
    );
  }

  /// Build a concise narrative summary picking the top 3–4 signals from
  /// 8 priority buckets.
  String buildNarrativeSummary({
    required WeekDisciplineCounts thisWeek,
    required WeekDisciplineCounts lastWeek,
    required int streak,
    required String locale,
  }) {
    final isFr = locale.startsWith('fr');
    final signals = <String>[];

    // ── Priority 1: Streak milestone ─────────────────────────────────────
    const milestones = [365, 100, 30, 7];
    for (final m in milestones) {
      if (streak == m) {
        signals.add(isFr
            ? 'Félicitations ! $m jours consécutifs de fidélité — quelle grâce de Dieu !'
            : 'Milestone! $m consecutive days of faithfulness — praise God!');
        break;
      }
    }

    // ── Priority 2: Perfect week ──────────────────────────────────────────
    if (signals.length < 4 && thisWeek.daysLogged == 7) {
      signals.add(isFr
          ? 'Semaine parfaite : 7 jours enregistrés — gloire à Dieu !'
          : 'Perfect week: all 7 days logged — glory to God!');
    }

    // ── Priority 3: Days comparison vs last week ──────────────────────────
    if (signals.length < 4) {
      final daysDiff = thisWeek.daysLogged - lastWeek.daysLogged;
      if (daysDiff > 0 && lastWeek.daysLogged > 0) {
        signals.add(isFr
            ? '${thisWeek.daysLogged} jours enregistrés cette semaine — $daysDiff de plus que la semaine dernière.'
            : '${thisWeek.daysLogged} days logged this week — $daysDiff more than last week.');
      } else if (daysDiff < 0 && lastWeek.daysLogged > 0) {
        final drop = -daysDiff;
        signals.add(isFr
            ? '${thisWeek.daysLogged} jours enregistrés cette semaine — $drop de moins que la semaine dernière.'
            : '${thisWeek.daysLogged} days logged this week — $drop fewer than last week.');
      } else if (thisWeek.daysLogged > 0) {
        signals.add(isFr
            ? '${thisWeek.daysLogged} jours enregistrés cette semaine.'
            : '${thisWeek.daysLogged} days logged this week.');
      }
    }

    // ── Priority 4: Biggest improvement (≥20%) ────────────────────────────
    if (signals.length < 4) {
      final best = _findBestImprovement(thisWeek, lastWeek, isFr);
      if (best != null) signals.add(best);
    }

    // ── Priority 5: Biggest decline (≥20%) ───────────────────────────────
    if (signals.length < 4) {
      final worst = _findBiggestDecline(thisWeek, lastWeek, isFr);
      if (worst != null) signals.add(worst);
    }

    // ── Priority 6: Notable activity (≥3 evangelism contacts or ≥2 fasting days) ──
    if (signals.length < 4) {
      if (thisWeek.evangelismContacts >= 3) {
        signals.add(isFr
            ? '${thisWeek.evangelismContacts} contacts évangéliques cette semaine — continue !'
            : '${thisWeek.evangelismContacts} evangelism contacts this week — keep pressing!');
      } else if (thisWeek.fastingDays >= 2) {
        signals.add(isFr
            ? '${thisWeek.fastingDays} jours de jeûne cette semaine — beau sacrifice.'
            : '${thisWeek.fastingDays} fasting days this week — beautiful sacrifice.');
      }
    }

    // ── Priority 7: Streak status (if not already a milestone) ───────────
    if (signals.length < 4 && streak > 0) {
      final alreadyMilestone = milestones.contains(streak);
      if (!alreadyMilestone) {
        signals.add(isFr
            ? 'Série en cours : $streak jour${streak == 1 ? '' : 's'} consécutif${streak == 1 ? '' : 's'}.'
            : 'Current streak: $streak consecutive day${streak == 1 ? '' : 's'}.');
      }
    }

    // ── Priority 8: Plan progress ──────────────────────────────────────────
    if (signals.length < 4) {
      final plan = ReadingPlanService.instance.activePlan;
      if (plan != null && !plan.isComplete) {
        final pct = (plan.progress * 100).round();
        final planDef = ReadingPlans.getById(plan.planId);
        if (planDef != null) {
          signals.add(isFr
              ? 'Plan ${planDef.name('fr')} : $pct% complété.'
              : '${planDef.name('en')} plan: $pct% complete.');
        }
      }
    }

    if (signals.isEmpty) {
      return isFr
          ? 'Continuez à persévérer dans la foi — chaque jour compte !'
          : 'Keep pressing on in faith — every day counts!';
    }

    return signals.take(4).join(' ');
  }

  /// Compute trend arrows for all 8 tracked disciplines.
  List<TrendSignal> computeTrendSignals(
    WeekDisciplineCounts thisWeek,
    WeekDisciplineCounts lastWeek,
  ) {
    return [
      _signal('Bible', thisWeek.bibleDays, lastWeek.bibleDays),
      _signal('Prayer', thisWeek.prayerDays, lastWeek.prayerDays),
      _signal('Evangelism', thisWeek.evangelismDays, lastWeek.evangelismDays),
      _signal('DDEG', thisWeek.ddegDays, lastWeek.ddegDays),
      _signal('Fasting', thisWeek.fastingDays, lastWeek.fastingDays),
      _signal('Literature', thisWeek.literatureItems, lastWeek.literatureItems),
      _signal(
          'Discipleship', thisWeek.discipleshipDays, lastWeek.discipleshipDays),
      _signal('Church', thisWeek.churchDays, lastWeek.churchDays),
    ];
  }

  /// Query ALL logs from 2020-01-01 to today, compute cumulative stats
  /// and the all-time longest streak.
  Future<CumulativeStats> computeAllTimeStats() async {
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    const startKey = '2020-01-01';

    final logs =
        await StorageService.instance.getLogsBetween(startKey, todayKey);

    // Build a sorted set of completed dateKeys for streak computation.
    final completedKeys = <String>{};
    int totalChapters = 0;
    int totalContacts = 0;
    int totalDaysLogged = 0;

    for (final log in logs) {
      if (log.completeness > 0) {
        totalDaysLogged++;
        totalChapters += log.totalBibleChapters;
        totalContacts +=
            int.tryParse(log.evangelismContacts) ?? 0;
        if (log.completed) completedKeys.add(log.dateKey);
      }
    }

    // Compute longest consecutive streak across all time.
    int longestStreak = 0;
    int currentStreak = 0;
    // Walk forward from 2020-01-01 to today.
    var cursor = DateTime(2020, 1, 1);
    while (!cursor.isAfter(today)) {
      final key = DateFormat('yyyy-MM-dd').format(cursor);
      if (completedKeys.contains(key)) {
        currentStreak++;
        if (currentStreak > longestStreak) longestStreak = currentStreak;
      } else {
        currentStreak = 0;
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return CumulativeStats(
      totalChapters: totalChapters,
      totalEvangelismContacts: totalContacts,
      totalDaysLogged: totalDaysLogged,
      longestStreakEver: longestStreak,
    );
  }

  /// Check which milestones have just been reached and return localised
  /// celebration strings.  Each milestone is stored in SharedPreferences as
  /// `milestone_<key>` = 'true' so it is only announced once.
  Future<List<String>> checkNewMilestones({
    required CumulativeStats stats,
    required int currentStreak,
    required int daysLoggedThisWeek,
    required String locale,
  }) async {
    final isFr = locale.startsWith('fr');
    final newMilestones = <String>[];

    // ── Chapter milestones ────────────────────────────────────────────────
    const chapterThresholds = [100, 250, 500, 1000, 2000];
    for (final threshold in chapterThresholds) {
      if (stats.totalChapters >= threshold) {
        final key = 'milestone_chapters_$threshold';
        final already = await StorageService.instance
            .getSetting(key, fallback: '');
        if (already != 'true') {
          await StorageService.instance.setSetting(key, 'true');
          newMilestones.add(isFr
              ? '$threshold chapitres lus au total — quelle fidélité !'
              : '$threshold chapters read in total — what faithfulness!');
        }
      }
    }

    // ── Longest-streak record ─────────────────────────────────────────────
    if (currentStreak > 0 && currentStreak == stats.longestStreakEver) {
      final key = 'milestone_streak_record_$currentStreak';
      final already =
          await StorageService.instance.getSetting(key, fallback: '');
      if (already != 'true') {
        await StorageService.instance.setSetting(key, 'true');
        newMilestones.add(isFr
            ? 'Nouveau record de série : $currentStreak jours consécutifs !'
            : 'New streak record: $currentStreak consecutive days!');
      }
    }

    // ── Perfect week ──────────────────────────────────────────────────────
    if (daysLoggedThisWeek == 7) {
      // Use a week-indexed key so it fires once per perfect week.
      final weekKey = DateFormat('yyyy-ww').format(DateTime.now());
      final key = 'milestone_perfect_week_$weekKey';
      final already =
          await StorageService.instance.getSetting(key, fallback: '');
      if (already != 'true') {
        await StorageService.instance.setSetting(key, 'true');
        newMilestones.add(isFr
            ? 'Semaine parfaite — 7 jours enregistrés !'
            : 'Perfect week — 7 days logged!');
      }
    }

    // ── Evangelism milestones ─────────────────────────────────────────────
    const evangelismThresholds = [50, 100, 250, 500];
    for (final threshold in evangelismThresholds) {
      if (stats.totalEvangelismContacts >= threshold) {
        final key = 'milestone_evangelism_$threshold';
        final already =
            await StorageService.instance.getSetting(key, fallback: '');
        if (already != 'true') {
          await StorageService.instance.setSetting(key, 'true');
          newMilestones.add(isFr
              ? '$threshold contacts évangéliques au total — gloire à Dieu !'
              : '$threshold evangelism contacts in total — glory to God!');
        }
      }
    }

    // ── Plan completion ─────────────────────────────────────────────────
    final plan = ReadingPlanService.instance.activePlan;
    if (plan != null && plan.isComplete) {
      final key = 'milestone_plan_${plan.planId}';
      final already =
          await StorageService.instance.getSetting(key, fallback: '');
      if (already != 'true') {
        await StorageService.instance.setSetting(key, 'true');
        final planDef = ReadingPlans.getById(plan.planId);
        final planName = planDef?.name(locale) ?? plan.planId;
        newMilestones.add(isFr
            ? 'Plan terminé : $planName — gloire à Dieu !'
            : 'Plan completed: $planName — glory to God!');
      }
    }

    return newMilestones;
  }

  // ── Private helpers for narrative ────────────────────────────────────────

  /// Returns a localised string for the single best-improving discipline
  /// (≥20% increase week-over-week), or null if none qualify.
  String? _findBestImprovement(
    WeekDisciplineCounts thisWeek,
    WeekDisciplineCounts lastWeek,
    bool isFr,
  ) {
    final changes = _computeAllChanges(thisWeek, lastWeek);
    MapEntry<String, double>? best;
    for (final entry in changes.entries) {
      if (entry.value >= 0.20) {
        if (best == null || entry.value > best.value) {
          best = entry;
        }
      }
    }
    if (best == null) return null;
    final pct = (best.value * 100).round();
    return isFr
        ? '${_disciplineLabel(best.key, isFr)} en hausse de $pct % par rapport à la semaine dernière.'
        : '${_disciplineLabel(best.key, isFr)} up $pct% from last week.';
  }

  /// Returns a localised string for the single biggest declining discipline
  /// (≥20% decrease week-over-week), or null if none qualify.
  String? _findBiggestDecline(
    WeekDisciplineCounts thisWeek,
    WeekDisciplineCounts lastWeek,
    bool isFr,
  ) {
    final changes = _computeAllChanges(thisWeek, lastWeek);
    MapEntry<String, double>? worst;
    for (final entry in changes.entries) {
      if (entry.value <= -0.20) {
        if (worst == null || entry.value < worst.value) {
          worst = entry;
        }
      }
    }
    if (worst == null) return null;
    final pct = (-worst.value * 100).round();
    return isFr
        ? '${_disciplineLabel(worst.key, isFr)} en baisse de $pct % — ne vous découragez pas !'
        : '${_disciplineLabel(worst.key, isFr)} down $pct% — keep pressing on!';
  }

  /// Returns a map of discipline-key → fractional change for all disciplines.
  Map<String, double> _computeAllChanges(
    WeekDisciplineCounts thisWeek,
    WeekDisciplineCounts lastWeek,
  ) {
    final result = <String, double>{};
    void add(String key, int tw, int lw) {
      final pct = _computeChangePct(tw, lw);
      if (pct != null) result[key] = pct;
    }

    add('bible', thisWeek.bibleDays, lastWeek.bibleDays);
    add('prayer', thisWeek.prayerDays, lastWeek.prayerDays);
    add('evangelism', thisWeek.evangelismDays, lastWeek.evangelismDays);
    add('ddeg', thisWeek.ddegDays, lastWeek.ddegDays);
    add('fasting', thisWeek.fastingDays, lastWeek.fastingDays);
    add('literature', thisWeek.literatureItems, lastWeek.literatureItems);
    add('discipleship', thisWeek.discipleshipDays, lastWeek.discipleshipDays);
    add('church', thisWeek.churchDays, lastWeek.churchDays);
    return result;
  }

  /// Human-friendly localised label for a discipline key.
  String _disciplineLabel(String key, bool isFr) {
    const en = {
      'bible': 'Bible reading',
      'prayer': 'Prayer',
      'evangelism': 'Evangelism',
      'ddeg': 'DDEG',
      'fasting': 'Fasting',
      'literature': 'Literature',
      'discipleship': 'Discipleship',
      'church': 'Church',
    };
    const fr = {
      'bible': 'Lecture de la Bible',
      'prayer': 'Prière',
      'evangelism': 'Évangélisation',
      'ddeg': 'RDQD',
      'fasting': 'Jeûne',
      'literature': 'Lecture',
      'discipleship': 'Discipulat',
      'church': 'Église',
    };
    return (isFr ? fr[key] : en[key]) ?? key;
  }
}
