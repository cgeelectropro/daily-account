import '../models/daily_log.dart';
import 'duration_parser.dart';
import 'report_cadence_service.dart';
import 'report_service.dart';
import 'storage_service.dart';
import '../models/goal.dart';

/// Computes progress toward any [Goal] over its current period (daily,
/// weekly using the cadence-configured week, or calendar-monthly).
class GoalProgressService {
  static final instance = GoalProgressService._();
  GoalProgressService._();

  Future<int> computeProgress(Goal goal, [DateTime? ref]) async {
    final d = ref ?? DateTime.now();
    final logs = await _logsForPeriod(goal.frequency, d);
    int total = 0;
    for (final log in logs) {
      total += _metricValue(goal.metricKey, log);
    }
    return total;
  }

  Future<bool> isComplete(Goal goal, [DateTime? ref]) async {
    return (await computeProgress(goal, ref)) >= goal.target;
  }

  /// True if [goal] is past its period's midpoint but under half its
  /// target — a simple, non-continuous pace heuristic (see design spec
  /// §9 for rationale).
  Future<bool> isBehindPace(Goal goal, [DateTime? ref]) async {
    final elapsed = periodElapsedFraction(goal.frequency, ref);
    if (elapsed <= 0.5) return false;
    final progress = await computeProgress(goal, ref);
    if (goal.target <= 0) return false;
    return (progress / goal.target) < 0.5;
  }

  double periodElapsedFraction(GoalFrequency frequency, [DateTime? ref]) {
    final d = ref ?? DateTime.now();
    switch (frequency) {
      case GoalFrequency.daily:
        return 1.0;
      case GoalFrequency.weekly:
        // Synchronous fallback: use the default Sunday-ending window's
        // weekday index, since this method is sync (called from build
        // methods) and cannot await the configured cadence day. Callers
        // needing the true cadence-aware fraction should prefer computing
        // it from computeProgress's own period resolution; this method is
        // a lightweight approximation for pace-check UI only.
        return (d.weekday) / 7.0;
      case GoalFrequency.monthly:
        final lastDay = DateTime(d.year, d.month + 1, 0).day;
        return d.day / lastDay;
    }
  }

  /// [after] must already be persisted to storage (i.e. call this after
  /// StorageService.saveLog(after) has completed) — computeProgress reads
  /// from storage, so it needs the just-saved day's data to be there.
  Future<List<Goal>> justCompletedGoals(DailyLog? before, DailyLog after, List<Goal> goals) async {
    final completed = <Goal>[];
    final refDate = DateTime.parse(after.dateKey);
    for (final goal in goals) {
      // Period-aware: compare the period's total progress before vs. after
      // this save, not just today's single-day contribution — a weekly or
      // monthly goal can be completed by cumulative logging across several
      // days, not only by what changed today.
      final afterTotal = await computeProgress(goal, refDate);
      final todayAfterVal = _metricValue(goal.metricKey, after);
      final todayBeforeVal = before != null ? _metricValue(goal.metricKey, before) : 0;
      final beforeTotal = afterTotal - (todayAfterVal - todayBeforeVal);
      if (beforeTotal < goal.target && afterTotal >= goal.target) {
        completed.add(goal);
      }
    }
    return completed;
  }

  Future<List<DailyLog>> _logsForPeriod(GoalFrequency frequency, DateTime ref) async {
    final rs = ReportService.instance;
    switch (frequency) {
      case GoalFrequency.daily:
        final log = await StorageService.instance.getLog(rs.keyFor(ref));
        return log != null ? [log] : [];
      case GoalFrequency.weekly:
        final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
        final dates = rs.weekDates(ref, endWeekday);
        return StorageService.instance.getLogsBetween(rs.keyFor(dates.first), rs.keyFor(dates.last));
      case GoalFrequency.monthly:
        final first = DateTime(ref.year, ref.month, 1);
        final last = DateTime(ref.year, ref.month + 1, 0);
        return StorageService.instance.getLogsBetween(rs.keyFor(first), rs.keyFor(last));
    }
  }

  int _metricValue(String metricKey, DailyLog log) {
    if (metricKey.startsWith('custom:')) {
      final parts = metricKey.split(':');
      if (parts.length < 3) return 0;
      final activityId = parts[1];
      final fieldLabel = parts.sublist(2).join(':'); // field labels may contain ':'
      final data = log.customActivityData[activityId];
      if (data == null) return 0;
      final fields = data['fields'] as Map<String, dynamic>? ?? {};
      final raw = fields[fieldLabel];
      if (raw == null) return 0;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return parseDurationMinutes(raw.toString());
    }
    switch (metricKey) {
      case 'bibleChapters':
        return log.totalBibleChapters;
      case 'prayer':
        return _durationField(log.prayerAloneSessions.map((s) => s.duration).toList(),
                log.prayerAloneSessions.any((s) => s.isNotEmpty), log.prayerAloneDuration) +
            _durationField(log.prayerOthersSessions.map((s) => s.duration).toList(),
                log.prayerOthersSessions.any((s) => s.isNotEmpty), log.prayerOthersDuration);
      case 'evangelismContacts':
        return int.tryParse(log.evangelismContacts) ?? 0;
      case 'literatureItems':
        return log.literature.where((e) => e.title.isNotEmpty).length;
      case 'ddegTime':
        return _durationField(log.ddegSessions.map((s) => s.time).toList(),
            log.ddegSessions.any((s) => s.isNotEmpty), log.ddegTime);
      case 'fastingCount':
        return (log.fastingType.isNotEmpty || log.fastingDuration.isNotEmpty) ? 1 : 0;
      case 'churchCount':
        return log.churchType.isNotEmpty ? 1 : 0;
      case 'discipleshipTime':
        return parseDurationMinutes(log.discipleshipDuration);
      case 'proclamationCount':
        return int.tryParse(log.proclamationCount) ?? 0;
      default:
        return 0;
    }
  }

  /// Sums session durations if any session is non-empty, else falls back
  /// to the legacy single-duration field. Mirrors the session-aware
  /// pattern already used throughout report_service.dart.
  int _durationField(List<String> sessionDurations, bool hasNonEmptySession, String legacyDuration) {
    if (hasNonEmptySession) {
      int total = 0;
      for (final d in sessionDurations) {
        total += parseDurationMinutes(d);
      }
      return total;
    }
    return parseDurationMinutes(legacyDuration);
  }
}
