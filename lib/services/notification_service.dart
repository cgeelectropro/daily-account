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
///   30 = Mid-week nudge (Wednesday)
///   40 = Saturday summary
///   50 = Test notification
///   99 = Snooze notification
///  110–120 = Per-discipline reminders
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // ── Notification channels ──────────────────────────────────

  /// Snooze notification ID
  static const _snoozeId = 99;

  /// Test notification ID (must not collide with _disciplineBaseId range 110–120)
  static const _testId = 50;

  /// High-importance channel — sound, vibration, LED, heads-up display.
  /// Includes a "Snooze 15 min" action button.
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
    // Don't use fullScreenIntent — restricted on Android 14+ and
    // causes silent suppression on some OEMs for non-alarm apps.
    fullScreenIntent: false,
    category: AndroidNotificationCategory.reminder,
    visibility: NotificationVisibility.public,
    autoCancel: true,
    ongoing: false,
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction(
        'snooze_15',
        'Snooze 15 min',
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ],
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

  /// Stopwatch notification ID — ongoing while a timer runs.
  static const stopwatchNotifId = 200;

  /// Per-discipline reminder IDs (110–120).
  static const _disciplineBaseId = 110;

  /// Saturday summary notification ID.
  static const _saturdaySummaryId = 40;

  /// Streak-at-risk notification ID.
  static const _streakRiskId = 60;

  /// Milestone celebration notification ID.
  static const _milestoneId = 61;

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
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Android 13+ runtime permission
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      // Request notification permission (Android 13+)
      final notifGranted = await androidImpl.requestNotificationsPermission();
      if (notifGranted != true) {
        // User denied notification permission — notifications won't work.
        // We still mark ready so the app doesn't crash, but log the issue.
        _ready = true;
        return;
      }

      // Create notification channels explicitly
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

      // Request exact alarm permission (Android 12+)
      // If denied, _safeZonedSchedule will fall back to inexact alarms.
      await androidImpl.requestExactAlarmsPermission();
    }

    _ready = true;

    // Schedule defaults on first launch
    rescheduleAll();
  }

  /// Re-schedule all reminders. Safe to call repeatedly.
  ///
  /// This is critical because Android can silently drop scheduled alarms
  /// after app updates, battery optimization, or reboots. Cheap to call
  /// and guarantees notifications stay alive.
  ///
  /// Called automatically on init(), and should also be called when the
  /// app returns to the foreground (AppLifecycleState.resumed).
  Future<void> rescheduleAll() async {
    final s = StorageService.instance;
    final enabled = await s.getSetting('notificationsEnabled', fallback: '');

    if (enabled.isEmpty) {
      // First launch — set defaults and schedule
      await scheduleDailyReminder(20, 0);
      await scheduleSundayReminder(18, 0);
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
    await scheduleSundayReminder(sh, sm,
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

    // Mid-week nudge (Wednesday at 18:00)
    final midWeekTitle = await s.getSetting('notifMidWeekTitle', fallback: '');
    final midWeekBody = await s.getSetting('notifMidWeekBody', fallback: '');
    await scheduleMidWeekNudge(18, 0,
      title: midWeekTitle.isNotEmpty ? midWeekTitle : null,
      body: midWeekBody.isNotEmpty ? midWeekBody : null,
    );

    // Saturday summary (Saturday at 18:00)
    await scheduleSaturdaySummary(18, 0,
      title: 'Your week so far',
      body: 'Check your progress and finish strong tomorrow!',
    );

    // Re-schedule per-discipline reminders
    for (int i = 0; i < 11; i++) {
      final raw = await s.getSetting('discReminder_$i', fallback: '');
      if (raw.isNotEmpty) {
        final parts = raw.split(':');
        if (parts.length == 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final names = ['Bible', 'Literature', 'DDEG', 'Prayer (alone)', 'Prayer (others)',
            'Evangelism', 'Fasting', 'Giving', 'Church', 'Discipleship', 'Proclamation'];
          await scheduleDisciplineReminder(i, h, m, names[i]);
        }
      }
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  NOTIFICATION ACTION HANDLER (snooze)
  // ═════════════════════════════════════════════════════════════

  /// Callback for handling timer notification actions from outside.
  /// Set this from TimerService so notification actions can control the timer.
  void Function(String action)? onTimerAction;

  void _onNotificationResponse(NotificationResponse response) {
    switch (response.actionId) {
      case 'snooze_15':
        _scheduleSnooze();
      case 'timer_pause':
      case 'timer_stop':
        onTimerAction?.call(response.actionId!);
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
      );
    } catch (_) {
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
        );
      } catch (_) {
        // Even inexact failed — silently ignore
        // (notification permission likely denied entirely)
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
    await _safeZonedSchedule(
      2,
      t,
      body ?? 'It\'s time to send your weekly account to your disciple maker.',
      _nextInstanceOfSunday(hour, minute),
      _alarmDetails,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    // Follow-up #1 — 30 minutes later
    if (followUpCount >= 1) {
      final followUp1 = _addMinutesToTime(hour, minute, 30);
      await _safeZonedSchedule(
        21,
        '\u23F0 $t',
        'Your disciple maker is waiting! Send your weekly report now.',
        _nextInstanceOfSunday(followUp1.hour, followUp1.minute),
        _alarmDetails,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }

    // Follow-up #2 — 60 minutes later
    if (followUpCount >= 2) {
      final followUp2 = _addMinutesToTime(hour, minute, 60);
      await _safeZonedSchedule(
        22,
        '\u26A0\uFE0F $t',
        'Last chance today! Send your account before the week ends.',
        _nextInstanceOfSunday(followUp2.hour, followUp2.minute),
        _alarmDetails,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  AUTO-SEND REMINDER
  // ═════════════════════════════════════════════════════════════

  Future<void> scheduleAutoSendReminder(int hour, int minute, {String? title, String? body}) async {
    await init();
    await _plugin.cancel(3);
    await _safeZonedSchedule(
      3,
      title ?? 'Time to Send Your Account',
      body ?? 'Your weekly report is ready. Tap to review and send it now.',
      _nextInstanceOfSunday(hour, minute),
      _alarmDetails,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
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

  /// Gentle notification style (lower importance, no alarm sound).
  NotificationDetails get _gentleDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_account_discipline',
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
  //  SATURDAY SUMMARY NOTIFICATION
  // ═════════════════════════════════════════════════════════════

  /// Schedule a Saturday evening summary notification.
  Future<void> scheduleSaturdaySummary(int hour, int minute, {required String title, required String body}) async {
    await init();
    await _plugin.cancel(_saturdaySummaryId);
    await _safeZonedSchedule(
      _saturdaySummaryId,
      title,
      body,
      _nextInstanceOfSaturday(hour, minute),
      _alarmDetails,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Cancel Saturday summary.
  Future<void> cancelSaturdaySummary() async {
    await _plugin.cancel(_saturdaySummaryId);
  }

  tz.TZDateTime _nextInstanceOfSaturday(int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != DateTime.saturday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
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

    // Build actions based on state
    final actions = <AndroidNotificationAction>[
      if (!isPaused)
        const AndroidNotificationAction(
          'timer_pause',
          'Pause',
          showsUserInterface: false,
          cancelNotification: false,
        ),
      const AndroidNotificationAction(
        'timer_stop',
        'Stop',
        showsUserInterface: true,
        cancelNotification: true,
      ),
    ];

    // Use Android's native chronometer so the time counts in real-time
    // even when the app is in the background. The `when` field is set to
    // (now - elapsedMs) so the chronometer starts from the correct offset.
    final useChronometer = !isPaused && elapsedMs != null;
    final whenMs = useChronometer
        ? DateTime.now().millisecondsSinceEpoch - elapsedMs
        : null;

    final channel = AndroidNotificationDetails(
      'daily_account_stopwatch',
      'Activity Timer',
      channelDescription: 'Shows while a spiritual activity timer is running',
      importance: Importance.low,
      priority: Priority.low,
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
    );

    final details = NotificationDetails(
      android: channel,
      iOS: const DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      ),
    );

    // When running, the Android chronometer handles the live time display
    // in the notification's `when` field — use a static body to avoid a
    // stale elapsed string that freezes when the Dart isolate is suspended.
    final status = isPaused ? (pausedLabel ?? 'Paused — $elapsed') : 'In progress';
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

  /// Schedule a Wednesday mid-week check-in notification.
  Future<void> scheduleMidWeekNudge(int hour, int minute, {String? title, String? body}) async {
    await init();
    await _plugin.cancel(_midWeekId);
    await _safeZonedSchedule(
      _midWeekId,
      title ?? 'Mid-Week Check-in',
      body ?? 'How\'s your week going? Check your progress!',
      _nextInstanceOfWeekday(DateTime.wednesday, hour, minute),
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
}
