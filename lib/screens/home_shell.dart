import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/generated/app_localizations_en.dart';
import '../l10n/generated/app_localizations_fr.dart';
import '../models/daily_log.dart';
import '../models/activity_timer.dart';
import '../services/notification_service.dart';
import '../services/report_service.dart';
import '../services/storage_service.dart';
import '../services/timer_service.dart';
import '../theme/app_theme.dart';
import 'log_screen.dart';
import 'prayer_request_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'stopwatch_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  DateTime _selected = DateTime.now();
  /// The Monday anchor of the currently viewed week.
  late DateTime _weekMonday;
  Map<String, bool> _weekCompletion = {};
  int _reportKey = 0; // forces ReportScreen rebuild on data change
  bool _hasPendingReport = false;
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _weekMonday = _mondayOf(DateTime.now());
    _loadWeekCompletion();
    _updateHomeWidget();
    _checkPendingReport();
    _trySendPending(); // retry any queued report first
    _checkAutoSend();
    _scheduleSaturdaySummary();
    _handleWidgetClicks();
    // Update widget on timer ticks
    TimerService.instance.addListener(_onTimerTick);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClickSub?.cancel();
    TimerService.instance.removeListener(_onTimerTick);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-schedule notifications on every foreground return.
      // Android can silently drop alarms after Doze, battery optimization,
      // or OEM power management — re-scheduling guarantees they stay alive.
      NotificationService.instance.rescheduleAll();
    }
  }

  void _onTimerTick() {
    _updateHomeWidget();
  }

  /// Listen for widget click deep links.
  void _handleWidgetClicks() {
    _widgetClickSub = HomeWidget.widgetClicked.listen((uri) {
      if (uri == null) return;
      _processWidgetUri(uri);
    });
    // Also check initial launch URI
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri == null) return;
      _processWidgetUri(uri);
    });
  }

  void _processWidgetUri(Uri uri) {
    switch (uri.host) {
      case 'toggle':
        if (uri.pathSegments.isNotEmpty) {
          _toggleDisciplineFromWidget(uri.pathSegments.first);
        }
      case 'timer':
        if (uri.pathSegments.isNotEmpty) {
          _handleTimerFromWidget(uri.pathSegments);
        }
      case 'proclamation':
        if (uri.pathSegments.isNotEmpty &&
            uri.pathSegments.first == 'increment') {
          _incrementProclamationFromWidget();
        }
      case 'open':
        if (uri.pathSegments.isNotEmpty) {
          switch (uri.pathSegments.first) {
            case 'log':
              setState(() => _tab = 1);
            case 'proclamation':
              setState(() => _tab = 1); // Open to log (proclamation is in log)
          }
        }
    }
  }

  /// Handle timer deep links from the widget.
  Future<void> _handleTimerFromWidget(List<String> segments) async {
    final action = segments.first;
    final ts = TimerService.instance;

    switch (action) {
      case 'start':
        if (segments.length > 1) {
          final discipline = segments[1];
          // Map discipline string to ActivityType
          ActivityType? activity;
          switch (discipline) {
            case 'prayerAlone':
              activity = ActivityType.prayerAlone;
            case 'bible':
              activity = ActivityType.bibleReading;
            case 'literature':
              activity = ActivityType.literature;
          }
          if (activity != null) {
            ts.startBuiltIn(activity);
            await HomeWidget.saveWidgetData('show_timer_picker', '0');
            _updateHomeWidget();
          }
        }
      case 'pause':
        final running = ts.activeKey;
        if (running != null) {
          ts.pause(running);
        } else {
          // Resume paused timer
          for (final entry in ts.sessions.entries) {
            if (entry.value.paused) {
              ts.start(entry.key);
              break;
            }
          }
        }
        _updateHomeWidget();
      case 'stop':
        final running = ts.activeKey;
        if (running != null) {
          await ts.stop(running);
        } else {
          // Stop any paused timer
          for (final key in ts.sessions.keys.toList()) {
            await ts.stop(key);
          }
        }
        _onDataChanged();
      case 'picker':
        // Show timer discipline picker on widget
        await HomeWidget.saveWidgetData('show_timer_picker', '1');
        await HomeWidget.updateWidget(androidName: 'FullAltarWidgetProvider');
    }
  }

  /// Increment proclamation count from widget tap.
  Future<void> _incrementProclamationFromWidget() async {
    final key = _key(DateTime.now());
    final storage = StorageService.instance;
    final existing = await storage.getLog(key);
    final log = existing ?? DailyLog(dateKey: key);

    final current = int.tryParse(log.proclamationCount) ?? 0;
    log.proclamationCount = '${current + 1}';

    await storage.saveLog(log);
    _onDataChanged();
  }

  /// Quick-toggle a discipline from the widget without opening the log screen.
  Future<void> _toggleDisciplineFromWidget(String discipline) async {
    final key = _key(DateTime.now());
    final storage = StorageService.instance;
    final existing = await storage.getLog(key);
    final log = existing ?? DailyLog(dateKey: key);

    switch (discipline) {
      case 'bible':
        log.bibleReference = log.bibleReference.isEmpty ? '\u2713' : '';
      case 'literature':
        if (log.literature.every((l) => l.title.isEmpty)) {
          log.literature = [LiteratureEntry(title: '\u2713')];
        } else {
          log.literature = [LiteratureEntry()];
        }
      case 'ddeg':
        log.ddegScripture = log.ddegScripture.isEmpty ? '\u2713' : '';
      case 'prayerAlone':
        log.prayerAloneDuration = log.prayerAloneDuration.isEmpty ? '\u2713' : '';
      case 'evangelism':
        log.evangelismContacts = log.evangelismContacts.isEmpty ? '1' : '';
      case 'fasting':
        log.fastingType = log.fastingType.isEmpty ? '\u2713' : '';
      case 'giving':
        log.givingType = log.givingType.isEmpty ? '\u2713' : '';
      case 'church':
        log.churchType = log.churchType.isEmpty ? '\u2713' : '';
      case 'discipleship':
        log.discipleshipWho = log.discipleshipWho.isEmpty ? '\u2713' : '';
      case 'proclamation':
        log.proclamationCount = log.proclamationCount.isEmpty ? '1' : '';
    }

    await storage.saveLog(log);
    _onDataChanged();
  }

  Future<void> _checkPendingReport() async {
    final pending = await StorageService.instance.getPendingReport();
    if (mounted) setState(() => _hasPendingReport = pending != null);
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
    _checkPendingReport();
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

    // Build the report in the user's preferred report language
    final name = await s.getSetting('myName');
    if (!mounted) return;
    final l = await _getReportLocalizations();
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

  /// Get the S instance for the user's chosen report language.
  Future<S> _getReportLocalizations() async {
    final lang = await StorageService.instance.getSetting('reportLanguage', fallback: '');
    if (lang == 'en') return SEn();
    if (lang == 'fr') return SFr();
    return S.of(context);
  }

  /// Schedule the Saturday summary notification with current week stats.
  Future<void> _scheduleSaturdaySummary() async {
    final stats = await ReportService.instance.computeWeekStats();
    if (!mounted) return;
    final l = S.of(context);
    await NotificationService.instance.scheduleSaturdaySummary(
      18, 0,
      title: l.saturdaySummaryTitle,
      body: l.saturdaySummaryBody(
        stats.daysLogged,
        stats.totalBibleChapters,
        stats.totalEvangelismContacts,
      ),
    );
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
    _updateHomeWidget();
    setState(() => _reportKey++);
  }

  /// Push today's completion % , streak, and discipline flags to the Android home widget.
  Future<void> _updateHomeWidget() async {
    if (!Platform.isAndroid) return;
    try {
      final todayKey = _key(DateTime.now());
      final log = await StorageService.instance.getLog(todayKey);
      final pct = log != null ? (log.completeness * 100).round() : 0;
      final streak = await ReportService.instance.computeStreak();

      await HomeWidget.saveWidgetData('completion', '$pct');
      await HomeWidget.saveWidgetData('streak', '$streak days');

      // Individual discipline flags (1 = done, 0 = not done)
      final hasBible = log != null && (log.bibleReference.isNotEmpty || log.bibleChapters.isNotEmpty);
      final hasLit = log != null && log.literature.any((l) => l.title.isNotEmpty);
      final hasDdeg = log != null && (log.ddegScripture.isNotEmpty || log.ddegNotes.isNotEmpty);
      final hasPrayer = log != null && (log.prayerAloneDuration.isNotEmpty || log.prayerOthersDuration.isNotEmpty);
      final hasEvangelism = log != null && log.evangelismContacts.isNotEmpty;
      final hasFasting = log != null && (log.fastingType.isNotEmpty || log.fastingDuration.isNotEmpty);
      final hasGiving = log != null && log.givingType.isNotEmpty;
      final hasChurch = log != null && log.churchType.isNotEmpty;
      final hasDisciple = log != null && log.discipleshipWho.isNotEmpty;
      final hasProclamation = log != null && log.proclamationCount.isNotEmpty;

      final doneFlags = [hasBible, hasLit, hasDdeg, hasPrayer, hasEvangelism,
          hasFasting, hasGiving, hasChurch, hasDisciple, hasProclamation];
      final doneCount = doneFlags.where((f) => f).length;

      await HomeWidget.saveWidgetData('d_bible', hasBible ? '1' : '0');
      await HomeWidget.saveWidgetData('d_lit', hasLit ? '1' : '0');
      await HomeWidget.saveWidgetData('d_ddeg', hasDdeg ? '1' : '0');
      await HomeWidget.saveWidgetData('d_prayer', hasPrayer ? '1' : '0');
      await HomeWidget.saveWidgetData('d_evangelism', hasEvangelism ? '1' : '0');
      await HomeWidget.saveWidgetData('d_fasting', hasFasting ? '1' : '0');
      await HomeWidget.saveWidgetData('d_giving', hasGiving ? '1' : '0');
      await HomeWidget.saveWidgetData('d_church', hasChurch ? '1' : '0');
      await HomeWidget.saveWidgetData('d_disciple', hasDisciple ? '1' : '0');
      await HomeWidget.saveWidgetData('d_proclamation', hasProclamation ? '1' : '0');
      await HomeWidget.saveWidgetData('done_count', '$doneCount');

      // Proclamation count (numeric for counter widget)
      final procCount = log?.proclamationCount ?? '0';
      await HomeWidget.saveWidgetData('proclamation_count',
          procCount.isNotEmpty ? procCount : '0');

      // DDEG scripture (for scripture card DDEG override)
      final ddegScripture = log?.ddegScripture ?? '';
      await HomeWidget.saveWidgetData('ddeg_scripture', ddegScripture);

      // Active timer info
      final ts = TimerService.instance;
      final activeKey = ts.activeKey;
      if (activeKey != null) {
        final session = ts.getSession(activeKey);
        final label = ts.timerLabelResolver?.call(activeKey) ?? 'Timer';
        final elapsed = session != null
            ? _formatDuration(session.elapsed)
            : '';
        final elapsedMs = session?.currentElapsed.inMilliseconds ?? 0;
        await HomeWidget.saveWidgetData('timer_active', '1');
        await HomeWidget.saveWidgetData('timer_paused', '0');
        await HomeWidget.saveWidgetData('timer_label', label);
        await HomeWidget.saveWidgetData('timer_elapsed', elapsed);
        await HomeWidget.saveWidgetData('timer_elapsed_ms', '$elapsedMs');
        await HomeWidget.saveWidgetData('timer_start_ms',
            '${session?.startedAt?.millisecondsSinceEpoch ?? 0}');
      } else {
        // Check for paused timer
        TimerKey? pausedKey;
        for (final entry in ts.sessions.entries) {
          if (entry.value.paused) {
            pausedKey = entry.key;
            break;
          }
        }
        if (pausedKey != null) {
          final session = ts.getSession(pausedKey);
          final label = ts.timerLabelResolver?.call(pausedKey) ?? 'Timer';
          final elapsedMs = session?.elapsed.inMilliseconds ?? 0;
          await HomeWidget.saveWidgetData('timer_active', '0');
          await HomeWidget.saveWidgetData('timer_paused', '1');
          await HomeWidget.saveWidgetData('timer_label', label);
          await HomeWidget.saveWidgetData('timer_elapsed_ms', '$elapsedMs');
        } else {
          await HomeWidget.saveWidgetData('timer_active', '0');
          await HomeWidget.saveWidgetData('timer_paused', '0');
        }
      }

      // Days logged this week (for motivational text)
      final daysThisWeek = await _countDaysThisWeek();
      await HomeWidget.saveWidgetData('days_this_week', '$daysThisWeek');

      // Widget locale — use 'language' key (set by main.dart), falling back to 'appLocale'
      var widgetLocale = await StorageService.instance.getSetting('language',
          fallback: '');
      if (widgetLocale.isEmpty) {
        widgetLocale = await StorageService.instance.getSetting('appLocale',
            fallback: 'en');
      }
      await HomeWidget.saveWidgetData('widget_locale', widgetLocale);

      // Update ALL widget providers
      await HomeWidget.updateWidget(androidName: 'ScriptureWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'DisciplineBarWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'FullAltarWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'ProclamationWidgetProvider');
    } catch (_) {
      // Widget not available — ignore
    }
  }

  /// Count how many days this week have at least one discipline logged.
  Future<int> _countDaysThisWeek() async {
    final storage = StorageService.instance;
    int count = 0;
    for (int i = 0; i < 7; i++) {
      final day = _weekMonday.add(Duration(days: i));
      if (day.isAfter(DateTime.now())) break;
      final log = await storage.getLog(_key(day));
      if (log != null && log.completeness > 0) count++;
    }
    return count;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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

  String _timerLabel(TimerKey key) {
    final l = S.of(context);
    if (key.isBuiltIn) {
      switch (key.builtIn!) {
        case ActivityType.bibleReading: return l.sectionBible;
        case ActivityType.literature: return l.sectionLiterature;
        case ActivityType.ddeg: return l.ddegShort;
        case ActivityType.prayerAlone: return l.sectionPrayerAlone;
        case ActivityType.prayerOthers: return l.sectionPrayerOthers;
        case ActivityType.evangelism: return l.sectionEvangelism;
        case ActivityType.fasting: return l.sectionFasting;
        case ActivityType.discipleship: return l.sectionDiscipleship;
        case ActivityType.church: return l.sectionChurch;
        case ActivityType.proclamation: return l.sectionProclamation;
      }
    }
    // Custom activity — read name from storage cache
    return key.customId ?? '';
  }

  String _timerIcon(TimerKey key) {
    if (key.isBuiltIn) return key.builtIn!.icon;
    return '\u2728';
  }

  @override
  Widget build(BuildContext context) {
    // Provide localized activity names for stopwatch notifications
    TimerService.instance.timerLabelResolver = _timerLabel;
    TimerService.instance.timerIconResolver = _timerIcon;

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              if (_hasPendingReport) _pendingReportBanner(),
              if (_tab == 1) _weekStrip(),
              Expanded(child: _body()),
            ],
          ),
        ),
        bottomNavigationBar: _bottomNav(),
      ),
    );
  }

  Widget _header() {
    final accent = AppTheme.accentGold(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text('\u2720', style: TextStyle(fontSize: 26, color: AppTheme.gold)),
                const SizedBox(height: 4),
                Text(S.of(context).appTitle, style: AppTheme.display(22, color: accent)),
                Text(S.of(context).tagline,
                    style: AppTheme.label(9, color: AppTheme.faintColor(context))),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Prayer requests button — always visible
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrayerRequestScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Text('\uD83D\uDE4F', style: const TextStyle(fontSize: 18)),
                ),
              ),
              // Quick Log button — only on Log tab
              if (_tab == 1) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showQuickLog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flash_on, color: accent, size: 16),
                        const SizedBox(width: 4),
                        Text(S.of(context).quickLogButton,
                            style: AppTheme.label(9, color: accent)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Quick Log — checkbox-based fast entry for busy days.
  void _showQuickLog() {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final disciplines = <String, (String, String, bool)>{
      'bible': ('\uD83D\uDCD6', l.sectionBible, false),
      'literature': ('\uD83D\uDCDA', l.sectionLiterature, false),
      'ddeg': ('\uD83D\uDD25', l.sectionDDEG, false),
      'prayerAlone': ('\uD83D\uDE4F', l.sectionPrayerAlone, false),
      'prayerOthers': ('\uD83E\uDD1D', l.sectionPrayerOthers, false),
      'evangelism': ('\uD83D\uDCE2', l.sectionEvangelism, false),
      'fasting': ('\uD83C\uDF7D\uFE0F', l.sectionFasting, false),
      'giving': ('\uD83D\uDCB0', l.sectionGiving, false),
      'church': ('\u26EA', l.sectionChurch, false),
      'discipleship': ('\uD83D\uDC65', l.sectionDiscipleship, false),
      'proclamation': ('\uD83D\uDCE3', l.sectionProclamation, false),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final checked = Map<String, bool>.fromEntries(
            disciplines.keys.map((k) => MapEntry(k, false)));
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.quickLogTitle, style: AppTheme.display(20, color: accent)),
                const SizedBox(height: 4),
                Text(l.quickLogSubtitle,
                    style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
                const SizedBox(height: 16),
                ...disciplines.entries.map((e) {
                  final key = e.key;
                  final emoji = e.value.$1;
                  final label = e.value.$2;
                  final isChecked = checked[key] ?? false;
                  return GestureDetector(
                    onTap: () => setSheetState(() => checked[key] = !isChecked),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isChecked
                            ? AppTheme.green.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isChecked
                              ? AppTheme.green.withValues(alpha: 0.4)
                              : accent.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(label,
                                style: AppTheme.serif(13,
                                    color: AppTheme.textColor(context))),
                          ),
                          Icon(
                            isChecked
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: isChecked
                                ? AppTheme.green
                                : AppTheme.faintColor(context),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _saveQuickLog(checked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text('\u2705 ${l.quickLogSaved}',
                          style: AppTheme.display(16, color: AppTheme.bg0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveQuickLog(Map<String, bool> checked) async {
    final key = _key(_selected);
    final storage = StorageService.instance;
    final existing = await storage.getLog(key);
    final log = existing ?? DailyLog(dateKey: key);

    // Only fill fields that are currently empty — don't overwrite existing data
    if (checked['bible'] == true && log.bibleReference.isEmpty) {
      log.bibleReference = '\u2713';
    }
    if (checked['literature'] == true && log.literature.every((l) => l.title.isEmpty)) {
      log.literature = [LiteratureEntry(title: '\u2713')];
    }
    if (checked['ddeg'] == true && log.ddegScripture.isEmpty && log.ddegNotes.isEmpty) {
      log.ddegScripture = '\u2713';
    }
    if (checked['prayerAlone'] == true && log.prayerAloneDuration.isEmpty) {
      log.prayerAloneDuration = '\u2713';
    }
    if (checked['prayerOthers'] == true && log.prayerOthersDuration.isEmpty) {
      log.prayerOthersDuration = '\u2713';
    }
    if (checked['evangelism'] == true && log.evangelismContacts.isEmpty) {
      log.evangelismContacts = '1';
    }
    if (checked['fasting'] == true && log.fastingType.isEmpty) {
      log.fastingType = '\u2713';
    }
    if (checked['giving'] == true && log.givingType.isEmpty) {
      log.givingType = '\u2713';
    }
    if (checked['church'] == true && log.churchType.isEmpty) {
      log.churchType = '\u2713';
    }
    if (checked['discipleship'] == true && log.discipleshipWho.isEmpty) {
      log.discipleshipWho = '\u2713';
    }
    if (checked['proclamation'] == true && log.proclamationCount.isEmpty) {
      log.proclamationCount = '1';
    }

    await storage.saveLog(log);
    _onDataChanged();
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

  Widget _pendingReportBanner() {
    final l = S.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.rust.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.rust.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('\u23F3', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l.pendingReportBanner,
                style: AppTheme.serif(12, color: AppTheme.rust)),
          ),
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await _trySendPending();
              if (mounted && !_hasPendingReport) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l.pendingReportSent,
                        style: AppTheme.serif(14, color: AppTheme.textColor(context))),
                    backgroundColor: AppTheme.surfaceColor(context),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.rust.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(l.pendingReportRetry,
                  style: AppTheme.label(10, color: AppTheme.rust)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    Widget child;
    switch (_tab) {
      case 0:
        child = StopwatchScreen(
          key: const ValueKey('stopwatch'),
          onTimerStopped: _onDataChanged,
        );
      case 1:
        child = LogScreen(
          key: ValueKey(_key(_selected)),
          date: _selected,
          onChanged: _onDataChanged,
        );
      case 2:
        child = ReportScreen(key: ValueKey(_reportKey));
      default:
        child = const SettingsScreen(key: ValueKey('settings'));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: child,
    );
  }

  Widget _bottomNav() {
    final items = [
      ('\u23F1\uFE0F', S.of(context).tabStopwatch, 0),
      ('\uD83D\uDCD6', S.of(context).tabLog, 1),
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
            return Semantics(
              label: it.$2,
              button: true,
              selected: active,
              child: GestureDetector(
                onTap: () {
                  if (_tab != it.$3) HapticFeedback.selectionClick();
                  setState(() => _tab = it.$3);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: Text(it.$1,
                            style: TextStyle(
                                fontSize: 20,
                                color: active ? null : AppTheme.faintColor(context))),
                      ),
                      const SizedBox(height: 2),
                      Text(it.$2,
                          style: AppTheme.label(10,
                              color: active ? AppTheme.accentGold(context) : AppTheme.faintColor(context))),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
