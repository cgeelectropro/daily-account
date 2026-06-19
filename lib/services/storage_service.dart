import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/custom_activity.dart';
import '../models/daily_log.dart';
import '../models/fasting_period.dart';
import '../models/prayer_request.dart';
import '../models/saved_report.dart';

/// Handles all persistence: a SQLite table for daily logs, and
/// SharedPreferences for lightweight user settings.
class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'daily_account.db');
    return openDatabase(
      path,
      version: 8,
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
            voiceNotePath TEXT DEFAULT ''
          )
        ''');
        await _createSavedReportsTable(db);
        await _createPrayerRequestsTable(db);
        await _createFastingPeriodsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          final newCols = [
            'fastingType', 'fastingDuration', 'fastingPrayerFocus',
            'givingType', 'givingAmount', 'givingPurpose',
            'churchType', 'churchNotes',
            'discipleshipWho', 'discipleshipTopic', 'discipleshipDuration',
          ];
          for (final col in newCols) {
            await db.execute("ALTER TABLE logs ADD COLUMN $col TEXT DEFAULT ''");
          }
        }
        if (oldVersion < 3) {
          await _createSavedReportsTable(db);
        }
        if (oldVersion < 4) {
          await db.execute("ALTER TABLE logs ADD COLUMN proclamationCount TEXT DEFAULT ''");
          await db.execute("ALTER TABLE logs ADD COLUMN proclamationDuration TEXT DEFAULT ''");
        }
        if (oldVersion < 5) {
          await _createPrayerRequestsTable(db);
        }
        if (oldVersion < 6) {
          for (final col in ['evangelismNewBelievers', 'evangelismBeingDiscipled', 'evangelismFollowUpNotes']) {
            await db.execute("ALTER TABLE logs ADD COLUMN $col TEXT DEFAULT ''");
          }
        }
        if (oldVersion < 7) {
          await db.execute("ALTER TABLE logs ADD COLUMN voiceNotePath TEXT DEFAULT ''");
        }
        if (oldVersion < 8) {
          await _createFastingPeriodsTable(db);
        }
      },
    );
  }

  static Future<void> _createSavedReportsTable(Database db) async {
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
  }

  static Future<void> _createPrayerRequestsTable(Database db) async {
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
  }

  static Future<void> _createFastingPeriodsTable(Database db) async {
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
  }

  // ── Fasting Periods CRUD ────────────────────────────────
  Future<int> addFastingPeriod(FastingPeriod period) async {
    final db = await database;
    return db.insert('fasting_periods', period.toMap());
  }

  Future<FastingPeriod?> getActiveFastingPeriod() async {
    final db = await database;
    final rows = await db.query(
      'fasting_periods',
      where: 'completed = 0',
      orderBy: 'startDate DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final period = FastingPeriod.fromMap(rows.first);
    return period.isActive ? period : null;
  }

  Future<List<FastingPeriod>> getFastingHistory() async {
    final db = await database;
    final rows = await db.query('fasting_periods', orderBy: 'startDate DESC');
    return rows.map((r) => FastingPeriod.fromMap(r)).toList();
  }

  Future<void> endFastingPeriod(int id) async {
    final db = await database;
    await db.update('fasting_periods', {'completed': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteFastingPeriod(int id) async {
    final db = await database;
    await db.delete('fasting_periods', where: 'id = ?', whereArgs: [id]);
  }

  // ── Prayer Requests CRUD ────────────────────────────────
  Future<int> addPrayerRequest(PrayerRequest req) async {
    final db = await database;
    return db.insert('prayer_requests', req.toMap());
  }

  Future<void> updatePrayerRequest(PrayerRequest req) async {
    final db = await database;
    await db.update('prayer_requests', req.toMap(),
        where: 'id = ?', whereArgs: [req.id]);
  }

  Future<void> deletePrayerRequest(int id) async {
    final db = await database;
    await db.delete('prayer_requests', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PrayerRequest>> getPrayerRequests({bool? answered}) async {
    final db = await database;
    String? where;
    List<Object>? whereArgs;
    if (answered != null) {
      where = 'isAnswered = ?';
      whereArgs = [answered ? 1 : 0];
    }
    final rows = await db.query('prayer_requests',
        where: where, whereArgs: whereArgs, orderBy: 'createdAt DESC');
    return rows.map((r) => PrayerRequest.fromMap(r)).toList();
  }

  Future<int> getPrayerRequestCount({bool? answered}) async {
    final db = await database;
    String query = 'SELECT COUNT(*) as cnt FROM prayer_requests';
    List<Object>? args;
    if (answered != null) {
      query += ' WHERE isAnswered = ?';
      args = [answered ? 1 : 0];
    }
    final result = await db.rawQuery(query, args);
    return result.first['cnt'] as int;
  }

  // ── Log CRUD ──────────────────────────────────────────────
  Future<void> saveLog(DailyLog log) async {
    final db = await database;
    await db.insert('logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DailyLog?> getLog(String dateKey) async {
    final db = await database;
    final rows = await db.query('logs', where: 'dateKey = ?', whereArgs: [dateKey]);
    if (rows.isEmpty) return null;
    return DailyLog.fromMap(rows.first);
  }

  Future<List<DailyLog>> getLogsBetween(String start, String end) async {
    final db = await database;
    final rows = await db.query(
      'logs',
      where: 'dateKey >= ? AND dateKey <= ?',
      whereArgs: [start, end],
      orderBy: 'dateKey ASC',
    );
    return rows.map((r) => DailyLog.fromMap(r)).toList();
  }

  Future<List<DailyLog>> getAllLogs() async {
    final db = await database;
    final rows = await db.query('logs', orderBy: 'dateKey DESC');
    return rows.map((r) => DailyLog.fromMap(r)).toList();
  }

  // ── Settings (SharedPreferences) ──────────────────────────
  Future<void> setSetting(String key, String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, value);
  }

  Future<String> getSetting(String key, {String fallback = ''}) async {
    final p = await SharedPreferences.getInstance();
    return p.getString(key) ?? fallback;
  }

  // ── Saved Reports (Archive) ────────────────────────────────

  Future<void> saveReport({
    required String weekStart,
    required String weekEnd,
    required String fullReport,
    required String compactReport,
    String sentVia = '',
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    // Upsert: if a report for this week already exists, update it
    final existing = await db.query(
      'saved_reports',
      where: 'weekStart = ?',
      whereArgs: [weekStart],
    );
    if (existing.isNotEmpty) {
      await db.update(
        'saved_reports',
        {
          'fullReport': fullReport,
          'compactReport': compactReport,
          'generatedAt': now,
          if (sentVia.isNotEmpty) 'sentVia': sentVia,
          if (sentVia.isNotEmpty) 'sentAt': now,
        },
        where: 'weekStart = ?',
        whereArgs: [weekStart],
      );
    } else {
      await db.insert('saved_reports', {
        'weekStart': weekStart,
        'weekEnd': weekEnd,
        'fullReport': fullReport,
        'compactReport': compactReport,
        'generatedAt': now,
        'sentVia': sentVia,
        'sentAt': sentVia.isNotEmpty ? now : '',
      });
    }
  }

  Future<List<SavedReport>> getAllReports() async {
    final db = await database;
    final rows = await db.query('saved_reports', orderBy: 'weekStart DESC');
    return rows.map((r) => SavedReport.fromMap(r)).toList();
  }

  Future<SavedReport?> getReport(String weekStart) async {
    final db = await database;
    final rows = await db.query(
      'saved_reports',
      where: 'weekStart = ?',
      whereArgs: [weekStart],
    );
    if (rows.isEmpty) return null;
    return SavedReport.fromMap(rows.first);
  }

  Future<void> deleteReport(int id) async {
    final db = await database;
    await db.delete('saved_reports', where: 'id = ?', whereArgs: [id]);
  }

  // ── Custom Activities ──────────────────────────────────────

  static const _customActivitiesKey = 'custom_activities';

  Future<List<CustomActivity>> getCustomActivities() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_customActivitiesKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => CustomActivity.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveCustomActivities(List<CustomActivity> activities) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _customActivitiesKey,
      jsonEncode(activities.map((a) => a.toMap()).toList()),
    );
  }

  Future<void> addCustomActivity(CustomActivity activity) async {
    final list = await getCustomActivities();
    list.add(activity);
    await saveCustomActivities(list);
  }

  Future<void> removeCustomActivity(String id) async {
    final list = await getCustomActivities();
    list.removeWhere((a) => a.id == id);
    await saveCustomActivities(list);
  }

  // ── Pending Report Queue (offline-aware) ──────────────────

  static const _pendingReportKey = 'pending_report';

  /// Queue a report to be sent when connectivity is available.
  Future<void> queuePendingReport(String compactReport, String whatsapp) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_pendingReportKey, jsonEncode({
      'report': compactReport,
      'whatsapp': whatsapp,
      'queuedAt': DateTime.now().toIso8601String(),
    }));
  }

  /// Get a pending report (null if none queued).
  Future<Map<String, dynamic>?> getPendingReport() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_pendingReportKey);
    if (raw == null || raw.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  /// Clear the pending report after successful send.
  Future<void> clearPendingReport() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_pendingReportKey);
  }

  /// Delete all logs and clear all settings. Used for factory reset.
  Future<void> resetAll() async {
    final db = await database;
    await db.delete('logs');
    await db.delete('saved_reports');
    final p = await SharedPreferences.getInstance();
    await p.clear();
  }
}
