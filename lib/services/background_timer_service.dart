import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'auto_send_runner.dart';

/// Notification channel shared between [NotificationService] and the
/// background isolate so both write to the same Android channel.
const kTimerChannelId = 'daily_account_stopwatch_v2';
const kTimerChannelName = 'Activity Timer';
const kTimerNotifId = 200; // must match NotificationService.stopwatchNotifId

/// Low-priority channel for the always-on guardian notification, shown
/// whenever no activity timer is running. Keeps the process classified as
/// a foreground service so Android (and OEM battery managers) are far less
/// likely to kill it before scheduled reminder alarms can fire.
const kGuardianChannelId = 'daily_account_guardian';
const kGuardianChannelName = 'Background Protection';
const kGuardianNotifId = 201;

/// Manages a single always-on Android foreground service that:
///  - keeps the process alive so scheduled reminder alarms are more likely
///    to survive Doze/App Standby and OEM background killers, and
///  - keeps the activity timer alive in the background when one is running.
///
/// Only one Android foreground service can exist per app, so both
/// responsibilities share the same service/notification, switching content
/// between an idle "guardian" state and the richer timer state.
///
/// Communication between the UI isolate and the background isolate uses
/// [FlutterBackgroundService.invoke] / [FlutterBackgroundService.on].
///
/// Events:
///   UI → BG:
///     "startTimer"  { label, icon, elapsedMs }
///     "pauseTimer"  { elapsedMs }
///     "stopTimer"   (no args)          — reverts to guardian idle state
///   BG → UI:
///     "timerTick"   { elapsedMs }   (every second while running)
class BackgroundTimerService {
  BackgroundTimerService._();
  static final BackgroundTimerService instance = BackgroundTimerService._();

  final _service = FlutterBackgroundService();
  bool _configured = false;

  /// Call once at app startup (before any timer interaction). Also starts
  /// the guardian service immediately so it's protecting reminders even
  /// when no timer is running.
  Future<void> init() async {
    if (_configured) return;
    if (!Platform.isAndroid) {
      _configured = true;
      return;
    }

    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            kTimerChannelId,
            kTimerChannelName,
            description: 'Shows while a spiritual activity timer is running',
            importance: Importance.defaultImportance,
            playSound: false,
            enableVibration: false,
          ),
        );
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            kGuardianChannelId,
            kGuardianChannelName,
            description: 'Keeps Daily Account active so reminders arrive on time',
            importance: Importance.min,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          ),
        );
      }

      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onStart,
          autoStart: true,
          autoStartOnBoot: true,
          isForegroundMode: true,
          notificationChannelId: kGuardianChannelId,
          initialNotificationTitle: 'Daily Account',
          initialNotificationContent: 'Protecting your reminders…',
          foregroundServiceNotificationId: kGuardianNotifId,
          foregroundServiceTypes: [AndroidForegroundType.specialUse],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
        ),
      );

      _configured = true;

      final running = await _service.isRunning();
      if (!running) {
        await _service.startService();
      }
    } catch (_) {
      // Background service configuration failed — app still works, just
      // without the extra protection against being killed in the background.
      _configured = true;
    }
  }

  /// Start (or switch) the foreground service into timer mode.
  Future<void> startForegroundTimer({
    required String label,
    required String icon,
    required int elapsedMs,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await init();

      final running = await _service.isRunning();
      if (!running) {
        await _service.startService();
        // Small delay so the service isolate is ready to receive events.
        await Future.delayed(const Duration(milliseconds: 300));
      }

      _service.invoke('startTimer', {
        'label': label,
        'icon': icon,
        'elapsedMs': elapsedMs,
      });
    } catch (_) {
      // Service failed to start — timer still works in the UI
    }
  }

  /// Notify the service that the timer is paused.
  void pauseForegroundTimer({required int elapsedMs, required String label}) {
    if (!Platform.isAndroid) return;
    try {
      _service.invoke('pauseTimer', {
        'elapsedMs': elapsedMs,
        'label': label,
      });
    } catch (_) {}
  }

  /// Revert the service to its idle guardian state (does NOT stop the
  /// service — it keeps running to protect scheduled reminders).
  void stopForegroundTimer() {
    if (!Platform.isAndroid) return;
    try {
      _service.invoke('stopTimer');
    } catch (_) {}
  }

  /// Stream of tick events from the background isolate.
  Stream<Map<String, dynamic>?> get ticks => _service.on('timerTick');
}

