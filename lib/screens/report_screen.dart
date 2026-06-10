import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../l10n/generated/app_localizations.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Build the report once we have access to context (for i18n)
    if (!_loading && _report.isEmpty) _buildReport();
  }

  Future<void> _refresh() async {
    final s = StorageService.instance;
    _name = await s.getSetting('myName');
    _email = await s.getSetting('discipleEmail');
    _whatsapp = await s.getSetting('discipleWhatsApp');
    _stats = await ReportService.instance.computeWeekStats();
    _streak = await ReportService.instance.computeStreak();
    if (mounted) {
      setState(() => _loading = false);
      _buildReport();
    }
  }

  Future<void> _buildReport() async {
    if (!mounted) return;
    final l = S.of(context);
    _report = await ReportService.instance.buildWeeklyReport(_name, l);
    if (mounted) setState(() {});
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

  Future<bool> _confirmSend() async {
    final l = S.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg2,
        title: Text(l.confirmSendTitle, style: AppTheme.display(18, color: AppTheme.gold)),
        content: Text(l.confirmSendBody, style: AppTheme.serif(14, color: AppTheme.cream)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel, style: const TextStyle(color: AppTheme.sand))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.send, style: const TextStyle(color: AppTheme.gold))),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _sendEmail() async {
    final l = S.of(context);
    if (_email.isEmpty) { _toast('⚠️ ${l.addEmailInSettings}'); return; }
    if (!await _confirmSend()) return;
    final ok = await ReportService.instance.sendByEmail(_email, _name, _report, l);
    if (!mounted) return;
    _toast(ok ? '📨 ${l.sendEmail}...' : '❌ ${l.emailError}');
  }

  Future<void> _sendWhatsApp() async {
    final l = S.of(context);
    if (_whatsapp.isEmpty) { _toast('⚠️ ${l.addWhatsAppInSettings}'); return; }
    if (!await _confirmSend()) return;
    final ok = await ReportService.instance.sendByWhatsApp(_whatsapp, _report);
    if (!mounted) return;
    _toast(ok ? '💬 ${l.sendWhatsApp}...' : '❌ ${l.whatsappError}');
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _report));
    _toast('📋 ${S.of(context).reportCopied}');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.gold));
    }
    final isSunday = DateTime.now().weekday == DateTime.sunday;

    final l = S.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Text(l.reportTitle, style: AppTheme.display(24, color: AppTheme.gold)),
        Text(l.reportSubtitle, style: AppTheme.serif(13, color: AppTheme.sand)),
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
                  Text(l.streakDays(_streak),
                      style: AppTheme.display(28, color: AppTheme.goldSoft)),
                  Text(l.streakLabel, style: AppTheme.serif(13, color: AppTheme.sand)),
                ],
              ),
            ],
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96)),
        const SizedBox(height: 16),

        // Stats grid
        Row(
          children: [
            Expanded(child: StatTile(value: '${_stats!.daysLogged}/7', label: l.daysLogged, icon: '✅')),
            const SizedBox(width: 10),
            Expanded(child: StatTile(value: '${_stats!.totalBibleChapters}', label: l.bibleChapters, icon: '📖')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: StatTile(value: '${_stats!.litItems}', label: l.booksRead, icon: '📚')),
            const SizedBox(width: 10),
            Expanded(child: StatTile(value: '${_stats!.totalEvangelismContacts}', label: l.soulsReached, icon: '📢')),
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
                  child: Text(l.sundayBanner,
                      style: AppTheme.serif(13, color: AppTheme.goldSoft)),
                ),
              ],
            ),
          ).animate().fadeIn(),

        // Empty state or report preview + send buttons
        if (_stats != null && _stats!.daysLogged == 0) ...[
          const SizedBox(height: 40),
          Center(
            child: Text(l.noReportYet, textAlign: TextAlign.center, style: AppTheme.serif(15, color: AppTheme.sand)),
          ),
        ] else ...[
          // Report preview
          Text(l.previewLabel, style: AppTheme.label(11, color: AppTheme.gold.withOpacity(0.7))),
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
          _bigButton('📧  ${l.sendEmail}', AppTheme.goldGradient, AppTheme.bg0, _sendEmail),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _outlineButton('💬 ${l.sendWhatsApp}', _sendWhatsApp)),
              const SizedBox(width: 10),
              Expanded(child: _outlineButton('📋 ${l.copyReport}', _copy)),
            ],
          ),
        ],
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
