import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_timer.dart';
import '../models/daily_log.dart';
import 'storage_service.dart';

/// Manages activity stopwatch timers.
///
/// - Only one timer can be running at a time (auto-pauses the previous).
/// - State is persisted to SharedPreferences so timers survive app restarts.
/// - When a timer is stopped, its duration is written to today's DailyLog.
class TimerService extends ChangeNotifier {
  static final TimerService instance = TimerService._();
  TimerService._();

  static const _storageKey = 'timer_sessions';

  final Map<ActivityType, TimerSession> _sessions = {};
  Timer? _ticker;

  Map<ActivityType, TimerSession> get sessions => Map.unmodifiable(_sessions);

  /// The currently running activity (if any).
  ActivityType? get activeActivity {
    for (final entry in _sessions.entries) {
      if (entry.value.isRunning) return entry.key;
    }
    return null;
  }

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Load persisted state. Call once at app startup.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          final session = TimerSession.fromMap(Map<String, dynamic>.from(item));
          // Only restore sessions from today
          if (session.dateKey == _todayKey) {
            _sessions[session.activity] = session;
          }
        }
      } catch (_) {
        // Corrupted data — start fresh
      }
    }
    _ensureTicker();
    notifyListeners();
  }

  /// Start or resume a timer for [activity].
  /// [fields] are optional extra DailyLog fields to write when stopped.
  void start(ActivityType activity, {Map<String, String>? fields}) {
    // Pause any currently running timer first
    final running = activeActivity;
    if (running != null && running != activity) {
      pause(running);
    }

    var session = _sessions[activity];
    if (session == null) {
      session = TimerSession(
        activity: activity,
        dateKey: _todayKey,
        fields: fields,
      );
      _sessions[activity] = session;
    } else if (fields != null) {
      // Merge new fields into existing session
      session.fields.addAll(fields);
    }

    session.startedAt = DateTime.now();
    session.paused = false;
    _ensureTicker();
    _persist();
    notifyListeners();
  }

  /// Pause a running timer.
  void pause(ActivityType activity) {
    final session = _sessions[activity];
    if (session == null || !session.isRunning) return;

    session.elapsed += DateTime.now().difference(session.startedAt!);
    session.startedAt = null;
    session.paused = true;
    _persist();
    notifyListeners();
  }

  /// Stop a timer and write the duration to the DailyLog.
  Future<void> stop(ActivityType activity) async {
    final session = _sessions[activity];
    if (session == null) return;

    // Finalise elapsed
    if (session.isRunning) {
      session.elapsed += DateTime.now().difference(session.startedAt!);
      session.startedAt = null;
    }

    // Write to DailyLog
    await _writeToDailyLog(session);

    _sessions.remove(activity);
    _persist();
    notifyListeners();
  }

  /// Stop all timers (e.g. end of day).
  Future<void> stopAll() async {
    final activities = List<ActivityType>.from(_sessions.keys);
    for (final a in activities) {
      await stop(a);
    }
  }

  /// Get the session for a given activity (may be null).
  TimerSession? getSession(ActivityType activity) => _sessions[activity];

  /// Get today's total tracked time across all activities.
  Duration get todayTotal {
    var total = Duration.zero;
    for (final s in _sessions.values) {
      total += s.currentElapsed;
    }
    return total;
  }

  // ── Internal ──────────────────────────────────────────────

  void _ensureTicker() {
    if (activeActivity != null && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        notifyListeners();
      });
    } else if (activeActivity == null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _sessions.values.map((s) => s.toMap()).toList();
    await prefs.setString(_storageKey, jsonEncode(list));
  }

  Future<void> _writeToDailyLog(TimerSession session) async {
    final storage = StorageService.instance;
    final log = await storage.getLog(session.dateKey) ??
        DailyLog(dateKey: session.dateKey);

    final durationStr = session.logDurationString;

    // Write duration field if the activity has one
    final field = session.activity.logDurationField;
    if (field != null) {
      switch (field) {
        case 'ddegTime':
          log.ddegTime = durationStr;
        case 'prayerAloneDuration':
          log.prayerAloneDuration = durationStr;
        case 'prayerOthersDuration':
          log.prayerOthersDuration = durationStr;
        case 'fastingDuration':
          log.fastingDuration = durationStr;
        case 'discipleshipDuration':
          log.discipleshipDuration = durationStr;
      }
    }

    // Write all extra fields captured before start
    for (final entry in session.fields.entries) {
      _setLogField(log, entry.key, entry.value);
    }

    await storage.saveLog(log);
  }

  /// Set a DailyLog field by its string key name.
  void _setLogField(DailyLog log, String key, String value) {
    if (value.isEmpty) return;
    switch (key) {
      case 'bibleReference':
        log.bibleReference = value;
      case 'bibleChapters':
        log.bibleChapters = value;
      case 'ddegScripture':
        log.ddegScripture = value;
      case 'ddegNotes':
        log.ddegNotes = value;
      case 'prayerAloneNotes':
        log.prayerAloneNotes = value;
      case 'prayerOthersContext':
        log.prayerOthersContext = value;
      case 'evangelismContacts':
        log.evangelismContacts = value;
      case 'evangelismOutcome':
        log.evangelismOutcome = value;
      case 'evangelismNotes':
        log.evangelismNotes = value;
      case 'fastingType':
        log.fastingType = value;
      case 'fastingPrayerFocus':
        log.fastingPrayerFocus = value;
      case 'discipleshipWho':
        log.discipleshipWho = value;
      case 'discipleshipTopic':
        log.discipleshipTopic = value;
      case 'churchType':
        log.churchType = value;
      case 'churchNotes':
        log.churchNotes = value;
      case 'proclamationCount':
        log.proclamationCount = value;
      case 'proclamationDuration':
        log.proclamationDuration = value;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
