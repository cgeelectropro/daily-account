import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/daily_log.dart';
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
      final data = await _buildBackupData();
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

  /// Build backup data map from current DB state.
  Future<Map<String, dynamic>?> _buildBackupData() async {
    try {
      final logs = await StorageService.instance.getAllLogs();
      if (logs.isEmpty) return null; // nothing to back up

      final settings = <String, String>{};
      for (final key in [
        'myName', 'discipleEmail', 'discipleWhatsApp', 'language',
        'dailyHour', 'dailyMin', 'sundayHour', 'sundayMin',
        'appLockEnabled', 'useBiometrics', 'themeMode',
        'notificationsEnabled', 'autoSendEnabled',
        'autoSendHour', 'autoSendMin',
        'dailyFollowUps', 'sundayFollowUps',
      ]) {
        settings[key] = await StorageService.instance.getSetting(key);
      }
      final reports = await StorageService.instance.getAllReports();
      return {
        'version': 3,
        'exportDate': DateTime.now().toIso8601String(),
        'autoBackup': true,
        'settings': settings,
        'logs': logs.map((l) => l.toMap()).toList(),
        'saved_reports': reports.map((r) => r.toMap()).toList(),
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
    final data = await _buildBackupData();
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
      final file = File(result.files.single.path!);
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
      final logs = (data['logs'] as List).cast<Map<String, dynamic>>();
      final storage = StorageService.instance;
      if (!merge) {
        final db = await storage.database;
        await db.delete('logs');
        await db.delete('saved_reports');
      }
      for (final logMap in logs) {
        final log = DailyLog.fromMap(logMap);
        await storage.saveLog(log);
      }
      // Restore saved reports if present
      if (data['saved_reports'] != null) {
        final reports = (data['saved_reports'] as List).cast<Map<String, dynamic>>();
        for (final rMap in reports) {
          final report = SavedReport.fromMap(rMap);
          await storage.saveReport(
            weekStart: report.weekStart,
            weekEnd: report.weekEnd,
            fullReport: report.fullReport,
            compactReport: report.compactReport,
            sentVia: report.sentVia,
          );
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
