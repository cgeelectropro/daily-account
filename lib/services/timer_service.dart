import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_timer.dart';
import '../models/daily_log.dart';
import 'background_timer_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

/// Manages activity stopwatch timers.
///
/// - Only one timer can be running at a time (auto-pauses the previous).
/// - State is persisted to SharedPreferences so timers survive app restarts.
/// - When a timer is stopped, its duration is written to today's DailyLog.
/// - On Android, a foreground service keeps the timer alive in the background.
/// - An optional floating overlay shows the timer over other apps.
class TimerService extends ChangeNotifier {
  static final TimerService instance = TimerService._();
  TimerService._();

  static const _storageKey = 'timer_sessions';

  final Map<TimerKey, TimerSession> _sessions = {};
  Timer? _ticker;

  Map<TimerKey, TimerSession> get sessions => Map.unmodifiable(_sessions);

  /// The currently running timer key (if any).
  TimerKey? get activeKey {
    for (final entry in _sessions.entries) {
      if (entry.value.isRunning) return entry.key;
    }
    return null;
  }

  /// The currently running built-in activity (if any). Legacy convenience.
  ActivityType? get activeActivity => activeKey?.builtIn;

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Label resolver — set from the UI layer so we can show localized
  /// activity names in the stopwatch notification.
  String Function(TimerKey)? timerLabelResolver;

