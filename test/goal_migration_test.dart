import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_account/models/goal.dart';
import 'package:daily_account/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('migrateGoalsIfNeeded', () {
    test('converts old daily-frequency goals into new Goal list', () async {
      SharedPreferences.setMockInitialValues({
        'goalFrequency': 'daily',
        'goalBibleChapters': '3',
        'goalPrayerMinutes': '20',
        'goalEvangelismContacts': '0', // zero — should be excluded
        'goalLiteratureItems': '1',
      });

      await StorageService.instance.migrateGoalsIfNeeded();
      final goals = await StorageService.instance.getGoals();

      expect(goals.length, 3); // evangelismContacts excluded (was 0)
      final byKey = {for (final g in goals) g.metricKey: g};
      expect(byKey['bibleChapters']!.frequency, GoalFrequency.daily);
      expect(byKey['bibleChapters']!.target, 3);
      expect(byKey['prayer']!.target, 20);
      expect(byKey['prayer']!.unit, GoalUnit.minutes);
      expect(byKey['literatureItems']!.target, 1);
      expect(byKey.containsKey('evangelismContacts'), false);
    });

    test('converts old weekly-frequency goals correctly', () async {
      SharedPreferences.setMockInitialValues({
        'goalFrequency': 'weekly',
        'goalBibleChapters': '10',
      });

      await StorageService.instance.migrateGoalsIfNeeded();
      final goals = await StorageService.instance.getGoals();

      expect(goals.length, 1);
      expect(goals.first.frequency, GoalFrequency.weekly);
      expect(goals.first.target, 10);
    });

    test('is idempotent — a second call does not duplicate goals', () async {
      SharedPreferences.setMockInitialValues({
        'goalFrequency': 'daily',
        'goalBibleChapters': '3',
      });

      await StorageService.instance.migrateGoalsIfNeeded();
      await StorageService.instance.migrateGoalsIfNeeded();
      final goals = await StorageService.instance.getGoals();

      expect(goals.length, 1);
    });

    test('a user with no old goal settings migrates to an empty list without error', () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.instance.migrateGoalsIfNeeded();
      final goals = await StorageService.instance.getGoals();
      expect(goals, isEmpty);
    });
  });

  group('getGoals / saveGoals round-trip', () {
    test('saving then loading preserves goal data', () async {
      SharedPreferences.setMockInitialValues({});
      final goal = Goal(id: 'bibleChapters', metricKey: 'bibleChapters', frequency: GoalFrequency.monthly, target: 50, unit: GoalUnit.count);
      await StorageService.instance.saveGoals([goal]);
      final loaded = await StorageService.instance.getGoals();
      expect(loaded.length, 1);
      expect(loaded.first.target, 50);
      expect(loaded.first.frequency, GoalFrequency.monthly);
    });
  });
}
