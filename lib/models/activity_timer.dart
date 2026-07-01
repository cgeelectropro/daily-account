/// Represents a trackable spiritual activity with timer support.
enum ActivityType {
  bibleReading,
  literature,
  ddeg,
  prayerAlone,
  prayerOthers,
  evangelism,
  fasting,
  discipleship,
  church,
  proclamation,
}

/// A key that identifies either a built-in [ActivityType] or a custom activity
/// by its [customId]. Used as the map key in [TimerService].
class TimerKey {
  final ActivityType? builtIn;
  final String? customId;

  const TimerKey.builtIn(ActivityType type) : builtIn = type, customId = null;
  const TimerKey.custom(String id) : customId = id, builtIn = null;

  bool get isBuiltIn => builtIn != null;
  bool get isCustom => customId != null;

  /// Stable string for serialization.
  String get serialKey => isBuiltIn ? 'b:${builtIn!.index}' : 'c:$customId';

  factory TimerKey.fromSerialKey(String key) {
    if (key.startsWith('b:')) {
      final idx = int.parse(key.substring(2));
      return TimerKey.builtIn(ActivityType.values[idx]);
    }
    return TimerKey.custom(key.substring(2));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimerKey &&
          builtIn == other.builtIn &&
          customId == other.customId;

  @override
  int get hashCode => builtIn.hashCode ^ customId.hashCode;

  @override
  String toString() => isBuiltIn ? 'TimerKey(${builtIn!.name})' : 'TimerKey(custom:$customId)';
}

/// Maps an ActivityType to the DailyLog duration field it should auto-fill.
extension ActivityTypeMapping on ActivityType {
  /// The DailyLog field key this timer should write to.
  String? get logDurationField {
    switch (this) {
      case ActivityType.bibleReading:
        return 'bibleDuration';
      case ActivityType.literature:
        return 'literatureDuration';
      case ActivityType.ddeg:
        return 'ddegTime';
      case ActivityType.prayerAlone:
        return 'prayerAloneDuration';
      case ActivityType.prayerOthers:
        return 'prayerOthersDuration';
      case ActivityType.evangelism:
        return 'evangelismDuration';
      case ActivityType.fasting:
        return 'fastingDuration';
      case ActivityType.discipleship:
        return 'discipleshipDuration';
      case ActivityType.church:
        return 'churchDuration';
      case ActivityType.proclamation:
        return 'proclamationDuration';
    }
  }

  /// Emoji icon for the tile.
  String get icon {
    switch (this) {
      case ActivityType.bibleReading:
        return '\uD83D\uDCD6';
      case ActivityType.literature:
        return '\uD83D\uDCDA';
      case ActivityType.ddeg:
        return '\uD83D\uDD25';
      case ActivityType.prayerAlone:
        return '\uD83D\uDE4F';
      case ActivityType.prayerOthers:
        return '\uD83E\uDD1D';
      case ActivityType.evangelism:
        return '\uD83D\uDCE2';
      case ActivityType.fasting:
        return '\uD83C\uDF7D\uFE0F';
      case ActivityType.discipleship:
        return '\uD83D\uDC65';
      case ActivityType.church:
        return '\u26EA';
      case ActivityType.proclamation:
        return '\uD83D\uDCE3';
    }
  }

  /// Short code for the tile label (localised labels handled elsewhere).
  String get shortCode {
    switch (this) {
      case ActivityType.bibleReading:
        return 'LB';
      case ActivityType.literature:
        return 'Lit';
      case ActivityType.ddeg:
        return 'RDQD';
      case ActivityType.prayerAlone:
        return 'PS';
      case ActivityType.prayerOthers:
        return 'PA';
      case ActivityType.evangelism:
        return 'Ev';
      case ActivityType.fasting:
        return 'Je';
      case ActivityType.discipleship:
        return 'Dis';
      case ActivityType.church:
        return 'Eg';
      case ActivityType.proclamation:
        return 'Pr';
    }
  }
}

/// A single timer session for one activity on a specific date.
class TimerSession {
  final TimerKey key;
  final String dateKey; // 'yyyy-MM-dd'
  Duration elapsed;
  DateTime? startedAt; // non-null means running
  bool paused;

  /// Extra fields entered before starting (e.g. Bible reference, prayer notes).
  /// Keys match DailyLog field names.
  Map<String, String> fields;

  /// Convenience: the built-in activity type (null for custom).
  ActivityType? get activity => key.builtIn;

  TimerSession({
    required this.key,
    required this.dateKey,
    this.elapsed = Duration.zero,
    this.startedAt,
    this.paused = false,
    Map<String, String>? fields,
  }) : fields = fields ?? {};

  bool get isRunning => startedAt != null && !paused;
  bool get isStopped => startedAt == null && elapsed == Duration.zero;

  /// Total elapsed including current running segment.
  Duration get currentElapsed {
    if (startedAt != null && !paused) {
      return elapsed + DateTime.now().difference(startedAt!);
    }
    return elapsed;
  }

  /// Formatted as "Xh Ym" or "Xm Ys".
  String get formattedDuration {
    final d = currentElapsed;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  /// Formatted for the DailyLog field (e.g. "45 minutes", "1h 30m").
  String get logDurationString {
    final d = currentElapsed;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}min';
    if (h > 0) return '${h}h';
    if (m > 0) return '${m} minutes';
    return '${d.inSeconds}s';
  }

  /// For display as HH:MM:SS on the active timer.
  String get stopwatchDisplay {
    final d = currentElapsed;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() => {
        'timerKey': key.serialKey,
        'dateKey': dateKey,
        'elapsedMs': elapsed.inMilliseconds,
        'startedAt': startedAt?.toIso8601String(),
        'paused': paused ? 1 : 0,
        'fields': fields,
      };

  factory TimerSession.fromMap(Map<String, dynamic> m) {
    // Support legacy format (activity index) and new format (timerKey)
    TimerKey timerKey;
    if (m.containsKey('timerKey')) {
      timerKey = TimerKey.fromSerialKey(m['timerKey'] as String);
    } else {
      timerKey = TimerKey.builtIn(ActivityType.values[m['activity'] as int]);
    }
    return TimerSession(
      key: timerKey,
      dateKey: m['dateKey'] as String,
      elapsed: Duration(milliseconds: m['elapsedMs'] as int),
      startedAt: m['startedAt'] != null
          ? DateTime.parse(m['startedAt'] as String)
          : null,
      paused: (m['paused'] as int) == 1,
      fields: m['fields'] != null
          ? Map<String, String>.from(m['fields'] as Map)
          : {},
    );
  }
}
