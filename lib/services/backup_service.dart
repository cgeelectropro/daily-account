import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/daily_log.dart';
import 'storage_service.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  /// Export all logs and settings to a JSON file and share it
  Future<bool> exportData() async {
    final logs = await StorageService.instance.getAllLogs();
    final settings = <String, String>{};
    for (final key in [
      'myName', 'discipleEmail', 'discipleWhatsApp', 'language',
      'dailyHour', 'dailyMin', 'sundayHour', 'sundayMin',
    ]) {
      settings[key] = await StorageService.instance.getSetting(key);
    }
    final data = {
      'version': 2,
      'exportDate': DateTime.now().toIso8601String(),
      'settings': settings,
      'logs': logs.map((l) => l.toMap()).toList(),
    };
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
      }
      for (final logMap in logs) {
        final log = DailyLog.fromMap(logMap);
        await storage.saveLog(log);
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
