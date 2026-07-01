import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/models/activity_timer.dart';

void main() {
  // ---------------------------------------------------------------------------
  // TimerKey
  // ---------------------------------------------------------------------------
  group('TimerKey', () {
    group('construction', () {
      test('builtIn sets builtIn field and leaves customId null', () {
        const key = TimerKey.builtIn(ActivityType.bibleReading);
        expect(key.builtIn, ActivityType.bibleReading);
        expect(key.customId, isNull);
      });

      test('custom sets customId field and leaves builtIn null', () {
        const key = TimerKey.custom('my-custom-id');
        expect(key.customId, 'my-custom-id');
        expect(key.builtIn, isNull);
      });
    });

    group('isBuiltIn / isCustom', () {
      test('builtIn key reports isBuiltIn=true, isCustom=false', () {
        const key = TimerKey.builtIn(ActivityType.prayerAlone);
        expect(key.isBuiltIn, isTrue);
        expect(key.isCustom, isFalse);
      });

      test('custom key reports isCustom=true, isBuiltIn=false', () {
        const key = TimerKey.custom('abc');
        expect(key.isCustom, isTrue);
        expect(key.isBuiltIn, isFalse);
      });
    });

    group('serialKey — all 10 built-in types', () {
      final expectations = {
        ActivityType.bibleReading: 'b:0',
        ActivityType.literature: 'b:1',
        ActivityType.ddeg: 'b:2',
        ActivityType.prayerAlone: 'b:3',
        ActivityType.prayerOthers: 'b:4',
        ActivityType.evangelism: 'b:5',
        ActivityType.fasting: 'b:6',
        ActivityType.discipleship: 'b:7',
        ActivityType.church: 'b:8',
        ActivityType.proclamation: 'b:9',
      };

      for (final entry in expectations.entries) {
        test('${entry.key.name} → "${entry.value}"', () {
          expect(TimerKey.builtIn(entry.key).serialKey, entry.value);
        });
      }

      test('custom key serialKey has c: prefix', () {
        expect(
          const TimerKey.custom('yoga-123').serialKey,
          'c:yoga-123',
        );
      });
    });

    group('fromSerialKey round-trip', () {
      for (final type in ActivityType.values) {
        test('round-trip for ${type.name}', () {
          final original = TimerKey.builtIn(type);
          final restored = TimerKey.fromSerialKey(original.serialKey);
          expect(restored, original);
          expect(restored.builtIn, type);
        });
      }

      test('round-trip for custom key', () {
        const original = TimerKey.custom('custom-42');
        final restored = TimerKey.fromSerialKey(original.serialKey);
        expect(restored, original);
        expect(restored.customId, 'custom-42');
      });

      test('fromSerialKey parses b: prefix correctly', () {
        final key = TimerKey.fromSerialKey('b:5');
        expect(key.builtIn, ActivityType.evangelism);
        expect(key.isBuiltIn, isTrue);
      });

      test('fromSerialKey parses c: prefix correctly', () {
        final key = TimerKey.fromSerialKey('c:some-id');
        expect(key.customId, 'some-id');
        expect(key.isCustom, isTrue);
      });
    });

    group('equality', () {
      test('same built-in type are equal', () {
        expect(
          const TimerKey.builtIn(ActivityType.church),
          const TimerKey.builtIn(ActivityType.church),
        );
      });

      test('different built-in types are not equal', () {
        expect(
          const TimerKey.builtIn(ActivityType.church),
          isNot(const TimerKey.builtIn(ActivityType.fasting)),
        );
      });

      test('same custom id are equal', () {
        expect(
          const TimerKey.custom('foo'),
          const TimerKey.custom('foo'),
        );
      });

      test('different custom ids are not equal', () {
        expect(
          const TimerKey.custom('foo'),
          isNot(const TimerKey.custom('bar')),
        );
      });

      test('builtIn key is not equal to custom key', () {
        // Even if it looks similar, different kinds must not be equal.
        expect(
          const TimerKey.builtIn(ActivityType.bibleReading),
          isNot(const TimerKey.custom('bibleReading')),
        );
      });
    });

    group('hashCode', () {
      test('identical builtIn keys have the same hashCode', () {
        expect(
          const TimerKey.builtIn(ActivityType.ddeg).hashCode,
          const TimerKey.builtIn(ActivityType.ddeg).hashCode,
        );
      });

      test('identical custom keys have the same hashCode', () {
        expect(
          const TimerKey.custom('x').hashCode,
          const TimerKey.custom('x').hashCode,
        );
      });
    });

    group('toString', () {
      test('builtIn key toString contains the enum name', () {
        expect(
          const TimerKey.builtIn(ActivityType.proclamation).toString(),
          'TimerKey(proclamation)',
        );
      });

      test('custom key toString contains custom: prefix and id', () {
        expect(
          const TimerKey.custom('my-act').toString(),
          'TimerKey(custom:my-act)',
        );
      });
    });
  });

  // ---------------------------------------------------------------------------
  // ActivityTypeMapping extension
  // ---------------------------------------------------------------------------
  group('ActivityTypeMapping', () {
    group('logDurationField', () {
      const expected = {
        ActivityType.bibleReading: 'bibleDuration',
        ActivityType.literature: 'literatureDuration',
        ActivityType.ddeg: 'ddegTime',
        ActivityType.prayerAlone: 'prayerAloneDuration',
        ActivityType.prayerOthers: 'prayerOthersDuration',
        ActivityType.evangelism: 'evangelismDuration',
        ActivityType.fasting: 'fastingDuration',
        ActivityType.discipleship: 'discipleshipDuration',
        ActivityType.church: 'churchDuration',
        ActivityType.proclamation: 'proclamationDuration',
      };

      for (final entry in expected.entries) {
        test('${entry.key.name} → "${entry.value}"', () {
          expect(entry.key.logDurationField, entry.value);
        });
      }
    });

    group('icon', () {
      test('every ActivityType has a non-empty icon', () {
        for (final type in ActivityType.values) {
          expect(
            type.icon,
            isNotEmpty,
            reason: '${type.name} should have a non-empty icon',
          );
        }
      });
    });

    group('shortCode', () {
      const expected = {
        ActivityType.bibleReading: 'LB',
        ActivityType.literature: 'Lit',
        ActivityType.ddeg: 'RDQD',
        ActivityType.prayerAlone: 'PS',
        ActivityType.prayerOthers: 'PA',
        ActivityType.evangelism: 'Ev',
        ActivityType.fasting: 'Je',
        ActivityType.discipleship: 'Dis',
        ActivityType.church: 'Eg',
        ActivityType.proclamation: 'Pr',
      };

      test('every ActivityType has a non-empty shortCode', () {
        for (final type in ActivityType.values) {
          expect(
            type.shortCode,
            isNotEmpty,
            reason: '${type.name} should have a non-empty shortCode',
          );
        }
      });

      for (final entry in expected.entries) {
        test('${entry.key.name} → "${entry.value}"', () {
          expect(entry.key.shortCode, entry.value);
        });
      }
    });
  });

  // ---------------------------------------------------------------------------
  // TimerSession
  // ---------------------------------------------------------------------------
  group('TimerSession', () {
    const builtInKey = TimerKey.builtIn(ActivityType.bibleReading);
    const customKey = TimerKey.custom('custom-act-1');
    const testDate = '2026-06-15';

    group('constructor defaults', () {
      test('elapsed defaults to Duration.zero', () {
        final s = TimerSession(key: builtInKey, dateKey: testDate);
        expect(s.elapsed, Duration.zero);
      });

      test('startedAt defaults to null', () {
        final s = TimerSession(key: builtInKey, dateKey: testDate);
        expect(s.startedAt, isNull);
      });

      test('paused defaults to false', () {
        final s = TimerSession(key: builtInKey, dateKey: testDate);
        expect(s.paused, isFalse);
      });

      test('fields defaults to empty map', () {
        final s = TimerSession(key: builtInKey, dateKey: testDate);
        expect(s.fields, isEmpty);
      });

      test('explicit fields are stored', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          fields: {'bibleRef': 'John 3:16'},
        );
        expect(s.fields['bibleRef'], 'John 3:16');
      });
    });

    group('activity getter', () {
      test('returns builtIn type for a built-in key', () {
        final s = TimerSession(key: builtInKey, dateKey: testDate);
        expect(s.activity, ActivityType.bibleReading);
      });

      test('returns null for a custom key', () {
        final s = TimerSession(key: customKey, dateKey: testDate);
        expect(s.activity, isNull);
      });
    });

    group('isRunning', () {
      test('fresh session (no startedAt) is not running', () {
        final s = TimerSession(key: builtInKey, dateKey: testDate);
        expect(s.isRunning, isFalse);
      });

      test('session with startedAt and paused=false is running', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          startedAt: DateTime.now(),
        );
        expect(s.isRunning, isTrue);
      });

      test('session with startedAt but paused=true is NOT running', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          startedAt: DateTime.now(),
          paused: true,
        );
        expect(s.isRunning, isFalse);
      });
    });

    group('isStopped', () {
      test('fresh session with no startedAt and zero elapsed is stopped', () {
        final s = TimerSession(key: builtInKey, dateKey: testDate);
        expect(s.isStopped, isTrue);
      });

      test('running session is not stopped', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          startedAt: DateTime.now(),
        );
        expect(s.isStopped, isFalse);
      });

      test('paused session with elapsed > 0 is not stopped', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          elapsed: const Duration(minutes: 5),
          paused: true,
        );
        expect(s.isStopped, isFalse);
      });

      test('session with only elapsed (no startedAt) is not stopped', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          elapsed: const Duration(seconds: 30),
        );
        expect(s.isStopped, isFalse);
      });
    });

    group('currentElapsed', () {
      test('paused session returns stored elapsed only', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          elapsed: const Duration(minutes: 10),
          paused: true,
          startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        );
        expect(s.currentElapsed, const Duration(minutes: 10));
      });

      test('session with no startedAt returns stored elapsed', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          elapsed: const Duration(seconds: 45),
        );
        expect(s.currentElapsed, const Duration(seconds: 45));
      });

      test('running session includes live segment', () {
        final ago = DateTime.now().subtract(const Duration(seconds: 5));
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          elapsed: const Duration(seconds: 10),
          startedAt: ago,
        );
        // elapsed(10s) + ~5s live = at least 14s
        expect(s.currentElapsed.inSeconds, greaterThanOrEqualTo(14));
      });
    });

    group('formattedDuration', () {
      test('hours + minutes format (e.g. "1h 30m")', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          elapsed: const Duration(hours: 1, minutes: 30),
        );
        expect(s.formattedDuration, '1h 30m');
      });

      test('hours with zero minutes uses two-digit padding (e.g. "2h 00m")', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          elapsed: const Duration(hours: 2),
        );
        expect(s.formattedDuration, '2h 00m');
      });

      test('minutes + seconds format (e.g. "5m 09s")', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          elapsed: const Duration(minutes: 5, seconds: 9),
        );
        expect(s.formattedDuration, '5m 09s');
      });

      test('seconds only format (e.g. "45s")', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          elapsed: const Duration(seconds: 45),
        );
        expect(s.formattedDuration, '45s');
      });

      test('zero duration shows "0s"', () {
        final s = TimerSession(key: builtInKey, dateKey: testDate);
        expect(s.formattedDuration, '0s');
      });
    });

    group('logDurationString', () {
      test('hours + remaining minutes (e.g. "1h 30min")', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          elapsed: const Duration(hours: 1, minutes: 30),
        );
        expect(s.logDurationString, '1h 30min');
      });

      test('hours only when minutes are zero (e.g. "2h")', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          elapsed: const Duration(hours: 2),
        );
        expect(s.logDurationString, '2h');
      });

      test('minutes only (e.g. "45 minutes")', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          elapsed: const Duration(minutes: 45),
        );
        expect(s.logDurationString, '45 minutes');
      });

      test('seconds only fallback (e.g. "30s")', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          elapsed: const Duration(seconds: 30),
        );
        expect(s.logDurationString, '30s');
      });

      test('zero duration returns "0s"', () {
        final s = TimerSession(key: builtInKey, dateKey: testDate);
        expect(s.logDurationString, '0s');
      });
    });

    group('stopwatchDisplay', () {
      test('includes HH when hours > 0 (e.g. "01:30:05")', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          elapsed: const Duration(hours: 1, minutes: 30, seconds: 5),
        );
        expect(s.stopwatchDisplay, '01:30:05');
      });

      test('pads hours/minutes/seconds to two digits', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          elapsed: const Duration(hours: 2, minutes: 3, seconds: 4),
        );
        expect(s.stopwatchDisplay, '02:03:04');
      });

      test('omits HH when hours == 0 (e.g. "05:09")', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          elapsed: const Duration(minutes: 5, seconds: 9),
        );
        expect(s.stopwatchDisplay, '05:09');
      });

      test('zero duration shows "00:00"', () {
        final s = TimerSession(key: builtInKey, dateKey: testDate);
        expect(s.stopwatchDisplay, '00:00');
      });
    });

    group('toMap / fromMap round-trip', () {
      test('round-trip preserves all fields for a built-in paused session', () {
        final original = TimerSession(
          key: const TimerKey.builtIn(ActivityType.ddeg),
          dateKey: '2026-06-20',
          elapsed: const Duration(minutes: 25, seconds: 10),
          startedAt: null,
          paused: true,
          fields: {'note': 'some note'},
        );
        final map = original.toMap();
        final restored = TimerSession.fromMap(map);

        expect(restored.key, original.key);
        expect(restored.dateKey, original.dateKey);
        expect(restored.elapsed, original.elapsed);
        expect(restored.startedAt, isNull);
        expect(restored.paused, isTrue);
        expect(restored.fields['note'], 'some note');
      });

      test('round-trip preserves startedAt when present', () {
        final now = DateTime.utc(2026, 6, 20, 10, 30, 0);
        final original = TimerSession(
          key: const TimerKey.builtIn(ActivityType.prayerAlone),
          dateKey: '2026-06-20',
          elapsed: const Duration(seconds: 5),
          startedAt: now,
          paused: false,
        );
        final restored = TimerSession.fromMap(original.toMap());
        expect(restored.startedAt, now);
        expect(restored.isRunning, isTrue);
      });

      test('round-trip for a custom key session', () {
        final original = TimerSession(
          key: const TimerKey.custom('workout-1'),
          dateKey: '2026-06-21',
          elapsed: const Duration(minutes: 15),
        );
        final restored = TimerSession.fromMap(original.toMap());
        expect(restored.key, const TimerKey.custom('workout-1'));
        expect(restored.key.isCustom, isTrue);
        expect(restored.elapsed, const Duration(minutes: 15));
      });

      test('toMap encodes paused=false as 0', () {
        final s = TimerSession(key: builtInKey, dateKey: testDate);
        expect(s.toMap()['paused'], 0);
      });

      test('toMap encodes paused=true as 1', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          paused: true,
          startedAt: DateTime.now(),
        );
        expect(s.toMap()['paused'], 1);
      });

      test('toMap stores null startedAt as null', () {
        final s = TimerSession(key: builtInKey, dateKey: testDate);
        expect(s.toMap()['startedAt'], isNull);
      });
    });

    group('fromMap — legacy "activity" key support', () {
      test('legacy map with integer "activity" field is parsed correctly', () {
        final legacyMap = <String, dynamic>{
          // no 'timerKey' field — legacy format
          'activity': ActivityType.evangelism.index, // 5
          'dateKey': '2026-01-01',
          'elapsedMs': 120000,
          'startedAt': null,
          'paused': 0,
          'fields': <String, String>{},
        };
        final s = TimerSession.fromMap(legacyMap);
        expect(s.key.builtIn, ActivityType.evangelism);
        expect(s.key.isBuiltIn, isTrue);
        expect(s.elapsed, const Duration(minutes: 2));
      });

      test('legacy map for all built-in types resolves correctly', () {
        for (final type in ActivityType.values) {
          final legacyMap = <String, dynamic>{
            'activity': type.index,
            'dateKey': '2026-01-01',
            'elapsedMs': 0,
            'startedAt': null,
            'paused': 0,
            'fields': null,
          };
          final s = TimerSession.fromMap(legacyMap);
          expect(s.key.builtIn, type, reason: '${type.name} should deserialize');
        }
      });

      test('new-format map (timerKey) takes precedence over legacy', () {
        final map = <String, dynamic>{
          'timerKey': 'b:3', // prayerAlone
          'activity': 0, // bibleReading — should be ignored
          'dateKey': '2026-01-01',
          'elapsedMs': 0,
          'startedAt': null,
          'paused': 0,
          'fields': null,
        };
        final s = TimerSession.fromMap(map);
        expect(s.key.builtIn, ActivityType.prayerAlone);
      });
    });

    group('fields preservation', () {
      test('multiple fields are stored and retrieved correctly', () {
        final s = TimerSession(
          key: builtInKey,
          dateKey: testDate,
          fields: {
            'bibleRef': 'Psalm 23',
            'chapter': '23',
            'notes': 'Very comforting',
          },
        );
        final restored = TimerSession.fromMap(s.toMap());
        expect(restored.fields['bibleRef'], 'Psalm 23');
        expect(restored.fields['chapter'], '23');
        expect(restored.fields['notes'], 'Very comforting');
      });

      test('null fields in fromMap produces empty map', () {
        final map = <String, dynamic>{
          'timerKey': 'b:0',
          'dateKey': testDate,
          'elapsedMs': 0,
          'startedAt': null,
          'paused': 0,
          'fields': null,
        };
        final s = TimerSession.fromMap(map);
        expect(s.fields, isEmpty);
      });
    });
  });
}
