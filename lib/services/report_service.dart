import 'package:daily_account/models/daily_log.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/reading_plans.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/custom_activity.dart';
import 'duration_parser.dart';
import 'reading_plan_service.dart';
import 'report_cadence_service.dart';
import 'storage_service.dart';
import 'time_totals.dart';

class WeekStats {
  int daysLogged;
  int totalBibleChapters;
  int totalEvangelismContacts;
  int litItems;
  int totalPrayerMinutes;
  WeekStats(this.daysLogged, this.totalBibleChapters, this.totalEvangelismContacts, this.litItems, this.totalPrayerMinutes);
}

class MonthStats {
  int daysLogged;
  int totalDays;
  int totalBibleChapters;
  int totalEvangelismContacts;
  int litItems;
  int weeksReported;
  double avgCompletion;
  MonthStats({
    required this.daysLogged,
    required this.totalDays,
    required this.totalBibleChapters,
    required this.totalEvangelismContacts,
    required this.litItems,
    required this.weeksReported,
    required this.avgCompletion,
  });
}

/// Per-discipline consistency data for trend analysis.
class TrendData {
  /// Overall consistency this week (0.0–1.0).
  final double currentConsistency;
  /// Overall consistency last month (0.0–1.0).
  final double lastMonthConsistency;
  /// Per-discipline consistency this week — discipline name → (days done / total days).
  final Map<String, double> disciplineRates;
  /// Best discipline name.
  final String? bestDiscipline;
  /// Weakest discipline name.
  final String? weakDiscipline;
  /// Whether enough data exists.
  final bool hasData;

  TrendData({
    required this.currentConsistency,
    required this.lastMonthConsistency,
    required this.disciplineRates,
    this.bestDiscipline,
    this.weakDiscipline,
    required this.hasData,
  });

  /// Change percentage points: positive = improvement.
  double get change => currentConsistency - lastMonthConsistency;
}

/// Builds the weekly report and dispatches it via email, WhatsApp, or share.
///
/// Two report formats:
///   - **Full**: Detailed day-by-day, used for email and clipboard
///   - **Compact**: Summary-first, condensed daily notes, used for WhatsApp
class ReportService {
  static final ReportService instance = ReportService._();
  ReportService._();

  /// 7-day window ending on [endWeekday] (DateTime.weekday convention,
  /// default DateTime.sunday) that contains [ref] (default today).
  List<DateTime> weekDates([DateTime? ref, int? endWeekday]) {
    final today = ref ?? DateTime.now();
    final end = endWeekday ?? DateTime.sunday;
    // Days to add to today's weekday to reach the next (or same-day)
    // occurrence of `end` (0 if today already is that weekday).
    final daysUntilEnd = (end - today.weekday + 7) % 7;
    final lastDayOfWindow = today.add(Duration(days: daysUntilEnd));
    final start = lastDayOfWindow.subtract(const Duration(days: 6));
    return List.generate(7, (i) => DateTime(start.year, start.month, start.day + i));
  }

