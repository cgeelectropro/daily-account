import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_log.dart';

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
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE logs (
            dateKey TEXT PRIMARY KEY,
            bibleReference TEXT, bibleChapters TEXT, literature TEXT,
            ddegScripture TEXT, ddegTime TEXT, ddegNotes TEXT,
            prayerAloneDuration TEXT, prayerAloneNotes TEXT,
            prayerOthersDuration TEXT, prayerOthersContext TEXT,
            evangelismContacts TEXT, evangelismOutcome TEXT, evangelismNotes TEXT,
            other TEXT, aiReflection TEXT, completed INTEGER
          )
        ''');
      },
    );
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
}
