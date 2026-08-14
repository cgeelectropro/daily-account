import '../models/custom_activity.dart';
import '../models/goal.dart';

class GoalMetric {
  final String key;
  final String Function(dynamic l) label;
  final String icon;
  final GoalUnit baseUnit;

  const GoalMetric({
    required this.key,
    required this.label,
    required this.icon,
    required this.baseUnit,
  });
}

class GoalMetrics {
  GoalMetrics._();

  static const List<GoalMetric> builtIn = [
    GoalMetric(key: 'bibleChapters', label: _lBibleChapters, icon: '📖', baseUnit: GoalUnit.count),
    GoalMetric(key: 'prayer', label: _lPrayer, icon: '🙏', baseUnit: GoalUnit.minutes),
    GoalMetric(key: 'evangelismContacts', label: _lEvangelismContacts, icon: '📢', baseUnit: GoalUnit.count),
    GoalMetric(key: 'literatureItems', label: _lLiteratureItems, icon: '📚', baseUnit: GoalUnit.count),
    GoalMetric(key: 'ddegTime', label: _lDdegTime, icon: '🔥', baseUnit: GoalUnit.minutes),
    GoalMetric(key: 'fastingCount', label: _lFastingCount, icon: '🍽️', baseUnit: GoalUnit.count),
    GoalMetric(key: 'churchCount', label: _lChurchCount, icon: '⛪', baseUnit: GoalUnit.count),
    GoalMetric(key: 'discipleshipTime', label: _lDiscipleshipTime, icon: '👥', baseUnit: GoalUnit.minutes),
    GoalMetric(key: 'proclamationCount', label: _lProclamationCount, icon: '📣', baseUnit: GoalUnit.count),
  ];

  static String _lBibleChapters(dynamic l) => l.goalBibleChapters as String;
  static String _lPrayer(dynamic l) => l.goalPrayerMinutes as String;
  static String _lEvangelismContacts(dynamic l) => l.goalEvangelismContacts as String;
  static String _lLiteratureItems(dynamic l) => l.goalLiteratureItems as String;
  static String _lDdegTime(dynamic l) => l.goalDdegTime as String;
  static String _lFastingCount(dynamic l) => l.goalFastingCount as String;
  static String _lChurchCount(dynamic l) => l.goalChurchCount as String;
  static String _lDiscipleshipTime(dynamic l) => l.goalDiscipleshipTime as String;
  static String _lProclamationCount(dynamic l) => l.goalProclamationCount as String;

  /// One GoalMetric per counter/duration field across all of [activities].
  static List<GoalMetric> fromCustomActivities(List<CustomActivity> activities) {
    final result = <GoalMetric>[];
    for (final activity in activities) {
      for (final field in activity.fields) {
        if (field.type.name != 'counter' && field.type.name != 'duration') continue;
        final key = 'custom:${activity.id}:${field.label}';
        final unit = field.type.name == 'counter' ? GoalUnit.count : GoalUnit.minutes;
        result.add(GoalMetric(
          key: key,
          label: (dynamic l) => '${activity.name} — ${field.label}',
          icon: activity.icon,
          baseUnit: unit,
        ));
      }
    }
    return result;
  }
}
