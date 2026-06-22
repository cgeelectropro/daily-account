import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/generated/app_localizations_en.dart';
import '../l10n/generated/app_localizations_fr.dart';
import '../services/notification_service.dart';
import '../services/pdf_report_service.dart';
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
  String _fullReport = '';
  String _compactReport = '';
  WeekStats? _stats;
  int _streak = 0;
  String _name = '';
  String _email = '';
  String _whatsapp = '';
  bool _loading = true;
  bool _isMonthly = false;
  bool _sending = false; // prevent double-tap sends

  // Week navigation
  late DateTime _weekRef; // any date within the viewed week
  MonthStats? _monthStats;
  String _monthlyReport = '';

  // Chart data — completion % per day of the week
  List<double> _weekCompletions = List.filled(7, 0.0);

  // Trend data
  TrendData? _trend;

  // Goals
  Map<String, int> _goals = {};
  String _goalFrequency = 'weekly';

  // Badges
  List<(String, String, bool)> _badges = []; // (emoji, label, earned)

  @override
  void initState() {
    super.initState();
    _weekRef = DateTime.now();
    _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loading && _fullReport.isEmpty) _buildReport();
  }

  DateTime _mondayOf(DateTime d) {
    final mon = d.subtract(Duration(days: (d.weekday - 1) % 7));
    return DateTime(mon.year, mon.month, mon.day);
  }

  bool get _isCurrentWeek =>
      _mondayOf(DateTime.now()) == _mondayOf(_weekRef);

  Future<void> _refresh() async {
    final s = StorageService.instance;
    _name = await s.getSetting('myName');
    _email = await s.getSetting('discipleEmail');
    _whatsapp = await s.getSetting('discipleWhatsApp');
    _stats = await ReportService.instance.computeWeekStats(_weekRef);
    _streak = await ReportService.instance.computeStreak();
    _trend = await ReportService.instance.computeTrend(_weekRef);
    await _loadWeekCompletions();
    await _loadGoals();
    _computeBadges();
    if (mounted) {
      setState(() => _loading = false);
      _buildReport();
    }
  }

  Future<void> _loadWeekCompletions() async {
    final dates = ReportService.instance.weekDates(_weekRef);
    final completions = <double>[];
    for (final d in dates) {
      final log = await StorageService.instance.getLog(ReportService.instance.keyFor(d));
      completions.add(log?.completeness ?? 0.0);
    }
    _weekCompletions = completions;
  }

  Future<void> _loadGoals() async {
    final s = StorageService.instance;
    _goalFrequency = await s.getSetting('goalFrequency', fallback: 'weekly');
    _goals = {
      'bibleChapters': int.tryParse(await s.getSetting('goalBibleChapters', fallback: '0')) ?? 0,
      'prayerMinutes': int.tryParse(await s.getSetting('goalPrayerMinutes', fallback: '0')) ?? 0,
      'evangelismContacts': int.tryParse(await s.getSetting('goalEvangelismContacts', fallback: '0')) ?? 0,
      'literatureItems': int.tryParse(await s.getSetting('goalLiteratureItems', fallback: '0')) ?? 0,
    };
  }

  bool get _hasGoals => _goals.values.any((v) => v > 0);

  void _computeBadges() {
    if (!mounted) return;
    final l = S.of(context);
    final s = _stats;
    _badges = [
      ('\uD83D\uDD25', l.badgeStreakWeek, _streak >= 7),
      ('\uD83C\uDFC6', l.badgeStreakMonth, _streak >= 30),
      ('\uD83D\uDCD6', l.badgeBibleMarathon, (s?.totalBibleChapters ?? 0) >= 20),
      ('\uD83D\uDE4F', l.badgePrayerWarrior, (s?.daysLogged ?? 0) >= 5),
      ('\uD83D\uDCE2', l.badgeEvangelismFire, (s?.totalEvangelismContacts ?? 0) >= 5),
      ('\u2B50', l.badgePerfectWeek, (s?.daysLogged ?? 0) == 7),
    ];
  }

  /// Get the S instance for the user's chosen report language.
  /// Falls back to app locale if not set.
  Future<S> _reportLocalizations() async {
    final lang = await StorageService.instance.getSetting('reportLanguage', fallback: '');
    if (lang == 'en') return SEn();
    if (lang == 'fr') return SFr();
    // Default: use the app's current locale
    return S.of(context);
  }

  Future<void> _buildReport() async {
    if (!mounted) return;
    final l = await _reportLocalizations();
    if (_isMonthly) {
      _monthStats = await ReportService.instance.computeMonthStats(_weekRef.year, _weekRef.month);
      _monthlyReport = await ReportService.instance.buildMonthlyReport(_name, l, _weekRef.year, _weekRef.month);
    } else {
      final results = await Future.wait([
        ReportService.instance.buildFullReport(_name, l, _weekRef),
        ReportService.instance.buildCompactReport(_name, l, _weekRef),
      ]);
      _fullReport = results[0];
      _compactReport = results[1];
      _stats = await ReportService.instance.computeWeekStats(_weekRef);
    }
    if (mounted) setState(() {});
  }

  void _goToPreviousWeek() {
    setState(() {
      if (_isMonthly) {
        _weekRef = DateTime(_weekRef.year, _weekRef.month - 1, 15);
      } else {
        _weekRef = _weekRef.subtract(const Duration(days: 7));
      }
      _fullReport = '';
      _compactReport = '';
      _monthlyReport = '';
      _loading = true;
    });
    _refresh();
  }

  void _goToNextWeek() {
    final next = _isMonthly
        ? DateTime(_weekRef.year, _weekRef.month + 1, 15)
        : _weekRef.add(const Duration(days: 7));
    if (next.isAfter(DateTime.now())) return;
    setState(() {
      _weekRef = next;
      _fullReport = '';
      _compactReport = '';
      _monthlyReport = '';
      _loading = true;
    });
    _refresh();
  }

  void _goToCurrentWeek() {
    setState(() {
      _weekRef = DateTime.now();
      _fullReport = '';
      _compactReport = '';
      _monthlyReport = '';
      _loading = true;
    });
    _refresh();
  }

  void _toggleReportMode() {
    setState(() {
      _isMonthly = !_isMonthly;
      _fullReport = '';
      _compactReport = '';
      _monthlyReport = '';
    });
    _buildReport();
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: AppTheme.serif(14, color: AppTheme.textColor(context))),
        backgroundColor: AppTheme.surfaceColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.accentGold(context)),
        ),
      ));

  Future<bool> _confirmSend() async {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text(l.confirmSendTitle, style: AppTheme.display(18, color: accent)),
        content: Text(l.confirmSendBody, style: AppTheme.serif(14, color: AppTheme.textColor(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel, style: TextStyle(color: AppTheme.mutedColor(context)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.send, style: TextStyle(color: accent))),
        ],
      ),
    );
    return result ?? false;
  }

  String get _activeReport => _isMonthly ? _monthlyReport : _fullReport;

  Future<void> _sendEmail() async {
    if (_sending) return;
    final l = S.of(context);
    if (_email.isEmpty) { _toast('\u26A0\uFE0F ${l.addEmailInSettings}'); return; }
    if (!await _confirmSend()) return;
    HapticFeedback.mediumImpact();
    setState(() => _sending = true);
    try {
      final ok = await ReportService.instance.sendByEmail(_email, _name, _activeReport, l);
      if (!mounted) return;
      if (ok) await _recordSend('email');
      _toast(ok ? '\uD83D\uDCE8 ${l.sendEmail}...' : '\u274C ${l.emailError}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendWhatsApp() async {
    if (_sending) return;
    final l = S.of(context);
    if (_whatsapp.isEmpty) { _toast('\u26A0\uFE0F ${l.addWhatsAppInSettings}'); return; }
    if (!await _confirmSend()) return;
    HapticFeedback.mediumImpact();
    setState(() => _sending = true);
    try {
      final report = _isMonthly ? _monthlyReport : _fullReport;
      final ok = await ReportService.instance.sendByWhatsApp(_whatsapp, report);
      if (!mounted) return;
      if (ok) await _recordSend('whatsapp');
      _toast(ok ? '\uD83D\uDCAC ${l.sendWhatsApp}...' : '\u274C ${l.whatsappError}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sharePdf() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      if (_isMonthly) {
        await PdfReportService.instance.shareMonthlyPdf(_name, _weekRef.year, _weekRef.month);
      } else {
        await PdfReportService.instance.shareWeeklyPdf(_name, _weekRef);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: _activeReport));
    _toast('\uD83D\uDCCB ${S.of(context).reportCopied}');
  }

  Future<void> _share() async {
    await ReportService.instance.shareReport(_activeReport);
  }

  /// Save report to archive when sent.
  Future<void> _recordSend(String channel) async {
    final dates = ReportService.instance.weekDates(_weekRef);
    final weekStart = ReportService.instance.keyFor(dates.first);
    final weekEnd = ReportService.instance.keyFor(dates.last);
    await StorageService.instance.saveReport(
      weekStart: weekStart,
      weekEnd: weekEnd,
      fullReport: _fullReport,
      compactReport: _compactReport,
      sentVia: channel,
    );
    // Cancel Sunday follow-up reminders — report has been sent
    NotificationService.instance.cancelSundayFollowUps();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.accentGold(context)));
    }
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        // Title row with weekly/monthly toggle
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.reportTitle, style: AppTheme.display(24, color: accent)),
                  Text(l.reportSubtitle, style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
                ],
              ),
            ),
            // Weekly / Monthly toggle
            GestureDetector(
              onTap: _toggleReportMode,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _isMonthly ? l.weeklyReport : l.monthlyReport,
                  style: AppTheme.label(11, color: accent),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Week/Month navigation
        _buildPeriodNavigator(l, accent),
        const SizedBox(height: 16),

        // Streak banner (only for current week view)
        if (!_isMonthly && _isCurrentWeek) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                accent.withValues(alpha: 0.18),
                AppTheme.goldDeep.withValues(alpha: 0.08),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Text('\uD83D\uDD25', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.streakDays(_streak),
                        style: AppTheme.display(28, color: AppTheme.goldSoft)),
                    Text(l.streakLabel, style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96)),
          const SizedBox(height: 16),
        ],

        // Stats grid
        if (_isMonthly && _monthStats != null)
          _buildMonthlyStats(l)
        else if (!_isMonthly && _stats != null)
          _buildWeeklyStats(l),

        const SizedBox(height: 16),

        // Weekly goals progress
        if (!_isMonthly && _hasGoals && _stats != null)
          _buildGoalsCard(l, accent),

        // Trend analysis
        if (!_isMonthly && _trend != null && _trend!.hasData)
          _buildTrendCard(l, accent),

        // Weekly progress chart
        if (!_isMonthly) ...[
          _buildWeeklyChart(l, accent),
          const SizedBox(height: 16),
        ],

        // Badges / achievements
        if (!_isMonthly && _isCurrentWeek) ...[
          _buildBadges(l, accent),
          const SizedBox(height: 16),
        ],

        // Sunday banner
        if (!_isMonthly && _isCurrentWeek && DateTime.now().weekday == DateTime.sunday)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent),
            ),
            child: Row(
              children: [
                const Text('\u{1F54A}\uFE0F', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l.sundayBanner,
                      style: AppTheme.serif(13, color: AppTheme.goldSoft)),
                ),
              ],
            ),
          ).animate().fadeIn(),

        // Monthly certificate
        if (_isMonthly && _monthStats != null) ...[
          _buildCertificateCard(l, accent),
          const SizedBox(height: 16),
        ],

        // Empty state or report preview + send buttons
        if (_isMonthly) ...[
          _buildReportPreviewAndButtons(l, accent, _monthlyReport),
        ] else if (_stats != null && _stats!.daysLogged == 0) ...[
          const SizedBox(height: 40),
          Center(
            child: Text(
              _isCurrentWeek ? l.noReportYet : l.noReportForWeek,
              textAlign: TextAlign.center,
              style: AppTheme.serif(15, color: AppTheme.mutedColor(context)),
            ),
          ),
        ] else ...[
          _buildReportPreviewAndButtons(l, accent, _fullReport),
        ],
      ],
    );
  }

  Widget _buildPeriodNavigator(S l, Color accent) {
    final fmtRange = DateFormat('MMM d');
    final fmtMonth = DateFormat('MMMM yyyy');

    String label;
    if (_isMonthly) {
      label = fmtMonth.format(_weekRef);
    } else {
      final dates = ReportService.instance.weekDates(_weekRef);
      label = '${fmtRange.format(dates.first)} \u2013 ${fmtRange.format(dates.last)}';
    }

    final isCurrentPeriod = _isMonthly
        ? (_weekRef.year == DateTime.now().year && _weekRef.month == DateTime.now().month)
        : _isCurrentWeek;

    return Row(
      children: [
        GestureDetector(
          onTap: _goToPreviousWeek,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.chevron_left, color: accent, size: 24),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text(label, style: AppTheme.serif(14, color: AppTheme.textColor(context)), textAlign: TextAlign.center),
              if (!isCurrentPeriod)
                GestureDetector(
                  onTap: _goToCurrentWeek,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '\u21A9 ${l.thisWeek}',
                      style: AppTheme.label(10, color: accent),
                    ),
                  ),
                ),
            ],
          ),
        ),
        GestureDetector(
          onTap: isCurrentPeriod ? null : _goToNextWeek,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.chevron_right,
              color: isCurrentPeriod ? AppTheme.faintColor(context) : accent,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyStats(S l) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: StatTile(value: '${_stats!.daysLogged}/7', label: l.daysLogged, icon: '\u2705')),
            const SizedBox(width: 10),
            Expanded(child: StatTile(value: '${_stats!.totalBibleChapters}', label: l.bibleChapters, icon: '\uD83D\uDCD6')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: StatTile(value: '${_stats!.litItems}', label: l.booksRead, icon: '\uD83D\uDCDA')),
            const SizedBox(width: 10),
            Expanded(child: StatTile(value: '${_stats!.totalEvangelismContacts}', label: l.soulsReached, icon: '\uD83D\uDCE2')),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthlyStats(S l) {
    final ms = _monthStats!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: StatTile(value: '${ms.daysLogged}/${ms.totalDays}', label: l.daysLogged, icon: '\u2705')),
            const SizedBox(width: 10),
            Expanded(child: StatTile(value: '${ms.totalBibleChapters}', label: l.bibleChapters, icon: '\uD83D\uDCD6')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: StatTile(value: '${ms.litItems}', label: l.booksRead, icon: '\uD83D\uDCDA')),
            const SizedBox(width: 10),
            Expanded(child: StatTile(value: '${ms.totalEvangelismContacts}', label: l.soulsReached, icon: '\uD83D\uDCE2')),
          ],
        ),
      ],
    );
  }

  Widget _buildGoalsCard(S l, Color accent) {
    final s = _stats!;
    final isDaily = _goalFrequency == 'daily';
    // For daily goals, multiply target by days logged (or 7 for weekly view)
    // so progress compares actual totals against proportional targets
    final days = s.daysLogged > 0 ? s.daysLogged : 1;

    final items = <(String, String, int, int)>[]; // (icon, label, current, target)
    final gb = _goals['bibleChapters'] ?? 0;
    if (gb > 0) items.add(('\uD83D\uDCD6', l.goalBibleChapters, s.totalBibleChapters, isDaily ? gb * days : gb));
    final gp = _goals['prayerMinutes'] ?? 0;
    if (gp > 0) items.add(('\uD83D\uDE4F', l.goalPrayerMinutes, s.totalPrayerMinutes, isDaily ? gp * days : gp));
    final ge = _goals['evangelismContacts'] ?? 0;
    if (ge > 0) items.add(('\uD83D\uDCE2', l.goalEvangelismContacts, s.totalEvangelismContacts, isDaily ? ge * days : ge));
    final gl = _goals['literatureItems'] ?? 0;
    if (gl > 0) items.add(('\uD83D\uDCDA', l.goalLiteratureItems, s.litItems, isDaily ? gl * days : gl));

    final title = isDaily ? l.dailyGoals : l.weeklyGoals;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.isDark(context)
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
            const SizedBox(height: 12),
            ...items.map((item) => _goalProgressRow(item.$1, item.$2, item.$3, item.$4, accent)),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _goalProgressRow(String icon, String label, int current, int target, Color accent) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final reached = current >= target;
    final l = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: AppTheme.serif(13, color: AppTheme.textColor(context))),
              ),
              Text(
                reached ? l.goalReached : l.goalProgress('$current', '$target'),
                style: AppTheme.label(11, color: reached ? AppTheme.green : accent),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: accent.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                reached ? AppTheme.green : accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(S l, Color accent) {
    final t = _trend!;
    final changePct = (t.change * 100).round();
    final currentPct = (t.currentConsistency * 100).round();

    String trendLabel;
    String trendIcon;
    Color trendColor;
    if (changePct > 2) {
      trendLabel = l.trendUp(changePct);
      trendIcon = '\u2B06\uFE0F';
      trendColor = Colors.green;
    } else if (changePct < -2) {
      trendLabel = l.trendDown(changePct.abs());
      trendIcon = '\u2B07\uFE0F';
      trendColor = Colors.redAccent;
    } else {
      trendLabel = l.trendSteady;
      trendIcon = '\u2796';
      trendColor = accent;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.isDark(context)
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.trendTitle, style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
            const SizedBox(height: 12),
            // Main consistency row
            Row(
              children: [
                Text(trendIcon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$currentPct%  ${l.trendConsistency}',
                        style: AppTheme.display(20, color: accent)),
                    Text('$trendLabel ${l.trendVsLastMonth}',
                        style: AppTheme.serif(12, color: trendColor)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Best & weakest disciplines
            Row(
              children: [
                if (t.bestDiscipline != null) ...[
                  Expanded(
                    child: _trendChip('\u2B50', l.trendBestDiscipline, t.bestDiscipline!, accent),
                  ),
                  const SizedBox(width: 8),
                ],
                if (t.weakDiscipline != null)
                  Expanded(
                    child: _trendChip('\uD83D\uDCA1', l.trendWeakDiscipline, t.weakDiscipline!, accent),
                  ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _trendChip(String icon, String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(label.toUpperCase(), style: AppTheme.label(9, color: AppTheme.mutedColor(context))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.serif(13, color: AppTheme.textColor(context))),
        ],
      ),
    );
  }

  Widget _buildCertificateCard(S l, Color accent) {
    final pct = _monthStats != null ? (_monthStats!.avgCompletion * 100).round() : 0;
    final eligible = pct >= 80;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.certificateTitle.toUpperCase(),
              style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          Text(l.certificateSubtitle,
              style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
          const SizedBox(height: 12),
          if (eligible)
            GestureDetector(
              onTap: () async {
                await PdfReportService.instance.shareCertificatePdf(
                  _name, _weekRef.year, _weekRef.month,
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text('\uD83C\uDFC6 ${l.certificateGenerate}',
                    style: AppTheme.display(15, color: AppTheme.bg0)),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.15)),
              ),
              child: Text(
                l.certificateNoData,
                style: AppTheme.serif(12, color: AppTheme.mutedColor(context)),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildWeeklyChart(S l, Color accent) {
    final dates = ReportService.instance.weekDates(_weekRef);
    final dayLabels = dates.map((d) => DateFormat('E').format(d).substring(0, 1)).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.weeklyChart, style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                maxY: 100,
                minY: 0,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.surfaceColor(context),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.round()}%',
                        AppTheme.serif(12, color: accent),
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: accent.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 50,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: AppTheme.label(9, color: AppTheme.faintColor(context)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= dayLabels.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(dayLabels[idx],
                              style: AppTheme.label(10, color: AppTheme.faintColor(context))),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(7, (i) {
                  final pct = (_weekCompletions.length > i ? _weekCompletions[i] : 0.0) * 100;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: pct,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            accent.withValues(alpha: 0.4),
                            accent,
                          ],
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 100,
                          color: accent.withValues(alpha: 0.06),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildBadges(S l, Color accent) {
    final earned = _badges.where((b) => b.$3).toList();
    final locked = _badges.where((b) => !b.$3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.badgesTitle, style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
          const SizedBox(height: 12),
          if (earned.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l.badgesEmpty,
                  style: AppTheme.serif(12, color: AppTheme.mutedColor(context))),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: earned.map((b) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(b.$1, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(b.$2, style: AppTheme.serif(11, color: AppTheme.bg0, weight: FontWeight.w600)),
                  ],
                ),
              )).toList(),
            ),
          if (locked.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: locked.map((b) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('\uD83D\uDD12', style: TextStyle(fontSize: 14, color: AppTheme.faintColor(context))),
                    const SizedBox(width: 6),
                    Text(b.$2, style: AppTheme.serif(11, color: AppTheme.faintColor(context))),
                  ],
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildReportPreviewAndButtons(S l, Color accent, String report) {
    if (report.isEmpty) {
      return Center(child: CircularProgressIndicator(color: accent));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.previewLabel, style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.isDark(context)
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.15)),
          ),
          child: Text(report,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                height: 1.6,
                color: AppTheme.mutedColor(context),
              )),
        ),
        const SizedBox(height: 20),

        // Send buttons
        _bigButton('\uD83D\uDCE7  ${l.sendEmail}', AppTheme.goldGradient, AppTheme.bg0, _sending ? null : () => _sendEmail()),
        const SizedBox(height: 10),
        _bigButton('\uD83D\uDCAC  ${l.sendWhatsApp}', AppTheme.goldGradient, AppTheme.bg0, _sending ? null : () => _sendWhatsApp()),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _outlineButton('\uD83D\uDCE4 ${l.shareReport}', () => _share())),
            const SizedBox(width: 10),
            Expanded(child: _outlineButton('\uD83D\uDCCB ${l.copyReport}', _copy)),
          ],
        ),
        const SizedBox(height: 10),
        _outlineButton('\uD83D\uDCC4 ${l.sharePdf}', _sending ? null : () => _sharePdf()),
      ],
    );
  }

  Widget _bigButton(String text, Gradient grad, Color fg, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(gradient: grad, borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.center,
          child: Text(text, style: AppTheme.display(17, color: fg)),
        ),
      ),
    );
  }

  Widget _outlineButton(String text, VoidCallback? onTap) {
    final accent = AppTheme.accentGold(context);
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: Text(text, style: AppTheme.display(15, color: accent)),
        ),
      ),
    );
  }
}
