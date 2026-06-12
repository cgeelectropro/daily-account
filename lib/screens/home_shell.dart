import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/report_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'log_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'stopwatch_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  DateTime _selected = DateTime.now();
  /// The Monday anchor of the currently viewed week.
  late DateTime _weekMonday;
  Map<String, bool> _weekCompletion = {};
  int _reportKey = 0; // forces ReportScreen rebuild on data change

  @override
  void initState() {
    super.initState();
    _weekMonday = _mondayOf(DateTime.now());
    _loadWeekCompletion();
    _trySendPending(); // retry any queued report first
    _checkAutoSend();
  }

  /// Check if the device has internet connectivity.
  Future<bool> _hasConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Retry sending a queued pending report (from a previous offline attempt).
  Future<void> _trySendPending() async {
    final s = StorageService.instance;
    final pending = await s.getPendingReport();
    if (pending == null) return;

    if (!await _hasConnectivity()) return; // still offline, try next time

    final report = pending['report'] as String;
    final whatsapp = pending['whatsapp'] as String;
    final ok = await ReportService.instance.sendByWhatsApp(whatsapp, report);
    if (ok) {
      await s.clearPendingReport();
      // Mark week as sent
      final weekKey = _key(_mondayOf(DateTime.now()));
      await s.setSetting('lastAutoSend', weekKey);
    }
  }

  /// On Sunday, if auto-send is enabled, auto-send the report via WhatsApp.
  /// If offline, queue the report and send when connectivity returns.
  Future<void> _checkAutoSend() async {
    final now = DateTime.now();
    if (now.weekday != DateTime.sunday) return;

    final s = StorageService.instance;
    final autoEnabled = (await s.getSetting('autoSendEnabled', fallback: 'false')) == 'true';
    if (!autoEnabled) return;

    final whatsapp = await s.getSetting('discipleWhatsApp');
    if (whatsapp.isEmpty) return;

    // Check if we already auto-sent this week
    final weekKey = _key(_mondayOf(now));
    final alreadySent = await s.getSetting('lastAutoSend', fallback: '');
    if (alreadySent == weekKey) return;

    // Check if there's already a pending report queued
    final pending = await s.getPendingReport();
    if (pending != null) return;

    // Check if it's past the auto-send time
    final ash = int.tryParse(await s.getSetting('autoSendHour', fallback: '19')) ?? 19;
    final asm = int.tryParse(await s.getSetting('autoSendMin', fallback: '0')) ?? 0;
    if (now.hour < ash || (now.hour == ash && now.minute < asm)) return;

    // Build the report
    final name = await s.getSetting('myName');
    if (!mounted) return;
    final l = S.of(context);
    final fullReport = await ReportService.instance.buildFullReport(name, l);
    final compactReport = await ReportService.instance.buildCompactReport(name, l);

    // Check connectivity
    if (!await _hasConnectivity()) {
      // Queue for later
      await s.queuePendingReport(fullReport, whatsapp);
      return;
    }

    // Send now — use the full detailed report for WhatsApp
    final ok = await ReportService.instance.sendByWhatsApp(whatsapp, fullReport);

    if (ok) {
      await s.setSetting('lastAutoSend', weekKey);
      // Also save to archive
      final dates = ReportService.instance.weekDates();
      await s.saveReport(
        weekStart: ReportService.instance.keyFor(dates.first),
        weekEnd: ReportService.instance.keyFor(dates.last),
        fullReport: fullReport,
        compactReport: compactReport,
        sentVia: 'whatsapp (auto)',
      );
    } else {
      // Launch failed (WhatsApp not installed?) — queue for retry
      await s.queuePendingReport(fullReport, whatsapp);
    }
  }

  /// Returns the Monday of the week containing [d].
  DateTime _mondayOf(DateTime d) {
    final mon = d.subtract(Duration(days: (d.weekday - 1) % 7));
    return DateTime(mon.year, mon.month, mon.day);
  }

  List<DateTime> get _weekDates =>
      List.generate(7, (i) => DateTime(_weekMonday.year, _weekMonday.month, _weekMonday.day + i));

  bool get _isCurrentWeek => _mondayOf(DateTime.now()) == _weekMonday;

  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _loadWeekCompletion() async {
    final map = <String, bool>{};
    for (final d in _weekDates) {
      final log = await StorageService.instance.getLog(_key(d));
      map[_key(d)] = log?.completed ?? false;
    }
    if (mounted) setState(() => _weekCompletion = map);
  }

  void _onDataChanged() {
    _loadWeekCompletion();
    setState(() => _reportKey++);
  }

  void _goToPreviousWeek() {
    setState(() {
      _weekMonday = _weekMonday.subtract(const Duration(days: 7));
      _selected = _weekMonday; // select Monday of the new week
    });
    _loadWeekCompletion();
  }

  void _goToNextWeek() {
    final nextMonday = _weekMonday.add(const Duration(days: 7));
    // Don't go beyond current week
    if (nextMonday.isAfter(DateTime.now())) return;
    setState(() {
      _weekMonday = nextMonday;
      _selected = _weekMonday;
    });
    _loadWeekCompletion();
  }

  void _goToToday() {
    setState(() {
      _weekMonday = _mondayOf(DateTime.now());
      _selected = DateTime.now();
    });
    _loadWeekCompletion();
  }

  Future<void> _openCalendar() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
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
      ),
    );
    if (picked != null) {
      setState(() {
        _weekMonday = _mondayOf(picked);
        _selected = picked;
      });
      _loadWeekCompletion();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              if (_tab == 0) _weekStrip(),
              Expanded(child: _body()),
            ],
          ),
        ),
        bottomNavigationBar: _bottomNav(),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        children: [
          const Text('\u2720', style: TextStyle(fontSize: 26, color: AppTheme.gold)),
          const SizedBox(height: 4),
          Text(S.of(context).appTitle, style: AppTheme.display(22, color: AppTheme.accentGold(context))),
          Text(S.of(context).tagline,
              style: AppTheme.label(9, color: AppTheme.faintColor(context))),
        ],
      ),
    );
  }

  Widget _weekStrip() {
    final accent = AppTheme.accentGold(context);
    final fmtRange = DateFormat('MMM d');
    final sunday = _weekDates.last;
    final weekLabel = '${fmtRange.format(_weekMonday)} – ${fmtRange.format(sunday)}';

    return Column(
      children: [
        // Week navigation row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Row(
            children: [
              // Previous week arrow
              GestureDetector(
                onTap: _goToPreviousWeek,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.chevron_left, color: accent, size: 24),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _openCalendar,
                  child: Column(
                    children: [
                      Text(
                        weekLabel,
                        style: AppTheme.serif(13, color: AppTheme.textColor(context)),
                        textAlign: TextAlign.center,
                      ),
                      if (!_isCurrentWeek)
                        GestureDetector(
                          onTap: _goToToday,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '↩ ${S.of(context).today}',
                              style: AppTheme.label(10, color: accent),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Next week arrow (disabled if current week)
              GestureDetector(
                onTap: _isCurrentWeek ? null : _goToNextWeek,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.chevron_right,
                    color: _isCurrentWeek ? AppTheme.faintColor(context) : accent,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Day strip
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: _weekDates.map((d) {
              final key = _key(d);
              final done = _weekCompletion[key] ?? false;
              final isToday = key == _key(DateTime.now());
              final isSel = key == _key(_selected);
              final isFuture = d.isAfter(DateTime.now());
              return Expanded(
                child: GestureDetector(
                  onTap: isFuture ? null : () => setState(() => _selected = d),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: done
                          ? accent.withValues(alpha: 0.2)
                          : isToday
                              ? accent.withValues(alpha: 0.08)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSel ? accent : accent.withValues(alpha: 0.12),
                        width: isSel ? 1.6 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(DateFormat('E').format(d).substring(0, 1),
                            style: AppTheme.label(11,
                                color: isToday ? accent : AppTheme.faintColor(context))),
                        const SizedBox(height: 2),
                        Text('${d.day}',
                            style: AppTheme.serif(11,
                                color: isFuture
                                    ? AppTheme.faintColor(context)
                                    : AppTheme.textColor(context))),
                        const SizedBox(height: 2),
                        Text(
                          done ? '\u2705' : (isToday ? '\u{1F54A}\uFE0F' : (isFuture ? '\u00b7' : '\u25cb')),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    switch (_tab) {
      case 0:
        return LogScreen(
          key: ValueKey(_key(_selected)),
          date: _selected,
          onChanged: _onDataChanged,
        );
      case 1:
        return StopwatchScreen(
          onTimerStopped: _onDataChanged,
        );
      case 2:
        return ReportScreen(key: ValueKey(_reportKey));
      default:
        return const SettingsScreen();
    }
  }

  Widget _bottomNav() {
    final items = [
      ('\uD83D\uDCD6', S.of(context).tabLog, 0),
      ('\u23F1\uFE0F', S.of(context).tabStopwatch, 1),
      ('\uD83D\uDCE8', S.of(context).tabReport, 2),
      ('\u2699\uFE0F', S.of(context).tabSettings, 3),
    ];
    final dark = AppTheme.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: dark ? AppTheme.bg1 : AppTheme.lightBg1,
        border: Border(top: BorderSide(color: AppTheme.accentGold(context).withValues(alpha: 0.15))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((it) {
            final active = _tab == it.$3;
            return GestureDetector(
              onTap: () => setState(() => _tab = it.$3),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(it.$1,
                        style: TextStyle(
                            fontSize: 20,
                            color: active ? null : AppTheme.faintColor(context))),
                    const SizedBox(height: 2),
                    Text(it.$2,
                        style: AppTheme.label(10,
                            color: active ? AppTheme.accentGold(context) : AppTheme.faintColor(context))),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