  String keyFor(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<WeekStats> computeWeekStats([DateTime? ref]) async {
    final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
    final dates = weekDates(ref, endWeekday);
    final logs = await StorageService.instance
        .getLogsBetween(keyFor(dates.first), keyFor(dates.last));
    int days = 0, chapters = 0, contacts = 0, lit = 0, prayerMins = 0;
    for (final l in logs) {
      if (l.completed) days++;
      chapters += l.totalBibleChapters;
      contacts += int.tryParse(l.evangelismContacts) ?? 0;
      lit += l.literature.where((e) => e.title.isNotEmpty).length;
      final paSess = l.prayerAloneSessions.where((s) => s.isNotEmpty);
      if (paSess.isNotEmpty) {
        for (final s in paSess) {
          prayerMins += parseDurationMinutes(s.duration);
        }
      } else {
        prayerMins += parseDurationMinutes(l.prayerAloneDuration);
      }
      final poSess = l.prayerOthersSessions.where((s) => s.isNotEmpty);
      if (poSess.isNotEmpty) {
        for (final s in poSess) {
          prayerMins += parseDurationMinutes(s.duration);
        }
      } else {
        prayerMins += parseDurationMinutes(l.prayerOthersDuration);
      }
    }
    return WeekStats(days, chapters, contacts, lit, prayerMins);
  }

  /// Sum all duration fields across a list of logs.
  static int _totalConsecratedMinutes(List<DailyLog> logs) {
    int total = 0;
    for (final log in logs) {
      total += TimeTotals.consecratedMinutes(log);
    }
    return total;
  }

  /// Format minutes as "Xh Ym".
  static String _formatTotalTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  /// Current consecutive-day streak ending today.
  /// Uses a single batch query instead of N+1 individual queries.
  Future<int> computeStreak() async {
    final today = DateTime.now();
    // Fetch last 365 days in one query
    final start = today.subtract(const Duration(days: 365));
    final logs = await StorageService.instance
        .getLogsBetween(keyFor(start), keyFor(today));
    // Build a set of completed date keys for O(1) lookup
    final completedDays = <String>{
      for (final log in logs)
        if (log.completed) log.dateKey,
    };

    int streak = 0;
    var day = today;
    for (int i = 0; i < 365; i++) {
      if (completedDays.contains(keyFor(day))) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        if (i == 0) {
          // Today not yet completed — check yesterday
          day = day.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
    }
    return streak;
  }

  // ═══════════════════════════════════════════════════════════
  //  TREND ANALYSIS
  // ═══════════════════════════════════════════════════════════

  static const _disciplineNames = [
    'Bible', 'Literature', 'DDEG', 'Prayer (alone)',
    'Prayer (others)', 'Evangelism', 'Fasting',
    'Giving', 'Church', 'Discipleship', 'Proclamation',
  ];

  static List<bool> _disciplineChecks(DailyLog l) => [
    l.bibleReference.isNotEmpty || l.bibleChapters.isNotEmpty || l.bibleSessions.any((s) => s.isNotEmpty),
    l.literature.any((e) => e.title.isNotEmpty),
    l.ddegSessions.any((s) => s.isNotEmpty) || l.ddegScripture.isNotEmpty || l.ddegNotes.isNotEmpty,
    l.prayerAloneSessions.any((s) => s.isNotEmpty) || l.prayerAloneDuration.isNotEmpty,
    l.prayerOthersSessions.any((s) => s.isNotEmpty) || l.prayerOthersDuration.isNotEmpty,
    l.evangelismContacts.isNotEmpty || l.evangelismSessions.isNotEmpty,
    l.fastingType.isNotEmpty || l.fastingDuration.isNotEmpty,
    l.giving.any((g) => g.isNotEmpty),
    l.churchType.isNotEmpty || l.churchSessions.isNotEmpty,
    l.discipleshipWho.isNotEmpty,
    l.proclamationCount.isNotEmpty || l.proclamationSessions.isNotEmpty,
  ];

  /// Compare this week's discipline consistency with the previous 30 days.
  Future<TrendData> computeTrend([DateTime? ref]) async {
    final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
    final dates = weekDates(ref, endWeekday);
    final weekLogs = await StorageService.instance
        .getLogsBetween(keyFor(dates.first), keyFor(dates.last));

    if (weekLogs.isEmpty) {
      return TrendData(
        currentConsistency: 0, lastMonthConsistency: 0,
        disciplineRates: {}, hasData: false,
      );
    }

    // Current week per-discipline rates
    final weekCounts = List.filled(11, 0);
    for (final log in weekLogs) {
      final checks = _disciplineChecks(log);
      for (int i = 0; i < 11; i++) {
        if (checks[i]) weekCounts[i]++;
      }
    }
    final weekRates = <String, double>{};
    for (int i = 0; i < 11; i++) {
      weekRates[_disciplineNames[i]] = weekCounts[i] / weekLogs.length;
    }
    final currentConsistency = weekRates.values.fold(0.0, (a, b) => a + b) / 11;

    // Last 30 days (excluding current week)
    final monthEnd = dates.first.subtract(const Duration(days: 1));
    final monthStart = monthEnd.subtract(const Duration(days: 29));
    final monthLogs = await StorageService.instance
        .getLogsBetween(keyFor(monthStart), keyFor(monthEnd));

    double lastMonthConsistency = 0;
    if (monthLogs.isNotEmpty) {
      final monthCounts = List.filled(11, 0);
      for (final log in monthLogs) {
        final checks = _disciplineChecks(log);
        for (int i = 0; i < 11; i++) {
          if (checks[i]) monthCounts[i]++;
        }
      }
      lastMonthConsistency = monthCounts.fold(0.0, (a, c) => a + c / monthLogs.length) / 11;
    }

    // Best & weakest
    String? best, weak;
    double bestVal = -1, weakVal = 2;
    for (final entry in weekRates.entries) {
      if (entry.value > bestVal) { bestVal = entry.value; best = entry.key; }
      if (entry.value < weakVal) { weakVal = entry.value; weak = entry.key; }
    }

    return TrendData(
      currentConsistency: currentConsistency,
      lastMonthConsistency: lastMonthConsistency,
      disciplineRates: weekRates,
      bestDiscipline: best,
      weakDiscipline: weak,
      hasData: true,
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  MONTHLY STATS & REPORT
  // ═══════════════════════════════════════════════════════════

  /// Returns a list of Monday dates for all weeks in the given month.
  List<DateTime> _weeksInMonth(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0); // last day of month
    final firstMonday = firstDay.subtract(Duration(days: (firstDay.weekday - 1) % 7));
    final weeks = <DateTime>[];
    var monday = firstMonday;
    while (monday.isBefore(lastDay) || monday.isAtSameMomentAs(lastDay)) {
      weeks.add(monday);
      monday = monday.add(const Duration(days: 7));
    }
    return weeks;
  }

  Future<MonthStats> computeMonthStats(int year, int month) async {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final totalDays = lastDay.day;
    final logs = await StorageService.instance
        .getLogsBetween(keyFor(firstDay), keyFor(lastDay));
    int days = 0, chapters = 0, contacts = 0, lit = 0;
    double totalCompletion = 0;
    for (final l in logs) {
      if (l.completed) days++;
      chapters += l.totalBibleChapters;
      contacts += int.tryParse(l.evangelismContacts) ?? 0;
      lit += l.literature.where((e) => e.title.isNotEmpty).length;
      totalCompletion += l.completeness;
    }
    final weeks = _weeksInMonth(year, month);
    int weeksReported = 0;
    for (final mon in weeks) {
      final sun = mon.add(const Duration(days: 6));
      final weekLogs = await StorageService.instance
          .getLogsBetween(keyFor(mon), keyFor(sun));
      if (weekLogs.any((l) => l.completeness > 0)) weeksReported++;
    }
    return MonthStats(
      daysLogged: days,
      totalDays: totalDays,
      totalBibleChapters: chapters,
      totalEvangelismContacts: contacts,
      litItems: lit,
      weeksReported: weeksReported,
      avgCompletion: days > 0 ? totalCompletion / days : 0,
    );
  }

  Future<String> buildMonthlyReport(String name, S l, int year, int month) async {
    final locale = l.localeName;
    final fmtMonth = DateFormat('MMMM yyyy', locale);
    final fmtLong = DateFormat('EEEE, MMM d', locale);
    final monthDate = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final buf = StringBuffer();

    // Load custom activity names once for ID → display label lookup
    final customActivities = await StorageService.instance.getCustomActivities();
    final customNames = {for (final a in customActivities) a.id: '${a.icon} ${a.name}'};

    buf.writeln('\u271D\uFE0F ${l.reportHeader(name.isEmpty ? "Disciple" : name)}');
    buf.writeln(l.monthOf(fmtMonth.format(monthDate)));
    buf.writeln('');

    // Monthly summary at the top
    final stats = await computeMonthStats(year, month);
    buf.writeln('\uD83D\uDCCA ${l.monthlySummaryHeader}');
    buf.writeln(l.monthlySummaryActiveDays(stats.daysLogged, stats.totalDays));
    buf.writeln(l.monthlySummaryWeeks(stats.weeksReported));
    buf.writeln(l.reportSummaryBibleChapters(stats.totalBibleChapters));
    buf.writeln(l.reportSummaryEvangelism(stats.totalEvangelismContacts));
    final avgPct = (stats.avgCompletion * 100).round();
    buf.writeln(l.reportSummaryCompletion(avgPct));
    buf.writeln('');

    // Full day-by-day detail for every day of the month
    for (int day = 1; day <= lastDay.day; day++) {
      final d = DateTime(year, month, day);
      // Don't include future days
      if (d.isAfter(DateTime.now())) break;

      final log = await StorageService.instance.getLog(keyFor(d));
      buf.writeln('\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501');
      buf.writeln('\uD83D\uDCC5 ${fmtLong.format(d).toUpperCase()}');
      final hasContent = log != null && log.completeness > 0;
      if (!hasContent) {
        buf.writeln('   \u26A0\uFE0F  ${l.reportNoEntry}');
        buf.writeln('');
        continue;
      }

      // Same detailed output as the weekly full report
      final bibleRef = log.combinedBibleReference(l.localeName);
      if (bibleRef.isNotEmpty || log.totalBibleChapters > 0) {
        final ref = bibleRef.isNotEmpty ? bibleRef : log.bibleReference;
        final chapters = '${log.totalBibleChapters}';
        if (log.bibleDuration.isNotEmpty) {
          buf.writeln('\uD83D\uDCD6 ${l.reportBibleWithDuration(ref, chapters, log.bibleDuration)}');
        } else {
          buf.writeln('\uD83D\uDCD6 ${l.reportBible(ref, chapters)}');
        }
      }
      for (final lit in log.literature.where((e) => e.title.isNotEmpty)) {
        buf.writeln('\uD83D\uDCDA ${l.reportLiterature(lit.title, lit.amount, lit.unit)}');
      }
      _writeDdegSessions(buf, log, l);
      _writePrayerAloneSessions(buf, log, l);
      _writePrayerOthersSessions(buf, log, l);
      final hasEvangelismData = log.evangelismContacts.isNotEmpty || log.evangelismSessions.isNotEmpty;
      if (hasEvangelismData) {
        if (log.evangelismSessions.isNotEmpty) {
          final mins = log.totalEvangelismMinutes;
          final durationStr = mins >= 60 ? '${mins ~/ 60}h ${mins % 60}min' : '${mins}min';
          buf.writeln('\uD83D\uDCE2 ${l.reportEvangelismSessions('${log.evangelismSessions.length}', durationStr)}');
        } else if (log.evangelismContacts.isNotEmpty) {
          buf.writeln('\uD83D\uDCE2 ${l.reportEvangelism(log.evangelismContacts, log.evangelismOutcome, log.evangelismNotes)}');
        }
        if (log.evangelismNewBelievers.isNotEmpty || log.evangelismBeingDiscipled.isNotEmpty) {
          final parts = <String>[];
          if (log.evangelismNewBelievers.isNotEmpty) parts.add('${l.evangelismNewBelievers}: ${log.evangelismNewBelievers}');
          if (log.evangelismBeingDiscipled.isNotEmpty) parts.add('${l.evangelismBeingDiscipled}: ${log.evangelismBeingDiscipled}');
          buf.writeln('   \uD83C\uDF31 ${parts.join(' | ')}');
        }
        if (log.evangelismFollowUpNotes.isNotEmpty) {
          buf.writeln('   \uD83D\uDCDD ${log.evangelismFollowUpNotes}');
        }
      }
      if (log.fastingType.isNotEmpty || log.fastingDuration.isNotEmpty) {
        buf.writeln('\uD83C\uDF7D\uFE0F ${l.reportFasting(log.fastingType, log.fastingDuration, log.fastingPrayerFocus)}');
      }
      for (final g in log.giving.where((e) => e.isNotEmpty)) {
        final givingDetail = [
          if (g.amount.isNotEmpty) g.amount,
          if (g.purpose.isNotEmpty) g.purpose,
        ].join(' — ');
        buf.writeln('\uD83D\uDCB0 ${l.reportGiving(g.type, givingDetail)}');
      }
      if (log.churchType.isNotEmpty || log.churchSessions.isNotEmpty) {
        if (log.churchSessions.isNotEmpty) {
          final mins = log.totalChurchMinutes;
          final durationStr = mins >= 60 ? '${mins ~/ 60}h ${mins % 60}min' : '${mins}min';
          buf.writeln('\u26EA ${l.reportChurchSessions('${log.churchSessions.length}', durationStr)}');
        } else {
          buf.writeln('\u26EA ${l.reportChurch(log.churchType, log.churchNotes)}');
        }
      }
      if (log.discipleshipWho.isNotEmpty) {
        buf.writeln('\uD83D\uDC65 ${l.reportDiscipleship(log.discipleshipWho, log.discipleshipTopic, log.discipleshipDuration)}');
      }
      if (log.proclamationSessions.isNotEmpty) {
        final parts = log.proclamationSessions.map((s) {
          final label = s.topic.isNotEmpty ? s.topic : l.sectionProclamation;
          // A session can have a real duration but zero count (the user only
          // filled in the Duration field) \u2014 that's genuine data, not a
          // phantom entry, but showing "0x" would look broken. Omit the
          // count suffix entirely when count is 0.
          if (s.count == 0) {
            return '$label (${s.duration})';
          }
          final dur = s.duration.isNotEmpty ? s.duration : '-';
          return '$label (${s.count}x, $dur)';
        }).join(', ');
        buf.writeln('\uD83D\uDCE3 $parts');
      } else if (log.proclamationCount.isNotEmpty) {
        buf.writeln('\uD83D\uDCE3 ${l.reportProclamation(log.proclamationCount, log.proclamationDuration.isNotEmpty ? log.proclamationDuration : "-")}');
      }
      if (log.other.isNotEmpty) buf.writeln('\u2795 ${l.reportOther(log.other)}');
      // Custom activities
      for (final entry in log.customActivityData.entries) {
        final actData = entry.value;
        if (actData['done'] != true) continue;
        final label = customNames[entry.key] ?? entry.key;
        final fields = actData['fields'] as Map<String, dynamic>? ?? {};
        final parts = fields.entries
            .where((e) => !e.key.startsWith('_') && e.value.toString().isNotEmpty)
            .map((e) => '${e.key}: ${e.value}')
            .join(', ');
        buf.writeln('\uD83D\uDCCC $label${parts.isNotEmpty ? ": $parts" : ": \u2713"}');
      }
      buf.writeln('');
    }

    buf.writeln('${l.reportFooter} \u{1F54A}\uFE0F');
    return buf.toString();
  }

  // ═══════════════════════════════════════════════════════════
  //  SESSION-AWARE REPORT HELPERS
  // ═══════════════════════════════════════════════════════════

  /// Write DDEG sessions (or legacy single fields) to the report buffer.
  static void _writeDdegSessions(StringBuffer buf, DailyLog log, S l) {
    final sessions = log.ddegSessions.where((s) => s.isNotEmpty).toList();
    if (sessions.isNotEmpty) {
      for (int i = 0; i < sessions.length; i++) {
        final s = sessions[i];
        final suffix = sessions.length > 1 ? ' #${i + 1}' : '';
        buf.writeln('\uD83D\uDD25 ${l.reportDDEG}$suffix');
        if (s.scripture.isNotEmpty) buf.writeln(l.reportDDEGScripture(s.scripture));
        if (s.time.isNotEmpty) buf.writeln(l.reportDDEGTime(s.time));
        if (s.notes.isNotEmpty) buf.writeln(l.reportDDEGMeditation(s.notes));
      }
    } else if (log.ddegScripture.isNotEmpty || log.ddegNotes.isNotEmpty) {
      buf.writeln('\uD83D\uDD25 ${l.reportDDEG}');
      if (log.ddegScripture.isNotEmpty) buf.writeln(l.reportDDEGScripture(log.ddegScripture));
      if (log.ddegTime.isNotEmpty) buf.writeln(l.reportDDEGTime(log.ddegTime));
      if (log.ddegNotes.isNotEmpty) buf.writeln(l.reportDDEGMeditation(log.ddegNotes));
    }
  }

  /// Write prayer-alone sessions (or legacy single fields) to the report buffer.
  static void _writePrayerAloneSessions(StringBuffer buf, DailyLog log, S l) {
    final sessions = log.prayerAloneSessions.where((s) => s.isNotEmpty).toList();
    if (sessions.isNotEmpty) {
      for (int i = 0; i < sessions.length; i++) {
        final s = sessions[i];
        final suffix = sessions.length > 1 && s.title.isEmpty ? ' #${i + 1}' : '';
        final label = s.title.isNotEmpty ? '${s.title}: ' : '';
        buf.writeln('\uD83D\uDE4F $label${l.reportPrayerAlone(s.duration, s.notes)}$suffix');
      }
    } else if (log.prayerAloneDuration.isNotEmpty) {
      buf.writeln('\uD83D\uDE4F ${l.reportPrayerAlone(log.prayerAloneDuration, log.prayerAloneNotes)}');
    }
  }

  /// Write prayer-with-others sessions (or legacy single fields) to the report buffer.
  static void _writePrayerOthersSessions(StringBuffer buf, DailyLog log, S l) {
    final sessions = log.prayerOthersSessions.where((s) => s.isNotEmpty).toList();
    if (sessions.isNotEmpty) {
      for (int i = 0; i < sessions.length; i++) {
        final s = sessions[i];
        final suffix = sessions.length > 1 && s.title.isEmpty ? ' #${i + 1}' : '';
        final label = s.title.isNotEmpty ? '${s.title}: ' : '';
        final peopleSuffix = s.peopleCount.isNotEmpty ? ' (${s.peopleCount})' : '';
        // `context` (legacy: notes) is unused by session-based Prayer with
        // Others (title now carries that meaning, rendered as the label
        // prefix above). Calling reportPrayerOthers with an empty context
        // would leave a dangling " \u2014 " with nothing after it (the ARB
        // string is "Prayer (with others): {duration} \u2014 {context}"), so
        // strip the trailing separator rather than adding a new ARB
        // placeholder just for this task.
        final full = l.reportPrayerOthers(s.duration, '');
        final trimmed = full.endsWith(' \u2014 ') ? full.substring(0, full.length - 3) : full;
        buf.writeln('\uD83E\uDD1D $label$trimmed$peopleSuffix$suffix');
      }
    } else if (log.prayerOthersDuration.isNotEmpty) {
      buf.writeln('\uD83E\uDD1D ${l.reportPrayerOthers(log.prayerOthersDuration, log.prayerOthersContext)}');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  FULL REPORT — detailed day-by-day (email, clipboard)
  // ═══════════════════════════════════════════════════════════

  Future<String> buildFullReport(String name, S l, [DateTime? ref]) async {
    final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
    final dates = weekDates(ref, endWeekday);
    final locale = l.localeName;
    final fmtLong = DateFormat('EEEE, MMM d', locale);
    final fmtRange = DateFormat('MMM d', locale);
    final buf = StringBuffer();

    // Load custom activity names once for ID → display label lookup
    final List<CustomActivity> customActivities =
        await StorageService.instance.getCustomActivities();
    final customNames = {for (final a in customActivities) a.id: '${a.icon} ${a.name}'};

    buf.writeln('\u271D\uFE0F ${l.reportHeader(name.isEmpty ? "Disciple" : name)}');
    buf.writeln(l.reportWeekOf(fmtRange.format(dates.first), fmtRange.format(dates.last)));
    buf.writeln('');

    // Reading plan progress
    final activePlan = ReadingPlanService.instance.activePlan;
    if (activePlan != null && !activePlan.isComplete) {
      final planDef = ReadingPlans.getById(activePlan.planId);
      if (planDef != null) {
        final pct = (activePlan.progress * 100).round();
        buf.writeln('\uD83D\uDCDA ${l.reportPlanProgress(planDef.name(locale), activePlan.currentDay, activePlan.totalDays, pct)}');
        buf.writeln('');
      }
    }

    int activeDays = 0;
    int totalChapters = 0;
    int totalContacts = 0;
    double totalCompletion = 0;
    final allLogs = <DailyLog>[];

    for (final d in dates) {
      final log = await StorageService.instance.getLog(keyFor(d));
      if (log != null) allLogs.add(log);
      buf.writeln('\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501');
      buf.writeln('\uD83D\uDCC5 ${fmtLong.format(d).toUpperCase()}');
      final hasContent = log != null && log.completeness > 0;
      if (log == null || !hasContent) {
        buf.writeln('   \u26A0\uFE0F  ${l.reportNoEntry}');
        buf.writeln('');
        continue;
      }
      activeDays++;
      totalChapters += log.totalBibleChapters;
      totalContacts += int.tryParse(log.evangelismContacts) ?? 0;
      totalCompletion += log.completeness;

      final bibleRef = log.combinedBibleReference(l.localeName);
      if (bibleRef.isNotEmpty || log.totalBibleChapters > 0) {
        final ref = bibleRef.isNotEmpty ? bibleRef : log.bibleReference;
        final chapters = '${log.totalBibleChapters}';
        if (log.bibleDuration.isNotEmpty) {
          buf.writeln('\uD83D\uDCD6 ${l.reportBibleWithDuration(ref, chapters, log.bibleDuration)}');
        } else {
          buf.writeln('\uD83D\uDCD6 ${l.reportBible(ref, chapters)}');
        }
      }
      for (final lit in log.literature.where((e) => e.title.isNotEmpty)) {
        buf.writeln('\uD83D\uDCDA ${l.reportLiterature(lit.title, lit.amount, lit.unit)}');
      }
      _writeDdegSessions(buf, log, l);
      _writePrayerAloneSessions(buf, log, l);
      _writePrayerOthersSessions(buf, log, l);
      final hasEvangelismData = log.evangelismContacts.isNotEmpty || log.evangelismSessions.isNotEmpty;
      if (hasEvangelismData) {
        if (log.evangelismSessions.isNotEmpty) {
          final mins = log.totalEvangelismMinutes;
          final durationStr = mins >= 60 ? '${mins ~/ 60}h ${mins % 60}min' : '${mins}min';
          buf.writeln('\uD83D\uDCE2 ${l.reportEvangelismSessions('${log.evangelismSessions.length}', durationStr)}');
        } else if (log.evangelismContacts.isNotEmpty) {
          buf.writeln('\uD83D\uDCE2 ${l.reportEvangelism(log.evangelismContacts, log.evangelismOutcome, log.evangelismNotes)}');
        }
        if (log.evangelismNewBelievers.isNotEmpty || log.evangelismBeingDiscipled.isNotEmpty) {
          final parts = <String>[];
          if (log.evangelismNewBelievers.isNotEmpty) parts.add('${l.evangelismNewBelievers}: ${log.evangelismNewBelievers}');
          if (log.evangelismBeingDiscipled.isNotEmpty) parts.add('${l.evangelismBeingDiscipled}: ${log.evangelismBeingDiscipled}');
          buf.writeln('   \uD83C\uDF31 ${parts.join(' | ')}');
        }
        if (log.evangelismFollowUpNotes.isNotEmpty) {
          buf.writeln('   \uD83D\uDCDD ${log.evangelismFollowUpNotes}');
        }
      }
      if (log.fastingType.isNotEmpty || log.fastingDuration.isNotEmpty) {
        buf.writeln('\uD83C\uDF7D\uFE0F ${l.reportFasting(log.fastingType, log.fastingDuration, log.fastingPrayerFocus)}');
      }
      for (final g in log.giving.where((e) => e.isNotEmpty)) {
        final givingDetail = [
          if (g.amount.isNotEmpty) g.amount,
          if (g.purpose.isNotEmpty) g.purpose,
        ].join(' — ');
        buf.writeln('\uD83D\uDCB0 ${l.reportGiving(g.type, givingDetail)}');
      }
      if (log.churchType.isNotEmpty || log.churchSessions.isNotEmpty) {
        if (log.churchSessions.isNotEmpty) {
          final mins = log.totalChurchMinutes;
          final durationStr = mins >= 60 ? '${mins ~/ 60}h ${mins % 60}min' : '${mins}min';
          buf.writeln('\u26EA ${l.reportChurchSessions('${log.churchSessions.length}', durationStr)}');
        } else {
          buf.writeln('\u26EA ${l.reportChurch(log.churchType, log.churchNotes)}');
        }
      }
      if (log.discipleshipWho.isNotEmpty) {
        buf.writeln('\uD83D\uDC65 ${l.reportDiscipleship(log.discipleshipWho, log.discipleshipTopic, log.discipleshipDuration)}');
      }
      if (log.proclamationSessions.isNotEmpty) {
        final parts = log.proclamationSessions.map((s) {
          final label = s.topic.isNotEmpty ? s.topic : l.sectionProclamation;
          // A session can have a real duration but zero count (the user only
          // filled in the Duration field) \u2014 that's genuine data, not a
          // phantom entry, but showing "0x" would look broken. Omit the
          // count suffix entirely when count is 0.
          if (s.count == 0) {
            return '$label (${s.duration})';
          }
          final dur = s.duration.isNotEmpty ? s.duration : '-';
          return '$label (${s.count}x, $dur)';
        }).join(', ');
        buf.writeln('\uD83D\uDCE3 $parts');
      } else if (log.proclamationCount.isNotEmpty) {
        buf.writeln('\uD83D\uDCE3 ${l.reportProclamation(log.proclamationCount, log.proclamationDuration.isNotEmpty ? log.proclamationDuration : "-")}');
      }
      if (log.other.isNotEmpty) buf.writeln('\u2795 ${l.reportOther(log.other)}');
      // Custom activities
      for (final entry in log.customActivityData.entries) {
        final actData = entry.value;
        if (actData['done'] != true) continue;
        final label = customNames[entry.key] ?? entry.key;
        final fields = actData['fields'] as Map<String, dynamic>? ?? {};
        final parts = fields.entries
            .where((e) => !e.key.startsWith('_') && e.value.toString().isNotEmpty)
            .map((e) => '${e.key}: ${e.value}')
            .join(', ');
        buf.writeln('\uD83D\uDCCC $label${parts.isNotEmpty ? ": $parts" : ": \u2713"}');
      }
      buf.writeln('');
    }

    buf.writeln('\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501');
    buf.writeln('\uD83D\uDCCA ${l.reportSummaryHeader}');
    buf.writeln(l.reportSummaryActiveDays(activeDays));

    buf.writeln(l.reportSummaryBibleChapters(totalChapters));
    buf.writeln(l.reportSummaryEvangelism(totalContacts));

    final avgPct = activeDays > 0 ? (totalCompletion / activeDays * 100).round() : 0;
    buf.writeln(l.reportSummaryCompletion(avgPct));
    final totalMins = _totalConsecratedMinutes(allLogs);
    if (totalMins > 0) {
      buf.writeln(l.totalTimeConsecrated(_formatTotalTime(totalMins)));
    }
    buf.writeln('');
    buf.writeln('${l.reportFooter} \u{1F54A}\uFE0F');
    return buf.toString();
  }

  // ═══════════════════════════════════════════════════════════
  //  COMPACT REPORT — summary-first (WhatsApp-optimized)
  // ═══════════════════════════════════════════════════════════

  Future<String> buildCompactReport(String name, S l, [DateTime? ref]) async {
    final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
    final dates = weekDates(ref, endWeekday);
    final locale = l.localeName;
    final fmtRange = DateFormat('MMM d', locale);
    final fmtShort = DateFormat('E d', locale);
    final buf = StringBuffer();

    buf.writeln('\u271D\uFE0F ${l.reportHeader(name.isEmpty ? "Disciple" : name)}');
    buf.writeln(l.reportWeekOf(fmtRange.format(dates.first), fmtRange.format(dates.last)));
    buf.writeln('');

    // Reading plan progress
    final activePlan = ReadingPlanService.instance.activePlan;
    if (activePlan != null && !activePlan.isComplete) {
      final planDef = ReadingPlans.getById(activePlan.planId);
      if (planDef != null) {
        final pct = (activePlan.progress * 100).round();
        buf.writeln('\uD83D\uDCDA ${l.reportPlanProgress(planDef.name(locale), activePlan.currentDay, activePlan.totalDays, pct)}');
        buf.writeln('');
      }
    }

    // Summary first — the disciple maker sees this immediately
    int activeDays = 0;
    int totalChapters = 0;
    int totalContacts = 0;
    double totalCompletion = 0;

    // Pre-compute stats
    final dayEntries = <String>[];
    final allLogs = <DailyLog>[];
    for (final d in dates) {
      final log = await StorageService.instance.getLog(keyFor(d));
      if (log != null) allLogs.add(log);
      final hasContent = log != null && log.completeness > 0;
      if (log == null || !hasContent) {
        dayEntries.add('\u274C ${fmtShort.format(d)}');
        continue;
      }
      activeDays++;
      totalChapters += log.totalBibleChapters;
      totalContacts += int.tryParse(log.evangelismContacts) ?? 0;
      totalCompletion += log.completeness;

      // Build a compact one-line summary per day
      final parts = <String>[];
      if (log.bibleReference.isNotEmpty || log.bibleSessions.any((s) => s.isNotEmpty)) {
        final ch = log.totalBibleChapters;
        parts.add('\uD83D\uDCD6${ch > 0 ? "$ch" : ""}ch');
      }
      if (log.ddegSessions.any((s) => s.isNotEmpty) || log.ddegScripture.isNotEmpty || log.ddegNotes.isNotEmpty) parts.add('\uD83D\uDD25${l.ddegShort}');
      if (log.prayerAloneSessions.any((s) => s.isNotEmpty) || log.prayerAloneDuration.isNotEmpty) {
        final dur = log.prayerAloneSessions.any((s) => s.isNotEmpty)
            ? log.prayerAloneSessions.where((s) => s.isNotEmpty).map((s) => s.duration).where((d) => d.isNotEmpty).join('+')
            : log.prayerAloneDuration;
        parts.add('\uD83D\uDE4F${dur.isNotEmpty ? dur : ""}');
      }
      if (log.prayerOthersSessions.any((s) => s.isNotEmpty) || log.prayerOthersDuration.isNotEmpty) parts.add('\uD83E\uDD1D');
      if (log.evangelismContacts.isNotEmpty || log.evangelismSessions.isNotEmpty) {
        final count = log.evangelismSessions.isNotEmpty ? '${log.evangelismSessions.length}' : log.evangelismContacts;
        parts.add('\uD83D\uDCE2$count');
      }
      if (log.fastingType.isNotEmpty || log.fastingDuration.isNotEmpty) parts.add('\uD83C\uDF7D\uFE0F');
      if (log.giving.any((g) => g.isNotEmpty)) parts.add('\uD83D\uDCB0');
      if (log.churchType.isNotEmpty || log.churchSessions.isNotEmpty) parts.add('\u26EA');
      if (log.discipleshipWho.isNotEmpty) parts.add('\uD83D\uDC65');
      if (log.proclamationCount.isNotEmpty || log.proclamationSessions.isNotEmpty) {
        final count = log.proclamationSessions.isNotEmpty ? '${log.totalProclamationCount}' : log.proclamationCount;
        parts.add('\uD83D\uDCE3$count');
      }
      final pct = (log.completeness * 100).round();
      dayEntries.add('\u2705 ${fmtShort.format(d)} ($pct%) ${parts.join(' ')}');
    }

    // Summary block
    final avgPct = activeDays > 0 ? (totalCompletion / activeDays * 100).round() : 0;
    buf.writeln('\uD83D\uDCCA ${l.reportSummaryHeader}');
    buf.writeln(l.reportSummaryActiveDays(activeDays));
    buf.writeln(l.reportSummaryBibleChapters(totalChapters));
    buf.writeln(l.reportSummaryEvangelism(totalContacts));
    buf.writeln(l.reportSummaryCompletion(avgPct));
    final totalMins = _totalConsecratedMinutes(allLogs);
    if (totalMins > 0) {
      buf.writeln(l.totalTimeConsecrated(_formatTotalTime(totalMins)));
    }
    buf.writeln('');

    // Day-by-day compact view
    for (final entry in dayEntries) {
      buf.writeln(entry);
    }
    buf.writeln('');
    buf.writeln('${l.reportFooter} \u{1F54A}\uFE0F');
    return buf.toString();
  }

  // ═══════════════════════════════════════════════════════════
  //  SEND METHODS
  // ═══════════════════════════════════════════════════════════

  /// Open the device email client pre-filled with the FULL report.
  Future<bool> sendByEmail(String toEmail, String name, String body, S l) async {
    final subject = '\uD83D\uDCD6 ${l.reportEmailSubject(
      name.isEmpty ? "Disciple" : name,
      DateFormat('MMM d, y', l.localeName).format(DateTime.now()),
    )}';
    final uri = Uri(
      scheme: 'mailto',
      path: toEmail,
      query: _encodeQuery({'subject': subject, 'body': body}),
    );
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Share the COMPACT report via WhatsApp using deep link.
  Future<bool> sendByWhatsApp(String phone, String compactReport) async {
    // Normalise phone: ensure it starts with country code, no +
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final encoded = Uri.encodeComponent(compactReport);

    // Try wa.me HTTPS link first — most reliable across Android versions
    final webUri = Uri.parse('https://wa.me/$cleanPhone?text=$encoded');
    try {
      final ok = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (ok) return true;
    } catch (_) {}

    // Fallback: whatsapp:// deep link
    final waUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encoded');
    try {
      return await launchUrl(waUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Share the report via the system share sheet (any app).
  Future<void> shareReport(String report) async {
    await SharePlus.instance.share(ShareParams(text: report));
  }

  String _encodeQuery(Map<String, String> params) => params.entries
      .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
}
