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
    _dailyTime = TimeOfDay(hour: dh, minute: dm);
    _sundayTime = TimeOfDay(hour: sh, minute: sm);
    if (mounted) setState(() => _loading = false);
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: AppTheme.serif(14, color: AppTheme.cream)),
        backgroundColor: AppTheme.bg2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.gold),
        ),
      ));

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
    if (!mounted) return;
    _toast(l.remindersSaved);
  }

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
        backgroundColor: AppTheme.bg2,
        title: Text(l.importData, style: AppTheme.display(18, color: AppTheme.gold)),
        content: Text(l.importPreview(logs.length), style: AppTheme.serif(14, color: AppTheme.cream)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.importMerge, style: const TextStyle(color: AppTheme.gold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.importReplace, style: const TextStyle(color: AppTheme.rust)),
          ),
        ],
      ),
    );
    if (merge == null) return;
    final success = await BackupService.instance.importData(data, merge: merge);
    if (mounted) _toast(success ? l.importSuccess : l.importFailed);
  }

  Widget _languageCard(String flag, String label, String code) {
    final isSelected = Localizations.localeOf(context).languageCode == code;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          DailyAccountApp.setLocale(context, Locale(code));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.gold.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.gold : AppTheme.gold.withOpacity(0.2),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(flag, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(label, style: AppTheme.serif(14, color: isSelected ? AppTheme.gold : AppTheme.cream)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime(bool daily) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: daily ? _dailyTime : _sundayTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.gold,
            surface: AppTheme.bg2,
            onSurface: AppTheme.cream,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => daily ? _dailyTime = picked : _sundayTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.gold));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Text(S.of(context).settingsTitle, style: AppTheme.display(24, color: AppTheme.gold)),
        const SizedBox(height: 20),

        SectionCard(icon: '👤', title: S.of(context).profileSection, children: [
          GoldField(
            label: S.of(context).yourNameLabel,
            hint: S.of(context).yourNameHint,
            value: _name,
            onChanged: (v) { _name = v; StorageService.instance.setSetting('myName', v); },
          ),
        ]),

        SectionCard(icon: '📧', title: S.of(context).discipleMakerSection, children: [
          GoldField(
            label: S.of(context).emailLabel,
            hint: S.of(context).emailHint,
            value: _email,
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) { _email = v; StorageService.instance.setSetting('discipleEmail', v); },
          ),
          GoldField(
            label: S.of(context).whatsappLabel,
            hint: S.of(context).whatsappHint,
            value: _whatsapp,
            keyboardType: TextInputType.phone,
            onChanged: (v) { _whatsapp = v; StorageService.instance.setSetting('discipleWhatsApp', v); },
          ),
        ]),

        SectionCard(icon: '⏰', title: S.of(context).remindersSection, children: [
          _timeRow(S.of(context).dailyReminder, _dailyTime, () => _pickTime(true)),
          const SizedBox(height: 8),
          _timeRow(S.of(context).sundayReminder, _sundayTime, () => _pickTime(false)),
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
              child: Text(S.of(context).saveReminders,
                  style: AppTheme.display(15, color: AppTheme.bg0)),
            ),
          ),
        ]),

        SectionCard(
          icon: '🌐',
          title: S.of(context).languageSection,
          children: [
            Row(
              children: [
                _languageCard('🇬🇧', S.of(context).languageEnglish, 'en'),
                const SizedBox(width: 12),
                _languageCard('🇫🇷', S.of(context).languageFrench, 'fr'),
              ],
            ),
          ],
        ),

        SectionCard(
          icon: '💾',
          title: S.of(context).backupSection,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.upload, color: AppTheme.gold),
                label: Text(S.of(context).exportData, style: const TextStyle(color: AppTheme.gold)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: AppTheme.gold.withOpacity(0.3))),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _import,
                icon: const Icon(Icons.download, color: AppTheme.gold),
                label: Text(S.of(context).importData, style: const TextStyle(color: AppTheme.gold)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: AppTheme.gold.withOpacity(0.3))),
              ),
            ),
          ],
        ),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.gold.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.gold.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📌 ${S.of(context).howItWorksTitle}', style: AppTheme.display(15, color: AppTheme.gold)),
              const SizedBox(height: 8),
              Text(
                S.of(context).howItWorks,
                style: AppTheme.serif(13, color: AppTheme.sand),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timeRow(String label, TimeOfDay time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.gold.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTheme.serif(14, color: AppTheme.cream)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.15),
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
