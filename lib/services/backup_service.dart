import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../models/custom_activity.dart';
import '../models/daily_log.dart';
import '../models/fasting_period.dart';
import '../models/prayer_request.dart';
import '../models/saved_report.dart';
import 'storage_service.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  /// Maximum number of rolling auto-backups to keep
  static const _maxAutoBackups = 3;

  // ═════════════════════════════════════════════════════════════
  //  AUTO-BACKUP — runs silently on every app start
  // ═════════════════════════════════════════════════════════════

  /// Run a silent auto-backup to the app's documents directory.
  /// Keeps the last [_maxAutoBackups] files, deletes older ones.
  /// Safe to call on every app start — skips if last backup was < 6 hours ago.
  Future<void> autoBackup() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/auto_backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // Check if we backed up recently (within 6 hours)
      final existing = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (existing.isNotEmpty) {
        final lastBackup = existing.first.lastModifiedSync();
        if (DateTime.now().difference(lastBackup).inHours < 6) return;
      }

      // Build backup data
      final data = await buildFullBackupData();
      if (data == null) return;

      final json = const JsonEncoder.withIndent('  ').convert(data);
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final file = File('${backupDir.path}/auto_backup_$timestamp.json');
      await file.writeAsString(json);

      // Prune old backups — keep only the newest _maxAutoBackups
      final allBackups = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (allBackups.length > _maxAutoBackups) {
        for (final old in allBackups.sublist(_maxAutoBackups)) {
          await old.delete();
        }
      }
    } catch (_) {
      // Auto-backup is best-effort — never crash the app
    }
  }

  /// Restore from the most recent auto-backup (for recovery after data loss).
  /// Returns null if no auto-backup exists.
  Future<Map<String, dynamic>?> getLatestAutoBackup() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${dir.path}/auto_backups');
      if (!await backupDir.exists()) return null;

      final backups = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (backups.isEmpty) return null;

      final json = await backups.first.readAsString();
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Build a comprehensive backup of ALL app data.
  ///
  /// Includes: logs, saved reports, prayer requests, fasting periods,
  /// custom activities, and all user settings.
  Future<Map<String, dynamic>?> buildFullBackupData() async {
    try {
      final storage = StorageService.instance;
      final logs = await storage.getAllLogs();
      final reports = await storage.getAllReports();
      final prayerRequests = await storage.getPrayerRequests();
      final fastingPeriods = await storage.getFastingHistory();
      final customActivities = await storage.getCustomActivities();

      // Nothing at all to back up
      if (logs.isEmpty && prayerRequests.isEmpty && reports.isEmpty
          && fastingPeriods.isEmpty && customActivities.isEmpty) {
        return null;
      }

      // Comprehensive settings list
      final settingsKeys = [
        'myName', 'discipleEmail', 'discipleWhatsApp', 'language',
        'dailyHour', 'dailyMin', 'sundayHour', 'sundayMin',
        'appLockEnabled', 'useBiometrics', 'themeMode',
        'notificationsEnabled', 'autoSendEnabled',
        'autoSendHour', 'autoSendMin',
        'dailyFollowUps', 'sundayFollowUps',
        'goalFrequency', 'goalBibleChapters', 'goalPrayerMinutes',
        'goalEvangelismContacts', 'goalLiteratureItems',
        'reportLanguage', 'textScale', 'onboarding_complete',
        ...List.generate(11, (i) => 'discReminder_$i'),
      ];

      final settings = <String, String>{};
      for (final key in settingsKeys) {
        final val = await storage.getSetting(key);
        if (val.isNotEmpty) settings[key] = val;
      }

      return {
        'version': 4,
        'exportDate': DateTime.now().toIso8601String(),
        'settings': settings,
        'logs': logs.map((l) => l.toMap()).toList(),
        'saved_reports': reports.map((r) => r.toMap()).toList(),
        'prayer_requests': prayerRequests.map((p) => p.toMap()).toList(),
        'fasting_periods': fastingPeriods.map((f) => f.toMap()).toList(),
        'custom_activities': customActivities.map((c) => c.toMap()).toList(),
      };
    } catch (_) {
      return null;
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  MANUAL EXPORT / IMPORT
  // ═════════════════════════════════════════════════════════════

  /// Export all logs and settings to a JSON file and share it
  Future<bool> exportData() async {
    final data = await buildFullBackupData();
    if (data == null) return false;
    data.remove('autoBackup'); // not an auto-backup
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getTemporaryDirectory();
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final file = File('${dir.path}/daily_account_backup_$date.json');
    await file.writeAsString(json);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Daily Account Backup'),
    );
    return true;
  }

  /// Pick a JSON file and preview its contents (returns null if cancelled/invalid)
  Future<Map<String, dynamic>?> pickAndPreview() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;
    try {
      final filePath = result.files.single.path;
      if (filePath == null) return null;
      final file = File(filePath);
      final json = await file.readAsString();
      final data = jsonDecode(json) as Map<String, dynamic>;
      if (!data.containsKey('logs')) return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Import data from a parsed backup. If merge=true, merges with existing. If false, replaces all.
  Future<bool> importData(Map<String, dynamic> data, {bool merge = true}) async {
    try {
      final storage = StorageService.instance;
      final db = await storage.database;

      // Wrap all DB operations in a transaction to prevent partial imports
      await db.transaction((txn) async {
        if (!merge) {
          await txn.delete('logs');
          await txn.delete('saved_reports');
          await txn.delete('prayer_requests');
          await txn.delete('fasting_periods');
        }

        // Restore logs
        if (data['logs'] != null) {
          final logs = (data['logs'] as List).cast<Map<String, dynamic>>();
          for (final logMap in logs) {
            final log = DailyLog.fromMap(logMap);
            await txn.insert('logs', log.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // Restore saved reports
        if (data['saved_reports'] != null) {
          final reports = (data['saved_reports'] as List).cast<Map<String, dynamic>>();
          for (final rMap in reports) {
            final report = SavedReport.fromMap(rMap);
            final existing = await txn.query('saved_reports',
                where: 'weekStart = ?', whereArgs: [report.weekStart]);
            if (existing.isNotEmpty) {
              await txn.update('saved_reports', {
                'fullReport': report.fullReport,
                'compactReport': report.compactReport,
                'generatedAt': report.generatedAt,
                if (report.sentVia.isNotEmpty) 'sentVia': report.sentVia,
                if (report.sentVia.isNotEmpty) 'sentAt': report.sentAt,
              }, where: 'weekStart = ?', whereArgs: [report.weekStart]);
            } else {
              final insertMap = Map<String, dynamic>.from(rMap);
              insertMap.remove('id');
              await txn.insert('saved_reports', insertMap);
            }
          }
        }

        // Restore prayer requests
        if (data['prayer_requests'] != null) {
          final prayers = (data['prayer_requests'] as List).cast<Map<String, dynamic>>();
          for (final pMap in prayers) {
            final req = PrayerRequest.fromMap(pMap);
            if (merge) {
              final existing = await txn.query('prayer_requests',
                where: 'title = ? AND createdAt = ?',
                whereArgs: [req.title, req.createdAt]);
              if (existing.isEmpty) {
                final insertMap = req.toMap()..remove('id');
                await txn.insert('prayer_requests', insertMap);
              }
            } else {
              final insertMap = req.toMap()..remove('id');
              await txn.insert('prayer_requests', insertMap);
            }
          }
        }

        // Restore fasting periods
        if (data['fasting_periods'] != null) {
          final periods = (data['fasting_periods'] as List).cast<Map<String, dynamic>>();
          for (final fMap in periods) {
            final period = FastingPeriod.fromMap(fMap);
            if (merge) {
              final existing = await txn.query('fasting_periods',
                where: 'startDate = ? AND endDate = ?',
                whereArgs: [period.startDate, period.endDate]);
              if (existing.isEmpty) {
                final insertMap = period.toMap()..remove('id');
                await txn.insert('fasting_periods', insertMap);
              }
            } else {
              final insertMap = period.toMap()..remove('id');
              await txn.insert('fasting_periods', insertMap);
            }
          }
        }
      });

      // Custom activities & settings are in SharedPreferences (not SQLite),
      // so they're outside the transaction
      if (data['custom_activities'] != null) {
        final activities = (data['custom_activities'] as List)
            .map((e) => CustomActivity.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        if (merge) {
          final existing = await storage.getCustomActivities();
          final existingIds = existing.map((a) => a.id).toSet();
          for (final a in activities) {
            if (!existingIds.contains(a.id)) existing.add(a);
          }
          await storage.saveCustomActivities(existing);
        } else {
          await storage.saveCustomActivities(activities);
        }
      }

      if (data['settings'] != null) {
        final settings = Map<String, String>.from(
          (data['settings'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
        );
        for (final entry in settings.entries) {
          if (entry.value.isNotEmpty) {
            await storage.setSetting(entry.key, entry.value);
          }
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
