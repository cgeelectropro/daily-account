import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_account/models/daily_log.dart';
import 'package:daily_account/models/goal.dart';
import 'package:daily_account/services/goal_progress_service.dart';
import 'package:daily_account/services/storage_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Tests share one in-memory database via the StorageService singleton
  // (which caches its Database for the process lifetime). Distinct dateKeys
  // per test avoid same-day overwrites, but weekly/monthly aggregation
  // tests scan date *ranges* that can accidentally include dates seeded by
  // earlier, unrelated tests. Clear the logs table between tests so each
  // test's aggregation window only ever contains what it seeded itself.
  tearDown(() async {
    final db = await StorageService.instance.database;
    await db.delete('logs');
  });

  final svc = GoalProgressService.instance;

  group('computeProgress — daily, count metrics', () {
    test('bibleChapters sums totalBibleChapters for the single day', () async {
      final today = DateTime(2026, 8, 14);
      final log = DailyLog(dateKey: '2026-08-14', bibleChapters: '5');
      await StorageService.instance.saveLog(log);

      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.daily, target: 3, unit: GoalUnit.count);
      final progress = await svc.computeProgress(goal, today);
      expect(progress, 5);
    });

    test('evangelismContacts parses the stored numeric string', () async {
      final today = DateTime(2026, 8, 15);
      final log = DailyLog(dateKey: '2026-08-15', evangelismContacts: '7');
      await StorageService.instance.saveLog(log);

      final goal = Goal(id: 'evangelismContacts', metricKey: 'evangelismContacts', frequency: GoalFrequency.daily, target: 5, unit: GoalUnit.count);
      final progress = await svc.computeProgress(goal, today);
      expect(progress, 7);
    });

    test('literatureItems counts entries with non-empty title', () async {
      final today = DateTime(2026, 8, 16);
      final log = DailyLog(
        dateKey: '2026-08-16',
        literature: [
          LiteratureEntry(title: 'Book A', amount: '10', unit: 'pages'),
          LiteratureEntry(title: '', amount: '', unit: 'pages'),
          LiteratureEntry(title: 'Book B', amount: '5', unit: 'pages'),
        ],
      );
      await StorageService.instance.saveLog(log);

      final goal = Goal(id: 'literatureItems', metricKey: 'literatureItems', frequency: GoalFrequency.daily, target: 1, unit: GoalUnit.count);
      final progress = await svc.computeProgress(goal, today);
      expect(progress, 2);
    });

    test('no log for the day returns 0', () async {
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.daily, target: 3, unit: GoalUnit.count);
      final progress = await svc.computeProgress(goal, DateTime(2099, 1, 1));
      expect(progress, 0);
    });
  });

  group('computeProgress — daily, duration metrics', () {
    test('prayer sums session-aware alone + together minutes', () async {
      final today = DateTime(2026, 8, 17);
      final log = DailyLog(
        dateKey: '2026-08-17',
        prayerAloneSessions: [PrayerSession(duration: '30m', notes: '')],
        prayerOthersSessions: [PrayerSession(duration: '15m', notes: '')],
      );
      await StorageService.instance.saveLog(log);

      final goal = Goal(id: 'prayer', metricKey: 'prayer', frequency: GoalFrequency.daily, target: 20, unit: GoalUnit.minutes);
      final progress = await svc.computeProgress(goal, today);
      expect(progress, 45);
    });

    test('prayer falls back to legacy duration fields when sessions are empty', () async {
      final today = DateTime(2026, 8, 18);
      final log = DailyLog(dateKey: '2026-08-18', prayerAloneDuration: '1h', prayerOthersDuration: '10m');
      await StorageService.instance.saveLog(log);

      final goal = Goal(id: 'prayer', metricKey: 'prayer', frequency: GoalFrequency.daily, target: 20, unit: GoalUnit.minutes);
      final progress = await svc.computeProgress(goal, today);
      expect(progress, 70);
    });

    test('ddegTime is session-aware with legacy fallback', () async {
      final today = DateTime(2026, 8, 19);
      final log = DailyLog(dateKey: '2026-08-19', ddegSessions: [DdegSession(scripture: 'Ps 23', time: '25m', notes: '')]);
      await StorageService.instance.saveLog(log);

      final goal = Goal(id: 'ddegTime', metricKey: 'ddegTime', frequency: GoalFrequency.daily, target: 10, unit: GoalUnit.minutes);
      final progress = await svc.computeProgress(goal, today);
      expect(progress, 25);
    });

    test('discipleshipTime parses the legacy duration string', () async {
      final today = DateTime(2026, 8, 20);
      final log = DailyLog(dateKey: '2026-08-20', discipleshipDuration: '45m');
      await StorageService.instance.saveLog(log);

      final goal = Goal(id: 'discipleshipTime', metricKey: 'discipleshipTime', frequency: GoalFrequency.daily, target: 30, unit: GoalUnit.minutes);
      final progress = await svc.computeProgress(goal, today);
      expect(progress, 45);
    });
  });

  group('computeProgress — daily, presence-count metrics', () {
    test('fastingCount is 1 when fastingType or fastingDuration is set, 0 otherwise', () async {
      final day1 = DateTime(2026, 8, 21);
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-21', fastingType: 'Full fast'));
      final day2 = DateTime(2026, 8, 22);
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-22'));

      final goal = Goal(id: 'fastingCount', metricKey: 'fastingCount', frequency: GoalFrequency.daily, target: 1, unit: GoalUnit.count);
      expect(await svc.computeProgress(goal, day1), 1);
      expect(await svc.computeProgress(goal, day2), 0);
    });

    test('churchCount is 1 when churchType is set', () async {
      final day = DateTime(2026, 8, 23);
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-23', churchType: 'Sunday service'));
      final goal = Goal(id: 'churchCount', metricKey: 'churchCount', frequency: GoalFrequency.daily, target: 1, unit: GoalUnit.count);
      expect(await svc.computeProgress(goal, day), 1);
    });

    test('proclamationCount parses the stored numeric string', () async {
      final day = DateTime(2026, 8, 24);
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-24', proclamationCount: '3'));
      final goal = Goal(id: 'proclamationCount', metricKey: 'proclamationCount', frequency: GoalFrequency.daily, target: 2, unit: GoalUnit.count);
      expect(await svc.computeProgress(goal, day), 3);
    });
  });

  group('computeProgress — custom activity metrics', () {
    test('counter field sums the stored int value for the day', () async {
      final day = DateTime(2026, 8, 25);
      await StorageService.instance.saveLog(DailyLog(
        dateKey: '2026-08-25',
        customActivityData: {
          'act1': {'done': true, 'fields': {'Push-ups': 20}},
        },
      ));
      final goal = Goal(id: 'custom:act1:Push-ups', metricKey: 'custom:act1:Push-ups', frequency: GoalFrequency.daily, target: 10, unit: GoalUnit.count);
      expect(await svc.computeProgress(goal, day), 20);
    });

    test('duration field parses the stored duration string for the day', () async {
      final day = DateTime(2026, 8, 26);
      await StorageService.instance.saveLog(DailyLog(
        dateKey: '2026-08-26',
        customActivityData: {
          'act2': {'done': true, 'fields': {'Meditation': '20m'}},
        },
      ));
      final goal = Goal(id: 'custom:act2:Meditation', metricKey: 'custom:act2:Meditation', frequency: GoalFrequency.daily, target: 10, unit: GoalUnit.minutes);
      expect(await svc.computeProgress(goal, day), 20);
    });
  });

  group('computeProgress — weekly aggregation', () {
    test('sums a count metric across the cadence-configured week window', () async {
      // Default cadence is Sunday-ending, Monday-start. Seed 3 days within
      // the week containing 2026-08-12 (a Wednesday) with bibleChapters.
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-10', bibleChapters: '2')); // Monday
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-12', bibleChapters: '3')); // Wednesday
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-16', bibleChapters: '1')); // Sunday
      // A day outside this window should not be counted.
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-17', bibleChapters: '99')); // next Monday

      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.weekly, target: 5, unit: GoalUnit.count);
      final progress = await svc.computeProgress(goal, DateTime(2026, 8, 12));
      expect(progress, 6); // 2 + 3 + 1, not the 99 from the following week
    });
  });

  group('computeProgress — monthly aggregation', () {
    test('sums a count metric across the full calendar month', () async {
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-01', evangelismContacts: '2'));
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-31', evangelismContacts: '3'));
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-09-01', evangelismContacts: '99')); // next month excluded

      final goal = Goal(id: 'evangelismContacts', metricKey: 'evangelismContacts', frequency: GoalFrequency.monthly, target: 5, unit: GoalUnit.count);
      final progress = await svc.computeProgress(goal, DateTime(2026, 8, 15));
      expect(progress, 5); // 2 + 3, not the 99 from September
    });
  });

  group('isComplete', () {
    test('true when progress meets or exceeds target', () async {
      final day = DateTime(2026, 8, 27);
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-27', bibleChapters: '5'));
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.daily, target: 5, unit: GoalUnit.count);
      expect(await svc.isComplete(goal, day), true);
    });

    test('false when progress is under target', () async {
      final day = DateTime(2026, 8, 28);
      await StorageService.instance.saveLog(DailyLog(dateKey: '2026-08-28', bibleChapters: '2'));
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.daily, target: 5, unit: GoalUnit.count);
      expect(await svc.isComplete(goal, day), false);
    });
  });

  group('periodElapsedFraction', () {
    test('daily: always 1.0 regardless of time of day (whole-day granularity)', () {
      expect(svc.periodElapsedFraction(GoalFrequency.daily, DateTime(2026, 8, 14, 9)), 1.0);
      expect(svc.periodElapsedFraction(GoalFrequency.daily, DateTime(2026, 8, 14, 23)), 1.0);
    });

    test('weekly: fraction of the 7-day cadence window elapsed so far', () {
      // Default cadence Sunday-ending, week is Mon 8/10 - Sun 8/16.
      // Wednesday 8/12 is the 3rd day (index 2), so 3/7 elapsed.
      final frac = svc.periodElapsedFraction(GoalFrequency.weekly, DateTime(2026, 8, 12));
      expect(frac, closeTo(3 / 7, 0.01));
    });

    test('monthly: fraction of the calendar month elapsed so far', () {
      // August 2026 has 31 days; the 16th is day 16, so 16/31 elapsed.
      final frac = svc.periodElapsedFraction(GoalFrequency.monthly, DateTime(2026, 8, 16));
      expect(frac, closeTo(16 / 31, 0.01));
    });

    test('monthly: handles February in a non-leap year (28 days)', () {
      final frac = svc.periodElapsedFraction(GoalFrequency.monthly, DateTime(2026, 2, 14));
      expect(frac, closeTo(14 / 28, 0.01));
    });
  });

  group('justCompletedGoals', () {
    test('returns a goal that crossed from under-target to at-target', () async {
      final before = DailyLog(dateKey: '2026-08-29', bibleChapters: '2');
      final after = DailyLog(dateKey: '2026-08-29', bibleChapters: '5');
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.daily, target: 5, unit: GoalUnit.count);
      final result = await svc.justCompletedGoals(before, after, [goal]);
      expect(result, [goal]);
    });

    test('does not return a goal already complete before the save', () async {
      final before = DailyLog(dateKey: '2026-08-30', bibleChapters: '5');
      final after = DailyLog(dateKey: '2026-08-30', bibleChapters: '6');
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.daily, target: 5, unit: GoalUnit.count);
      final result = await svc.justCompletedGoals(before, after, [goal]);
      expect(result, isEmpty);
    });

    test('does not return a goal still under target after the save', () async {
      final before = DailyLog(dateKey: '2026-08-31', bibleChapters: '1');
      final after = DailyLog(dateKey: '2026-08-31', bibleChapters: '2');
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.daily, target: 5, unit: GoalUnit.count);
      final result = await svc.justCompletedGoals(before, after, [goal]);
      expect(result, isEmpty);
    });

    test('handles a null "before" (first save of a new day) as zero progress', () async {
      final after = DailyLog(dateKey: '2026-09-01', bibleChapters: '5');
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.daily, target: 5, unit: GoalUnit.count);
      final result = await svc.justCompletedGoals(null, after, [goal]);
      expect(result, [goal]);
    });
  });
}
