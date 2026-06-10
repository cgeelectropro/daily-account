import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'storage_service.dart';

/// Schedules the daily "log your account" reminder and the special
/// Sunday "send to your disciple maker" reminder.
///
/// Notification IDs:
///   1 = Daily log reminder
///   2 = Sunday send reminder
///   3 = Sunday auto-send reminder (sends report)
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // Cameroon / Africa-Lagos timezone (WAT, UTC+1)
    tz.setLocalLocation(tz.getLocation('Africa/Lagos'));

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
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _ready = true;

    // Schedule default notifications on first launch (non-blocking)
    _scheduleDefaultsIfNeeded();
  }

  /// Schedule default daily (20:00) and Sunday (18:00) reminders on first launch.
  Future<void> _scheduleDefaultsIfNeeded() async {
    final hasScheduled = await StorageService.instance.getSetting('notifs_initialized', fallback: '');
    if (hasScheduled.isNotEmpty) return;

    await scheduleDailyReminder(20, 0);
    await scheduleSundayReminder(18, 0);
    await StorageService.instance.setSetting('notifs_initialized', 'true');
    await StorageService.instance.setSetting('notificationsEnabled', 'true');
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_account_channel',
      'Daily Account Reminders',
      channelDescription: 'Reminders to record your daily walk with God',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Schedule a daily reminder at [hour]:[minute] (repeats every day).
  /// Pass [title] and [body] to use localized strings; defaults to English.
  Future<void> scheduleDailyReminder(int hour, int minute, {String? title, String? body}) async {
    await init();
    await _plugin.cancel(1);
    await _plugin.zonedSchedule(
      1,
      title ?? 'Daily Account',
      body ?? 'Have you recorded your walk with God today? Tap to log it.',
      _nextInstanceOfTime(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule the weekly Sunday reminder to send the report.
  /// Pass [title] and [body] to use localized strings; defaults to English.
  Future<void> scheduleSundayReminder(int hour, int minute, {String? title, String? body}) async {
    await init();
    await _plugin.cancel(2);
    await _plugin.zonedSchedule(
      2,
      title ?? 'Sunday — Send Your Account',
      body ?? 'Send this week\'s account to your disciple maker. Tap to review & send.',
      _nextInstanceOfSunday(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule a Sunday auto-send reminder (separate from the regular Sunday reminder).
  Future<void> scheduleAutoSendReminder(int hour, int minute, {String? title, String? body}) async {
    await init();
    await _plugin.cancel(3);
    await _plugin.zonedSchedule(
      3,
      title ?? 'Time to Send Your Account',
      body ?? 'Your weekly report is ready. Tap to review and send it now.',
      _nextInstanceOfSunday(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel a specific notification by ID.
  Future<void> cancel(int id) async => _plugin.cancel(id);

  /// Cancel all notifications.
  Future<void> cancelAll() async => _plugin.cancelAll();

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
