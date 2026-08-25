enum GoalFrequency { daily, weekly, monthly }
enum GoalUnit { count, minutes, hours }

/// A user-configured target for a trackable metric, scoped to one
/// frequency (daily/weekly/monthly). Multiple goals of different
/// frequencies can target the same metric simultaneously.
class Goal {
  String id;
  String metricKey;
  GoalFrequency frequency;
  int target;
  GoalUnit unit;
  String? customLabel;
  String? customIcon;

  Goal({
    required this.id,
    required this.metricKey,
    required this.frequency,
    required this.target,
    required this.unit,
    this.customLabel,
    this.customIcon,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'metricKey': metricKey,
        'frequency': frequency.name,
        'target': target,
        'unit': unit.name,
        'customLabel': customLabel,
        'customIcon': customIcon,
      };

  factory Goal.fromMap(Map<String, dynamic> m) => Goal(
        id: m['id'] as String,
        metricKey: m['metricKey'] as String,
        frequency: GoalFrequency.values.byName(m['frequency'] as String? ?? 'weekly'),
        target: m['target'] as int? ?? 0,
        unit: GoalUnit.values.byName(m['unit'] as String? ?? 'count'),
        customLabel: m['customLabel'] as String?,
        customIcon: m['customIcon'] as String?,
      );
}
