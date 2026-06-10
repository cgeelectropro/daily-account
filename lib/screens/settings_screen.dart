import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart';
import '../services/backup_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

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
  bool _loading = true;

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

  Future<void> _scheduleAllNotifications() async {
    final l = S.of(context);
    await NotificationService.instance.scheduleDailyReminder(
      _dailyTime.hour, _dailyTime.minute,
      title: l.notifDailyTitle,
      body: l.notifDailyBody,
    );
    await NotificationService.instance.scheduleSundayReminder(
      _sundayTime.hour, _sundayTime.minute,
      title: l.notifSundayTitle,
      body: l.notifSundayBody,
    );
    if (_autoSendEnabled) {
      await NotificationService.instance.scheduleAutoSendReminder(
        _autoSendTime.hour, _autoSendTime.minute,
        title: l.notifSundayTitle,
        body: l.notifSundayBody,
      );
    }
  }

  Future<void> _saveReminders() async {
    final l = S.of(context);
    // Email validation
    if (_email.isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(_email)) {
      _toast(l.invalidEmail);
      return;
    }
    // WhatsApp validation
    if (_whatsapp.isNotEmpty && !RegExp(r'^\d{10,15}$').hasMatch(_whatsapp)) {
      _toast(l.invalidWhatsapp);
      return;
    }
    final s = StorageService.instance;
    await s.setSetting('dailyHour', '${_dailyTime.hour}');
    await s.setSetting('dailyMin', '${_dailyTime.minute}');
    await s.setSetting('sundayHour', '${_sundayTime.hour}');
    await s.setSetting('sundayMin', '${_sundayTime.minute}');

    if (_notificationsEnabled) {
      await _scheduleAllNotifications();
    }
    if (!mounted) return;
    _toast(l.remindersSaved);
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
            child: const Text('Replace', style: TextStyle(color: AppTheme.rust)),
          ),
        ],
      ),
    );
    if (merge == null) return;
    final success = await BackupService.instance.importData(data, merge: merge);
    if (mounted) _toast(success ? l.importSuccess : l.importFailed);
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
        onTap: () => DailyAccountApp.setLocale(context, Locale(code)),
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

        // ── Disciple Maker ──
        SectionCard(icon: '📧', title: l.discipleMakerSection, children: [
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
        ]),

        // ── Notifications ──
        SectionCard(icon: '🔔', title: l.notificationsSection, children: [
          _switchRow(l.notificationsEnabled, _notificationsEnabled, _toggleNotifications),
          if (_notificationsEnabled) ...[
            const SizedBox(height: 8),
            _timeRow(l.dailyReminder, _dailyTime, () => _pickTime(true)),
            const SizedBox(height: 8),
            _timeRow(l.sundayReminder, _sundayTime, () => _pickTime(false)),
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
        SectionCard(icon: '🌐', title: l.languageSection, children: [
          Row(
            children: [
              _languageCard('🇬🇧', l.languageEnglish, 'en'),
              const SizedBox(width: 12),
              _languageCard('🇫🇷', l.languageFrench, 'fr'),
            ],
          ),
        ]),

        // ── Backup ──
        SectionCard(icon: '💾', title: l.backupSection, children: [
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
              Text('✝️', style: TextStyle(fontSize: 28, color: accent)),
              const SizedBox(height: 8),
              Text(l.appTitle, style: AppTheme.display(18, color: accent)),
              const SizedBox(height: 4),
              Text(l.appVersion('1.1.0'), style: AppTheme.serif(12, color: mutedCol)),
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
}
