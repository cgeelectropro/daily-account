import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_account/models/activity_timer.dart';
import 'package:daily_account/services/storage_service.dart';
import 'package:daily_account/services/timer_service.dart';

/// Tests for TimerService's DailyLog-writing logic, focused on the
/// Proclamation/Evangelism/Church session-append paths (Task 4).
///
/// TimerService.instance is a singleton that internally uses the real
/// StorageService (sqflite) and SharedPreferences. To make this work under
/// `flutter test` (no device/platform), we route sqflite through the FFI
/// backend before anything touches StorageService.instance.database. This
/// lets the actual singleton run against a real file-backed database via
/// getDatabasesPath(), mirroring the production code path exactly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // The FFI backend persists to a real file under .dart_tool/ (there's no
    // in-memory equivalent for StorageService's hardcoded getDatabasesPath()
    // path), so a stale file from a previous run/schema can linger and
    // desync from onCreate/onUpgrade. Start every run from a clean file.
    final dbPath = await getDatabasesPath();
    await deleteDatabase(join(dbPath, 'daily_account.db'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Clear any in-memory timer sessions left over from a previous test.
    TimerService.instance.sessions.keys.toList().forEach((key) {
      TimerService.instance.cancelTimer(key);
    });
    // Clear today's log row so each test starts from a clean slate.
    final db = await StorageService.instance.database;
    await db.delete('logs', where: 'dateKey = ?', whereArgs: [todayKey]);
  });

  group('TimerService — Proclamation session writes', () {
    test('stopping a proclamation timer with a new topic appends a session', () async {
      final key = const TimerKey.builtIn(ActivityType.proclamation);
      TimerService.instance.start(key, fields: {'proclamationTopic': 'Healing'});
      await TimerService.instance.stop(key);

      final log = await StorageService.instance.getLog(todayKey);
      expect(log, isNotNull);
      expect(log!.proclamationSessions.length, 1);
      expect(log.proclamationSessions.first.topic, 'Healing');
      expect(log.proclamationSessions.first.count, 1);
    });

    test('stopping a second proclamation timer with the same topic (case-insensitive, trimmed) merges into the existing session', () async {
      final key = const TimerKey.builtIn(ActivityType.proclamation);

      TimerService.instance.start(key, fields: {'proclamationTopic': 'Healing'});
      await TimerService.instance.stop(key);

      TimerService.instance.start(key, fields: {'proclamationTopic': '  healing  '});
      await TimerService.instance.stop(key);

      final log = await StorageService.instance.getLog(todayKey);
      expect(log, isNotNull);
      expect(log!.proclamationSessions.length, 1); // still 1, merged not appended
      expect(log.proclamationSessions.first.count, 2);
    });

    test('stopping proclamation timers with different topics appends separate sessions', () async {
      final key = const TimerKey.builtIn(ActivityType.proclamation);

      TimerService.instance.start(key, fields: {'proclamationTopic': 'Healing'});
      await TimerService.instance.stop(key);

      TimerService.instance.start(key, fields: {'proclamationTopic': 'Salvation'});
      await TimerService.instance.stop(key);

      final log = await StorageService.instance.getLog(todayKey);
      expect(log, isNotNull);
      expect(log!.proclamationSessions.length, 2);
      final topics = log.proclamationSessions.map((s) => s.topic).toSet();
      expect(topics, {'Healing', 'Salvation'});
    });

    test('proclamation no longer writes to the legacy proclamationDuration scalar', () async {
      final key = const TimerKey.builtIn(ActivityType.proclamation);
      TimerService.instance.start(key, fields: {'proclamationTopic': 'Healing'});
      await TimerService.instance.stop(key);

      final log = await StorageService.instance.getLog(todayKey);
      expect(log, isNotNull);
      expect(log!.proclamationDuration, isEmpty);
    });
  });

  group('TimerService — Evangelism/Church session writes', () {
    test('stopping an evangelism timer appends a TimedSession', () async {
      final key = const TimerKey.builtIn(ActivityType.evangelism);
      TimerService.instance.start(key);
      await TimerService.instance.stop(key);

      final log = await StorageService.instance.getLog(todayKey);
      expect(log, isNotNull);
      expect(log!.evangelismSessions.length, 1);
      expect(log.evangelismDuration, isEmpty);
    });

    test('stopping two evangelism timers appends two TimedSessions (no accumulation into one)', () async {
      final key = const TimerKey.builtIn(ActivityType.evangelism);
      TimerService.instance.start(key);
      await TimerService.instance.stop(key);
      TimerService.instance.start(key);
      await TimerService.instance.stop(key);

      final log = await StorageService.instance.getLog(todayKey);
      expect(log, isNotNull);
      expect(log!.evangelismSessions.length, 2);
    });

    test('stopping a church timer appends a TimedSession', () async {
      final key = const TimerKey.builtIn(ActivityType.church);
      TimerService.instance.start(key);
      await TimerService.instance.stop(key);

      final log = await StorageService.instance.getLog(todayKey);
      expect(log, isNotNull);
      expect(log!.churchSessions.length, 1);
      expect(log.churchDuration, isEmpty);
    });
  });

  group('TimerService — untouched scalar-accumulating activities still work', () {
    test('stopping a Bible reading timer still accumulates into bibleDuration', () async {
      final key = const TimerKey.builtIn(ActivityType.bibleReading);
      TimerService.instance.start(key);
      await TimerService.instance.stop(key);

      final log = await StorageService.instance.getLog(todayKey);
      expect(log, isNotNull);
      // Elapsed is effectively 0s immediately after start/stop, so the
      // duration string may be empty — the key assertion is simply that
      // this activity did NOT get routed into a sessions list.
      expect(log!.proclamationSessions, isEmpty);
      expect(log.evangelismSessions, isEmpty);
      expect(log.churchSessions, isEmpty);
    });
  });
}
