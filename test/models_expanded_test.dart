import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/models/activity_timer.dart';
import 'package:daily_account/models/custom_activity.dart';
import 'package:daily_account/models/fasting_period.dart';
import 'package:daily_account/models/daily_log.dart';

void main() {
  // ──────────────────────────────────────────────
  // 1. FastingPeriod.isActive
  // ──────────────────────────────────────────────
  group('FastingPeriod.isActive', () {
    test('completed=true always returns false regardless of dates', () {
      final period = FastingPeriod(
        startDate: '2020-01-01',
        endDate: '2099-12-31',
        type: FastType.complete,
        completed: true,
      );
      expect(period.isActive, false);
    });

    test('invalid startDate returns false', () {
      final period = FastingPeriod(
        startDate: 'not-a-date',
        endDate: '2099-12-31',
        type: FastType.complete,
      );
      expect(period.isActive, false);
    });

    test('invalid endDate returns false', () {
      final period = FastingPeriod(
        startDate: '2020-01-01',
        endDate: 'not-a-date',
        type: FastType.complete,
      );
      expect(period.isActive, false);
    });

    test('both dates invalid returns false', () {
      final period = FastingPeriod(
        startDate: '',
        endDate: '',
        type: FastType.complete,
      );
      expect(period.isActive, false);
    });

    test('fast spanning far past to far future is active today', () {
      // 2000-01-01 to 2099-12-31 definitely contains any run date.
      final period = FastingPeriod(
        startDate: '2000-01-01',
        endDate: '2099-12-31',
        type: FastType.partial,
      );
      expect(period.isActive, true);
    });

    test('fast that ended far in the past is not active', () {
      final period = FastingPeriod(
        startDate: '2000-01-01',
        endDate: '2000-01-07',
        type: FastType.complete,
      );
      expect(period.isActive, false);
    });

    test('fast that starts far in the future is not active', () {
      final period = FastingPeriod(
        startDate: '2099-01-01',
        endDate: '2099-12-31',
        type: FastType.esther,
      );
      expect(period.isActive, false);
    });

    test('completed=true with wide date range still returns false', () {
      final period = FastingPeriod(
        startDate: '2000-01-01',
        endDate: '2099-12-31',
        type: FastType.complete,
        completed: true,
      );
      expect(period.isActive, false);
    });
  });

  // ──────────────────────────────────────────────
  // 2. CustomField standalone tests
  // ──────────────────────────────────────────────
  group('CustomField', () {
    test('default type is text', () {
      final field = CustomField(label: 'Notes');
      expect(field.type, CustomFieldType.text);
    });

    test('toMap / fromMap round-trip — text', () {
      final field = CustomField(label: 'Name', type: CustomFieldType.text);
      final restored = CustomField.fromMap(field.toMap());
      expect(restored.label, 'Name');
      expect(restored.type, CustomFieldType.text);
    });

    test('toMap / fromMap round-trip — number', () {
      final field = CustomField(label: 'Count', type: CustomFieldType.number);
      final restored = CustomField.fromMap(field.toMap());
      expect(restored.label, 'Count');
      expect(restored.type, CustomFieldType.number);
    });

    test('toMap / fromMap round-trip — duration', () {
      final field = CustomField(label: 'Time', type: CustomFieldType.duration);
      final restored = CustomField.fromMap(field.toMap());
      expect(restored.label, 'Time');
      expect(restored.type, CustomFieldType.duration);
    });

    test('toMap / fromMap round-trip — yesNo', () {
      final field = CustomField(label: 'Done?', type: CustomFieldType.yesNo);
      final restored = CustomField.fromMap(field.toMap());
      expect(restored.label, 'Done?');
      expect(restored.type, CustomFieldType.yesNo);
    });

    test('toMap / fromMap round-trip — notes', () {
      final field = CustomField(label: 'Journal', type: CustomFieldType.notes);
      final restored = CustomField.fromMap(field.toMap());
      expect(restored.label, 'Journal');
      expect(restored.type, CustomFieldType.notes);
    });

    test('toMap encodes type as enum name string', () {
      final map = CustomField(label: 'X', type: CustomFieldType.yesNo).toMap();
      expect(map['type'], 'yesNo');
    });

    test('toMap encodes label correctly', () {
      final map = CustomField(label: 'My Label').toMap();
      expect(map['label'], 'My Label');
    });

    test('fromMap with missing type key throws (byName on null)', () {
      // byName receives null cast to String — this is an implementation detail.
      // Null type in the map causes a type error because fromMap casts to String?.
      // The null branch returns 'text' via the null-coalescing default.
      final field = CustomField.fromMap({'label': 'X', 'type': null});
      // null ?? 'text'  => byName('text') => CustomFieldType.text
      expect(field.type, CustomFieldType.text);
    });

    test('fromMap with explicit "text" type resolves to text', () {
      final field = CustomField.fromMap({'label': 'Desc', 'type': 'text'});
      expect(field.type, CustomFieldType.text);
      expect(field.label, 'Desc');
    });

    test('all five CustomFieldType values are serializable by name', () {
      for (final type in CustomFieldType.values) {
        final field = CustomField(label: 'test', type: type);
        final map = field.toMap();
        expect(map['type'], type.name);
        final restored = CustomField.fromMap(map);
        expect(restored.type, type);
      }
    });
  });

  // ──────────────────────────────────────────────
  // 3. CustomActivity.countsForCompleteness persistence
  // ──────────────────────────────────────────────
  group('CustomActivity.countsForCompleteness', () {
    test('default value is true', () {
      final activity = CustomActivity(id: 'a1', name: 'Worship');
      expect(activity.countsForCompleteness, true);
    });

    test('true persists through toMap/fromMap', () {
      final activity = CustomActivity(
        id: 'a2',
        name: 'Worship',
        countsForCompleteness: true,
      );
      final restored = CustomActivity.fromMap(activity.toMap());
      expect(restored.countsForCompleteness, true);
    });

    test('false persists through toMap/fromMap', () {
      final activity = CustomActivity(
        id: 'a3',
        name: 'Journal',
        countsForCompleteness: false,
      );
      final restored = CustomActivity.fromMap(activity.toMap());
      expect(restored.countsForCompleteness, false);
    });

    test('toMap encodes countsForCompleteness as bool', () {
      final map = CustomActivity(
        id: 'a4',
        name: 'Test',
        countsForCompleteness: false,
      ).toMap();
      expect(map['countsForCompleteness'], false);
    });

    test('fromMap missing countsForCompleteness defaults to true', () {
      final activity = CustomActivity.fromMap({'id': 'a5', 'name': 'Test'});
      expect(activity.countsForCompleteness, true);
    });
  });

  // ──────────────────────────────────────────────
  // 4. DailyLog.completeness with customActivityData
  // ──────────────────────────────────────────────
  group('DailyLog.completeness with customActivityData', () {
    // Helper: a fully filled built-in log (all 11 disciplines satisfied).
    DailyLog fullBuiltInLog() => DailyLog(
          dateKey: '2024-01-01',
          bibleReference: 'John 1',
          literature: [LiteratureEntry(title: 'Book')],
          ddegScripture: 'Ps 23',
          prayerAloneDuration: '30min',
          prayerOthersDuration: '15min',
          evangelismContacts: '1',
          fastingType: 'complete',
          givingType: 'tithe',
          churchType: 'Sunday',
          discipleshipWho: 'James',
          proclamationCount: '3',
        );

    test('no custom activities — completeness is filled/11', () {
      // 0 filled, 0 custom → 0/11
      final log = DailyLog(dateKey: '2024-01-01');
      expect(log.completeness, 0.0);
    });

    test('no custom activities — fully filled is 11/11 = 1.0', () {
      final log = fullBuiltInLog();
      expect(log.completeness, 1.0);
    });

    test('custom activity with countsForCompleteness=true and done=true increases both', () {
      final log = DailyLog(
        dateKey: '2024-01-01',
        customActivityData: {
          'custom-1': {
            'countsForCompleteness': true,
            'done': true,
          },
        },
      );
      // 0 built-in filled, 1 custom filled out of 11+1=12
      expect(log.completeness, closeTo(1 / 12, 0.001));
    });

    test('custom activity with countsForCompleteness=false does not affect completeness', () {
      final log = DailyLog(
        dateKey: '2024-01-01',
        bibleReference: 'John 1',
        customActivityData: {
          'custom-x': {
            'countsForCompleteness': false,
            'done': true,
          },
        },
      );
      // Only built-in: 1 filled out of 11 (custom excluded entirely)
      expect(log.completeness, closeTo(1 / 11, 0.001));
    });

    test('custom activity with countsForCompleteness=true but done=false increases total only', () {
      final log = DailyLog(
        dateKey: '2024-01-01',
        customActivityData: {
          'custom-2': {
            'countsForCompleteness': true,
            'done': false,
          },
        },
      );
      // 0 filled, total = 12
      expect(log.completeness, 0.0);
    });

    test('custom activity with countsForCompleteness=true and done missing counts as not filled', () {
      final log = DailyLog(
        dateKey: '2024-01-01',
        customActivityData: {
          'custom-3': {
            'countsForCompleteness': true,
            // 'done' key absent — treated as not true
          },
        },
      );
      // total=12, filled=0
      expect(log.completeness, 0.0);
    });

    test('multiple custom activities mixed', () {
      // 2 count-for-completeness, 1 done; 1 does not count
      final log = DailyLog(
        dateKey: '2024-01-01',
        bibleReference: 'Gen 1',
        customActivityData: {
          'c1': {'countsForCompleteness': true, 'done': true},
          'c2': {'countsForCompleteness': true, 'done': false},
          'c3': {'countsForCompleteness': false, 'done': true},
        },
      );
      // built-in: 1 filled / 11 total
      // custom counting: 2 total, 1 filled
      // overall: 2 / 13
      expect(log.completeness, closeTo(2 / 13, 0.001));
    });

    test('fully filled built-in log plus completed custom = (11+1)/(11+1)', () {
      final log = fullBuiltInLog();
      log.customActivityData['c-done'] = {
        'countsForCompleteness': true,
        'done': true,
      };
      expect(log.completeness, 1.0);
    });

    test('fully filled built-in log plus incomplete custom < 1.0', () {
      final log = fullBuiltInLog();
      log.customActivityData['c-pending'] = {
        'countsForCompleteness': true,
        'done': false,
      };
      // 11 / 12
      expect(log.completeness, closeTo(11 / 12, 0.001));
    });
  });

  // ──────────────────────────────────────────────
  // 5. TimerSession format tests with specific durations
  // ──────────────────────────────────────────────
  group('TimerSession format — paused sessions', () {
    TimerSession pausedSession(Duration elapsed) => TimerSession(
          key: const TimerKey.builtIn(ActivityType.bibleReading),
          dateKey: '2024-01-01',
          elapsed: elapsed,
          paused: true,
        );

    // formattedDuration tests
    group('formattedDuration', () {
      test('zero seconds → "0s"', () {
        expect(pausedSession(Duration.zero).formattedDuration, '0s');
      });

      test('30 seconds → "30s"', () {
        expect(pausedSession(const Duration(seconds: 30)).formattedDuration, '30s');
      });

      test('exactly 1 minute → "1m 00s"', () {
        expect(
          pausedSession(const Duration(minutes: 1)).formattedDuration,
          '1m 00s',
        );
      });

      test('1 minute 5 seconds → "1m 05s"', () {
        expect(
          pausedSession(const Duration(minutes: 1, seconds: 5)).formattedDuration,
          '1m 05s',
        );
      });

      test('45 minutes → "45m 00s"', () {
        expect(
          pausedSession(const Duration(minutes: 45)).formattedDuration,
          '45m 00s',
        );
      });

      test('1 hour → "1h 00m"', () {
        expect(
          pausedSession(const Duration(hours: 1)).formattedDuration,
          '1h 00m',
        );
      });

      test('1 hour 30 minutes → "1h 30m"', () {
        expect(
          pausedSession(const Duration(hours: 1, minutes: 30)).formattedDuration,
          '1h 30m',
        );
      });

      test('2 hours 5 minutes → "2h 05m"', () {
        expect(
          pausedSession(const Duration(hours: 2, minutes: 5)).formattedDuration,
          '2h 05m',
        );
      });
    });

    // logDurationString tests
    group('logDurationString', () {
      test('zero → "0s"', () {
        expect(pausedSession(Duration.zero).logDurationString, '0s');
      });

      test('30 seconds → "30s"', () {
        expect(
          pausedSession(const Duration(seconds: 30)).logDurationString,
          '30s',
        );
      });

      test('1 minute → "1 minutes"', () {
        expect(
          pausedSession(const Duration(minutes: 1)).logDurationString,
          '1 minutes',
        );
      });

      test('45 minutes → "45 minutes"', () {
        expect(
          pausedSession(const Duration(minutes: 45)).logDurationString,
          '45 minutes',
        );
      });

      test('1 hour exactly → "1h"', () {
        expect(
          pausedSession(const Duration(hours: 1)).logDurationString,
          '1h',
        );
      });

      test('1 hour 30 minutes → "1h 30min"', () {
        expect(
          pausedSession(const Duration(hours: 1, minutes: 30)).logDurationString,
          '1h 30min',
        );
      });

      test('2 hours → "2h"', () {
        expect(
          pausedSession(const Duration(hours: 2)).logDurationString,
          '2h',
        );
      });
    });

    // stopwatchDisplay tests
    group('stopwatchDisplay', () {
      test('zero → "00:00"', () {
        expect(pausedSession(Duration.zero).stopwatchDisplay, '00:00');
      });

      test('30 seconds → "00:30"', () {
        expect(
          pausedSession(const Duration(seconds: 30)).stopwatchDisplay,
          '00:30',
        );
      });

      test('1 minute 5 seconds → "01:05"', () {
        expect(
          pausedSession(const Duration(minutes: 1, seconds: 5)).stopwatchDisplay,
          '01:05',
        );
      });

      test('59 minutes 59 seconds → "59:59"', () {
        expect(
          pausedSession(const Duration(minutes: 59, seconds: 59)).stopwatchDisplay,
          '59:59',
        );
      });

      test('1 hour → "01:00:00"', () {
        expect(
          pausedSession(const Duration(hours: 1)).stopwatchDisplay,
          '01:00:00',
        );
      });

      test('1 hour 30 minutes 45 seconds → "01:30:45"', () {
        expect(
          pausedSession(const Duration(hours: 1, minutes: 30, seconds: 45)).stopwatchDisplay,
          '01:30:45',
        );
      });

      test('10 hours 5 minutes 3 seconds → "10:05:03"', () {
        expect(
          pausedSession(const Duration(hours: 10, minutes: 5, seconds: 3)).stopwatchDisplay,
          '10:05:03',
        );
      });
    });

    // currentElapsed returns elapsed directly when paused
    group('currentElapsed when paused', () {
      test('returns elapsed unchanged (no running segment added)', () {
        const d = Duration(minutes: 42, seconds: 17);
        final session = TimerSession(
          key: const TimerKey.builtIn(ActivityType.prayerAlone),
          dateKey: '2024-01-01',
          elapsed: d,
          startedAt: DateTime.now(), // even with startedAt set, paused=true → no addition
          paused: true,
        );
        expect(session.currentElapsed, d);
      });
    });

    // isRunning / isStopped semantics for paused sessions
    group('isRunning / isStopped', () {
      test('paused session with startedAt is not running', () {
        final session = TimerSession(
          key: const TimerKey.builtIn(ActivityType.ddeg),
          dateKey: '2024-01-01',
          elapsed: const Duration(minutes: 5),
          startedAt: DateTime.now(),
          paused: true,
        );
        expect(session.isRunning, false);
      });

      test('paused session with elapsed > 0 is not stopped', () {
        final session = pausedSession(const Duration(minutes: 5));
        expect(session.isStopped, false);
      });

      test('fresh session with no elapsed and no startedAt is stopped', () {
        final session = TimerSession(
          key: const TimerKey.builtIn(ActivityType.evangelism),
          dateKey: '2024-01-01',
        );
        expect(session.isStopped, true);
      });
    });

    // Custom key paused session
    group('TimerSession with custom key', () {
      test('paused custom session format works', () {
        final session = TimerSession(
          key: const TimerKey.custom('my-activity-id'),
          dateKey: '2024-01-01',
          elapsed: const Duration(hours: 1, minutes: 15),
          paused: true,
        );
        expect(session.formattedDuration, '1h 15m');
        expect(session.logDurationString, '1h 15min');
        expect(session.stopwatchDisplay, '01:15:00');
      });

      test('custom key serialKey prefixed with c:', () {
        const key = TimerKey.custom('abc-123');
        expect(key.serialKey, 'c:abc-123');
      });

      test('built-in key serialKey prefixed with b:', () {
        const key = TimerKey.builtIn(ActivityType.bibleReading);
        expect(key.serialKey, startsWith('b:'));
      });
    });
  });
}
