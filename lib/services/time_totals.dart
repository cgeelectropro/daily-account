import '../models/daily_log.dart';
import 'duration_parser.dart';

/// Single source of truth for "total time consecrated" on a given day —
/// used by both the weekly/monthly report footer (`ReportService`) and the
/// AI reflection text (`ReflectionService`), which previously had two
/// divergent implementations of the same calculation.
///
/// Session-aware fields (DDEG, prayer alone/others, evangelism, church,
/// proclamation) prefer their session list total when sessions exist and
/// fall back to the legacy scalar duration field otherwise — never both,
/// to avoid double-counting. `givingDuration` is intentionally excluded:
/// giving is not "time consecrated" in the same sense as the other
/// disciplines.
class TimeTotals {
  TimeTotals._();

  static int consecratedMinutes(DailyLog log) {
    int total = 0;

    // Scalar-only fields (no session lists in the current model).
    total += parseDurationMinutes(log.discipleshipDuration);
    total += parseDurationMinutes(log.bibleDuration);
    total += parseDurationMinutes(log.literatureDuration);

    // Session-aware DDEG time.
    final ddegSessions = log.ddegSessions.where((s) => s.isNotEmpty);
    if (ddegSessions.isNotEmpty) {
      for (final s in ddegSessions) {
        total += parseDurationMinutes(s.time);
      }
    } else {
      total += parseDurationMinutes(log.ddegTime);
    }

    // Session-aware prayer alone duration.
    final paSessions = log.prayerAloneSessions.where((s) => s.isNotEmpty);
    if (paSessions.isNotEmpty) {
      for (final s in paSessions) {
        total += parseDurationMinutes(s.duration);
      }
    } else {
      total += parseDurationMinutes(log.prayerAloneDuration);
    }

    // Session-aware prayer with others duration.
    final poSessions = log.prayerOthersSessions.where((s) => s.isNotEmpty);
    if (poSessions.isNotEmpty) {
      for (final s in poSessions) {
        total += parseDurationMinutes(s.duration);
      }
    } else {
      total += parseDurationMinutes(log.prayerOthersDuration);
    }

    // Proclamation, evangelism, church: these getters already fall back to
    // the legacy scalar internally when no sessions exist, so calling them
    // alone (never also parsing the raw scalar) avoids double-counting.
    total += log.totalProclamationMinutes;
    total += log.totalEvangelismMinutes;
    total += log.totalChurchMinutes;

    // Custom activity duration fields — any field in a custom activity's
    // `fields` map whose key is `_duration` or contains "duration"/"time"
    // (case-insensitive) is treated as a timed value.
    for (final actData in log.customActivityData.values) {
      final fields = actData['fields'] as Map<String, dynamic>? ?? {};
      for (final entry in fields.entries) {
        if (entry.key == '_duration' ||
            entry.key.toLowerCase().contains('duration') ||
            entry.key.toLowerCase().contains('time')) {
          total += parseDurationMinutes(entry.value.toString());
        }
      }
    }

    return total;
  }
}
