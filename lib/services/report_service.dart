import 'package:daily_account/models/daily_log.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/generated/app_localizations.dart';
import 'storage_service.dart';

class WeekStats {
  int daysLogged;
  int totalBibleChapters;
  int totalEvangelismContacts;
  int litItems;
  WeekStats(this.daysLogged, this.totalBibleChapters, this.totalEvangelismContacts, this.litItems);
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

  /// Monday->Sunday dates for the week containing [ref] (default today).
  List<DateTime> weekDates([DateTime? ref]) {
    final today = ref ?? DateTime.now();
    final monday = today.subtract(Duration(days: (today.weekday + 6) % 7));
    return List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));
  }

  String keyFor(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<WeekStats> computeWeekStats([DateTime? ref]) async {
    final dates = weekDates(ref);
    final logs = await StorageService.instance
        .getLogsBetween(keyFor(dates.first), keyFor(dates.last));
    int days = 0, chapters = 0, contacts = 0, lit = 0;
    for (final l in logs) {
      if (l.completed) days++;
      chapters += int.tryParse(l.bibleChapters) ?? 0;
      contacts += int.tryParse(l.evangelismContacts) ?? 0;
      lit += l.literature.where((e) => e.title.isNotEmpty).length;
    }
    return WeekStats(days, chapters, contacts, lit);
  }

  /// Current consecutive-day streak ending today.
  Future<int> computeStreak() async {
    int streak = 0;
    var day = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final log = await StorageService.instance.getLog(keyFor(day));
      if (log != null && log.completed) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        if (i == 0) {
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
    l.bibleReference.isNotEmpty || l.bibleChapters.isNotEmpty,
    l.literature.any((e) => e.title.isNotEmpty),
    l.ddegScripture.isNotEmpty || l.ddegNotes.isNotEmpty,
    l.prayerAloneDuration.isNotEmpty,
    l.prayerOthersDuration.isNotEmpty,
    l.evangelismContacts.isNotEmpty,
    l.fastingType.isNotEmpty || l.fastingDuration.isNotEmpty,
    l.givingType.isNotEmpty,
    l.churchType.isNotEmpty,
    l.discipleshipWho.isNotEmpty,
    l.proclamationCount.isNotEmpty,
  ];

  /// Compare this week's discipline consistency with the previous 30 days.
  Future<TrendData> computeTrend([DateTime? ref]) async {
    final dates = weekDates(ref);
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
      chapters += int.tryParse(l.bibleChapters) ?? 0;
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
    final fmtMonth = DateFormat('MMMM yyyy');
    final fmtLong = DateFormat('EEEE, MMM d');
    final monthDate = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final buf = StringBuffer();

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
      if (log.bibleReference.isNotEmpty) {
        buf.writeln('\uD83D\uDCD6 ${l.reportBible(log.bibleReference, log.bibleChapters.isNotEmpty ? log.bibleChapters : "0")}');
      }
      for (final lit in log.literature.where((e) => e.title.isNotEmpty)) {
        buf.writeln('\uD83D\uDCDA ${l.reportLiterature(lit.title, lit.amount, lit.unit)}');
      }
      if (log.ddegScripture.isNotEmpty || log.ddegNotes.isNotEmpty) {
        buf.writeln('\uD83D\uDD25 ${l.reportDDEG}');
        if (log.ddegScripture.isNotEmpty) buf.writeln(l.reportDDEGScripture(log.ddegScripture));
        if (log.ddegTime.isNotEmpty) buf.writeln(l.reportDDEGTime(log.ddegTime));
        if (log.ddegNotes.isNotEmpty) buf.writeln(l.reportDDEGMeditation(log.ddegNotes));
      }
      if (log.prayerAloneDuration.isNotEmpty) {
        buf.writeln('\uD83D\uDE4F ${l.reportPrayerAlone(log.prayerAloneDuration, log.prayerAloneNotes)}');
      }
      if (log.prayerOthersDuration.isNotEmpty) {
        buf.writeln('\uD83E\uDD1D ${l.reportPrayerOthers(log.prayerOthersDuration, log.prayerOthersContext)}');
      }
      if (log.evangelismContacts.isNotEmpty) {
        buf.writeln('\uD83D\uDCE2 ${l.reportEvangelism(log.evangelismContacts, log.evangelismOutcome, log.evangelismNotes)}');
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
      if (log.givingType.isNotEmpty) {
        buf.writeln('\uD83D\uDCB0 ${l.reportGiving(log.givingType, log.givingPurpose)}');
      }
      if (log.churchType.isNotEmpty) {
        buf.writeln('\u26EA ${l.reportChurch(log.churchType, log.churchNotes)}');
      }
      if (log.discipleshipWho.isNotEmpty) {
        buf.writeln('\uD83D\uDC65 ${l.reportDiscipleship(log.discipleshipWho, log.discipleshipTopic, log.discipleshipDuration)}');
      }
      if (log.proclamationCount.isNotEmpty) {
        buf.writeln('\uD83D\uDCE3 ${l.reportProclamation(log.proclamationCount, log.proclamationDuration.isNotEmpty ? log.proclamationDuration : "-")}');
      }
      if (log.other.isNotEmpty) buf.writeln('\u2795 ${l.reportOther(log.other)}');
      buf.writeln('');
    }

    buf.writeln('${l.reportFooter} \u{1F54A}\uFE0F');
    return buf.toString();
  }

  // ═══════════════════════════════════════════════════════════
  //  FULL REPORT — detailed day-by-day (email, clipboard)
  // ═══════════════════════════════════════════════════════════

  Future<String> buildFullReport(String name, S l, [DateTime? ref]) async {
    final dates = weekDates(ref);
    final fmtLong = DateFormat('EEEE, MMM d');
    final fmtRange = DateFormat('MMM d');
    final buf = StringBuffer();

    buf.writeln('\u271D\uFE0F ${l.reportHeader(name.isEmpty ? "Disciple" : name)}');
    buf.writeln(l.reportWeekOf(fmtRange.format(dates.first), fmtRange.format(dates.last)));
    buf.writeln('');

    int activeDays = 0;
    int totalChapters = 0;
    int totalContacts = 0;
    double totalCompletion = 0;

    for (final d in dates) {
      final log = await StorageService.instance.getLog(keyFor(d));
      buf.writeln('\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501');
      buf.writeln('\uD83D\uDCC5 ${fmtLong.format(d).toUpperCase()}');
      final hasContent = log != null && log.completeness > 0;
      if (log == null || !hasContent) {
        buf.writeln('   \u26A0\uFE0F  ${l.reportNoEntry}');
        buf.writeln('');
        continue;
      }
      activeDays++;
      totalChapters += int.tryParse(log.bibleChapters) ?? 0;
      totalContacts += int.tryParse(log.evangelismContacts) ?? 0;
      totalCompletion += log.completeness;

      if (log.bibleReference.isNotEmpty) {
        buf.writeln('\uD83D\uDCD6 ${l.reportBible(log.bibleReference, log.bibleChapters.isNotEmpty ? log.bibleChapters : "0")}');
      }
      for (final lit in log.literature.where((e) => e.title.isNotEmpty)) {
        buf.writeln('\uD83D\uDCDA ${l.reportLiterature(lit.title, lit.amount, lit.unit)}');
      }
      if (log.ddegScripture.isNotEmpty || log.ddegNotes.isNotEmpty) {
        buf.writeln('\uD83D\uDD25 ${l.reportDDEG}');
        if (log.ddegScripture.isNotEmpty) buf.writeln(l.reportDDEGScripture(log.ddegScripture));
        if (log.ddegTime.isNotEmpty) buf.writeln(l.reportDDEGTime(log.ddegTime));
        if (log.ddegNotes.isNotEmpty) buf.writeln(l.reportDDEGMeditation(log.ddegNotes));
      }
      if (log.prayerAloneDuration.isNotEmpty) {
        buf.writeln('\uD83D\uDE4F ${l.reportPrayerAlone(log.prayerAloneDuration, log.prayerAloneNotes)}');
      }
      if (log.prayerOthersDuration.isNotEmpty) {
        buf.writeln('\uD83E\uDD1D ${l.reportPrayerOthers(log.prayerOthersDuration, log.prayerOthersContext)}');
      }
      if (log.evangelismContacts.isNotEmpty) {
        buf.writeln('\uD83D\uDCE2 ${l.reportEvangelism(log.evangelismContacts, log.evangelismOutcome, log.evangelismNotes)}');
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
      if (log.givingType.isNotEmpty) {
        buf.writeln('\uD83D\uDCB0 ${l.reportGiving(log.givingType, log.givingPurpose)}');
      }
      if (log.churchType.isNotEmpty) {
        buf.writeln('\u26EA ${l.reportChurch(log.churchType, log.churchNotes)}');
      }
      if (log.discipleshipWho.isNotEmpty) {
        buf.writeln('\uD83D\uDC65 ${l.reportDiscipleship(log.discipleshipWho, log.discipleshipTopic, log.discipleshipDuration)}');
      }
      if (log.proclamationCount.isNotEmpty) {
        buf.writeln('\uD83D\uDCE3 ${l.reportProclamation(log.proclamationCount, log.proclamationDuration.isNotEmpty ? log.proclamationDuration : "-")}');
      }
      if (log.other.isNotEmpty) buf.writeln('\u2795 ${l.reportOther(log.other)}');
      buf.writeln('');
    }

    buf.writeln('\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501');
    buf.writeln('\uD83D\uDCCA ${l.reportSummaryHeader}');
    buf.writeln(l.reportSummaryActiveDays(activeDays));
    buf.writeln(l.reportSummaryBibleChapters(totalChapters));
    buf.writeln(l.reportSummaryEvangelism(totalContacts));
    final avgPct = activeDays > 0 ? (totalCompletion / activeDays * 100).round() : 0;
    buf.writeln(l.reportSummaryCompletion(avgPct));
    buf.writeln('');
    buf.writeln('${l.reportFooter} \u{1F54A}\uFE0F');
    return buf.toString();
  }

  // ═══════════════════════════════════════════════════════════
  //  COMPACT REPORT — summary-first (WhatsApp-optimized)
  // ═══════════════════════════════════════════════════════════

  Future<String> buildCompactReport(String name, S l, [DateTime? ref]) async {
    final dates = weekDates(ref);
    final fmtRange = DateFormat('MMM d');
    final fmtShort = DateFormat('E d');
    final buf = StringBuffer();

    buf.writeln('\u271D\uFE0F ${l.reportHeader(name.isEmpty ? "Disciple" : name)}');
    buf.writeln(l.reportWeekOf(fmtRange.format(dates.first), fmtRange.format(dates.last)));
    buf.writeln('');

    // Summary first — the disciple maker sees this immediately
    int activeDays = 0;
    int totalChapters = 0;
    int totalContacts = 0;
    double totalCompletion = 0;

    // Pre-compute stats
    final dayEntries = <String>[];
    for (final d in dates) {
      final log = await StorageService.instance.getLog(keyFor(d));
      final hasContent = log != null && log.completeness > 0;
      if (log == null || !hasContent) {
        dayEntries.add('\u274C ${fmtShort.format(d)}');
        continue;
      }
      activeDays++;
      totalChapters += int.tryParse(log.bibleChapters) ?? 0;
      totalContacts += int.tryParse(log.evangelismContacts) ?? 0;
      totalCompletion += log.completeness;

      // Build a compact one-line summary per day
      final parts = <String>[];
      if (log.bibleReference.isNotEmpty) {
        parts.add('\uD83D\uDCD6${log.bibleChapters.isNotEmpty ? log.bibleChapters : ""}ch');
      }
      if (log.ddegScripture.isNotEmpty || log.ddegNotes.isNotEmpty) parts.add('\uD83D\uDD25${l.ddegShort}');
      if (log.prayerAloneDuration.isNotEmpty) parts.add('\uD83D\uDE4F${log.prayerAloneDuration}');
      if (log.prayerOthersDuration.isNotEmpty) parts.add('\uD83E\uDD1D');
      if (log.evangelismContacts.isNotEmpty) parts.add('\uD83D\uDCE2${log.evangelismContacts}');
      if (log.fastingType.isNotEmpty || log.fastingDuration.isNotEmpty) parts.add('\uD83C\uDF7D\uFE0F');
      if (log.givingType.isNotEmpty) parts.add('\uD83D\uDCB0');
      if (log.churchType.isNotEmpty) parts.add('\u26EA');
      if (log.discipleshipWho.isNotEmpty) parts.add('\uD83D\uDC65');
      if (log.proclamationCount.isNotEmpty) parts.add('\uD83D\uDCE3${log.proclamationCount}');
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
      DateFormat('MMM d, y').format(DateTime.now()),
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
