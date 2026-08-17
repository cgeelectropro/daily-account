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

  group('TimerService — literature writes a real entry', () {
    test('stopping a literature timer with a title creates a LiteratureEntry, not a no-op', () async {
      final key = TimerKey.builtIn(ActivityType.literature);
      TimerService.instance.start(key, fields: {'literatureTitle': 'Mere Christianity'});
      await TimerService.instance.stop(key);
      final log = await StorageService.instance.getLog(
          DateFormat('yyyy-MM-dd').format(DateTime.now()));
      expect(log!.literature.any((l) => l.title == 'Mere Christianity'), true);
    });
  });

  group('TimerService — untouched scalar-accumulating activities still work', () {
    test('stopping a Bible reading timer without reference fields does not write a session or legacy scalar', () async {
      final key = const TimerKey.builtIn(ActivityType.bibleReading);
      TimerService.instance.start(key);
      await TimerService.instance.stop(key);

      final log = await StorageService.instance.getLog(todayKey);
      expect(log, isNotNull);
      // No bibleStartBook field was supplied, so _appendBibleSession is a
      // no-op — nothing should land in bibleSessions, and the legacy
      // bibleDuration scalar is no longer written by this path at all.
      expect(log!.bibleSessions, isEmpty);
      expect(log.bibleDuration, isEmpty);
      expect(log.proclamationSessions, isEmpty);
      expect(log.evangelismSessions, isEmpty);
      expect(log.churchSessions, isEmpty);
    });
  });

  group('TimerService — DDEG/Prayer session writes', () {
    test('stopping a ddeg timer appends a DdegSession, not just ddegTime scalar', () async {
      const key = TimerKey.builtIn(ActivityType.ddeg);
      TimerService.instance.start(key, fields: {'ddegScripture': 'Psalm 23'});
      await TimerService.instance.stop(key);
      final log = await StorageService.instance.getLog(todayKey);
      expect(log!.ddegSessions.any((s) => s.scripture == 'Psalm 23'), true);
      expect(log.ddegTime, isEmpty);
    });

    test('stopping a prayer-alone timer with a title appends a PrayerSession under that title', () async {
      const key = TimerKey.builtIn(ActivityType.prayerAlone);
      TimerService.instance.start(key, fields: {'prayerAloneTitle': 'Healing for Mom'});
      await TimerService.instance.stop(key);
      final log = await StorageService.instance.getLog(todayKey);
      expect(log!.prayerAloneSessions.any((s) => s.title == 'Healing for Mom'), true);
      expect(log.prayerAloneDuration, isEmpty);
    });

    test('a second prayer-alone timer with the same title merges duration into the existing session', () async {
      // Seeded within this test body (rather than relying on state left
      // over from the previous test) because this file's setUp() clears
      // TimerService sessions and today's log row before every test.
      const key = TimerKey.builtIn(ActivityType.prayerAlone);

      TimerService.instance.start(key, fields: {'prayerAloneTitle': 'Healing for Mom'});
      await TimerService.instance.stop(key);

      TimerService.instance.start(key, fields: {'prayerAloneTitle': 'healing for mom'});
      await TimerService.instance.stop(key);

      final log = await StorageService.instance.getLog(todayKey);
      final matching = log!.prayerAloneSessions
          .where((s) => s.title.toLowerCase() == 'healing for mom');
      expect(matching.length, 1); // merged, not duplicated
    });

    test('stopping a prayer-with-others timer with a title appends a PrayerSession under that title', () async {
      const key = TimerKey.builtIn(ActivityType.prayerOthers);
      TimerService.instance.start(key, fields: {'prayerOthersTitle': 'Cell group intercession'});
      await TimerService.instance.stop(key);
      final log = await StorageService.instance.getLog(todayKey);
      expect(log!.prayerOthersSessions.any((s) => s.title == 'Cell group intercession'), true);
      expect(log.prayerOthersDuration, isEmpty);
    });
  });
}
