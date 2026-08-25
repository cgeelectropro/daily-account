import 'dart:async';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'storage_service.dart';
import 'report_cadence_service.dart';
import 'goal_progress_service.dart';
import '../models/goal.dart';

/// Top-level handler for notification actions when the app is in the
/// background or terminated. Must be top-level (not an instance method)
/// because it runs in a separate isolate.
///
/// Timer actions are stored in SharedPreferences so the main isolate can
/// pick them up when the app resumes. Snooze works directly since it only
/// needs to schedule a new notification.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  // Timer actions open the app (showsUserInterface: true) — handled in foreground.
  // Snooze must work even when the app is terminated — schedule directly.
  if (response.actionId == 'snooze_15') {
    _backgroundSnooze();
  }
}

/// Schedule a snooze notification from the background isolate.
/// Uses a fresh plugin instance since the main isolate isn't running.
Future<void> _backgroundSnooze() async {
  try {
    tzdata.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    final plugin = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: android));

    final snoozeTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 15));
    await plugin.zonedSchedule(
      99, // snooze ID
      '\u23F0 Daily Account',
      'Snooze is over! Time to log your walk with God.',
      snoozeTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_account_alarm_sound_happy_bells',
          'Daily Account Reminders',
          channelDescription: 'Alarm-style reminders to record your walk with God',
          importance: Importance.max,
          priority: Priority.max,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  } catch (_) {
    // Best-effort — if it fails in background, next foreground launch re-schedules
  }
}

