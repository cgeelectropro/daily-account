import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/report_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _report = '';
  WeekStats? _stats;
  int _streak = 0;
  String _name = '';
  String _email = '';
  String _whatsapp = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = StorageService.instance;
    _name = await s.getSetting('myName');
    _email = await s.getSetting('discipleEmail');
    _whatsapp = await s.getSetting('discipleWhatsApp');
    _report = await ReportService.instance.buildWeeklyReport(_name);
    _stats = await ReportService.instance.computeWeekStats();
    _streak = await ReportService.instance.computeStreak();
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

  Future<void> _sendEmail() async {
    if (_email.isEmpty) { _toast('⚠️ Add your disciple maker\'s email in Settings.'); return; }
    final ok = await ReportService.instance.sendByEmail(_email, _name, _report);
    _toast(ok ? '📨 Opening email to send your account...' : '❌ Could not open email app.');
  }

  Future<void> _sendWhatsApp() async {
    if (_whatsapp.isEmpty) { _toast('⚠️ Add a WhatsApp number in Settings.'); return; }
    final ok = await ReportService.instance.sendByWhatsApp(_whatsapp, _report);
    _toast(ok ? '💬 Opening WhatsApp...' : '❌ Could not open WhatsApp.');
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _report));
    _toast('📋 Report copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.gold));
    }
    final isSunday = DateTime.now().weekday == DateTime.sunday;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Text('Weekly Account', style: AppTheme.display(24, color: AppTheme.gold)),
        Text('Your walk with God, this week', style: AppTheme.serif(13, color: AppTheme.sand)),
        const SizedBox(height: 20),

        // Streak banner
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.gold.withOpacity(0.18),
              AppTheme.goldDeep.withOpacity(0.08),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.gold.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 34)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_streak day${_streak == 1 ? "" : "s"}',
                      style: AppTheme.display(28, color: AppTheme.goldSoft)),
                  Text('Faithfulness streak', style: AppTheme.serif(13, color: AppTheme.sand)),
                ],
              ),
            ],
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96)),
        const SizedBox(height: 16),

        // Stats grid
        Row(
          children: [
            Expanded(child: StatTile(value: '${_stats!.daysLogged}/7', label: 'Days Logged', icon: '✅')),
            const SizedBox(width: 10),
            Expanded(child: StatTile(value: '${_stats!.totalBibleChapters}', label: 'Bible Chapters', icon: '📖')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: StatTile(value: '${_stats!.litItems}', label: 'Books Read', icon: '📚')),
            const SizedBox(width: 10),
            Expanded(child: StatTile(value: '${_stats!.totalEvangelismContacts}', label: 'Souls Reached', icon: '📢')),
          ],
        ),
        const SizedBox(height: 22),

        if (isSunday)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.gold),
            ),
            child: Row(
              children: [
                const Text('🕊️', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text("It's Sunday — time to send your account to your disciple maker.",
                      style: AppTheme.serif(13, color: AppTheme.goldSoft)),
                ),
              ],
            ),
          ).animate().fadeIn(),

        // Report preview
        Text('PREVIEW', style: AppTheme.label(11, color: AppTheme.gold.withOpacity(0.7))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.gold.withOpacity(0.15)),
          ),
          child: Text(_report,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                height: 1.6,
                color: AppTheme.sand,
              )),
        ),
        const SizedBox(height: 20),

        // Send buttons
        _bigButton('📧  Send via Email', AppTheme.goldGradient, AppTheme.bg0, _sendEmail),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _outlineButton('💬 WhatsApp', _sendWhatsApp)),
            const SizedBox(width: 10),
            Expanded(child: _outlineButton('📋 Copy', _copy)),
          ],
        ),
      ],
    );
  }

  Widget _bigButton(String text, Gradient grad, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(gradient: grad, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.center,
        child: Text(text, style: AppTheme.display(17, color: fg)),
      ),
    );
  }

  Widget _outlineButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.gold.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.gold.withOpacity(0.3)),
        ),
        alignment: Alignment.center,
        child: Text(text, style: AppTheme.display(15, color: AppTheme.gold)),
      ),
    );
  }
}
