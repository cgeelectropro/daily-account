import 'package:flutter/material.dart';
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
    final s = StorageService.instance;
    await s.setSetting('dailyHour', '${_dailyTime.hour}');
    await s.setSetting('dailyMin', '${_dailyTime.minute}');
    await s.setSetting('sundayHour', '${_sundayTime.hour}');
    await s.setSetting('sundayMin', '${_sundayTime.minute}');
    await NotificationService.instance.scheduleDailyReminder(_dailyTime.hour, _dailyTime.minute);
    await NotificationService.instance.scheduleSundayReminder(_sundayTime.hour, _sundayTime.minute);
    _toast('⏰ Reminders scheduled. God bless your consistency!');
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
        Text('Settings', style: AppTheme.display(24, color: AppTheme.gold)),
        const SizedBox(height: 20),

        SectionCard(icon: '👤', title: 'Your Profile', children: [
          GoldField(
            label: 'Your Name',
            hint: 'e.g. Emmanuel',
            value: _name,
            onChanged: (v) { _name = v; StorageService.instance.setSetting('myName', v); },
          ),
        ]),

        SectionCard(icon: '📧', title: 'Disciple Maker', children: [
          GoldField(
            label: "Email Address",
            hint: 'disciplemaker@example.com',
            value: _email,
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) { _email = v; StorageService.instance.setSetting('discipleEmail', v); },
          ),
          GoldField(
            label: 'WhatsApp Number (intl, no +)',
            hint: 'e.g. 2376XXXXXXXX',
            value: _whatsapp,
            keyboardType: TextInputType.phone,
            onChanged: (v) { _whatsapp = v; StorageService.instance.setSetting('discipleWhatsApp', v); },
          ),
        ]),

        SectionCard(icon: '⏰', title: 'Reminders', children: [
          _timeRow('Daily log reminder', _dailyTime, () => _pickTime(true)),
          const SizedBox(height: 8),
          _timeRow('Sunday send reminder', _sundayTime, () => _pickTime(false)),
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
              child: Text('Save & Schedule Reminders',
                  style: AppTheme.display(15, color: AppTheme.bg0)),
            ),
          ),
        ]),

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
              Text('📌 How it works', style: AppTheme.display(15, color: AppTheme.gold)),
              const SizedBox(height: 8),
              Text(
                '1. Log your walk with God each day\n'
                '2. Mark each day complete ✅\n'
                '3. Get a gentle reminder daily, and a special one each Sunday\n'
                '4. Tap Send to email or WhatsApp the full week to your disciple maker\n'
                '5. Everything is stored privately on your device',
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