// ═══════════════════════════════════════════════════════════════
//  BACKGROUND ISOLATE — runs independently of the Flutter UI
// ═══════════════════════════════════════════════════════════════

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  Timer? ticker;
  int elapsedMs = 0;
  DateTime? startedAt;
  String currentLabel = 'Timer';
  String currentIcon = '⏱';
  bool timerActive = false;

  void showGuardianNotification() {
    plugin.show(
      kGuardianNotifId,
      'Daily Account',
      'Protecting your reminders — tap to open.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          kGuardianChannelId,
          kGuardianChannelName,
          channelDescription: 'Keeps Daily Account active so reminders arrive on time',
          importance: Importance.min,
          priority: Priority.min,
          playSound: false,
          enableVibration: false,
          ongoing: true,
          autoCancel: false,
          showWhen: false,
          category: AndroidNotificationCategory.service,
          visibility: NotificationVisibility.public,
        ),
      ),
    );
  }

  void updateTimerNotification({bool running = true, bool paused = false}) {
    final totalMs = running && startedAt != null
        ? elapsedMs + DateTime.now().difference(startedAt!).inMilliseconds
        : elapsedMs;

    // Action buttons matching NotificationService.showStopwatchNotification
    final actions = <AndroidNotificationAction>[
      if (running)
        const AndroidNotificationAction(
          'timer_pause', '⏸ Pause',
          showsUserInterface: false, cancelNotification: false,
        )
      else if (paused)
        const AndroidNotificationAction(
          'timer_resume', '▶ Resume',
          showsUserInterface: false, cancelNotification: false,
        ),
      AndroidNotificationAction(
        'timer_stop', '⏹ Stop',
        showsUserInterface: currentLabel.contains('Bible') ||
            currentLabel.contains('Lecture') ||
            currentLabel.contains('Littérature'),
        cancelNotification: true,
      ),
      const AndroidNotificationAction(
        'timer_cancel', '✕ Cancel',
        showsUserInterface: true, cancelNotification: false,
      ),
    ];

    final channel = AndroidNotificationDetails(
      kTimerChannelId,
      kTimerChannelName,
      channelDescription: 'Shows while a spiritual activity timer is running',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: false,
      enableVibration: false,
      ongoing: running,
      autoCancel: false,
      showWhen: running,
      usesChronometer: running,
      when: running ? DateTime.now().millisecondsSinceEpoch - totalMs : null,
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
      actions: actions,
    );

    final secs = (totalMs ~/ 1000) % 60;
    final mins = (totalMs ~/ 60000) % 60;
    final hrs = totalMs ~/ 3600000;
    final display = hrs > 0
        ? '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}'
        : '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    final body = paused ? '⏸ Paused — $display' : '⏱ In progress — $display';

    // Cancel the guardian notification while the richer timer one is shown
    // under a different channel/ID — avoids two persistent icons at once.
    plugin.cancel(kGuardianNotifId);
    plugin.show(
      kTimerNotifId,
      '$currentIcon $currentLabel',
      body,
      NotificationDetails(android: channel),
    );
  }

  // Start in idle guardian mode.
  showGuardianNotification();

  // Run once at service start — covers the case where the service (and
  // therefore the app process) was launched fresh right around report
  // time (e.g. after a reboot or the periodic tick below), without
  // waiting for the first 15-minute interval.
  AutoSendRunner.trySendPending();
  AutoSendRunner.checkAutoSend();

  service.on('startTimer').listen((data) {
    timerActive = true;
    currentLabel = data?['label'] ?? 'Timer';
    currentIcon = data?['icon'] ?? '⏱';
    elapsedMs = data?['elapsedMs'] ?? 0;
    startedAt = DateTime.now();

    ticker?.cancel();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final totalMs = elapsedMs + now.difference(startedAt!).inMilliseconds;
      service.invoke('timerTick', {'elapsedMs': totalMs});
    });

    updateTimerNotification();
  });

  service.on('pauseTimer').listen((data) {
    ticker?.cancel();
    ticker = null;
    elapsedMs = data?['elapsedMs'] ?? elapsedMs;
    currentLabel = data?['label'] ?? currentLabel;
    startedAt = null;
    updateTimerNotification(running: false, paused: true);
  });

  service.on('stopTimer').listen((_) {
    ticker?.cancel();
    ticker = null;
    elapsedMs = 0;
    startedAt = null;
    timerActive = false;
    // Revert to the idle guardian notification instead of stopping the
    // service — the service keeps running to protect scheduled reminders.
    plugin.cancel(kTimerNotifId);
    showGuardianNotification();
  });

  // Periodic self-heal: nudge the guardian notification so it stays alive
  // in the eyes of the OS even across long idle stretches, without
  // interrupting an active timer's own richer notification. Also drives
  // auto-send: since Android has no reliable way to run app code at an
  // exact instant while fully closed, this tick is what makes auto-send
  // fire even if the user never opens the app on report day — every 15
  // minutes it checks whether it's report day/time and, if so, sends (or
  // retries a previously-queued) report via AutoSendRunner.
  Timer.periodic(const Duration(minutes: 15), (_) async {
    if (!timerActive) {
      showGuardianNotification();
    }
    await AutoSendRunner.trySendPending();
    await AutoSendRunner.checkAutoSend();
  });
}
