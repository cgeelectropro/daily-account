/// Types of fasting in CMFI tradition.
enum FastType { complete, partial, esther }

/// A multi-day fasting period.
class FastingPeriod {
  int? id;
  String startDate; // yyyy-MM-dd
  String endDate;   // yyyy-MM-dd
  FastType type;
  String prayerFocus;
  bool completed; // manually ended or date passed

  FastingPeriod({
    this.id,
    required this.startDate,
    required this.endDate,
    required this.type,
    this.prayerFocus = '',
    this.completed = false,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'startDate': startDate,
    'endDate': endDate,
    'type': type.name,
    'prayerFocus': prayerFocus,
    'completed': completed ? 1 : 0,
  };

  factory FastingPeriod.fromMap(Map<String, dynamic> m) => FastingPeriod(
    id: m['id'] as int?,
    startDate: m['startDate'] ?? '',
    endDate: m['endDate'] ?? '',
    type: FastType.values.firstWhere(
      (t) => t.name == (m['type'] ?? ''),
      orElse: () => FastType.complete,
    ),
    prayerFocus: m['prayerFocus'] ?? '',
    completed: (m['completed'] ?? 0) == 1,
  );

  /// Total days of the fast (inclusive).
  int get totalDays {
    final s = DateTime.tryParse(startDate);
    final e = DateTime.tryParse(endDate);
    if (s == null || e == null) return 1;
    return e.difference(s).inDays + 1;
  }

  /// Current day number (1-based). Returns totalDays if past end.
  int currentDay([DateTime? now]) {
    final s = DateTime.tryParse(startDate);
    if (s == null) return 1;
    final today = now ?? DateTime.now();
    final day = DateTime(today.year, today.month, today.day)
        .difference(DateTime(s.year, s.month, s.day))
        .inDays + 1;
    return day.clamp(1, totalDays);
  }

  /// Whether this fast is currently active (today falls within range and not completed).
  bool get isActive {
    if (completed) return false;
    final s = DateTime.tryParse(startDate);
    final e = DateTime.tryParse(endDate);
    if (s == null || e == null) return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return !todayOnly.isBefore(DateTime(s.year, s.month, s.day)) &&
           !todayOnly.isAfter(DateTime(e.year, e.month, e.day));
  }

  /// Localized type label key.
  String get typeLabel {
    switch (type) {
      case FastType.complete: return 'fastingTypeComplete';
      case FastType.partial: return 'fastingTypePartial';
      case FastType.esther: return 'fastingTypeEsther';
    }
  }
}
