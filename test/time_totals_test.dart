import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/models/daily_log.dart';
import 'package:daily_account/services/time_totals.dart';

void main() {
  test('consecratedMinutes sums duration fields, excluding givingDuration', () {
    final log = DailyLog(
      dateKey: '2026-08-16',
      bibleDuration: '30 minutes',
      literatureDuration: '15 minutes',
      discipleshipDuration: '1h',
      churchDuration: '2h',
      givingDuration: '99 minutes', // must NOT be counted
    );
    // 30 + 15 + 60 + 120 = 225
    expect(TimeTotals.consecratedMinutes(log), 225);
  });

  test('consecratedMinutes uses session totals for evangelism/church when present', () {
    final log = DailyLog(
      dateKey: '2026-08-16',
      evangelismSessions: [
        TimedSession(
          start: DateTime(2026, 8, 16, 9),
          end: DateTime(2026, 8, 16, 9, 30),
          durationSeconds: 1800,
        ),
      ],
    );
    expect(TimeTotals.consecratedMinutes(log), 30);
  });

  test('consecratedMinutes uses proclamation session totals when present', () {
    final log = DailyLog(
      dateKey: '2026-08-16',
      proclamationSessions: [
        ProclamationSession(topic: 'Healing', count: 1, duration: '12min'),
      ],
    );
    expect(TimeTotals.consecratedMinutes(log), 12);
  });

  test('consecratedMinutes uses session-aware ddeg/prayer totals when present', () {
    final log = DailyLog(
      dateKey: '2026-08-16',
      ddegSessions: [DdegSession(scripture: 'Ps 23', time: '10m', notes: 'x')],
      prayerAloneSessions: [PrayerSession(duration: '20m', notes: '')],
      prayerOthersSessions: [PrayerSession(duration: '5m', notes: '')],
      // Legacy scalars should be ignored since session lists are populated.
      ddegTime: '999m',
      prayerAloneDuration: '999m',
      prayerOthersDuration: '999m',
    );
    expect(TimeTotals.consecratedMinutes(log), 35);
  });

  test('consecratedMinutes falls back to legacy scalars when session lists are empty', () {
    final log = DailyLog(
      dateKey: '2026-08-16',
      ddegTime: '10m',
      prayerAloneDuration: '20m',
      prayerOthersDuration: '5m',
    );
    expect(TimeTotals.consecratedMinutes(log), 35);
  });

  test('consecratedMinutes includes custom-activity duration fields', () {
    final log = DailyLog(
      dateKey: '2026-08-16',
      bibleDuration: '10m',
      customActivityData: {
        'act1': {
          'fields': {'_duration': '20m'},
        },
        'act2': {
          'fields': {'sessionTime': '5m', 'notes': 'ignored, no time/duration in key'},
        },
      },
    );
    // 10 (bible) + 20 (_duration) + 5 (sessionTime, matches "time") = 35
    expect(TimeTotals.consecratedMinutes(log), 35);
  });

  test('consecratedMinutes does not double-count proclamation/evangelism legacy scalars '
      'alongside session totals', () {
    final log = DailyLog(
      dateKey: '2026-08-16',
      proclamationDuration: '50m', // legacy scalar, should be ignored
      proclamationSessions: [
        ProclamationSession(topic: 'Grace', count: 1, duration: '12min'),
      ],
      evangelismDuration: '50m', // legacy scalar, should be ignored
      evangelismSessions: [
        TimedSession(
          start: DateTime(2026, 8, 16, 9),
          end: DateTime(2026, 8, 16, 9, 30),
          durationSeconds: 1800,
        ),
      ],
    );
    expect(TimeTotals.consecratedMinutes(log), 42);
  });
}
