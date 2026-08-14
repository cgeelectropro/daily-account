import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/models/goal.dart';
import 'package:daily_account/data/goal_metrics.dart';

void main() {
  group('Goal', () {
    test('toMap / fromMap round-trip preserves all fields', () {
      final goal = Goal(
        id: 'bibleChapters',
        metricKey: 'bibleChapters',
        frequency: GoalFrequency.weekly,
        target: 20,
        unit: GoalUnit.count,
      );
      final restored = Goal.fromMap(goal.toMap());
      expect(restored.id, 'bibleChapters');
      expect(restored.metricKey, 'bibleChapters');
      expect(restored.frequency, GoalFrequency.weekly);
      expect(restored.target, 20);
      expect(restored.unit, GoalUnit.count);
      expect(restored.customLabel, isNull);
      expect(restored.customIcon, isNull);
    });

    test('toMap / fromMap round-trip preserves custom label and icon', () {
      final goal = Goal(
        id: 'custom:abc123:Pages Read',
        metricKey: 'custom:abc123:Pages Read',
        frequency: GoalFrequency.monthly,
        target: 300,
        unit: GoalUnit.count,
        customLabel: 'Pages Read',
        customIcon: '📖',
      );
      final restored = Goal.fromMap(goal.toMap());
      expect(restored.customLabel, 'Pages Read');
      expect(restored.customIcon, '📖');
    });

    test('fromMap handles a duration goal with hours unit', () {
      final goal = Goal(
        id: 'prayer',
        metricKey: 'prayer',
        frequency: GoalFrequency.daily,
        target: 90,
        unit: GoalUnit.hours,
      );
      final restored = Goal.fromMap(goal.toMap());
      expect(restored.unit, GoalUnit.hours);
      expect(restored.target, 90);
    });
  });

  group('GoalMetrics.builtIn', () {
    test('contains exactly 9 entries with unique keys', () {
      final keys = GoalMetrics.builtIn.map((m) => m.key).toSet();
      expect(keys.length, 9);
      expect(GoalMetrics.builtIn.length, 9);
    });

    test('contains the 4 legacy metric keys used by migration', () {
      final keys = GoalMetrics.builtIn.map((m) => m.key).toSet();
      expect(keys, containsAll(['bibleChapters', 'prayer', 'evangelismContacts', 'literatureItems']));
    });

    test('duration metrics have baseUnit minutes, count metrics have baseUnit count', () {
      final byKey = {for (final m in GoalMetrics.builtIn) m.key: m};
      expect(byKey['bibleChapters']!.baseUnit, GoalUnit.count);
      expect(byKey['prayer']!.baseUnit, GoalUnit.minutes);
      expect(byKey['evangelismContacts']!.baseUnit, GoalUnit.count);
      expect(byKey['literatureItems']!.baseUnit, GoalUnit.count);
      expect(byKey['ddegTime']!.baseUnit, GoalUnit.minutes);
      expect(byKey['fastingCount']!.baseUnit, GoalUnit.count);
      expect(byKey['churchCount']!.baseUnit, GoalUnit.count);
      expect(byKey['discipleshipTime']!.baseUnit, GoalUnit.minutes);
      expect(byKey['proclamationCount']!.baseUnit, GoalUnit.count);
    });
  });
}