  /// Icon resolver for custom activities in notifications.
  String Function(TimerKey)? timerIconResolver;

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
            _sessions[session.key] = session;
          }
        }
      } catch (_) {
        // Corrupted data — start fresh
      }
    }

    // Listen for notification action buttons (pause/stop from shade)
    NotificationService.instance.onTimerAction = _handleNotifAction;

    _ensureTicker();
    // Restore stopwatch notification + foreground service if a timer was running
    _updateStopwatchNotification();
    final running = activeKey;
    if (running != null) {
      final session = _sessions[running]!;
      _startForegroundService(running, session);
      _showOverlay(running, session);
    }
    notifyListeners();
  }

  void _handleNotifAction(String action) {
    final running = activeKey;
    if (running == null) return;
    switch (action) {
      case 'timer_pause':
        pause(running);
      case 'timer_stop':
        stop(running);
    }
  }

  /// Start or resume a timer.
  /// [fields] are optional extra DailyLog fields to write when stopped.
  void start(TimerKey key, {Map<String, String>? fields}) {
    // Pause any currently running timer first
    final running = activeKey;
    if (running != null && running != key) {
      pause(running);
    }

    var session = _sessions[key];
    if (session == null) {
      session = TimerSession(
        key: key,
        dateKey: _todayKey,
        fields: fields,
      );
      _sessions[key] = session;
    } else if (fields != null) {
      // Merge new fields into existing session
      session.fields.addAll(fields);
    }

    session.startedAt = DateTime.now();
    session.paused = false;
    _ensureTicker();
    _persist();
    _updateStopwatchNotification();
    _startForegroundService(key, session);
    _showOverlay(key, session);
    notifyListeners();
  }

  /// Convenience: start a built-in activity timer.
  void startBuiltIn(ActivityType activity, {Map<String, String>? fields}) {
    start(TimerKey.builtIn(activity), fields: fields);
  }

  /// Pause a running timer.
  void pause(TimerKey key) {
    final session = _sessions[key];
    if (session == null || !session.isRunning) return;

    session.elapsed += DateTime.now().difference(session.startedAt!);
    session.startedAt = null;
    session.paused = true;
    _persist();
    _updateStopwatchNotification();
    _pauseForegroundService(key, session);
    _updateOverlay(key, session, paused: true);
    notifyListeners();
  }

  /// Stop a timer and write the duration to the DailyLog.
  Future<void> stop(TimerKey key) async {
    final session = _sessions[key];
    if (session == null) return;

    // Finalise elapsed
    if (session.isRunning) {
      session.elapsed += DateTime.now().difference(session.startedAt!);
      session.startedAt = null;
    }

    // Write to DailyLog
    await _writeToDailyLog(session);

    _sessions.remove(key);
    _persist();
    _updateStopwatchNotification();
    _stopForegroundService();
    _closeOverlay();
    notifyListeners();
  }

  /// Stop all timers (e.g. end of day).
  Future<void> stopAll() async {
    final keys = List<TimerKey>.from(_sessions.keys);
    for (final k in keys) {
      await stop(k);
    }
  }

  /// Get the session for a given key (may be null).
  TimerSession? getSession(TimerKey key) => _sessions[key];

  /// Convenience: get session for a built-in activity.
  TimerSession? getBuiltInSession(ActivityType activity) =>
      _sessions[TimerKey.builtIn(activity)];

  /// Get today's total tracked time across all activities.
  Duration get todayTotal {
    var total = Duration.zero;
    for (final s in _sessions.values) {
      total += s.currentElapsed;
    }
    return total;
  }

  // ── Foreground service helpers ─────────────────────────────

  String _resolveLabel(TimerKey key) =>
      timerLabelResolver?.call(key) ??
      (key.isBuiltIn ? key.builtIn!.shortCode : '');

  String _resolveIcon(TimerKey key) =>
      timerIconResolver?.call(key) ??
      (key.isBuiltIn ? key.builtIn!.icon : '\u2728');

  void _startForegroundService(TimerKey key, TimerSession session) {
    if (!Platform.isAndroid) return;
    BackgroundTimerService.instance.startForegroundTimer(
      label: _resolveLabel(key),
      icon: _resolveIcon(key),
      elapsedMs: session.currentElapsed.inMilliseconds,
    );
  }

  void _pauseForegroundService(TimerKey key, TimerSession session) {
    if (!Platform.isAndroid) return;
    BackgroundTimerService.instance.pauseForegroundTimer(
      elapsedMs: session.currentElapsed.inMilliseconds,
      label: _resolveLabel(key),
    );
  }

  void _stopForegroundService() {
    if (!Platform.isAndroid) return;
    BackgroundTimerService.instance.stopForegroundTimer();
  }

  // ── Overlay helpers ───────────────────────────────────────

  bool _overlayActive = false;

  Future<void> _showOverlay(TimerKey key, TimerSession session) async {
    if (!Platform.isAndroid) return;
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) return; // Don't show if permission not granted yet

    if (!_overlayActive) {
      await FlutterOverlayWindow.showOverlay(
        height: 80,
        width: 80,
        alignment: OverlayAlignment.topRight,
        enableDrag: true,
        positionGravity: PositionGravity.auto,
        overlayTitle: 'Daily Account Timer',
        overlayContent: 'Timer running',
        flag: OverlayFlag.defaultFlag,
      );
      _overlayActive = true;
    }

    _sendOverlayData(key, session, paused: false);
  }

  void _updateOverlay(TimerKey key, TimerSession session, {bool paused = false}) {
    if (!_overlayActive) return;
    _sendOverlayData(key, session, paused: paused);
  }

  void _sendOverlayData(TimerKey key, TimerSession session, {required bool paused}) {
    FlutterOverlayWindow.shareData({
      'elapsed': session.stopwatchDisplay,
      'icon': _resolveIcon(key),
      'label': _resolveLabel(key),
      'paused': paused,
    });
  }

  void _closeOverlay() {
    if (!_overlayActive) return;
    FlutterOverlayWindow.shareData({'action': 'close'});
    _overlayActive = false;
  }

  // ── Internal ──────────────────────────────────────────────

  void _ensureTicker() {
    if (activeKey != null && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        // Push live elapsed time to the overlay (it doesn't have a native
        // chronometer). The Android notification is NOT re-posted here —
        // its chronometer counts natively even when the isolate sleeps.
        final key = activeKey;
        if (key != null && _overlayActive) {
          final session = _sessions[key];
          if (session != null) _sendOverlayData(key, session, paused: false);
        }
        notifyListeners();
      });
    } else if (activeKey == null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  /// Show, update, or cancel the ongoing stopwatch notification.
  void _updateStopwatchNotification() {
    final running = activeKey;

    if (running != null) {
      final session = _sessions[running]!;
      final label = timerLabelResolver?.call(running) ??
          (running.isBuiltIn ? running.builtIn!.shortCode : '');
      final icon = timerIconResolver?.call(running) ??
          (running.isBuiltIn ? running.builtIn!.icon : '\u2728');
      NotificationService.instance.showStopwatchNotification(
        activityLabel: label,
        elapsed: session.stopwatchDisplay,
        activityIcon: icon,
        elapsedMs: session.currentElapsed.inMilliseconds,
      );
      return;
    }

    // Check if any timer is paused
    for (final entry in _sessions.entries) {
      if (entry.value.paused) {
        final label = timerLabelResolver?.call(entry.key) ??
            (entry.key.isBuiltIn ? entry.key.builtIn!.shortCode : '');
        final icon = timerIconResolver?.call(entry.key) ??
            (entry.key.isBuiltIn ? entry.key.builtIn!.icon : '\u2728');
        NotificationService.instance.showStopwatchNotification(
          activityLabel: label,
          elapsed: entry.value.formattedDuration,
          activityIcon: icon,
          isPaused: true,
        );
        return;
      }
    }

    // No running or paused timers — cancel notification
    NotificationService.instance.cancelStopwatchNotification();
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

    if (session.key.isBuiltIn) {
      // Accumulate duration field (add to existing) if the activity has one
      final field = session.key.builtIn!.logDurationField;
      if (field != null) {
        switch (field) {
          case 'ddegTime':
            log.ddegTime = _accumulateDuration(log.ddegTime, durationStr);
          case 'prayerAloneDuration':
            log.prayerAloneDuration =
                _accumulateDuration(log.prayerAloneDuration, durationStr);
          case 'prayerOthersDuration':
            log.prayerOthersDuration =
                _accumulateDuration(log.prayerOthersDuration, durationStr);
          case 'fastingDuration':
            log.fastingDuration =
                _accumulateDuration(log.fastingDuration, durationStr);
          case 'discipleshipDuration':
            log.discipleshipDuration =
                _accumulateDuration(log.discipleshipDuration, durationStr);
          case 'proclamationDuration':
            log.proclamationDuration =
                _accumulateDuration(log.proclamationDuration, durationStr);
        }
      }

      // Merge extra fields captured before start (accumulate, don't overwrite)
      for (final entry in session.fields.entries) {
        _mergeLogField(log, entry.key, entry.value);
      }
    } else {
      // Custom activity — write to "other" field with duration
      final name = session.fields['_customName'] ?? '';
      final notes = session.fields.entries
          .where((e) => !e.key.startsWith('_') && e.value.isNotEmpty)
          .map((e) => '${e.key}: ${e.value}')
          .join('; ');
      final parts = <String>[
        if (name.isNotEmpty) name,
        if (notes.isNotEmpty) notes,
        durationStr,
      ];
      log.other = _appendText(log.other, parts.join(' — '));
    }

    await storage.saveLog(log);
  }

  /// Parse a human-readable duration string into total minutes.
  int _parseDurationMinutes(String s) {
    if (s.isEmpty) return 0;
    final cleaned = s.trim().toLowerCase();

    final hm = RegExp(r'(\d+)\s*h\w*\s*(\d+)?\s*m?\w*');
    final hmMatch = hm.firstMatch(cleaned);
    if (hmMatch != null) {
      final h = int.tryParse(hmMatch.group(1)!) ?? 0;
      final m = int.tryParse(hmMatch.group(2) ?? '0') ?? 0;
      return h * 60 + m;
    }

    final mOnly = RegExp(r'(\d+)\s*m(?:in(?:ute)?s?)?$');
    final mMatch = mOnly.firstMatch(cleaned);
    if (mMatch != null) return int.tryParse(mMatch.group(1)!) ?? 0;

    final hOnly = RegExp(r'(\d+)\s*h(?:ours?)?$');
    final hMatch = hOnly.firstMatch(cleaned);
    if (hMatch != null) return (int.tryParse(hMatch.group(1)!) ?? 0) * 60;

    final plain = int.tryParse(cleaned);
    if (plain != null) return plain;

    return 0;
  }

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return '';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}min';
    if (h > 0) return '${h}h';
    return '$m minutes';
  }

  String _accumulateDuration(String existing, String added) {
    final existingMin = _parseDurationMinutes(existing);
    final addedMin = _parseDurationMinutes(added);
    final total = existingMin + addedMin;
    return _formatMinutes(total);
  }

  String _appendText(String existing, String added) {
    if (existing.isEmpty) return added;
    if (added.isEmpty) return existing;
    if (existing == added) return existing;
    return '$existing; $added';
  }

  String _addNumeric(String existing, String added) {
    final a = int.tryParse(existing) ?? 0;
    final b = int.tryParse(added) ?? 0;
    final sum = a + b;
    return sum > 0 ? '$sum' : (added.isNotEmpty ? added : existing);
  }

  void _mergeLogField(DailyLog log, String key, String value) {
    if (value.isEmpty) return;
    switch (key) {
      case 'bibleReference':
        log.bibleReference = _appendText(log.bibleReference, value);
      case 'bibleChapters':
        log.bibleChapters = _addNumeric(log.bibleChapters, value);
      case 'ddegScripture':
        log.ddegScripture = _appendText(log.ddegScripture, value);
      case 'ddegNotes':
        log.ddegNotes = _appendText(log.ddegNotes, value);
      case 'prayerAloneNotes':
        log.prayerAloneNotes = _appendText(log.prayerAloneNotes, value);
      case 'prayerOthersContext':
        log.prayerOthersContext = _appendText(log.prayerOthersContext, value);
      case 'evangelismContacts':
        log.evangelismContacts = _addNumeric(log.evangelismContacts, value);
      case 'evangelismOutcome':
        log.evangelismOutcome = _appendText(log.evangelismOutcome, value);
      case 'evangelismNotes':
        log.evangelismNotes = _appendText(log.evangelismNotes, value);
      case 'evangelismNewBelievers':
        log.evangelismNewBelievers = _addNumeric(log.evangelismNewBelievers, value);
      case 'evangelismBeingDiscipled':
        log.evangelismBeingDiscipled = _addNumeric(log.evangelismBeingDiscipled, value);
      case 'evangelismFollowUpNotes':
        log.evangelismFollowUpNotes = _appendText(log.evangelismFollowUpNotes, value);
      case 'fastingType':
        log.fastingType = _appendText(log.fastingType, value);
      case 'fastingPrayerFocus':
        log.fastingPrayerFocus = _appendText(log.fastingPrayerFocus, value);
      case 'discipleshipWho':
        log.discipleshipWho = _appendText(log.discipleshipWho, value);
      case 'discipleshipTopic':
        log.discipleshipTopic = _appendText(log.discipleshipTopic, value);
      case 'churchType':
        log.churchType = _appendText(log.churchType, value);
      case 'churchNotes':
        log.churchNotes = _appendText(log.churchNotes, value);
      case 'proclamationCount':
        log.proclamationCount = _addNumeric(log.proclamationCount, value);
      case 'proclamationDuration':
        log.proclamationDuration =
            _accumulateDuration(log.proclamationDuration, value);
      case 'other':
        log.other = _appendText(log.other, value);
      case 'literatureTitle':
        break;
      case 'literatureAmount':
        break;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
