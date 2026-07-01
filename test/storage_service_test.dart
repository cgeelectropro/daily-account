import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:daily_account/models/daily_log.dart';

/// Direct DB tests that exercise the schema and migration logic
/// without relying on the singleton StorageService (which uses SharedPreferences).
void main() {
  // Use FFI for desktop testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// Helper: open an in-memory database with the same schema as the app (v10).
  Future<Database> openTestDb() async {
    return openDatabase(
      inMemoryDatabasePath,
      version: 10,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE logs (
            dateKey TEXT PRIMARY KEY,
            bibleReference TEXT,
            bibleChapters TEXT,
            literature TEXT,
            ddegScripture TEXT,
            ddegTime TEXT,
            ddegNotes TEXT,
            prayerAloneDuration TEXT,
            prayerAloneNotes TEXT,
            prayerOthersDuration TEXT,
            prayerOthersContext TEXT,
            evangelismContacts TEXT,
            evangelismOutcome TEXT,
            evangelismNotes TEXT,
            other TEXT,
            aiReflection TEXT,
            completed INTEGER,
            fastingType TEXT DEFAULT '',
            fastingDuration TEXT DEFAULT '',
            fastingPrayerFocus TEXT DEFAULT '',
            givingType TEXT DEFAULT '',
            givingAmount TEXT DEFAULT '',
            givingPurpose TEXT DEFAULT '',
            churchType TEXT DEFAULT '',
            churchNotes TEXT DEFAULT '',
            discipleshipWho TEXT DEFAULT '',
            discipleshipTopic TEXT DEFAULT '',
            discipleshipDuration TEXT DEFAULT '',
            proclamationCount TEXT DEFAULT '',
            proclamationDuration TEXT DEFAULT '',
            evangelismNewBelievers TEXT DEFAULT '',
            evangelismBeingDiscipled TEXT DEFAULT '',
            evangelismFollowUpNotes TEXT DEFAULT '',
            voiceNotePath TEXT DEFAULT '',
            bibleSessions TEXT DEFAULT '',
            bibleDuration TEXT DEFAULT '',
            literatureDuration TEXT DEFAULT '',
            evangelismDuration TEXT DEFAULT '',
            givingDuration TEXT DEFAULT '',
            churchDuration TEXT DEFAULT '',
            custom_activity_data TEXT DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE saved_reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            weekStart TEXT,
            weekEnd TEXT,
            fullReport TEXT,
            compactReport TEXT,
            generatedAt TEXT,
            sentVia TEXT DEFAULT '',
            sentAt TEXT DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE prayer_requests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            description TEXT DEFAULT '',
            category TEXT DEFAULT 'personal',
            createdAt TEXT,
            answeredAt TEXT DEFAULT '',
            answerNote TEXT DEFAULT '',
            isAnswered INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE fasting_periods (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            startDate TEXT,
            endDate TEXT,
            type TEXT,
            prayerFocus TEXT DEFAULT '',
            completed INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  group('Database schema', () {
    test('logs table accepts full DailyLog data', () async {
      final db = await openTestDb();
      final log = DailyLog(
        dateKey: '2025-01-15',
        bibleReference: 'John 3',
        bibleChapters: '5',
        ddegScripture: 'Ps 23',
        prayerAloneDuration: '30 minutes',
        evangelismContacts: '2',
        fastingType: 'Daniel',
        givingType: 'tithe',
        churchType: 'Sunday',
        discipleshipWho: 'John',
        proclamationCount: '5',
      );
      await db.insert('logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      final rows = await db.query('logs', where: 'dateKey = ?', whereArgs: ['2025-01-15']);
      expect(rows.length, 1);
      final restored = DailyLog.fromMap(rows.first);
      expect(restored.dateKey, '2025-01-15');
      expect(restored.bibleReference, 'John 3');
      expect(restored.bibleChapters, '5');
      expect(restored.ddegScripture, 'Ps 23');
      expect(restored.prayerAloneDuration, '30 minutes');
      await db.close();
    });

    test('logs table upserts on same dateKey', () async {
      final db = await openTestDb();
      final log1 = DailyLog(dateKey: '2025-01-15', bibleReference: 'John 3');
      await db.insert('logs', log1.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      final log2 = DailyLog(dateKey: '2025-01-15', bibleReference: 'John 5');
      await db.insert('logs', log2.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      final rows = await db.query('logs');
      expect(rows.length, 1);
      expect(DailyLog.fromMap(rows.first).bibleReference, 'John 5');
      await db.close();
    });

    test('logs query between dates', () async {
      final db = await openTestDb();
      for (int i = 10; i <= 20; i++) {
        final log = DailyLog(dateKey: '2025-01-$i');
        await db.insert('logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final rows = await db.query(
        'logs',
        where: 'dateKey >= ? AND dateKey <= ?',
        whereArgs: ['2025-01-13', '2025-01-17'],
        orderBy: 'dateKey ASC',
      );
      expect(rows.length, 5);
      expect(rows.first['dateKey'], '2025-01-13');
      expect(rows.last['dateKey'], '2025-01-17');
      await db.close();
    });
  });

  group('Database CRUD for saved_reports', () {
    test('insert and query saved report', () async {
      final db = await openTestDb();
      await db.insert('saved_reports', {
        'weekStart': '2025-01-06',
        'weekEnd': '2025-01-12',
        'fullReport': 'Full',
        'compactReport': 'Compact',
        'generatedAt': '2025-01-12T18:00:00',
        'sentVia': 'email',
        'sentAt': '2025-01-12T19:00:00',
      });

      final rows = await db.query('saved_reports');
      expect(rows.length, 1);
      expect(rows.first['weekStart'], '2025-01-06');
      expect(rows.first['sentVia'], 'email');
      await db.close();
    });
  });

  group('Database CRUD for prayer_requests', () {
    test('insert and query prayer request', () async {
      final db = await openTestDb();
      final id = await db.insert('prayer_requests', {
        'title': 'Healing',
        'description': 'For brother',
        'category': 'church',
        'createdAt': '2025-01-01',
        'isAnswered': 0,
      });
      expect(id, greaterThan(0));

      final rows = await db.query('prayer_requests');
      expect(rows.length, 1);
      expect(rows.first['title'], 'Healing');
      await db.close();
    });

    test('update prayer request as answered', () async {
      final db = await openTestDb();
      final id = await db.insert('prayer_requests', {
        'title': 'Healing',
        'createdAt': '2025-01-01',
        'isAnswered': 0,
      });
      await db.update('prayer_requests', {
        'isAnswered': 1,
        'answeredAt': '2025-01-15',
        'answerNote': 'Healed!',
      }, where: 'id = ?', whereArgs: [id]);

      final rows = await db.query('prayer_requests', where: 'id = ?', whereArgs: [id]);
      expect(rows.first['isAnswered'], 1);
      expect(rows.first['answeredAt'], '2025-01-15');
      await db.close();
    });
  });

  group('Database CRUD for fasting_periods', () {
    test('insert and query fasting period', () async {
      final db = await openTestDb();
      await db.insert('fasting_periods', {
        'startDate': '2025-01-10',
        'endDate': '2025-01-13',
        'type': 'complete',
        'prayerFocus': 'Family',
        'completed': 0,
      });

      final rows = await db.query('fasting_periods', where: 'completed = 0');
      expect(rows.length, 1);
      expect(rows.first['type'], 'complete');
      await db.close();
    });

    test('end fasting period', () async {
      final db = await openTestDb();
      final id = await db.insert('fasting_periods', {
        'startDate': '2025-01-10',
        'endDate': '2025-01-13',
        'type': 'partial',
        'completed': 0,
      });
      await db.update('fasting_periods', {'completed': 1},
          where: 'id = ?', whereArgs: [id]);

      final rows = await db.query('fasting_periods', where: 'completed = 0');
      expect(rows, isEmpty);
      await db.close();
    });
  });

  group('Transaction safety', () {
    test('transaction rolls back on failure', () async {
      final db = await openTestDb();
      // Insert a log
      await db.insert('logs', DailyLog(dateKey: '2025-01-01').toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      try {
        await db.transaction((txn) async {
          // Delete the log
          await txn.delete('logs', where: 'dateKey = ?', whereArgs: ['2025-01-01']);
          // Force a failure
          throw Exception('Simulated failure');
        });
      } catch (_) {}

      // Log should still exist because transaction rolled back
      final rows = await db.query('logs', where: 'dateKey = ?', whereArgs: ['2025-01-01']);
      expect(rows.length, 1);
      await db.close();
    });

    test('transaction commits on success', () async {
      final db = await openTestDb();
      await db.transaction((txn) async {
        await txn.insert('logs', DailyLog(dateKey: '2025-01-01').toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.insert('logs', DailyLog(dateKey: '2025-01-02').toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      });

      final rows = await db.query('logs', orderBy: 'dateKey ASC');
      expect(rows.length, 2);
      expect(rows[0]['dateKey'], '2025-01-01');
      expect(rows[1]['dateKey'], '2025-01-02');
      await db.close();
    });
  });

  group('Migration simulation', () {
    test('v1 to v10 migration adds all columns', () async {
      // Create a v1-like database (minimal schema)
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 10,
        onCreate: (db, version) async {
          // Simulate v1 schema
          await db.execute('''
            CREATE TABLE logs (
              dateKey TEXT PRIMARY KEY,
              bibleReference TEXT,
              bibleChapters TEXT,
              literature TEXT,
              ddegScripture TEXT,
              ddegTime TEXT,
              ddegNotes TEXT,
              prayerAloneDuration TEXT,
              prayerAloneNotes TEXT,
              prayerOthersDuration TEXT,
              prayerOthersContext TEXT,
              evangelismContacts TEXT,
              evangelismOutcome TEXT,
              evangelismNotes TEXT,
              other TEXT,
              aiReflection TEXT,
              completed INTEGER
            )
          ''');
          // Simulate migrations v2-v9 in a transaction (matching new code)
          await db.transaction((txn) async {
            // v2 columns
            for (final col in [
              'fastingType', 'fastingDuration', 'fastingPrayerFocus',
              'givingType', 'givingAmount', 'givingPurpose',
              'churchType', 'churchNotes',
              'discipleshipWho', 'discipleshipTopic', 'discipleshipDuration',
            ]) {
              await txn.execute("ALTER TABLE logs ADD COLUMN $col TEXT DEFAULT ''");
            }
            // v3 table
            await txn.execute('''
              CREATE TABLE IF NOT EXISTS saved_reports (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                weekStart TEXT, weekEnd TEXT,
                fullReport TEXT, compactReport TEXT, generatedAt TEXT,
                sentVia TEXT DEFAULT '', sentAt TEXT DEFAULT ''
              )
            ''');
            // v4 columns
            await txn.execute("ALTER TABLE logs ADD COLUMN proclamationCount TEXT DEFAULT ''");
            await txn.execute("ALTER TABLE logs ADD COLUMN proclamationDuration TEXT DEFAULT ''");
            // v5 table
            await txn.execute('''
              CREATE TABLE IF NOT EXISTS prayer_requests (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT, description TEXT DEFAULT '', category TEXT DEFAULT 'personal',
                createdAt TEXT, answeredAt TEXT DEFAULT '', answerNote TEXT DEFAULT '',
                isAnswered INTEGER DEFAULT 0
              )
            ''');
            // v6 columns
            for (final col in ['evangelismNewBelievers', 'evangelismBeingDiscipled', 'evangelismFollowUpNotes']) {
              await txn.execute("ALTER TABLE logs ADD COLUMN $col TEXT DEFAULT ''");
            }
            // v7 column
            await txn.execute("ALTER TABLE logs ADD COLUMN voiceNotePath TEXT DEFAULT ''");
            // v8 table
            await txn.execute('''
              CREATE TABLE IF NOT EXISTS fasting_periods (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                startDate TEXT, endDate TEXT, type TEXT,
                prayerFocus TEXT DEFAULT '', completed INTEGER DEFAULT 0
              )
            ''');
            // v9 column
            await txn.execute("ALTER TABLE logs ADD COLUMN bibleSessions TEXT DEFAULT ''");
            // v10 columns
            for (final col in [
              'bibleDuration', 'literatureDuration', 'evangelismDuration',
              'givingDuration', 'churchDuration', 'custom_activity_data',
            ]) {
              await txn.execute("ALTER TABLE logs ADD COLUMN $col TEXT DEFAULT ''");
            }
          });
        },
      );

      // Verify all columns exist by inserting a full DailyLog
      final log = DailyLog(
        dateKey: '2025-06-01',
        bibleReference: 'Test',
        bibleSessions: [BibleReadingEntry(startBook: 'Genesis', startChapter: 1)],
        proclamationCount: '5',
        evangelismNewBelievers: '1',
        voiceNotePath: '/test',
      );
      await db.insert('logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      final rows = await db.query('logs');
      expect(rows.length, 1);
      final restored = DailyLog.fromMap(rows.first);
      expect(restored.bibleReference, 'Test');
      expect(restored.proclamationCount, '5');
      expect(restored.evangelismNewBelievers, '1');
      expect(restored.voiceNotePath, '/test');
      expect(restored.bibleSessions.length, 1);

      // Verify all tables exist
      await db.insert('saved_reports', {
        'weekStart': '2025-06-02', 'weekEnd': '2025-06-08',
        'fullReport': '', 'compactReport': '', 'generatedAt': '',
      });
      await db.insert('prayer_requests', {'title': 'test', 'createdAt': ''});
      await db.insert('fasting_periods', {
        'startDate': '', 'endDate': '', 'type': 'complete',
      });

      expect((await db.query('saved_reports')).length, 1);
      expect((await db.query('prayer_requests')).length, 1);
      expect((await db.query('fasting_periods')).length, 1);

      await db.close();
    });
  });

  group('BibleSessions persistence', () {
    test('stores and retrieves bible sessions as JSON', () async {
      final db = await openTestDb();
      final log = DailyLog(
        dateKey: '2025-01-15',
        bibleSessions: [
          BibleReadingEntry(
            startBook: 'Genesis',
            startChapter: 1,
            endBook: 'Genesis',
            endChapter: 3,
            chaptersRead: 3,
          ),
          BibleReadingEntry(
            startBook: 'John',
            startChapter: 1,
            endBook: 'John',
            endChapter: 5,
            chaptersRead: 5,
          ),
        ],
      );
      await db.insert('logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      final rows = await db.query('logs', where: 'dateKey = ?', whereArgs: ['2025-01-15']);
      final restored = DailyLog.fromMap(rows.first);
      expect(restored.bibleSessions.length, 2);
      expect(restored.bibleSessions[0].startBook, 'Genesis');
      expect(restored.bibleSessions[0].chaptersRead, 3);
      expect(restored.bibleSessions[1].startBook, 'John');
      expect(restored.bibleSessions[1].chaptersRead, 5);
      expect(restored.totalSessionChapters, 8);
      await db.close();
    });

    test('empty bibleSessions column deserializes to empty list', () async {
      final db = await openTestDb();
      await db.insert('logs', {
        'dateKey': '2025-01-15',
        'bibleReference': '',
        'bibleChapters': '',
        'bibleSessions': '',
        'literature': '[]',
        'ddegScripture': '', 'ddegTime': '', 'ddegNotes': '',
        'prayerAloneDuration': '', 'prayerAloneNotes': '',
        'prayerOthersDuration': '', 'prayerOthersContext': '',
        'evangelismContacts': '', 'evangelismOutcome': '', 'evangelismNotes': '',
        'other': '', 'aiReflection': '', 'completed': 0,
      });

      final rows = await db.query('logs');
      final restored = DailyLog.fromMap(rows.first);
      expect(restored.bibleSessions, isEmpty);
      await db.close();
    });
  });
}
