import 'dart:ui' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'storage_service.dart';

/// Aggressive, alarm-style notification system for Daily Account.
///
/// The goal: make it impossible to forget your daily spiritual disciplines.
///
/// Notification IDs:
///   1  = Daily log reminder (primary)
///   2  = Sunday send reminder (primary)
///   3  = Sunday auto-send reminder
///   11 = Daily follow-up #1 (30 min after primary)
///   12 = Daily follow-up #2 (60 min after primary)
///   13 = Daily follow-up #3 (90 min after primary)
///   21 = Sunday follow-up #1
///   22 = Sunday follow-up #2
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // ── Notification channels ──────────────────────────────────

  /// High-importance alarm channel — pops up, sound, vibration, LED.
  static const _alarmChannel = AndroidNotificationDetails(
    'daily_account_alarm',
    'Daily Account Reminders',
    channelDescription: 'Alarm-style reminders to record your walk with God',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    ledColor: Color(0xFFD4AF64), // gold
    ledOnMs: 1000,
    ledOffMs: 500,
    fullScreenIntent: true, // shows over lock screen like an alarm
    category: AndroidNotificationCategory.alarm,
    visibility: NotificationVisibility.public,
    autoCancel: true,
    ongoing: false,
  );

  static const _alarmDetails = NotificationDetails(
    android: _alarmChannel,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  // ── Initialization ────────────────────────────────────────

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();

    // Use the device's actual timezone instead of hardcoding
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      // Fallback for Cameroon users
      tz.setLocalLocation(tz.getLocation('Africa/Lagos'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Android 13+ runtime permission
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      // Explicitly create the alarm notification channel
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          'daily_account_alarm',
          'Daily Account Reminders',
          description: 'Alarm-style reminders to record your walk with God',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Color(0xFFD4AF64),
        ),
      );
      // Request exact alarm permission (Android 12+)
      await androidImpl.requestExactAlarmsPermission();
    }

    _ready = true;

    // Schedule defaults on first launch
    _scheduleDefaultsIfNeeded();
  }

  Future<void> _scheduleDefaultsIfNeeded() async {
    final hasScheduled = await StorageService.instance.getSetting('notifs_initialized', fallback: '');
    if (hasScheduled.isNotEmpty) return;

    await scheduleDailyReminder(20, 0);
    await scheduleSundayReminder(18, 0);
    await StorageService.instance.setSetting('notifs_initialized', 'true');
    await StorageService.instance.setSetting('notificationsEnabled', 'true');
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

    // Primary reminder (alarm-style)
    await _plugin.zonedSchedule(
      1,
      t,
      body ?? 'Have you recorded your walk with God today? Tap to log it.',
      _nextInstanceOfTime(hour, minute),
      _alarmDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    // Follow-up #1 — 30 minutes later
    if (followUpCount >= 1) {
      await _plugin.zonedSchedule(
        11,
        '\u23F0 $t',
        body ?? 'You still haven\'t logged today. Your disciple maker is counting on you!',
        _nextInstanceOfTime(hour, minute).add(const Duration(minutes: 30)),
        _alarmDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // Follow-up #2 — 60 minutes later
    if (followUpCount >= 2) {
      await _plugin.zonedSchedule(
        12,
        '\u26A0\uFE0F $t',
        'Don\'t break your streak! Open the app and log your spiritual walk now.',
        _nextInstanceOfTime(hour, minute).add(const Duration(minutes: 60)),
        _alarmDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // Follow-up #3 — 90 minutes later (final)
    if (followUpCount >= 3) {
      await _plugin.zonedSchedule(
        13,
        '\uD83D\uDEA8 $t',
        'Last reminder! Your day\'s account is still empty. Tap to log before midnight.',
        _nextInstanceOfTime(hour, minute).add(const Duration(minutes: 90)),
        _alarmDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  SUNDAY SEND REMINDER (alarm-style + follow-ups)
  // ═════════════════════════════════════════════════════════════

  /// Schedule the Sunday send reminder + follow-ups.
  /// [followUpCount] controls how many follow-ups (0–2), default 2.
  Future<void> scheduleSundayReminder(int hour, int minute, {String? title, String? body, int followUpCount = 2}) async {
    await init();

    final t = title ?? 'Sunday — Send Your Account';

    // Cancel all existing Sunday notifications
    for (final id in [2, 21, 22]) {
      await _plugin.cancel(id);
    }

    // Primary Sunday reminder
    await _plugin.zonedSchedule(
      2,
      t,
      body ?? 'It\'s time to send your weekly account to your disciple maker.',
      _nextInstanceOfSunday(hour, minute),
      _alarmDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    // Follow-up #1 — 30 minutes later
    if (followUpCount >= 1) {
      await _plugin.zonedSchedule(
        21,
        '\u23F0 $t',
        'Your disciple maker is waiting! Send your weekly report now.',
        _nextInstanceOfSunday(hour, minute).add(const Duration(minutes: 30)),
        _alarmDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // Follow-up #2 — 60 minutes later
    if (followUpCount >= 2) {
      await _plugin.zonedSchedule(
        22,
        '\u26A0\uFE0F $t',
        'Last chance today! Send your account before the week ends.',
        _nextInstanceOfSunday(hour, minute).add(const Duration(minutes: 60)),
        _alarmDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  AUTO-SEND REMINDER
  // ═════════════════════════════════════════════════════════════

  Future<void> scheduleAutoSendReminder(int hour, int minute, {String? title, String? body}) async {
    await init();
    await _plugin.cancel(3);
    await _plugin.zonedSchedule(
      3,
      title ?? 'Time to Send Your Account',
      body ?? 'Your weekly report is ready. Tap to review and send it now.',
      _nextInstanceOfSunday(hour, minute),
      _alarmDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ═════════════════════════════════════════════════════════════
  //  CANCEL FOLLOW-UPS (when user logs their account)
  // ═════════════════════════════════════════════════════════════

  /// Call this when the user completes their daily log.
  /// Cancels follow-up reminders for today so they stop nagging.
  Future<void> cancelDailyFollowUps() async {
    for (final id in [11, 12, 13]) {
      await _plugin.cancel(id);
    }
  }

  /// Call this when the user sends their Sunday report.
  Future<void> cancelSundayFollowUps() async {
    for (final id in [21, 22]) {
      await _plugin.cancel(id);
    }
  }

  /// Cancel a specific notification by ID.
  Future<void> cancel(int id) async => _plugin.cancel(id);

  /// Cancel all notifications.
  Future<void> cancelAll() async => _plugin.cancelAll();

  // ── Time helpers ──────────────────────────────────────────

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfSunday(int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != DateTime.sunday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

