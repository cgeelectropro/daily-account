import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Schedules the daily "log your account" reminder and the special
/// Sunday "send to your disciple maker" reminder.
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
  Future<void> scheduleDailyReminder(int hour, int minute) async {
    await init();
    await _plugin.cancel(1);
    await _plugin.zonedSchedule(
      1,
      '📖 Daily Account',
      'Have you recorded your walk with God today? Tap to log it.',
      _nextInstanceOfTime(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime, // daily repeat
    );
  }

  /// Schedule the weekly Sunday reminder to send the report.
  Future<void> scheduleSundayReminder(int hour, int minute) async {
    await init();
    await _plugin.cancel(2);
    await _plugin.zonedSchedule(
      2,
      '🕊️ Sunday — Send Your Account',
      'Send this week\'s account to your disciple maker. Tap to review & send.',
      _nextInstanceOfSunday(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, 
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime, // weekly
    );
  }

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
    // DateTime.sunday == 7
    while (scheduled.weekday != DateTime.sunday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
