import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification channel shared between [NotificationService] and the
/// background isolate so both write to the same Android channel.
const kTimerChannelId = 'daily_account_stopwatch_v2';
const kTimerChannelName = 'Activity Timer';
const kTimerNotifId = 200; // must match NotificationService.stopwatchNotifId

/// Manages an Android foreground service that keeps the activity timer
/// alive even when the Flutter UI is suspended.
///
/// Communication between the UI isolate and the background isolate uses
/// [FlutterBackgroundService.invoke] / [FlutterBackgroundService.on].
///
/// Events:
///   UI → BG:
///     "startTimer"  { label, icon, elapsedMs }
///     "pauseTimer"  { elapsedMs }
///     "stopTimer"   (no args)
///   BG → UI:
///     "timerTick"   { elapsedMs }   (every second while running)
class BackgroundTimerService {
  BackgroundTimerService._();
  static final BackgroundTimerService instance = BackgroundTimerService._();

  final _service = FlutterBackgroundService();
  bool _configured = false;

  /// Call once at app startup (before any timer interaction).
  Future<void> init() async {
    if (_configured) return;
    if (!Platform.isAndroid) {
      _configured = true;
      return;
    }

    try {
      // Create the notification channel up-front so the service can use it.
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
      }

      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onStart,
          autoStart: false, // only start when a timer starts
          autoStartOnBoot: false,
          isForegroundMode: true,
          notificationChannelId: kTimerChannelId,
          initialNotificationTitle: 'Daily Account',
          initialNotificationContent: 'Timer running…',
          foregroundServiceNotificationId: kTimerNotifId,
          foregroundServiceTypes: [AndroidForegroundType.specialUse],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
        ),
      );
    } catch (_) {
      // Background service configuration failed — timer will work
      // without foreground service (just won't survive backgrounding)
    }

    _configured = true;
  }

  /// Start the foreground service for a running timer.
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

  /// Stop the foreground service.
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
  String currentIcon = '\u23F1';

  void updateNotification({bool running = true, bool paused = false}) {
    final totalMs = running && startedAt != null
        ? elapsedMs + DateTime.now().difference(startedAt!).inMilliseconds
        : elapsedMs;

    // Action buttons matching NotificationService.showStopwatchNotification
    final actions = <AndroidNotificationAction>[
      if (running)
        const AndroidNotificationAction(
          'timer_pause', '\u23F8 Pause',
          showsUserInterface: false, cancelNotification: false,
        )
      else if (paused)
        const AndroidNotificationAction(
          'timer_resume', '\u25B6 Resume',
          showsUserInterface: false, cancelNotification: false,
        ),
      AndroidNotificationAction(
        'timer_stop', '\u23F9 Stop',
        showsUserInterface: currentLabel.contains('Bible') ||
            currentLabel.contains('Lecture') ||
            currentLabel.contains('Litt\u00e9rature'),
        cancelNotification: true,
      ),
      const AndroidNotificationAction(
        'timer_cancel', '\u2715 Cancel',
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

    final body = paused ? '\u23F8 Paused \u2014 $display' : '\u23F1 In progress \u2014 $display';

    plugin.show(
      kTimerNotifId,
      '$currentIcon $currentLabel',
      body,
      NotificationDetails(android: channel),
    );
  }

  service.on('startTimer').listen((data) {
    currentLabel = data?['label'] ?? 'Timer';
    currentIcon = data?['icon'] ?? '\u23F1';
    elapsedMs = data?['elapsedMs'] ?? 0;
    startedAt = DateTime.now();

    ticker?.cancel();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final totalMs = elapsedMs + now.difference(startedAt!).inMilliseconds;
      service.invoke('timerTick', {'elapsedMs': totalMs});
    });

    updateNotification();
  });

  service.on('pauseTimer').listen((data) {
    ticker?.cancel();
    ticker = null;
    elapsedMs = data?['elapsedMs'] ?? elapsedMs;
    currentLabel = data?['label'] ?? currentLabel;
    startedAt = null;
    updateNotification(running: false, paused: true);
  });

  service.on('stopTimer').listen((_) {
    ticker?.cancel();
    ticker = null;
    elapsedMs = 0;
    startedAt = null;
    plugin.cancel(kTimerNotifId);
    service.stopSelf();
  });
}