/// Aggressive, alarm-style notification system for Daily Account.
///
/// The goal: make it impossible to forget your daily spiritual disciplines.
///
/// Notification IDs:
///   1  = Daily log reminder (primary)
///   2  = Report day send reminder (primary)
///   3  = Report day auto-send reminder
///   11 = Daily follow-up #1 (30 min after primary)
///   12 = Daily follow-up #2 (60 min after primary)
///   13 = Daily follow-up #3 (90 min after primary)
///   21 = Report day follow-up #1
///   22 = Report day follow-up #2
///   30 = Mid-week nudge (weekly cadence only, 3 days before report day)
///   40 = Week-so-far summary (weekly cadence only, evening before report day)
///   50 = Test notification
///   99 = Snooze notification
///  110–120 = Per-discipline reminders
///  130 = Goal completed
///  140-142 = Goal pace-check reminders
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Completer<void>? _initCompleter;

  // ── Notification channels ──────────────────────────────────

  /// Snooze notification ID
  static const _snoozeId = 99;

  /// Test notification ID (must not collide with _disciplineBaseId range 110–120)
  static const _testId = 50;

  /// Available notification sounds. Keys are the raw resource file names
  /// (without extension). Users pick from these in Settings.
  static const notificationSounds = <String, String>{
    'sound_bell_notification': 'Bell Notification',
    'sound_happy_bells': 'Happy Bells',
    'sound_happy_alert': 'Happy Alert',
    'sound_uplifting_bells': 'Uplifting Bells',
    'sound_melodic_bell': 'Melodic Bell',
    'sound_service_bell': 'Service Bell',
    'sound_bright_bells': 'Bright Bells',
    'sound_clean_ding': 'Clean Ding',
  };

  /// Currently selected sound resource name. Loaded from settings.
  String _selectedSound = 'sound_happy_bells';

  /// Get the current sound selection key.
  String get selectedSound => _selectedSound;

  /// Set the notification sound and persist the choice.
  Future<void> setNotificationSound(String soundKey) async {
    _selectedSound = soundKey;
    await StorageService.instance.setSetting('notifSound', soundKey);
    // Recreate the channel with the new sound — requires a new channel ID
    // because Android caches channel settings permanently.
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          'daily_account_alarm_$soundKey',
          'Daily Account Reminders',
          description: 'Alarm-style reminders to record your walk with God',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: const Color(0xFFD4AF64),
          sound: RawResourceAndroidNotificationSound(soundKey),
        ),
      );
    }
  }

  /// Build alarm notification details using the user's selected sound.
  NotificationDetails get _alarmDetails {
    final channelId = 'daily_account_alarm_$_selectedSound';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Daily Account Reminders',
        channelDescription: 'Alarm-style reminders to record your walk with God',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_selectedSound),
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFFD4AF64), // gold
        ledOnMs: 1000,
        ledOffMs: 500,
        fullScreenIntent: false,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        autoCancel: true,
        ongoing: false,
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'snooze_15',
            'Snooze 15 min',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  /// Stopwatch notification ID — ongoing while a timer runs.
  static const stopwatchNotifId = 200;

  /// Per-discipline reminder IDs (110–120).
  static const _disciplineBaseId = 110;

  /// Week-so-far summary notification ID.
  static const _saturdaySummaryId = 40;

  /// Streak-at-risk notification ID.
  static const _streakRiskId = 60;

  /// Milestone celebration notification ID.
  static const _milestoneId = 61;

  // ── Initialization ────────────────────────────────────────

  /// Whether notification permission was granted.
  bool _notifPermissionGranted = false;

  /// Whether exact alarm permission was granted.
  bool _exactAlarmGranted = false;

  /// Whether battery optimization exemption was granted.
  bool _batteryOptExempt = false;

  /// Diagnostic info for the settings screen.
  Map<String, bool> get diagnostics => {
    'notificationPermission': _notifPermissionGranted,
    'exactAlarmPermission': _exactAlarmGranted,
    'batteryOptExempt': _batteryOptExempt,
    'initialized': _ready,
  };

  Future<void> init() async {
    if (_ready) return;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    try {
      await _doInit();
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<void> _doInit() async {
    tzdata.initializeTimeZones();

    // Use the device's actual timezone instead of hardcoding
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      // Fallback for Cameroon users
      tz.setLocalLocation(tz.getLocation('Africa/Lagos'));
    }

    // Load user's sound preference before creating channels
    _selectedSound = await StorageService.instance
        .getSetting('notifSound', fallback: 'sound_happy_bells');

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    // Android-specific setup
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      // ── 1. Request notification permission (Android 13+) ──
      final notifGranted = await androidImpl.requestNotificationsPermission();
      _notifPermissionGranted = notifGranted == true;
      if (!_notifPermissionGranted) {
        debugPrint('[NotificationService] Notification permission DENIED');
        _ready = true;
        return;
      }

      // ── 2. Create notification channels ──
      // Each sound choice gets its own channel because Android caches
      // channel settings permanently — changing code has no effect.
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          'daily_account_alarm_$_selectedSound',
          'Daily Account Reminders',
          description: 'Alarm-style reminders to record your walk with God',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: const Color(0xFFD4AF64),
          sound: RawResourceAndroidNotificationSound(_selectedSound),
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          'daily_account_stopwatch',
          'Activity Timer',
          description: 'Shows while a spiritual activity timer is running',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ),
      );
      // v2 channel with default importance so action buttons are visible.
      // Android caches channel settings permanently, so a new channel ID is
      // required to change importance on existing installs.
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          'daily_account_stopwatch_v2',
          'Activity Timer',
          description: 'Shows while a spiritual activity timer is running',
          importance: Importance.defaultImportance,
          playSound: false,
          enableVibration: false,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          'daily_account_discipline_v2',
          'Discipline Reminders',
          description: 'Gentle reminders for specific disciplines',
          importance: Importance.defaultImportance,
          playSound: true,
          enableVibration: true,
        ),
      );

      // ── 3. Request exact alarm permission (Android 12+) ──
      final exactResult = await androidImpl.requestExactAlarmsPermission();
      _exactAlarmGranted = exactResult == true;
      if (!_exactAlarmGranted) {
        debugPrint('[NotificationService] Exact alarm permission DENIED — will use inexact');
      }

      // ── 4. Check battery optimization status ──
      _batteryOptExempt = await _checkBatteryOptimization();
    }

    _ready = true;

    // Schedule defaults on first launch (must be awaited to prevent
    // race conditions with callers that schedule immediately after init)
    await rescheduleAll();
  }

  /// Play a preview of a notification sound (for the settings sound picker).
  Future<void> previewSound(String soundKey) async {
    if (!_ready) return;
    // Create the channel for this sound so Android knows about it
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        AndroidNotificationChannel(
          'daily_account_alarm_$soundKey',
          'Daily Account Reminders',
          description: 'Alarm-style reminders to record your walk with God',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: const Color(0xFFD4AF64),
          sound: RawResourceAndroidNotificationSound(soundKey),
        ),
      );
    }
    await _plugin.show(
      _testId,
      '\uD83D\uDD14 ${notificationSounds[soundKey] ?? soundKey}',
      'This is how your reminders will sound.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_account_alarm_$soundKey',
          'Daily Account Reminders',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(soundKey),
        ),
      ),
    );
  }

  /// Re-check live OS permission/battery state.
  ///
  /// [requestExactAlarmsPermission] and the notification-permission request
  /// only report their result once, at the moment they're called — Android
  /// can revoke exact-alarm permission or battery-optimization exemption
  /// later (OEM battery managers, "remove permissions if unused", or the
  /// user changing it in system Settings) without ever notifying the app.
  /// Without this re-check, `diagnostics` shows a stale install-time
  /// snapshot that can read "healthy" while every scheduled alarm is
  /// silently being dropped by the OS.
  Future<void> _refreshDiagnostics() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;
    _notifPermissionGranted =
        await androidImpl.areNotificationsEnabled() ?? _notifPermissionGranted;
    _exactAlarmGranted =
        await androidImpl.canScheduleExactNotifications() ?? _exactAlarmGranted;
    _batteryOptExempt = await _checkBatteryOptimization();
  }

  /// Public wrapper so screens (e.g. Settings) can refresh the diagnostics
  /// panel against live OS state without paying for a full reschedule.
  Future<void> refreshDiagnostics() => _refreshDiagnostics();

  /// Re-schedule all reminders. Safe to call repeatedly.
  ///
  /// This is critical because Android can silently drop scheduled alarms
  /// after app updates, battery optimization, or reboots. Cheap to call
  /// and guarantees notifications stay alive.
  ///
  /// Called automatically on init(), and should also be called when the
  /// app returns to the foreground (AppLifecycleState.resumed).
  Future<void> rescheduleAll() async {
    // Reset diagnostic counters for this run
    _scheduledCount = 0;
    _failedCount = 0;
    await _refreshDiagnostics();

    final s = StorageService.instance;
    final enabled = await s.getSetting('notificationsEnabled', fallback: '');

    if (enabled.isEmpty) {
      // First launch — set defaults and schedule
      await scheduleDailyReminder(20, 0);
      await scheduleReportReminder(18, 0);
      await scheduleMidWeekNudge(18, 0);
      await scheduleSaturdaySummary(18, 0,
        title: 'Your week so far',
        body: 'Check your progress and finish strong tomorrow!',
      );
      await s.setSetting('notifs_initialized', 'true');
      await s.setSetting('notificationsEnabled', 'true');
      return;
    }

    if (enabled != 'true') return; // User disabled notifications

    // Re-schedule using saved preferences (runs every launch)
    final dh = int.tryParse(await s.getSetting('dailyHour', fallback: '20')) ?? 20;
    final dm = int.tryParse(await s.getSetting('dailyMin', fallback: '0')) ?? 0;
    final sh = int.tryParse(await s.getSetting('sundayHour', fallback: '18')) ?? 18;
    final sm = int.tryParse(await s.getSetting('sundayMin', fallback: '0')) ?? 0;
    final dailyFollowUps = int.tryParse(await s.getSetting('dailyFollowUps', fallback: '3')) ?? 3;
    final sundayFollowUps = int.tryParse(await s.getSetting('sundayFollowUps', fallback: '2')) ?? 2;

    // Read saved localized strings (saved by settings screen)
    final dailyTitle = await s.getSetting('notifDailyTitle', fallback: '');
    final dailyBody = await s.getSetting('notifDailyBody', fallback: '');
    final sundayTitle = await s.getSetting('notifSundayTitle', fallback: '');
    final sundayBody = await s.getSetting('notifSundayBody', fallback: '');

    await scheduleDailyReminder(dh, dm,
      followUpCount: dailyFollowUps,
      title: dailyTitle.isNotEmpty ? dailyTitle : null,
      body: dailyBody.isNotEmpty ? dailyBody : null,
    );
    await scheduleReportReminder(sh, sm,
      followUpCount: sundayFollowUps,
      title: sundayTitle.isNotEmpty ? sundayTitle : null,
      body: sundayBody.isNotEmpty ? sundayBody : null,
    );

    // Re-schedule auto-send if enabled
    final autoSend = await s.getSetting('autoSendEnabled', fallback: 'false');
    if (autoSend == 'true') {
      final ash = int.tryParse(await s.getSetting('autoSendHour', fallback: '19')) ?? 19;
      final asm = int.tryParse(await s.getSetting('autoSendMin', fallback: '0')) ?? 0;
      await scheduleAutoSendReminder(ash, asm,
        title: sundayTitle.isNotEmpty ? sundayTitle : null,
        body: sundayBody.isNotEmpty ? sundayBody : null,
      );
    }

    // Mid-week nudge (3 days before the report day, at 18:00; weekly cadence only)
    final midWeekTitle = await s.getSetting('notifMidWeekTitle', fallback: '');
    final midWeekBody = await s.getSetting('notifMidWeekBody', fallback: '');
    await scheduleMidWeekNudge(18, 0,
      title: midWeekTitle.isNotEmpty ? midWeekTitle : null,
      body: midWeekBody.isNotEmpty ? midWeekBody : null,
    );

    // Week-so-far summary (evening before the report day, at 18:00; weekly cadence only)
    final satTitle = await s.getSetting('notifSatTitle', fallback: 'Your week so far');
    final satBody = await s.getSetting('notifSatBody', fallback: 'Check your progress and finish strong tomorrow!');
    await scheduleSaturdaySummary(18, 0,
      title: satTitle,
      body: satBody,
    );

    // Re-schedule per-discipline reminders — use saved localized names
    for (int i = 0; i < 11; i++) {
      final raw = await s.getSetting('discReminder_$i', fallback: '');
      if (raw.isNotEmpty) {
        final parts = raw.split(':');
        if (parts.length == 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final savedName = await s.getSetting('discName_$i', fallback: '');
          final fallbackNames = ['Bible', 'Literature', 'DDEG', 'Prayer (alone)', 'Prayer (others)',
            'Evangelism', 'Fasting', 'Giving', 'Church', 'Discipleship', 'Proclamation'];
          await scheduleDisciplineReminder(i, h, m,
            savedName.isNotEmpty ? savedName : fallbackNames[i]);
        }
      }
    }

    // Re-schedule goal pace-check reminders (independently gated by their
    // own 'goalPaceRemindersEnabled' setting, checked inside the method).
    await scheduleGoalPaceChecks();
  }

  // ═════════════════════════════════════════════════════════════
  //  NOTIFICATION ACTION HANDLER (snooze)
  // ═════════════════════════════════════════════════════════════

  /// Callback for handling timer notification actions from outside.
  /// Set this from TimerService so notification actions can control the timer.
  void Function(String action)? onTimerAction;

  /// Callback for handling notification tap navigation.
  /// Set this from HomeShell so tapping a report notification navigates to the report tab.
  void Function(String payload)? onNotificationTap;

  void _onNotificationResponse(NotificationResponse response) {
    // Handle action button taps (snooze, timer controls)
    switch (response.actionId) {
      case 'snooze_15':
        _scheduleSnooze();
        return;
      case 'timer_pause':
      case 'timer_resume':
      case 'timer_stop':
      case 'timer_cancel':
        onTimerAction?.call(response.actionId!);
        return;
    }
    // Handle notification body tap — check payload for navigation
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      onNotificationTap?.call(payload);
    }
  }

  /// Schedule a one-shot reminder 15 minutes from now.
  Future<void> _scheduleSnooze() async {
    final snoozeTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 15));
    await _safeZonedSchedule(
      _snoozeId,
      '\u23F0 Daily Account',
      'Snooze is over! Time to log your walk with God.',
      snoozeTime,
      _alarmDetails,
      matchDateTimeComponents: null, // one-shot, not recurring
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  SAFE SCHEDULING — falls back to inexact if exact denied
  // ═════════════════════════════════════════════════════════════

  /// Count of successfully scheduled notifications (for diagnostics).
  int _scheduledCount = 0;
  int _failedCount = 0;

  /// Diagnostic: how many notifications were scheduled vs failed.
  (int scheduled, int failed) get scheduleStats => (_scheduledCount, _failedCount);

  /// Wraps zonedSchedule with automatic fallback from exact → inexact alarms.
  /// This prevents silent failures on Android 12+ when SCHEDULE_EXACT_ALARM
  /// permission is denied.
  Future<void> _safeZonedSchedule(
    int id,
    String title,
    String body,
    tz.TZDateTime scheduledDate,
    NotificationDetails details, {
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {
    try {
      // Try exact alarm first
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      _scheduledCount++;
      debugPrint('[NotificationService] Scheduled #$id (exact) at $scheduledDate');
    } catch (e) {
      debugPrint('[NotificationService] Exact alarm #$id failed: $e — trying inexact');
      // Exact alarm denied or failed — fall back to inexact
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: matchDateTimeComponents,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        _scheduledCount++;
        debugPrint('[NotificationService] Scheduled #$id (inexact) at $scheduledDate');
      } catch (e2) {
        _failedCount++;
        debugPrint('[NotificationService] FAILED to schedule #$id entirely: $e2');
      }
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  TEST NOTIFICATION — fire immediately to verify it works
  // ═════════════════════════════════════════════════════════════

  /// Fire a test notification immediately to verify the system works.
  /// Returns true if the notification was shown successfully.
  Future<bool> testNotification() async {
    await init();
    try {
      await _plugin.show(
        _testId,
        'Daily Account',
        'Notifications are working! Your reminders will fire on time.',
        _alarmDetails,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  DAILY LOG REMINDER (alarm-style + follow-ups)
  // ═════════════════════════════════════════════════════════════

  /// Schedule the primary daily reminder + follow-up reminders.
  ///
  /// Primary fires at [hour]:[minute].
  /// [followUpCount] controls how many follow-ups (0–3), default 3.
  /// Follow-ups fire at +30m, +60m, +90m with escalating messages.
  Future<void> scheduleDailyReminder(int hour, int minute, {String? title, String? body, int followUpCount = 3}) async {
    await init();

    final t = title ?? 'Daily Account';

    // Cancel all existing daily notifications
    for (final id in [1, 11, 12, 13]) {
      await _plugin.cancel(id);
    }

    // Primary reminder
    await _safeZonedSchedule(
      1,
      t,
      body ?? 'Have you recorded your walk with God today? Tap to log it.',
      _nextInstanceOfTime(hour, minute),
      _alarmDetails,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Follow-up #1 — 30 minutes later
    if (followUpCount >= 1) {
      final followUp1 = _addMinutesToTime(hour, minute, 30);
      await _safeZonedSchedule(
        11,
        '\u23F0 $t',
        body ?? 'You still haven\'t logged today. Your disciple maker is counting on you!',
        _nextInstanceOfTime(followUp1.hour, followUp1.minute),
        _alarmDetails,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    // Follow-up #2 — 60 minutes later
    if (followUpCount >= 2) {
      final followUp2 = _addMinutesToTime(hour, minute, 60);
      await _safeZonedSchedule(
        12,
        '\u26A0\uFE0F $t',
        'Don\'t break your streak! Open the app and log your spiritual walk now.',
        _nextInstanceOfTime(followUp2.hour, followUp2.minute),
        _alarmDetails,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    // Follow-up #3 — 90 minutes later (final)
    if (followUpCount >= 3) {
      final followUp3 = _addMinutesToTime(hour, minute, 90);
      await _safeZonedSchedule(
        13,
        '\uD83D\uDEA8 $t',
        'Last reminder! Your day\'s account is still empty. Tap to log before midnight.',
        _nextInstanceOfTime(followUp3.hour, followUp3.minute),
        _alarmDetails,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  REPORT SEND REMINDER (alarm-style + follow-ups)
  // ═════════════════════════════════════════════════════════════

  /// Schedule the report send reminder + follow-ups, on whichever day the
  /// user's configured cadence (weekly/monthly) lands.
  /// [followUpCount] controls how many follow-ups (0–2), default 2.
  Future<void> scheduleReportReminder(int hour, int minute, {String? title, String? body, int followUpCount = 2}) async {
    await init();

    final t = title ?? 'Time to Send Your Account';
    final cadence = await ReportCadenceService.instance.getCadence();
    final matchComponents = cadence == ReportCadence.weekly
        ? DateTimeComponents.dayOfWeekAndTime
        : null; // no monthly-recurrence equivalent — see plan notes; one-shot only

    // Cancel all existing report notifications
    for (final id in [2, 21, 22]) {
      await _plugin.cancel(id);
    }

    // Primary reminder
    await _safeZonedSchedule(
      2,
      t,
      body ?? 'It\'s time to send your account to your disciple maker.',
      await _nextReportOccurrence(hour, minute),
      _alarmDetails,
      matchDateTimeComponents: matchComponents,
      payload: 'navigate_report',
    );

    // Follow-up #1 — 30 minutes later
    if (followUpCount >= 1) {
      final followUp1 = _addMinutesToTime(hour, minute, 30);
      await _safeZonedSchedule(
        21,
        '\u23F0 $t',
        'Your disciple maker is waiting! Send your report now.',
        await _nextReportOccurrence(followUp1.hour, followUp1.minute),
        _alarmDetails,
        matchDateTimeComponents: matchComponents,
      );
    }

    // Follow-up #2 — 60 minutes later
    if (followUpCount >= 2) {
      final followUp2 = _addMinutesToTime(hour, minute, 60);
      await _safeZonedSchedule(
        22,
        '\u26A0\uFE0F $t',
        'Last chance today! Send your account before the day ends.',
        await _nextReportOccurrence(followUp2.hour, followUp2.minute),
        _alarmDetails,
        matchDateTimeComponents: matchComponents,
      );
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  AUTO-SEND REMINDER
  // ═════════════════════════════════════════════════════════════

  Future<void> scheduleAutoSendReminder(int hour, int minute, {String? title, String? body}) async {
    await init();
    await _plugin.cancel(3);
    final cadence = await ReportCadenceService.instance.getCadence();
    await _safeZonedSchedule(
      3,
      title ?? 'Time to Send Your Account',
      body ?? 'Your report is ready. Tap to review and send it now.',
      await _nextReportOccurrence(hour, minute),
      _alarmDetails,
      matchDateTimeComponents:
          cadence == ReportCadence.weekly ? DateTimeComponents.dayOfWeekAndTime : null,
      payload: 'navigate_report',
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  CANCEL FOLLOW-UPS (when user logs their account)
  // ═════════════════════════════════════════════════════════════

  /// Call this when the user completes their daily log.
  /// Cancels follow-up reminders for today, then re-schedules them
  /// so they still fire tomorrow. (cancel() permanently kills a
  /// recurring zonedSchedule — we must re-register.)
  Future<void> cancelDailyFollowUps() async {
    for (final id in [11, 12, 13]) {
      await _plugin.cancel(id);
    }
    // Re-schedule so they fire again tomorrow
    final s = StorageService.instance;
    final dh = int.tryParse(await s.getSetting('dailyHour', fallback: '20')) ?? 20;
    final dm = int.tryParse(await s.getSetting('dailyMin', fallback: '0')) ?? 0;
    final count = int.tryParse(await s.getSetting('dailyFollowUps', fallback: '3')) ?? 3;
    final body = await s.getSetting('notifDailyBody', fallback: '');

    if (count >= 1) {
      final f1 = _addMinutesToTime(dh, dm, 30);
      await _safeZonedSchedule(11, '\u23F0 Daily Account',
        body.isNotEmpty ? body : 'You still haven\'t logged today. Your disciple maker is counting on you!',
        _nextInstanceOfTime(f1.hour, f1.minute),
        _alarmDetails, matchDateTimeComponents: DateTimeComponents.time);
    }
    if (count >= 2) {
      final f2 = _addMinutesToTime(dh, dm, 60);
      await _safeZonedSchedule(12, '\u26A0\uFE0F Daily Account',
        'Don\'t break your streak! Open the app and log your spiritual walk now.',
        _nextInstanceOfTime(f2.hour, f2.minute),
        _alarmDetails, matchDateTimeComponents: DateTimeComponents.time);
    }
    if (count >= 3) {
      final f3 = _addMinutesToTime(dh, dm, 90);
      await _safeZonedSchedule(13, '\uD83D\uDEA8 Daily Account',
        'Last reminder! Your day\'s account is still empty. Tap to log before midnight.',
        _nextInstanceOfTime(f3.hour, f3.minute),
        _alarmDetails, matchDateTimeComponents: DateTimeComponents.time);
    }
  }

  /// Call this when the user sends their report.
  /// Cancels follow-up reminders for today, then re-schedules for the next occurrence.
  Future<void> cancelReportFollowUps() async {
    for (final id in [21, 22]) {
      await _plugin.cancel(id);
    }
    // Re-schedule so they fire again next time
    final s = StorageService.instance;
    final sh = int.tryParse(await s.getSetting('sundayHour', fallback: '18')) ?? 18;
    final sm = int.tryParse(await s.getSetting('sundayMin', fallback: '0')) ?? 0;
    final count = int.tryParse(await s.getSetting('sundayFollowUps', fallback: '2')) ?? 2;
    final cadence = await ReportCadenceService.instance.getCadence();
    final matchComponents =
        cadence == ReportCadence.weekly ? DateTimeComponents.dayOfWeekAndTime : null;

    if (count >= 1) {
      final f1 = _addMinutesToTime(sh, sm, 30);
      await _safeZonedSchedule(21, '\u23F0 Time to Send Your Account',
        'Your disciple maker is waiting! Send your report now.',
        await _nextReportOccurrence(f1.hour, f1.minute),
        _alarmDetails, matchDateTimeComponents: matchComponents);
    }
    if (count >= 2) {
      final f2 = _addMinutesToTime(sh, sm, 60);
      await _safeZonedSchedule(22, '\u26A0\uFE0F Time to Send Your Account',
        'Last chance today! Send your account before the day ends.',
        await _nextReportOccurrence(f2.hour, f2.minute),
        _alarmDetails, matchDateTimeComponents: matchComponents);
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  PER-DISCIPLINE REMINDERS
  // ═════════════════════════════════════════════════════════════

  static const _disciplineEmojis = [
    '\uD83D\uDCD6', '\uD83D\uDCDA', '\uD83D\uDD25', '\uD83D\uDE4F', '\uD83E\uDD1D',
    '\uD83D\uDCE2', '\uD83C\uDF7D\uFE0F', '\uD83D\uDCB0', '\u26EA', '\uD83D\uDC65', '\uD83D\uDCE3',
  ];

  /// Schedule a daily reminder for a specific discipline.
  /// [index] is 0–10 matching the discipline order.
  Future<void> scheduleDisciplineReminder(int index, int hour, int minute, String disciplineName) async {
    await init();
    final id = _disciplineBaseId + index;
    await _plugin.cancel(id);
    final emoji = _disciplineEmojis[index];

    await _safeZonedSchedule(
      id,
      '$emoji $disciplineName',
      'Time for $disciplineName. Open the app to get started.',
      _nextInstanceOfTime(hour, minute),
      _gentleDetails,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancel a specific discipline reminder.
  Future<void> cancelDisciplineReminder(int index) async {
    await _plugin.cancel(_disciplineBaseId + index);
  }

  /// Cancel all per-discipline reminders.
  Future<void> cancelAllDisciplineReminders() async {
    for (int i = 0; i < 11; i++) {
      await _plugin.cancel(_disciplineBaseId + i);
    }
  }

  /// Gentle notification style (lower importance, default sound).
  NotificationDetails get _gentleDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_account_discipline_v2',
      'Discipline Reminders',
      channelDescription: 'Gentle reminders for specific disciplines',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    ),
  );

  // ═════════════════════════════════════════════════════════════
  //  WEEK-SO-FAR SUMMARY NOTIFICATION
  // ═════════════════════════════════════════════════════════════

  /// Schedule a "week so far" summary notification for the evening before
  /// the user's configured weekly report day. Only meaningful for weekly
  /// cadence — cancelled (not scheduled) under monthly cadence.
  Future<void> scheduleSaturdaySummary(int hour, int minute, {required String title, required String body}) async {
    await init();
    await _plugin.cancel(_saturdaySummaryId);
    final cadence = await ReportCadenceService.instance.getCadence();
    if (cadence != ReportCadence.weekly) return;
    final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
    final eveBeforeWeekday = ((endWeekday - 1 - 1) % 7) + 1; // 1 day before the report day, DateTime.weekday convention
    await _safeZonedSchedule(
      _saturdaySummaryId,
      title,
      body,
      _nextInstanceOfWeekday(eveBeforeWeekday, hour, minute),
      _alarmDetails,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Cancel the week-so-far summary.
  Future<void> cancelSaturdaySummary() async {
    await _plugin.cancel(_saturdaySummaryId);
  }

  // ═════════════════════════════════════════════════════════════
  //  STOPWATCH ONGOING NOTIFICATION
  // ═════════════════════════════════════════════════════════════

  /// Show or update the ongoing stopwatch notification.
  /// [activityLabel] is the localized activity name (e.g. "Prayer — Alone").
  /// [elapsed] is the current formatted duration (e.g. "12:34").
  Future<void> showStopwatchNotification({
    required String activityLabel,
    required String elapsed,
    required String activityIcon,
    bool isPaused = false,
    String? pausedLabel,
    int? elapsedMs,
  }) async {
    if (!_ready) return;

    // Build actions based on state — include Resume/Pause toggle and Cancel
    final actions = <AndroidNotificationAction>[
      if (!isPaused)
        const AndroidNotificationAction(
          'timer_pause',
          '\u23F8 Pause',
          showsUserInterface: false,
          cancelNotification: false,
        )
      else
        const AndroidNotificationAction(
          'timer_resume',
          '\u25B6 Resume',
          showsUserInterface: false,
          cancelNotification: false,
        ),
      AndroidNotificationAction(
        'timer_stop',
        '\u23F9 Stop',
        showsUserInterface: activityLabel.contains('Bible') ||
            activityLabel.contains('Lecture') ||
            activityLabel.contains('Littérature'),
        cancelNotification: true,
      ),
      const AndroidNotificationAction(
        'timer_cancel',
        '\u2715 Cancel',
        showsUserInterface: true,
        cancelNotification: false,
      ),
    ];

    // Use Android's native chronometer so the time counts in real-time
    // even when the app is in the background. The `when` field is set to
    // (now - elapsedMs) so the chronometer starts from the correct offset.
    final useChronometer = !isPaused && elapsedMs != null;
    final whenMs = useChronometer
        ? DateTime.now().millisecondsSinceEpoch - elapsedMs
        : null;

    // Body text: show elapsed when paused, "in progress" when running
    // (the chronometer in the `when` field shows live time when running).
    final status = isPaused
        ? (pausedLabel ?? '\u23F8 Paused \u2014 $elapsed')
        : '\u23F1 In progress \u2014 $elapsed';

    final channel = AndroidNotificationDetails(
      'daily_account_stopwatch_v2',
      'Activity Timer',
      channelDescription: 'Shows while a spiritual activity timer is running',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: false,
      enableVibration: false,
      ongoing: !isPaused,
      autoCancel: false,
      showWhen: useChronometer,
      usesChronometer: useChronometer,
      when: whenMs,
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
      actions: actions,
      styleInformation: BigTextStyleInformation(
        status,
        contentTitle: '$activityIcon $activityLabel',
      ),
    );

    final details = NotificationDetails(
      android: channel,
      iOS: const DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      ),
    );

    await _plugin.show(
      stopwatchNotifId,
      '$activityIcon $activityLabel',
      status,
      details,
    );
  }

  /// Cancel the stopwatch notification (when timer stops).
  Future<void> cancelStopwatchNotification() async {
    await _plugin.cancel(stopwatchNotifId);
  }

  /// Cancel a specific notification by ID.
  Future<void> cancel(int id) async => _plugin.cancel(id);

  /// Cancel all notifications.
  Future<void> cancelAll() async => _plugin.cancelAll();

  /// Get all pending notifications (for debugging).
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _plugin.pendingNotificationRequests();
  }

  // ═════════════════════════════════════════════════════════════
  //  MID-WEEK NUDGE (Wednesday check-in)
  // ═════════════════════════════════════════════════════════════

  static const _midWeekId = 30;

  /// Schedule a mid-week check-in notification, 3 days before the user's
  /// configured weekly report day. Only meaningful for weekly cadence —
  /// cancelled (not scheduled) under monthly cadence.
  Future<void> scheduleMidWeekNudge(int hour, int minute, {String? title, String? body}) async {
    await init();
    await _plugin.cancel(_midWeekId);
    final cadence = await ReportCadenceService.instance.getCadence();
    if (cadence != ReportCadence.weekly) return;
    final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
    final midWeekday = ((endWeekday - 3 - 1) % 7) + 1; // 3 days before the report day, DateTime.weekday convention
    await _safeZonedSchedule(
      _midWeekId,
      title ?? 'Mid-Week Check-in',
      body ?? 'How\'s your week going? Check your progress!',
      _nextInstanceOfWeekday(midWeekday, hour, minute),
      _alarmDetails,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Next occurrence of day-of-month [day] (already resolved — e.g. from
  /// ReportCadenceService.resolveMonthlyDay) at [hour]:[minute]. Walks
  /// forward day-by-day like _nextInstanceOfWeekday, re-resolving [day]
  /// against each candidate month in case the walk crosses into a new
  /// month with a different last-day (for "last day" configurations).
  tz.TZDateTime _nextInstanceOfMonthlyDay(int Function(int year, int month) resolveDay, int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.day != resolveDay(scheduled.year, scheduled.month)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Next occurrence of the user's configured report day at [hour]:[minute],
  /// whether that's weekly (a fixed weekday) or monthly (a specific day or
  /// the last day of the month).
  Future<tz.TZDateTime> _nextReportOccurrence(int hour, int minute) async {
    final cadenceSvc = ReportCadenceService.instance;
    final cadence = await cadenceSvc.getCadence();
    if (cadence == ReportCadence.weekly) {
      final weekday = await cadenceSvc.getWeeklyDay();
      return _nextInstanceOfWeekday(weekday, hour, minute);
    }
    final monthlyDay = await cadenceSvc.getMonthlyDay();
    return _nextInstanceOfMonthlyDay(
      (year, month) => cadenceSvc.resolveMonthlyDay(year, month, monthlyDay),
      hour,
      minute,
    );
  }

  // ── Time helpers ──────────────────────────────────────────

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Compute the (hour, minute) that is [addMinutes] after (hour, minute).
  /// Handles midnight wraparound correctly.
  ({int hour, int minute}) _addMinutesToTime(int hour, int minute, int addMinutes) {
    final total = hour * 60 + minute + addMinutes;
    return (hour: (total ~/ 60) % 24, minute: total % 60);
  }

  // ═════════════════════════════════════════════════════════════
  //  STREAK-AT-RISK NOTIFICATION
  // ═════════════════════════════════════════════════════════════

  /// Check if the user's streak is at risk and fire a notification.
  /// Call this from app lifecycle (evening check) or widget update.
  /// Only fires once per day and only in the evening (after 8 PM).
  Future<void> checkStreakRisk({
    required int streak,
    required bool loggedToday,
    String? title,
    String? body,
  }) async {
    if (!_ready) await init();
    if (streak <= 0 || loggedToday) return;

    // Only fire in the evening (8 PM – midnight)
    final now = DateTime.now();
    if (now.hour < 20) return;

    // Don't fire if already fired today
    final lastFired = await StorageService.instance.getSetting('streakRiskLastDate', fallback: '');
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (lastFired == todayKey) return;

    await StorageService.instance.setSetting('streakRiskLastDate', todayKey);

    final t = title ?? "Your $streak-day streak is at risk!";
    final b = body ?? "You haven't logged today — don't let your streak break. Open Daily Account now.";

    await _plugin.show(
      _streakRiskId,
      t,
      b,
      _alarmDetails,
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  MILESTONE CELEBRATION NOTIFICATION
  // ═════════════════════════════════════════════════════════════

  /// Fire a celebration notification when the user hits a milestone.
  Future<void> showMilestoneNotification({
    required String title,
    required String body,
  }) async {
    if (!_ready) await init();

    await _plugin.show(
      _milestoneId,
      title,
      body,
      _alarmDetails,
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  GOAL COMPLETION NOTIFICATION
  // ═════════════════════════════════════════════════════════════

  /// Immediately show a one-shot "goal completed" notification (not
  /// scheduled — fires right away when called). Always uses id 130;
  /// if multiple goals complete in the same save, the notifications
  /// overwrite each other on the notification tray, which is an
  /// accepted simplification for a celebratory, non-durable notification.
  Future<void> showGoalCompletedNotification(String title, String body) async {
    await init();
    await _plugin.show(130, title, body, _alarmDetails, payload: 'navigate_report');
  }

  // ═════════════════════════════════════════════════════════════
  //  GOAL PACE-CHECK REMINDERS
  // ═════════════════════════════════════════════════════════════

  /// Schedule (or re-schedule) the three goal pace-check reminders. Each
  /// is a one-shot notification whose "is the user actually behind" state
  /// is computed at schedule time (this plugin's zonedSchedule bakes text
  /// in at schedule time, not fire time — see design spec §9) and re-armed
  /// whenever this method runs again (called from rescheduleAll(), i.e.
  /// on every app start/resume).
  Future<void> scheduleGoalPaceChecks() async {
    await init();
    final enabled = (await StorageService.instance.getSetting('goalPaceRemindersEnabled', fallback: 'true')) == 'true';
    for (final id in [140, 141, 142]) {
      await _plugin.cancel(id);
    }
    if (!enabled) return;

    final goals = await StorageService.instance.getGoals();
    final byFrequency = {
      GoalFrequency.daily: goals.where((g) => g.frequency == GoalFrequency.daily).toList(),
      GoalFrequency.weekly: goals.where((g) => g.frequency == GoalFrequency.weekly).toList(),
      GoalFrequency.monthly: goals.where((g) => g.frequency == GoalFrequency.monthly).toList(),
    };

    Future<int> countBehind(List<Goal> list) async {
      int n = 0;
      for (final g in list) {
        if (await GoalProgressService.instance.isBehindPace(g)) n++;
      }
      return n;
    }

    final dailyBehind = await countBehind(byFrequency[GoalFrequency.daily]!);
    if (dailyBehind > 0) {
      await _safeZonedSchedule(140, 'Goals', '$dailyBehind daily goal(s) could use some attention today.',
          _nextInstanceOfTime(15, 0), _alarmDetails);
    }

    final weeklyBehind = await countBehind(byFrequency[GoalFrequency.weekly]!);
    if (weeklyBehind > 0) {
      final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
      final midWeekday = ((endWeekday - 3 - 1) % 7) + 1; // 3 days before the week-ending day, DateTime.weekday convention
      await _safeZonedSchedule(141, 'Goals', '$weeklyBehind weekly goal(s) could use some attention.',
          _nextInstanceOfWeekday(midWeekday, 18, 0), _alarmDetails);
    }

    final monthlyBehind = await countBehind(byFrequency[GoalFrequency.monthly]!);
    if (monthlyBehind > 0) {
      await _safeZonedSchedule(142, 'Goals', '$monthlyBehind monthly goal(s) could use some attention.',
          _nextInstanceOfMonthlyDay((year, month) => 15, 18, 0), _alarmDetails);
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  BATTERY OPTIMIZATION (Android)
  // ═════════════════════════════════════════════════════════════

  static const _batteryChannel = MethodChannel('com.jilengineering.dailyaccount/battery');

  /// Check if the app is exempt from battery optimization.
  /// Returns true if exempt (good) or if not on Android.
  Future<bool> _checkBatteryOptimization() async {
    try {
      final result = await _batteryChannel.invokeMethod<bool>('isBatteryOptimizationDisabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request the system to disable battery optimization for this app.
  /// Shows Android's native "Allow app to always run?" dialog.
  /// Returns the updated exemption status after the request.
  Future<bool> requestBatteryOptimizationExemption() async {
    try {
      await _batteryChannel.invokeMethod('requestDisableBatteryOptimization');
      // Re-check after a short delay (the dialog is async)
      await Future.delayed(const Duration(seconds: 1));
      _batteryOptExempt = await _checkBatteryOptimization();
      return _batteryOptExempt;
    } catch (_) {
      return false;
    }
  }

  /// Open the system battery optimization settings page (list of all apps).
  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _batteryChannel.invokeMethod('openBatteryOptimizationSettings');
    } catch (_) {
      debugPrint('[NotificationService] Failed to open battery settings');
    }
  }

  /// Manufacturers with a known OEM-specific autostart/background manager
  /// screen (lowercase `Build.MANUFACTURER` values). Standard Android's
  /// battery-optimization exemption does not reach this layer — the OEM
  /// kills scheduled alarms anyway unless the app is whitelisted here too.
  static const _oemsWithAutostartManager = {
    'xiaomi', 'oppo', 'vivo', 'huawei', 'honor', 'samsung', 'oneplus', 'asus',
  };

  String? _manufacturer;

  /// Whether this device's manufacturer is known to enforce a separate
  /// autostart/background-permission layer beyond stock Android's battery
  /// optimization exemption (MIUI, ColorOS, FuntouchOS/OriginOS, EMUI, etc).
  Future<bool> hasKnownOemAutostartSettings() async {
    _manufacturer ??= await _getManufacturer();
    return _oemsWithAutostartManager.contains(_manufacturer);
  }

  Future<String?> _getManufacturer() async {
    try {
      final result = await _batteryChannel.invokeMethod<String>('getManufacturer');
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Open this OEM's autostart/background-app manager so the user can
  /// whitelist the app. Falls back to the app's details settings page if no
  /// known screen exists for this manufacturer/firmware. Returns true if a
  /// manufacturer-specific screen was launched, false if it fell back.
  Future<bool> openOemAutostartSettings() async {
    try {
      final result = await _batteryChannel.invokeMethod<bool>('openOemAutostartSettings');
      return result ?? false;
    } catch (_) {
      debugPrint('[NotificationService] Failed to open OEM autostart settings');
      return false;
    }
  }
}
