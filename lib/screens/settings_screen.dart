import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart';
import 'package:local_auth/local_auth.dart';
import '../data/reading_plans.dart';
import '../services/backup_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/reading_plan_service.dart';
import '../services/report_cadence_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'report_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _name = '', _email = '', _whatsapp = '';
  TimeOfDay _dailyTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _sundayTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _autoSendTime = const TimeOfDay(hour: 19, minute: 0);
  bool _notificationsEnabled = true;
  bool _autoSendEnabled = false;
  bool _isDark = true;
  bool _appLockEnabled = false;
  bool _useBiometrics = false;
  bool _biometricsAvailable = false;
  int _dailyFollowUps = 3; // default aggressive: 3 follow-ups
  int _sundayFollowUps = 2; // default aggressive: 2 follow-ups
  ReportCadence _reportCadence = ReportCadence.weekly;
  int _reportWeeklyDay = DateTime.sunday; // 7
  String _reportMonthlyDay = 'last';
  String _selectedSound = 'sound_happy_bells';
  bool _loading = true;
  String _version = '';
  String _reportLanguage = ''; // empty = same as app

  // Time-conscious mode
  bool _timeConscious = false;

  // Cloud sync
  bool _cloudSignedIn = false;
  String _cloudEmail = '';
  String _cloudLastBackup = '';
  bool _cloudBusy = false;

  // Reading plan
  final ReadingPlanService _planService = ReadingPlanService.instance;

  // Goals
  String _goalFrequency = 'weekly'; // 'weekly' or 'daily'
  int _goalBibleChapters = 0;
  int _goalPrayerMinutes = 0;
  int _goalEvangelismContacts = 0;
  int _goalLiteratureItems = 0;

  /// Per-discipline reminder times. null = off.
  final Map<int, TimeOfDay?> _disciplineTimes = {};
  static const _disciplineNames = [
    'Bible', 'Literature', 'DDEG', 'Prayer (alone)', 'Prayer (others)',
    'Evangelism', 'Fasting', 'Giving', 'Church', 'Discipleship', 'Proclamation',
  ];
  static const _disciplineIcons = [
    '\uD83D\uDCD6', '\uD83D\uDCDA', '\uD83D\uDD25', '\uD83D\uDE4F', '\uD83E\uDD1D',
    '\uD83D\uDCE2', '\uD83C\uDF7D\uFE0F', '\uD83D\uDCB0', '\u26EA', '\uD83D\uDC65', '\uD83D\uDCE3',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = StorageService.instance;
    _name = await s.getSetting('myName');
    _email = await s.getSetting('discipleEmail');
    _whatsapp = await s.getSetting('discipleWhatsApp');
    final dh = int.tryParse(await s.getSetting('dailyHour', fallback: '20')) ?? 20;
    final dm = int.tryParse(await s.getSetting('dailyMin', fallback: '0')) ?? 0;
    final sh = int.tryParse(await s.getSetting('sundayHour', fallback: '18')) ?? 18;
    final sm = int.tryParse(await s.getSetting('sundayMin', fallback: '0')) ?? 0;
    final ash = int.tryParse(await s.getSetting('autoSendHour', fallback: '19')) ?? 19;
    final asm_ = int.tryParse(await s.getSetting('autoSendMin', fallback: '0')) ?? 0;
    _dailyTime = TimeOfDay(hour: dh, minute: dm);
    _sundayTime = TimeOfDay(hour: sh, minute: sm);
    _autoSendTime = TimeOfDay(hour: ash, minute: asm_);
    _notificationsEnabled = (await s.getSetting('notificationsEnabled', fallback: 'true')) == 'true';
    _autoSendEnabled = (await s.getSetting('autoSendEnabled', fallback: 'false')) == 'true';
    _isDark = (await s.getSetting('themeMode', fallback: 'dark')) == 'dark';
    _timeConscious = (await s.getSetting('timeConscious', fallback: 'false')) == 'true';
    _appLockEnabled = (await s.getSetting('appLockEnabled', fallback: 'false')) == 'true';
    _useBiometrics = (await s.getSetting('useBiometrics', fallback: 'false')) == 'true';
    _dailyFollowUps = int.tryParse(await s.getSetting('dailyFollowUps', fallback: '3')) ?? 3;
    _sundayFollowUps = int.tryParse(await s.getSetting('sundayFollowUps', fallback: '2')) ?? 2;
    _reportCadence = await ReportCadenceService.instance.getCadence();
    _reportWeeklyDay = await ReportCadenceService.instance.getWeeklyDay();
    _reportMonthlyDay = await ReportCadenceService.instance.getMonthlyDay();
    _selectedSound = await s.getSetting('notifSound', fallback: 'sound_happy_bells');
    try {
      final auth = LocalAuthentication();
      _biometricsAvailable = await auth.canCheckBiometrics || await auth.isDeviceSupported();
    } catch (_) {
      _biometricsAvailable = false;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      _version = '${info.version}+${info.buildNumber}';
    } catch (_) {
      _version = '1.2.0';
    }
    // Load report language
    _reportLanguage = await s.getSetting('reportLanguage', fallback: '');
    // Load goals
    _goalFrequency = await s.getSetting('goalFrequency', fallback: 'weekly');
    _goalBibleChapters = int.tryParse(await s.getSetting('goalBibleChapters', fallback: '0')) ?? 0;
    _goalPrayerMinutes = int.tryParse(await s.getSetting('goalPrayerMinutes', fallback: '0')) ?? 0;
    _goalEvangelismContacts = int.tryParse(await s.getSetting('goalEvangelismContacts', fallback: '0')) ?? 0;
    _goalLiteratureItems = int.tryParse(await s.getSetting('goalLiteratureItems', fallback: '0')) ?? 0;
    // Load per-discipline reminder times
    for (int i = 0; i < 11; i++) {
      final raw = await s.getSetting('discReminder_$i', fallback: '');
      if (raw.isNotEmpty) {
        final parts = raw.split(':');
        if (parts.length == 2) {
          _disciplineTimes[i] = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    }
    // Load reading plan state
    await _planService.load();
    // Load cloud sync state
    final cloud = CloudSyncService.instance;
    _cloudSignedIn = cloud.isSignedIn;
    _cloudEmail = cloud.currentUser?.email ?? '';
    _cloudLastBackup = await s.getSetting('cloudLastBackupDate', fallback: '');

    if (mounted) setState(() => _loading = false);
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: AppTheme.serif(14, color: AppTheme.cream)),
        backgroundColor: AppTheme.surfaceColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.accentGold(context)),
        ),
      ));

  // ── Notifications ──────────────────────────────────────────

  Future<void> _toggleNotifications(bool enabled) async {
    final l = S.of(context);
    setState(() => _notificationsEnabled = enabled);
    await StorageService.instance.setSetting('notificationsEnabled', enabled ? 'true' : 'false');
    if (enabled) {
      await _scheduleAllNotifications();
      if (mounted) _toast(l.notificationsEnabledMsg);
    } else {
      await NotificationService.instance.cancelAll();
      if (mounted) _toast(l.notificationsDisabledMsg);
    }
  }

  /// Compute the localized reminder title text for the current cadence
  /// setting, e.g. "Friday — Send Your Account" or "The 25th — Send Your
  /// Account" or "Month-end — Send Your Account".
  String _reportReminderTitle(S l) {
    if (_reportCadence == ReportCadence.weekly) {
      final dayName = DateFormat('EEEE', l.localeName).format(
        DateTime(2026, 1, 4 + _reportWeeklyDay), // 2026-01-05 is a Monday (weekday=1); offset gives each weekday 1-7
      );
      return l.notifReportTitleWeekly(dayName);
    }
    if (_reportMonthlyDay == 'last') {
      return l.notifReportTitleMonthlyLast;
    }
    return l.notifReportTitleMonthlyDay(_reportMonthlyDay);
  }

  Future<void> _scheduleAllNotifications() async {
    final l = S.of(context);
    final s = StorageService.instance;

    // Persist localized strings so they can be re-used on app restart
    // (notification re-scheduling runs without BuildContext)
    await s.setSetting('notifDailyTitle', l.notifDailyTitle);
    await s.setSetting('notifDailyBody', l.notifDailyBody);
    await s.setSetting('notifSundayTitle', _reportReminderTitle(l));
    await s.setSetting('notifSundayBody', l.notifReportBody);
    await s.setSetting('notifSatTitle', l.saturdaySummaryTitle);
    await s.setSetting('notifMidWeekTitle', l.midWeekNudgeTitle);

    await NotificationService.instance.scheduleDailyReminder(
      _dailyTime.hour, _dailyTime.minute,
      title: l.notifDailyTitle,
      body: l.notifDailyBody,
      followUpCount: _dailyFollowUps,
    );
    await NotificationService.instance.scheduleReportReminder(
      _sundayTime.hour, _sundayTime.minute,
      title: _reportReminderTitle(l),
      body: l.notifReportBody,
      followUpCount: _sundayFollowUps,
    );
    if (_autoSendEnabled) {
      await NotificationService.instance.scheduleAutoSendReminder(
        _autoSendTime.hour, _autoSendTime.minute,
        title: _reportReminderTitle(l),
        body: l.notifReportBody,
      );
    }
  }

  Future<void> _saveReminders({bool showToast = true}) async {
    final l = S.of(context);
    final s = StorageService.instance;
    await s.setSetting('dailyHour', '${_dailyTime.hour}');
    await s.setSetting('dailyMin', '${_dailyTime.minute}');
    await s.setSetting('sundayHour', '${_sundayTime.hour}');
    await s.setSetting('sundayMin', '${_sundayTime.minute}');

    if (_notificationsEnabled) {
      await _scheduleAllNotifications();
    }
    if (!mounted) return;
    if (showToast) _toast(l.remindersSaved);
  }

  Future<void> _setCadence(ReportCadence cadence) async {
    setState(() => _reportCadence = cadence);
    await ReportCadenceService.instance.setCadence(cadence);
    if (_notificationsEnabled) await _scheduleAllNotifications();
  }

  Future<void> _setWeeklyDay(int weekday) async {
    setState(() => _reportWeeklyDay = weekday);
    await ReportCadenceService.instance.setWeeklyDay(weekday);
    if (_notificationsEnabled) await _scheduleAllNotifications();
  }

  Future<void> _setMonthlyDay(String day) async {
    setState(() => _reportMonthlyDay = day);
    await ReportCadenceService.instance.setMonthlyDay(day);
    if (_notificationsEnabled) await _scheduleAllNotifications();
  }

  // ── Auto-send ──────────────────────────────────────────────

  Future<void> _toggleAutoSend(bool enabled) async {
    final l = S.of(context);
    setState(() => _autoSendEnabled = enabled);
    await StorageService.instance.setSetting('autoSendEnabled', enabled ? 'true' : 'false');
    if (enabled && _notificationsEnabled) {
      await StorageService.instance.setSetting('autoSendHour', '${_autoSendTime.hour}');
      await StorageService.instance.setSetting('autoSendMin', '${_autoSendTime.minute}');
      await NotificationService.instance.scheduleAutoSendReminder(
        _autoSendTime.hour, _autoSendTime.minute,
        title: l.notifSundayTitle,
        body: l.notifSundayBody,
      );
    } else {
      await NotificationService.instance.cancel(3);
    }
  }

  Future<void> _pickAutoSendTime() async {
    final l = S.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: _autoSendTime,
      builder: _timePickerBuilder,
    );
    if (picked != null) {
      setState(() => _autoSendTime = picked);
      await StorageService.instance.setSetting('autoSendHour', '${picked.hour}');
      await StorageService.instance.setSetting('autoSendMin', '${picked.minute}');
      if (_autoSendEnabled && _notificationsEnabled) {
        await NotificationService.instance.scheduleAutoSendReminder(
          picked.hour, picked.minute,
          title: l.notifSundayTitle,
          body: l.notifSundayBody,
        );
      }
    }
  }

  // ── App Lock ───────────────────────────────────────────────

  Future<void> _toggleAppLock(bool enabled) async {
    if (enabled) {
      // Ask user to set a PIN
      final pin = await _showSetPinDialog();
      if (pin == null) return; // cancelled
      await StorageService.instance.setSetting('appPin', pin);
      await StorageService.instance.setSetting('appLockEnabled', 'true');
      setState(() => _appLockEnabled = true);
      if (mounted) _toast(S.of(context).pinSet);
    } else {
      await StorageService.instance.setSetting('appLockEnabled', 'false');
      await StorageService.instance.setSetting('appPin', '');
      await StorageService.instance.setSetting('useBiometrics', 'false');
      setState(() {
        _appLockEnabled = false;
        _useBiometrics = false;
      });
      if (mounted) _toast(S.of(context).pinRemoved);
    }
  }

  Future<void> _toggleBiometrics(bool enabled) async {
    setState(() => _useBiometrics = enabled);
    await StorageService.instance.setSetting('useBiometrics', enabled ? 'true' : 'false');
  }

  Future<String?> _showSetPinDialog() async {
    String pin = '';
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);

    // Step 1: Enter PIN
    final firstPin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String entered = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: AppTheme.surfaceColor(context),
            title: Text(l.setPinTitle, style: AppTheme.display(18, color: accent)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.setPinBody, style: AppTheme.serif(14, color: AppTheme.textColor(context))),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < entered.length ? accent : Colors.transparent,
                      border: Border.all(color: accent, width: 1.5),
                    ),
                  )),
                ),
                const SizedBox(height: 16),
                TextField(
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: AppTheme.display(24, color: AppTheme.textColor(context)),
                  decoration: InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: accent),
                    ),
                  ),
                  onChanged: (v) {
                    entered = v;
                    setDialogState(() {});
                    if (v.length == 4) Navigator.pop(ctx, v);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text(l.cancel, style: TextStyle(color: AppTheme.mutedColor(context))),
              ),
            ],
          ),
        );
      },
    );

    if (firstPin == null || firstPin.length != 4) return null;
    pin = firstPin;

    if (!mounted) return null;

    // Step 2: Confirm PIN
    final confirmed = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String entered = '';
        String error = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: AppTheme.surfaceColor(context),
            title: Text(l.confirmPinTitle, style: AppTheme.display(18, color: accent)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.confirmPinBody, style: AppTheme.serif(14, color: AppTheme.textColor(context))),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < entered.length ? accent : Colors.transparent,
                      border: Border.all(color: accent, width: 1.5),
                    ),
                  )),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(error, style: AppTheme.serif(12, color: AppTheme.rust)),
                ],
                const SizedBox(height: 16),
                TextField(
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: AppTheme.display(24, color: AppTheme.textColor(context)),
                  decoration: InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: accent),
                    ),
                  ),
                  onChanged: (v) {
                    entered = v;
                    setDialogState(() { error = ''; });
                    if (v.length == 4) {
                      if (v == pin) {
                        Navigator.pop(ctx, v);
                      } else {
                        setDialogState(() { error = l.pinMismatch; entered = ''; });
                      }
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text(l.cancel, style: TextStyle(color: AppTheme.mutedColor(context))),
              ),
            ],
          ),
        );
      },
    );

    return confirmed;
  }

  // ── Theme ──────────────────────────────────────────────────

  void _setTheme(bool dark) {
    setState(() => _isDark = dark);
    DailyAccountApp.setThemeMode(
      context,
      dark ? ThemeMode.dark : ThemeMode.light,
    );
  }

  // ── Backup ─────────────────────────────────────────────────

  Future<void> _export() async {
    final l = S.of(context);
    final success = await BackupService.instance.exportData();
    if (mounted) _toast(success ? l.exportSuccess : l.importFailed);
  }

  Future<void> _import() async {
    final l = S.of(context);
    final data = await BackupService.instance.pickAndPreview();
    if (data == null) {
      if (mounted) _toast(l.importFailed);
      return;
    }
    final logs = data['logs'] as List;
    if (!mounted) return;
    final merge = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text(l.importData, style: AppTheme.display(18, color: AppTheme.accentGold(context))),
        content: Text(l.importPreview(logs.length), style: AppTheme.serif(14, color: AppTheme.textColor(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.importMerge, style: TextStyle(color: AppTheme.accentGold(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.replaceData, style: const TextStyle(color: AppTheme.rust)),
          ),
        ],
      ),
    );
    if (merge == null) return;
    final success = await BackupService.instance.importData(data, merge: merge);
    if (mounted) _toast(success ? l.importSuccess : l.importFailed);
  }

  // ── Auto-backup restore ────────────────────────────────────

  Future<void> _restoreAutoBackup() async {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final data = await BackupService.instance.getLatestAutoBackup();
    if (data == null) {
      if (mounted) _toast(l.noAutoBackup);
      return;
    }
    final exportDate = data['exportDate'] as String? ?? '';
    final dateStr = exportDate.isNotEmpty
        ? exportDate.substring(0, 16).replaceFirst('T', ' ')
        : '?';
    final logs = data['logs'] as List? ?? [];
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text(l.restoreAutoBackup, style: AppTheme.display(18, color: accent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.autoBackupFound(dateStr),
                style: AppTheme.serif(14, color: AppTheme.textColor(context))),
            const SizedBox(height: 8),
            Text(l.importPreview(logs.length),
                style: AppTheme.serif(12, color: AppTheme.mutedColor(context))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel, style: TextStyle(color: AppTheme.mutedColor(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.restoreButton, style: TextStyle(color: accent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await BackupService.instance.importData(data, merge: true);
    if (mounted) _toast(success ? l.importSuccess : l.importFailed);
  }

  // ── Cloud Sync ─────────────────────────────────────────────

  Future<void> _cloudSignIn() async {
    final l = S.of(context);
    setState(() => _cloudBusy = true);
    final ok = await CloudSyncService.instance.signIn();
    if (!mounted) return;
    if (ok) {
      setState(() {
        _cloudSignedIn = true;
        _cloudEmail = CloudSyncService.instance.currentUser?.email ?? '';
        _cloudBusy = false;
      });
    } else {
      setState(() => _cloudBusy = false);
      final detail = CloudSyncService.instance.lastError ?? '';
      _toast('${l.cloudSignInFailed} $detail');
    }
  }

  Future<void> _cloudSignOut() async {
    await CloudSyncService.instance.signOut();
    if (!mounted) return;
    setState(() {
      _cloudSignedIn = false;
      _cloudEmail = '';
      _cloudLastBackup = '';
    });
  }

  Future<void> _cloudBackup() async {
    final l = S.of(context);
    setState(() => _cloudBusy = true);
    final ok = await CloudSyncService.instance.backupToDrive();
    if (!mounted) return;
    setState(() => _cloudBusy = false);
    if (ok) {
      final now = DateTime.now().toIso8601String();
      setState(() => _cloudLastBackup = now);
      _toast(l.cloudBackupSuccess);
    } else {
      final detail = CloudSyncService.instance.lastError ?? '';
      _toast('${l.cloudBackupFailed} $detail');
    }
  }

  Future<void> _cloudRestore() async {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text(l.cloudRestoreConfirmTitle, style: AppTheme.display(18, color: accent)),
        content: Text(l.cloudRestoreConfirmBody, style: AppTheme.serif(14, color: AppTheme.textColor(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel, style: TextStyle(color: AppTheme.mutedColor(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.restoreButton, style: TextStyle(color: accent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _cloudBusy = true);
    final data = await CloudSyncService.instance.downloadFromDrive();
    if (!mounted) return;
    if (data == null) {
      setState(() => _cloudBusy = false);
      final detail = CloudSyncService.instance.lastError ?? '';
      _toast('${l.cloudNoBackupFound} $detail');
      return;
    }
    final ok = await BackupService.instance.importData(data, merge: false);
    if (!mounted) return;
    setState(() => _cloudBusy = false);
    _toast(ok ? l.cloudRestoreSuccess : l.cloudRestoreFailed);
  }

  // ── Reset ──────────────────────────────────────────────────

  Future<void> _resetAll() async {
    final l = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text(l.resetConfirmTitle, style: AppTheme.display(18, color: AppTheme.rust)),
        content: Text(l.resetConfirmBody, style: AppTheme.serif(14, color: AppTheme.textColor(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel, style: TextStyle(color: AppTheme.mutedColor(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.resetConfirmButton, style: const TextStyle(color: AppTheme.rust)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await StorageService.instance.resetAll();
    await NotificationService.instance.cancelAll();
    if (mounted) {
      _toast(l.resetSuccess);
      // Reload screen
      setState(() => _loading = true);
      _load();
    }
  }

  // ── UI Helpers ─────────────────────────────────────────────

  Widget _themeCard(String label, IconData icon, bool isDark) {
    final isSelected = _isDark == isDark;
    final accent = AppTheme.accentGold(context);
    return Expanded(
      child: GestureDetector(
        onTap: () => _setTheme(isDark),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? accent.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accent : accent.withValues(alpha: 0.2),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: isSelected ? accent : AppTheme.mutedColor(context)),
              const SizedBox(height: 8),
              Text(label, style: AppTheme.serif(14, color: isSelected ? accent : AppTheme.textColor(context))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _languageCard(String flag, String label, String code) {
    final isSelected = Localizations.localeOf(context).languageCode == code;
    final accent = AppTheme.accentGold(context);
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          DailyAccountApp.setLocale(context, Locale(code));
          await StorageService.instance.setSetting('appLocale', code);
          try {
            await HomeWidget.saveWidgetData('widget_locale', code);
            await HomeWidget.updateWidget(androidName: 'ScriptureWidgetProvider');
            await HomeWidget.updateWidget(androidName: 'FullAltarWidgetProvider');
            await HomeWidget.updateWidget(androidName: 'ProclamationWidgetProvider');
          } catch (_) {}
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? accent.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accent : accent.withValues(alpha: 0.2),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(flag, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(label, style: AppTheme.serif(14, color: isSelected ? accent : AppTheme.textColor(context))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: AppTheme.serif(14, color: AppTheme.textColor(context)))),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppTheme.accentGold(context),
            activeThumbColor: AppTheme.isDark(context) ? AppTheme.cream : AppTheme.lightBg0,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget Function(BuildContext, Widget?) get _timePickerBuilder =>
      (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: AppTheme.isDark(context)
                  ? const ColorScheme.dark(
                      primary: AppTheme.gold,
                      surface: AppTheme.bg2,
                      onSurface: AppTheme.cream,
                    )
                  : const ColorScheme.light(
                      primary: AppTheme.lightGold,
                      surface: AppTheme.lightBg2,
                      onSurface: AppTheme.lightText,
                    ),
            ),
            child: child!,
          );

  Future<void> _pickTime(bool daily) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: daily ? _dailyTime : _sundayTime,
      builder: _timePickerBuilder,
    );
    if (picked != null) {
      setState(() => daily ? _dailyTime = picked : _sundayTime = picked);
      // Auto-save and schedule immediately so the user doesn't have to tap Save
      await _saveReminders(showToast: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.accentGold(context)));
    }
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final textCol = AppTheme.textColor(context);
    final mutedCol = AppTheme.mutedColor(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Text(l.settingsTitle, style: AppTheme.display(24, color: accent)),
        const SizedBox(height: 20),

        // ── Profile ──
        SectionCard(icon: '👤', title: l.profileSection, children: [
          GoldField(
            label: l.yourNameLabel,
            hint: l.yourNameHint,
            value: _name,
            onChanged: (v) { _name = v; StorageService.instance.setSetting('myName', v); },
          ),
        ]),

        // ── Goals ──
        SectionCard(icon: '\uD83C\uDFAF', title: _goalFrequency == 'daily' ? l.dailyGoals : l.weeklyGoals, initiallyExpanded: false, children: [
          Text(_goalFrequency == 'daily' ? l.dailyGoalsDesc : l.weeklyGoalsDesc, style: AppTheme.serif(12, color: mutedCol)),
          const SizedBox(height: 8),
          // Frequency toggle
          Row(
            children: [
              Text(l.goalFrequency, style: AppTheme.serif(13, color: AppTheme.textColor(context))),
              const Spacer(),
              _frequencyChip(l.daily, 'daily'),
              const SizedBox(width: 6),
              _frequencyChip(l.weekly, 'weekly'),
            ],
          ),
          const SizedBox(height: 12),
          _goalField(l.goalBibleChapters, '\uD83D\uDCD6', _goalBibleChapters, (v) {
            setState(() => _goalBibleChapters = v);
            StorageService.instance.setSetting('goalBibleChapters', '$v');
          }),
          _goalField(l.goalPrayerMinutes, '\uD83D\uDE4F', _goalPrayerMinutes, (v) {
            setState(() => _goalPrayerMinutes = v);
            StorageService.instance.setSetting('goalPrayerMinutes', '$v');
          }),
          _goalField(l.goalEvangelismContacts, '\uD83D\uDCE2', _goalEvangelismContacts, (v) {
            setState(() => _goalEvangelismContacts = v);
            StorageService.instance.setSetting('goalEvangelismContacts', '$v');
          }),
          _goalField(l.goalLiteratureItems, '\uD83D\uDCDA', _goalLiteratureItems, (v) {
            setState(() => _goalLiteratureItems = v);
            StorageService.instance.setSetting('goalLiteratureItems', '$v');
          }),
        ]),

        // ── Bible Reading Plan ──
        SectionCard(icon: '📖', title: l.planSectionTitle, initiallyExpanded: false, children: [
          _buildPlanSection(l),
        ]),

        // ── Disciple Maker ──
        SectionCard(icon: '\uD83D\uDCE7', title: l.discipleMakerSection, children: [
          GoldField(
            label: l.emailLabel,
            hint: l.emailHint,
            value: _email,
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) { _email = v; StorageService.instance.setSetting('discipleEmail', v); },
          ),
          GoldField(
            label: l.whatsappLabel,
            hint: l.whatsappHint,
            value: _whatsapp,
            keyboardType: TextInputType.phone,
            onChanged: (v) { _whatsapp = v; StorageService.instance.setSetting('discipleWhatsApp', v); },
          ),
        ]),

        // ── Appearance ──
        SectionCard(icon: '🎨', title: l.themeSection, children: [
          Row(
            children: [
              _themeCard(l.themeDark, Icons.dark_mode, true),
              const SizedBox(width: 12),
              _themeCard(l.themeLight, Icons.light_mode, false),
            ],
          ),
          const SizedBox(height: 16),
          // Text size slider
          Text(l.textSizeLabel.toUpperCase(),
              style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(l.textSizeSmall, style: AppTheme.serif(13, color: mutedCol)),
              Expanded(
                child: Slider(
                  value: DailyAccountApp.getTextScale(context),
                  min: 0.8,
                  max: 1.6,
                  divisions: 8,
                  activeColor: accent,
                  inactiveColor: accent.withValues(alpha: 0.2),
                  label: '${(DailyAccountApp.getTextScale(context) * 100).round()}%',
                  onChanged: (v) {
                    DailyAccountApp.setTextScale(context, v);
                  },
                ),
              ),
              Text(l.textSizeLarge, style: AppTheme.display(18, color: mutedCol)),
            ],
          ),
          // Preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.12)),
            ),
            child: Text(l.textSizePreview,
                style: AppTheme.serif(14, color: textCol)),
          ),
        ]),

        // ── Time-conscious mode ──
        SectionCard(icon: '⏱', title: l.timeConsciousLabel, initiallyExpanded: false, children: [
          _switchRow(l.timeConsciousLabel, _timeConscious, (v) async {
            setState(() => _timeConscious = v);
            await StorageService.instance.setSetting('timeConscious', v.toString());
          }),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              l.timeConsciousDescription,
              style: AppTheme.serif(11, color: textCol.withValues(alpha: 0.5)),
            ),
          ),
        ]),

        // ── Security ──
        SectionCard(icon: '🔒', title: l.securitySection, initiallyExpanded: false, children: [
          _switchRow(l.appLockEnabled, _appLockEnabled, _toggleAppLock),
          if (_appLockEnabled) ...[
            if (_biometricsAvailable)
              _switchRow(l.useBiometrics, _useBiometrics, _toggleBiometrics),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final pin = await _showSetPinDialog();
                  if (pin != null && mounted) {
                    await StorageService.instance.setSetting('appPin', pin);
                    _toast(l.pinSet);
                  }
                },
                icon: Icon(Icons.lock_reset, color: accent),
                label: Text(l.changePin, style: TextStyle(color: accent)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: accent.withValues(alpha: 0.3))),
              ),
            ),
          ],
        ]),

        // ── Notifications ──
        SectionCard(icon: '🔔', title: l.notificationsSection, children: [
          _switchRow(l.notificationsEnabled, _notificationsEnabled, _toggleNotifications),
          if (_notificationsEnabled) ...[
            // Intensity badge
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Text('🚨', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.intensityAggressive, style: AppTheme.serif(13, color: textCol)),
                        Text(l.intensityAggressiveDesc, style: AppTheme.label(10, color: mutedCol)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // ── Notification sound picker ──
            Text(l.notificationSoundLabel,
                style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
            const SizedBox(height: 6),
            ...NotificationService.notificationSounds.entries.map((entry) {
              final selected = _selectedSound == entry.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: GestureDetector(
                  onTap: () async {
                    setState(() => _selectedSound = entry.key);
                    await NotificationService.instance.setNotificationSound(entry.key);
                    await NotificationService.instance.previewSound(entry.key);
                    await _saveReminders(showToast: false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? accent
                            : accent.withValues(alpha: 0.15),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: selected ? accent : mutedCol,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '\uD83D\uDD14 ${entry.value}',
                          style: AppTheme.serif(13, color: selected ? textCol : mutedCol),
                        ),
                        const Spacer(),
                        if (selected)
                          Text(l.soundPlaying, style: AppTheme.label(10, color: accent)),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 14),
            // ── Notification health check ──
            Builder(builder: (_) {
              final diag = NotificationService.instance.diagnostics;
              final stats = NotificationService.instance.scheduleStats;
              final allGood = diag.values.every((v) => v);
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (allGood ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (allGood ? Colors.green : Colors.orange).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(allGood ? '\u2705' : '\u26A0\uFE0F', style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          allGood ? l.notificationsHealthy : l.notificationIssuesDetected,
                          style: AppTheme.serif(13, color: textCol),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _diagRow(l.diagPermissionGranted, diag['notificationPermission'] ?? false),
                    _diagRow(l.diagExactAlarms, diag['exactAlarmPermission'] ?? false),
                    Row(
                      children: [
                        Expanded(child: _diagRow(l.diagBatteryOptimized, diag['batteryOptExempt'] ?? false)),
                        if (!(diag['batteryOptExempt'] ?? false))
                          GestureDetector(
                            onTap: () async {
                              await NotificationService.instance.requestBatteryOptimizationExemption();
                              if (mounted) setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                              ),
                              child: Text(l.diagFix, style: AppTheme.label(10, color: Colors.orange)),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      l.diagScheduledFailed(stats.$1, stats.$2),
                      style: AppTheme.label(10, color: mutedCol),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () async {
                        final pending = await NotificationService.instance.getPendingNotifications();
                        if (!mounted) return;
                        final names = {
                          1: l.notifNameDaily,
                          2: l.notifNameSunday,
                          3: l.notifNameAutoSend,
                          11: l.notifNameDailyFollowUp1,
                          12: l.notifNameDailyFollowUp2,
                          13: l.notifNameDailyFollowUp3,
                          21: l.notifNameSundayFollowUp1,
                          22: l.notifNameSundayFollowUp2,
                          30: l.notifNameMidWeekNudge,
                          40: l.notifNameSaturdaySummary,
                        };
                        final lines = pending.map((n) {
                          final label = names[n.id] ?? (n.id >= 110 && n.id <= 120
                              ? l.notifNameDiscipline(n.id - 110)
                              : '#${n.id}');
                          return '$label (${n.id})';
                        }).toList()
                          ..sort();
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppTheme.surfaceColor(context),
                            title: Text(l.pendingNotificationsTitle(pending.length),
                                style: AppTheme.display(16, color: accent)),
                            content: SingleChildScrollView(
                              child: Text(
                                lines.isEmpty ? l.noneScheduled : lines.join('\n'),
                                style: AppTheme.serif(13, color: textCol),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(l.ok, style: TextStyle(color: accent)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text(
                        l.tapToSeePending,
                        style: AppTheme.label(10, color: accent.withValues(alpha: 0.7)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final ok = await NotificationService.instance.testNotification();
                              if (mounted) _toast(ok ? l.testNotifSent : l.testNotifFailed);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: accent.withValues(alpha: 0.4)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(l.testNotifButton, style: AppTheme.label(11, color: accent)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              await NotificationService.instance.rescheduleAll();
                              if (mounted) {
                                setState(() {});
                                _toast(l.allNotificationsRescheduled);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: accent.withValues(alpha: 0.4)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(l.rescheduleAll, style: AppTheme.label(11, color: accent)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 14),
            _timeRow(l.dailyReminder, _dailyTime, () => _pickTime(true)),
            const SizedBox(height: 8),
            // Daily follow-ups slider
            _followUpSlider(
              label: l.followUpReminders,
              value: _dailyFollowUps,
              max: 3,
              displayText: l.followUpCount(_dailyFollowUps),
              onChanged: (v) async {
                setState(() => _dailyFollowUps = v);
                await StorageService.instance.setSetting('dailyFollowUps', '$v');
                await _saveReminders(showToast: false);
              },
            ),
            const SizedBox(height: 12),
            _cadencePicker(l),
            const SizedBox(height: 14),
            _timeRow(l.sundayReminder, _sundayTime, () => _pickTime(false)),
            const SizedBox(height: 8),
            // Sunday follow-ups slider
            _followUpSlider(
              label: l.sundayFollowUps,
              value: _sundayFollowUps,
              max: 2,
              displayText: l.sundayFollowUpCount(_sundayFollowUps),
              onChanged: (v) async {
                setState(() => _sundayFollowUps = v);
                await StorageService.instance.setSetting('sundayFollowUps', '$v');
                await _saveReminders(showToast: false);
              },
            ),
            const SizedBox(height: 8),
            Text(l.followUpDescription, style: AppTheme.serif(11, color: mutedCol)),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _saveReminders,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(l.saveReminders, style: AppTheme.display(15, color: AppTheme.bg0)),
              ),
            ),
            const SizedBox(height: 20),
            // ── Per-discipline reminders ──
            Text(l.disciplineReminders.toUpperCase(),
                style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
            const SizedBox(height: 4),
            Text(l.disciplineRemindersDesc,
                style: AppTheme.serif(11, color: mutedCol)),
            const SizedBox(height: 8),
            ...List.generate(11, (i) => _disciplineReminderRow(i, accent, textCol, mutedCol)),
          ],
        ]),

        // ── Auto-Send ──
        SectionCard(icon: '📤', title: l.autoSendSection, children: [
          _switchRow(l.autoSendEnabled, _autoSendEnabled, _toggleAutoSend),
          if (_autoSendEnabled) ...[
            const SizedBox(height: 8),
            _timeRow(l.autoSendTime, _autoSendTime, _pickAutoSendTime),
            const SizedBox(height: 8),
            Text(l.autoSendDescription, style: AppTheme.serif(12, color: mutedCol)),
          ],
        ]),

        // ── Language ──
        SectionCard(icon: '\uD83C\uDF10', title: l.languageSection, children: [
          Row(
            children: [
              _languageCard('\uD83C\uDDEC\uD83C\uDDE7', l.languageEnglish, 'en'),
              const SizedBox(width: 12),
              _languageCard('\uD83C\uDDEB\uD83C\uDDF7', l.languageFrench, 'fr'),
            ],
          ),
          const SizedBox(height: 16),
          // Report language
          Text(l.reportLanguageSection.toUpperCase(),
              style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
          const SizedBox(height: 4),
          Text(l.reportLanguageDesc,
              style: AppTheme.serif(11, color: mutedCol)),
          const SizedBox(height: 8),
          Row(
            children: [
              _reportLanguageCard(l.reportLanguageSameAsApp, '', accent, textCol),
              const SizedBox(width: 8),
              _reportLanguageCard('English', 'en', accent, textCol),
              const SizedBox(width: 8),
              _reportLanguageCard('Français', 'fr', accent, textCol),
            ],
          ),
        ]),

        // ── Cloud Backup ──
        SectionCard(icon: '☁️', title: l.cloudBackupSection, children: [
          if (!_cloudSignedIn) ...[
            Text(l.cloudBackupDescription, style: AppTheme.serif(12, color: mutedCol)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _cloudBusy ? null : _cloudSignIn,
                icon: _cloudBusy
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                    : const Icon(Icons.login, color: AppTheme.bg0),
                label: Text(l.signInWithGoogle, style: const TextStyle(color: AppTheme.bg0)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  disabledBackgroundColor: accent.withValues(alpha: 0.5),
                ),
              ),
            ),
          ] else ...[
            // Signed-in status bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.green.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_done, color: AppTheme.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l.signedInAs(_cloudEmail), style: AppTheme.serif(12, color: AppTheme.green))),
                    ],
                  ),
                  if (_cloudLastBackup.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      l.lastCloudBackup(_cloudLastBackup.substring(0, 16).replaceFirst('T', ' ')),
                      style: AppTheme.serif(11, color: mutedCol),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cloudBusy ? null : _cloudBackup,
                icon: _cloudBusy
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                    : Icon(Icons.cloud_upload, color: accent),
                label: Text(l.backupToDrive, style: TextStyle(color: accent)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: accent.withValues(alpha: 0.3))),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cloudBusy ? null : _cloudRestore,
                icon: Icon(Icons.cloud_download, color: accent),
                label: Text(l.restoreFromDrive, style: TextStyle(color: accent)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: accent.withValues(alpha: 0.3))),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _cloudBusy ? null : _cloudSignOut,
                child: Text(l.signOut, style: AppTheme.serif(12, color: mutedCol)),
              ),
            ),
          ],
        ]),

        // ── Backup ──
        SectionCard(icon: '💾', title: l.backupSection, children: [
          // Auto-backup info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.green.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_done, color: AppTheme.green, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(l.autoBackupInfo, style: AppTheme.serif(11, color: AppTheme.green))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _export,
              icon: Icon(Icons.upload, color: accent),
              label: Text(l.exportData, style: TextStyle(color: accent)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: accent.withValues(alpha: 0.3))),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _import,
              icon: Icon(Icons.download, color: accent),
              label: Text(l.importData, style: TextStyle(color: accent)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: accent.withValues(alpha: 0.3))),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _restoreAutoBackup,
              icon: Icon(Icons.restore, color: accent),
              label: Text(l.restoreAutoBackup, style: TextStyle(color: accent)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: accent.withValues(alpha: 0.3))),
            ),
          ),
        ]),

        // ── Report Archive ──
        SectionCard(icon: '📜', title: l.reportHistorySection, initiallyExpanded: false, children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportHistoryScreen()),
              ),
              icon: Icon(Icons.history, color: accent),
              label: Text(l.reportHistory, style: TextStyle(color: accent)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: accent.withValues(alpha: 0.3))),
            ),
          ),
        ]),

        // ── How It Works ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📌 ${l.howItWorksTitle}', style: AppTheme.display(15, color: accent)),
              const SizedBox(height: 8),
              Text(l.howItWorks, style: AppTheme.serif(13, color: mutedCol)),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── About ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Image.asset('assets/cmfilogo.png', width: 55, height: 55),
              const SizedBox(height: 8),
              Text(l.appTitle, style: AppTheme.display(18, color: accent)),
              const SizedBox(height: 4),
              Text(l.appVersion(_version), style: AppTheme.serif(12, color: mutedCol)),
              const SizedBox(height: 4),
              Text('CMFI', style: AppTheme.label(10, color: accent.withValues(alpha: 0.7))),
              const SizedBox(height: 12),
              Text(l.aboutDescription, textAlign: TextAlign.center, style: AppTheme.serif(13, color: textCol)),
              const SizedBox(height: 8),
              Text(l.madeWithLove, style: AppTheme.label(10, color: mutedCol)),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Danger Zone ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.rust.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.rust.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('⚠️ ${l.dangerZone}', style: AppTheme.display(15, color: AppTheme.rust)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _resetAll,
                  icon: const Icon(Icons.delete_forever, color: AppTheme.rust),
                  label: Text(l.resetAllData, style: const TextStyle(color: AppTheme.rust)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.rust.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Bible Reading Plan ─────────────────────────────────────────────────────

  Widget _buildPlanSection(dynamic l) {
    final accent = AppTheme.accentGold(context);
    final textCol = AppTheme.textColor(context);
    final mutedCol = AppTheme.mutedColor(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final active = _planService.activePlan;

    // Helper: list of all plans to browse
    Widget planList() {
      return Column(
        children: ReadingPlans.all.map((plan) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name(locale),
                          style: AppTheme.serif(14,
                              color: textCol,
                              weight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          plan.description(locale),
                          style: AppTheme.serif(12, color: mutedCol),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () async {
                      await _planService.activate(plan.id);
                      if (mounted) setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l.planStart,
                        style: AppTheme.serif(12,
                            color: AppTheme.bg0,
                            weight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    // ── No active plan ──
    if (active == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.planNoActive, style: AppTheme.serif(13, color: mutedCol)),
          const SizedBox(height: 12),
          planList(),
        ],
      );
    }

    // ── Plan completed ──
    if (active.isComplete) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.planCompleted,
                    style: AppTheme.serif(13, color: accent)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          planList(),
        ],
      );
    }

    // ── Active plan in progress ──
    final plan = ReadingPlans.getById(active.planId);
    final planName =
        plan != null ? plan.name(locale) : active.planId;
    final percent = (active.progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(planName,
            style: AppTheme.serif(15,
                color: textCol, weight: FontWeight.bold)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: active.progress,
            minHeight: 7,
            backgroundColor: accent.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${l.planDayOf(active.currentDay, active.totalDays)}  •  ${l.planProgress(percent)}',
          style: AppTheme.serif(12, color: mutedCol),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  await _planService.pause();
                  if (mounted) setState(() {});
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accent.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(l.planPause,
                    style: AppTheme.serif(13, color: accent)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  await _planService.reset();
                  if (mounted) setState(() {});
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: AppTheme.rust.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(l.planReset,
                    style: AppTheme.serif(13, color: AppTheme.rust)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cadencePicker(S l) {
    final accent = AppTheme.accentGold(context);
    final textCol = AppTheme.textColor(context);
    final mutedCol = AppTheme.mutedColor(context);

    Widget segButton(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? accent : accent.withValues(alpha: 0.2)),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: AppTheme.label(12, color: selected ? accent : mutedCol)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.reportCadenceLabel.toUpperCase(),
            style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
        const SizedBox(height: 6),
        Row(
          children: [
            segButton(l.reportCadenceWeekly, _reportCadence == ReportCadence.weekly,
                () => _setCadence(ReportCadence.weekly)),
            const SizedBox(width: 8),
            segButton(l.reportCadenceMonthly, _reportCadence == ReportCadence.monthly,
                () => _setCadence(ReportCadence.monthly)),
          ],
        ),
        const SizedBox(height: 12),
        if (_reportCadence == ReportCadence.weekly) ...[
          Text(l.reportWeeklyDayLabel, style: AppTheme.serif(13, color: textCol)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (i) {
              final weekday = i + 1; // 1=Monday..7=Sunday
              final dayName = DateFormat('EEE', l.localeName)
                  .format(DateTime(2026, 1, 4 + weekday));
              final selected = _reportWeeklyDay == weekday;
              return GestureDetector(
                onTap: () => _setWeeklyDay(weekday),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: selected ? accent : accent.withValues(alpha: 0.2)),
                  ),
                  child: Text(dayName,
                      style: AppTheme.label(12, color: selected ? accent : mutedCol)),
                ),
              );
            }),
          ),
        ] else ...[
          Text(l.reportMonthlyDayLabel, style: AppTheme.serif(13, color: textCol)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...List.generate(31, (i) {
                final day = '${i + 1}';
                final selected = _reportMonthlyDay == day;
                return GestureDetector(
                  onTap: () => _setMonthlyDay(day),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: selected ? accent : accent.withValues(alpha: 0.2)),
                    ),
                    child: Text(day,
                        style: AppTheme.label(11, color: selected ? accent : mutedCol)),
                  ),
                );
              }),
              GestureDetector(
                onTap: () => _setMonthlyDay('last'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _reportMonthlyDay == 'last'
                        ? accent.withValues(alpha: 0.18) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _reportMonthlyDay == 'last' ? accent : accent.withValues(alpha: 0.2)),
                  ),
                  child: Text(l.reportMonthlyDayLast,
                      style: AppTheme.label(11,
                          color: _reportMonthlyDay == 'last' ? accent : mutedCol)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _followUpSlider({
    required String label,
    required int value,
    required int max,
    required String displayText,
    required ValueChanged<int> onChanged,
  }) {
    final accent = AppTheme.accentGold(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTheme.serif(13, color: AppTheme.textColor(context))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(displayText, style: AppTheme.label(10, color: accent)),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accent,
            inactiveTrackColor: accent.withValues(alpha: 0.15),
            thumbColor: accent,
            overlayColor: accent.withValues(alpha: 0.1),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: max.toDouble(),
            divisions: max,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }

  Widget _timeRow(String label, TimeOfDay time, VoidCallback onTap) {
    final accent = AppTheme.accentGold(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.isDark(context)
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTheme.serif(14, color: AppTheme.textColor(context))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(time.format(context),
                  style: AppTheme.display(15, color: AppTheme.goldSoft)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _diagRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel,
              size: 14, color: ok ? Colors.green : Colors.orange),
          const SizedBox(width: 6),
          Text(label, style: AppTheme.label(11, color: AppTheme.mutedColor(context))),
        ],
      ),
    );
  }

  Widget _disciplineReminderRow(int index, Color accent, Color textCol, Color mutedCol) {
    final time = _disciplineTimes[index];
    final name = _disciplineNames[index];
    final icon = _disciplineIcons[index];
    final l = S.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () async {
          if (time != null) {
            // Show option to change or turn off
            final action = await showModalBottomSheet<String>(
              context: context,
              backgroundColor: AppTheme.surfaceColor(context),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (ctx) => Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$icon $name', style: AppTheme.display(18, color: accent)),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Icon(Icons.access_time, color: accent),
                      title: Text(l.disciplineReminderSet, style: AppTheme.serif(14, color: textCol)),
                      onTap: () => Navigator.pop(ctx, 'change'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.notifications_off, color: AppTheme.rust),
                      title: Text(l.disciplineReminderOff, style: AppTheme.serif(14, color: AppTheme.rust)),
                      onTap: () => Navigator.pop(ctx, 'off'),
                    ),
                  ],
                ),
              ),
            );
            if (action == 'change') {
              await _pickDisciplineTime(index);
            } else if (action == 'off') {
              setState(() => _disciplineTimes.remove(index));
              await StorageService.instance.setSetting('discReminder_$index', '');
              await NotificationService.instance.cancelDisciplineReminder(index);
            }
          } else {
            await _pickDisciplineTime(index);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: time != null
                ? accent.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: time != null
                  ? accent.withValues(alpha: 0.2)
                  : AppTheme.faintColor(context).withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name, style: AppTheme.serif(13, color: textCol)),
              ),
              if (time != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(time.format(context),
                      style: AppTheme.label(10, color: accent)),
                )
              else
                Text(l.disciplineReminderOff,
                    style: AppTheme.label(10, color: mutedCol)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportLanguageCard(String label, String code, Color accent, Color textCol) {
    final isSelected = _reportLanguage == code;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _reportLanguage = code);
          StorageService.instance.setSetting('reportLanguage', code);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? accent.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accent : accent.withValues(alpha: 0.2),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: AppTheme.serif(12, color: isSelected ? accent : textCol),
              textAlign: TextAlign.center),
        ),
      ),
    );
  }

  Widget _frequencyChip(String label, String value) {
    final selected = _goalFrequency == value;
    final accent = AppTheme.accentGold(context);
    return GestureDetector(
      onTap: () {
        setState(() => _goalFrequency = value);
        StorageService.instance.setSetting('goalFrequency', value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent : accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? accent : accent.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: AppTheme.serif(12,
            color: selected ? AppTheme.bg0 : AppTheme.textColor(context)),
        ),
      ),
    );
  }

  Future<void> _showGoalInputDialog(int currentValue, ValueChanged<int> onChanged) async {
    final controller = TextEditingController(text: currentValue > 0 ? '$currentValue' : '');
    final accent = AppTheme.accentGold(context);
    final l = S.of(context);

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(ctx),
        title: Text(l.enterGoalValue, style: AppTheme.serif(16, color: AppTheme.textColor(ctx))),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: AppTheme.display(20, color: accent),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent.withValues(alpha: 0.3))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
          ),
          onSubmitted: (v) {
            Navigator.of(ctx).pop(int.tryParse(v) ?? 0);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.cancel, style: TextStyle(color: AppTheme.mutedColor(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(int.tryParse(controller.text) ?? 0),
            child: Text('OK', style: TextStyle(color: accent)),
          ),
        ],
      ),
    );

    if (result != null) {
      onChanged(result);
    }
  }

  Widget _goalField(String label, String icon, int value, ValueChanged<int> onChanged) {
    final accent = AppTheme.accentGold(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: AppTheme.serif(13, color: AppTheme.textColor(context))),
          ),
          GestureDetector(
            onTap: () {
              if (value > 0) onChanged(value - 1);
            },
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.remove, size: 18, color: value > 0 ? accent : AppTheme.faintColor(context)),
            ),
          ),
          GestureDetector(
            onTap: () => _showGoalInputDialog(value, onChanged),
            child: Container(
              width: 44,
              alignment: Alignment.center,
              child: Text('$value',
                  style: AppTheme.display(16, color: value > 0 ? accent : AppTheme.mutedColor(context))),
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(value + 1),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.add, size: 18, color: accent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDisciplineTime(int index) async {
    final accent = AppTheme.accentGold(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: _disciplineTimes[index] ?? const TimeOfDay(hour: 6, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: AppTheme.isDark(context)
              ? ColorScheme.dark(primary: accent, surface: AppTheme.bg2, onSurface: AppTheme.cream)
              : ColorScheme.light(primary: accent, surface: AppTheme.lightBg2, onSurface: AppTheme.lightText),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _disciplineTimes[index] = picked);
      final s = StorageService.instance;
      await s.setSetting('discReminder_$index', '${picked.hour}:${picked.minute}');
      await s.setSetting('discName_$index', _disciplineNames[index]);
      await NotificationService.instance.scheduleDisciplineReminder(
        index, picked.hour, picked.minute, _disciplineNames[index],
      );
    }
  }
}
