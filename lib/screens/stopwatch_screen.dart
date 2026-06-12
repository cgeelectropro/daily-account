import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/activity_timer.dart';
import '../models/custom_activity.dart';
import '../models/daily_log.dart';
import '../services/storage_service.dart';
import '../services/timer_service.dart';
import '../theme/app_theme.dart';
import '../utils/bible_books.dart';

class StopwatchScreen extends StatefulWidget {
  /// Called when a timer is stopped so the parent can refresh the log.
  final VoidCallback? onTimerStopped;

  const StopwatchScreen({super.key, this.onTimerStopped});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  List<CustomActivity> _customActivities = [];

  @override
  void initState() {
    super.initState();
    TimerService.instance.addListener(_onTick);
    _loadCustomActivities();
  }

  @override
  void dispose() {
    TimerService.instance.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCustomActivities() async {
    final list = await StorageService.instance.getCustomActivities();
    if (mounted) setState(() => _customActivities = list);
  }

  /// Localised label for each activity type.
  String _label(S l, ActivityType type) {
    switch (type) {
      case ActivityType.bibleReading:
        return l.sectionBible;
      case ActivityType.ddeg:
        return l.ddegShort;
      case ActivityType.prayerAlone:
        return l.sectionPrayerAlone;
      case ActivityType.prayerOthers:
        return l.sectionPrayerOthers;
      case ActivityType.evangelism:
        return l.sectionEvangelism;
      case ActivityType.fasting:
        return l.sectionFasting;
      case ActivityType.discipleship:
        return l.sectionDiscipleship;
      case ActivityType.church:
        return l.sectionChurch;
      case ActivityType.proclamation:
        return l.sectionProclamation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final ts = TimerService.instance;
    final accent = AppTheme.accentGold(context);
    final running = ts.activeActivity;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        // Title
        Text(l.stopwatchTitle, style: AppTheme.display(24, color: accent)),
        Text(l.stopwatchSubtitle,
            style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
        const SizedBox(height: 16),

        // Active timer hero (if running)
        if (running != null) ...[
          _activeTimerHero(running, ts, accent),
          const SizedBox(height: 20),
        ],

        // Today's total
        _todayTotalBanner(ts, accent),
        const SizedBox(height: 16),

        // Activity grid
        _activityGrid(l, ts, accent),
      ],
    );
  }

  Widget _activeTimerHero(ActivityType activity, TimerService ts, Color accent) {
    final session = ts.getSession(activity)!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          accent.withValues(alpha: 0.2),
          AppTheme.goldDeep.withValues(alpha: 0.1),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          // Activity icon + name
          Text(activity.icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            _label(S.of(context), activity),
            style: AppTheme.serif(14, color: AppTheme.textColor(context)),
          ),
          const SizedBox(height: 12),
          // Big timer display
          Text(
            session.stopwatchDisplay,
            style: AppTheme.display(48, color: accent),
          ),
          const SizedBox(height: 16),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pause
              _controlButton(
                icon: Icons.pause_rounded,
                color: AppTheme.goldSoft,
                onTap: () => ts.pause(activity),
              ),
              const SizedBox(width: 24),
              // Stop
              _controlButton(
                icon: Icons.stop_rounded,
                color: AppTheme.rust,
                onTap: () => _stopActivity(activity),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96));
  }

  Widget _todayTotalBanner(TimerService ts, Color accent) {
    final total = ts.todayTotal;
    final h = total.inHours;
    final m = total.inMinutes % 60;
    final display = h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text('\u23F1\uFE0F', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context).todayTotal,
              style: AppTheme.serif(13, color: AppTheme.mutedColor(context)),
            ),
          ),
          Text(display, style: AppTheme.display(20, color: accent)),
        ],
      ),
    );
  }

  Widget _activityGrid(S l, TimerService ts, Color accent) {
    final builtIn = ActivityType.values;
    // Total = built-in + custom + 1 for "Add" button
    final totalCount = builtIn.length + _customActivities.length + 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: totalCount,
      itemBuilder: (ctx, i) {
        if (i < builtIn.length) {
          return _activityTile(builtIn[i], l, ts, accent);
        }
        final customIdx = i - builtIn.length;
        if (customIdx < _customActivities.length) {
          return _customActivityTile(_customActivities[customIdx], ts, accent);
        }
        // "Add" button tile
        return _addActivityTile(l, accent);
      },
    );
  }

  Widget _activityTile(ActivityType activity, S l, TimerService ts, Color accent) {
    final session = ts.getSession(activity);
    final isRunning = session?.isRunning ?? false;
    final isPaused = session?.paused ?? false;
    final hasElapsed = session != null && session.currentElapsed > Duration.zero;
    final dark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRunning
            ? accent.withValues(alpha: 0.15)
            : dark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRunning
              ? accent.withValues(alpha: 0.5)
              : accent.withValues(alpha: 0.12),
          width: isRunning ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + label
          Row(
            children: [
              Text(activity.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _label(l, activity),
                  style: AppTheme.serif(11, color: AppTheme.textColor(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Elapsed time
          if (hasElapsed)
            Text(
              session.formattedDuration,
              style: AppTheme.display(16, color: accent),
            ),
          const Spacer(),
          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isRunning && !isPaused)
                _tileButton(Icons.play_arrow_rounded, AppTheme.green, () {
                  if (activity == ActivityType.proclamation) {
                    _openProclamationCounter();
                  } else {
                    _showFieldsAndStart(activity);
                  }
                }),
              if (isRunning) ...[
                _tileButton(Icons.pause_rounded, AppTheme.goldSoft, () {
                  ts.pause(activity);
                }),
                const SizedBox(width: 8),
                _tileButton(Icons.stop_rounded, AppTheme.rust, () => _stopActivity(activity)),
              ],
              if (isPaused) ...[
                _tileButton(Icons.play_arrow_rounded, AppTheme.green, () {
                  ts.start(activity);
                }),
                const SizedBox(width: 8),
                _tileButton(Icons.stop_rounded, AppTheme.rust, () => _stopActivity(activity)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Custom activity tiles ────────────────────────────────────

  Widget _customActivityTile(CustomActivity ca, TimerService ts, Color accent) {
    final dark = AppTheme.isDark(context);

    return GestureDetector(
      onLongPress: () => _confirmDeleteActivity(ca),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(ca.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ca.name,
                    style: AppTheme.serif(11, color: AppTheme.textColor(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _tileButton(Icons.play_arrow_rounded, AppTheme.green, () {
                  _showCustomFieldsAndStart(ca);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _addActivityTile(S l, Color accent) {
    return GestureDetector(
      onTap: () => _showAddActivityDialog(l, accent),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withValues(alpha: 0.2),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: accent, size: 32),
            const SizedBox(height: 6),
            Text(
              l.addActivity,
              style: AppTheme.serif(11, color: accent),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddActivityDialog(S l, Color accent) {
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController(text: '\u2728');
    final fieldCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.addActivity, style: AppTheme.display(18, color: accent)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: AppTheme.serif(14, color: AppTheme.textColor(context)),
              decoration: InputDecoration(
                labelText: l.activityName,
                hintText: l.activityNameHint,
                labelStyle: AppTheme.serif(12, color: accent),
                hintStyle: AppTheme.serif(12, color: AppTheme.faintColor(context)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: accent.withValues(alpha: 0.3)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: accent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: iconCtrl,
              style: const TextStyle(fontSize: 24),
              decoration: InputDecoration(
                labelText: l.activityIcon,
                labelStyle: AppTheme.serif(12, color: accent),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: accent.withValues(alpha: 0.3)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: accent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fieldCtrl,
              style: AppTheme.serif(14, color: AppTheme.textColor(context)),
              decoration: InputDecoration(
                labelText: l.customFieldLabel,
                hintText: l.customFieldHint,
                labelStyle: AppTheme.serif(12, color: accent),
                hintStyle: AppTheme.serif(12, color: AppTheme.faintColor(context)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: accent.withValues(alpha: 0.3)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: accent),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final activity = CustomActivity(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text.trim(),
                    icon: iconCtrl.text.trim().isEmpty ? '\u2728' : iconCtrl.text.trim(),
                    fieldLabels: fieldCtrl.text.trim().isNotEmpty
                        ? [fieldCtrl.text.trim()]
                        : [],
                  );
                  await StorageService.instance.addCustomActivity(activity);
                  nameCtrl.dispose();
                  iconCtrl.dispose();
                  fieldCtrl.dispose();
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadCustomActivities();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(l.addActivity, style: AppTheme.display(16, color: AppTheme.bg0)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteActivity(CustomActivity ca) {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text(l.deleteActivityConfirm, style: AppTheme.display(18, color: accent)),
        content: Text('${ca.icon} ${ca.name}', style: AppTheme.serif(14, color: AppTheme.textColor(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel, style: TextStyle(color: AppTheme.mutedColor(context))),
          ),
          TextButton(
            onPressed: () async {
              await StorageService.instance.removeCustomActivity(ca.id);
              Navigator.pop(ctx);
              _loadCustomActivities();
            },
            child: Text(l.deleteReport, style: const TextStyle(color: AppTheme.rust)),
          ),
        ],
      ),
    );
  }

  /// Show fields for a custom activity, then start a built-in timer
  /// that writes to the "other" field when stopped.
  void _showCustomFieldsAndStart(CustomActivity ca) {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final controllers = List.generate(
      ca.fieldLabels.length,
      (_) => TextEditingController(),
    );

    // For custom activities, use ActivityType.church as a proxy
    // (we'll override the fields written). Actually, let's just
    // start a generic timer and handle it via the "other" field.
    // We'll use the evangelism type if no fields, but really we
    // need a way to track custom timers. For now, we build the
    // notes string and write to "other".

    if (ca.fieldLabels.isEmpty) {
      // No fields — just start directly and track duration to "other"
      TimerService.instance.start(ActivityType.church, fields: {
        'churchType': ca.name,
        'churchNotes': '',
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(ca.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(ca.name, style: AppTheme.display(18, color: accent)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(l.stopwatchFillFields,
                style: AppTheme.serif(12, color: AppTheme.mutedColor(context))),
            const SizedBox(height: 16),
            ...List.generate(ca.fieldLabels.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: controllers[i],
                style: AppTheme.serif(14, color: AppTheme.textColor(context)),
                decoration: InputDecoration(
                  labelText: ca.fieldLabels[i],
                  labelStyle: AppTheme.serif(12, color: accent),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                ),
              ),
            )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  final notes = controllers
                      .asMap()
                      .entries
                      .where((e) => e.value.text.isNotEmpty)
                      .map((e) => '${ca.fieldLabels[e.key]}: ${e.value.text}')
                      .join('; ');
                  for (final c in controllers) {
                    c.dispose();
                  }
                  Navigator.pop(ctx);
                  // Use "other" field to store custom activity data
                  TimerService.instance.start(ActivityType.church, fields: {
                    'churchType': ca.name,
                    'churchNotes': notes,
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded, color: AppTheme.bg0, size: 22),
                      const SizedBox(width: 8),
                      Text(l.startTimer, style: AppTheme.display(16, color: AppTheme.bg0)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Field definitions per activity ──────────────────────────

  /// Returns a list of (fieldKey, label, hint) for the bottom sheet.
  List<(String, String, String)> _fieldsFor(S l, ActivityType type) {
    switch (type) {
      case ActivityType.bibleReading:
        return [
          ('bibleStartRef', l.bibleStartRef, l.bibleStartHint),
        ];
      case ActivityType.ddeg:
        return [
          ('ddegScripture', l.ddegScriptureLabel, l.ddegScriptureHint),
        ];
      case ActivityType.prayerAlone:
        return [
          ('prayerAloneNotes', l.prayerAloneNotesLabel, l.prayerAloneNotesHint),
        ];
      case ActivityType.prayerOthers:
        return [
          ('prayerOthersContext', l.prayerOthersContextLabel, l.prayerOthersContextHint),
        ];
      case ActivityType.evangelism:
        return [
          ('evangelismContacts', l.evangelismContactsLabel, l.evangelismContactsHint),
          ('evangelismNotes', l.evangelismNotesLabel, l.evangelismNotesHint),
        ];
      case ActivityType.fasting:
        return [
          ('fastingType', l.fastingTypeLabel, l.fastingTypeHint),
          ('fastingPrayerFocus', l.fastingPrayerFocusLabel, l.fastingPrayerFocusHint),
        ];
      case ActivityType.discipleship:
        return [
          ('discipleshipWho', l.discipleshipWhoLabel, l.discipleshipWhoHint),
          ('discipleshipTopic', l.discipleshipTopicLabel, l.discipleshipTopicHint),
        ];
      case ActivityType.church:
        return [
          ('churchType', l.churchTypeLabel, l.churchTypeHint),
        ];
      case ActivityType.proclamation:
        return []; // Proclamation uses a special counter screen, no pre-fields
    }
  }

  /// Show bottom sheet with fields, then start timer.
  void _showFieldsAndStart(ActivityType activity) {
    final l = S.of(context);
    final fields = _fieldsFor(l, activity);
    final accent = AppTheme.accentGold(context);
    final controllers = <String, TextEditingController>{};
    for (final f in fields) {
      controllers[f.$1] = TextEditingController();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(activity.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _label(l, activity),
                    style: AppTheme.display(18, color: accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l.stopwatchFillFields,
              style: AppTheme.serif(12, color: AppTheme.mutedColor(context)),
            ),
            const SizedBox(height: 16),
            // Fields
            ...fields.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: controllers[f.$1],
                style: AppTheme.serif(14, color: AppTheme.textColor(context)),
                decoration: InputDecoration(
                  labelText: f.$2,
                  hintText: f.$3,
                  labelStyle: AppTheme.serif(12, color: accent),
                  hintStyle: AppTheme.serif(12, color: AppTheme.faintColor(context)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                ),
              ),
            )),
            const SizedBox(height: 8),
            // Start button
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  final fieldMap = <String, String>{};
                  for (final entry in controllers.entries) {
                    if (entry.value.text.isNotEmpty) {
                      fieldMap[entry.key] = entry.value.text;
                    }
                  }
                  for (final c in controllers.values) {
                    c.dispose();
                  }
                  Navigator.pop(ctx);
                  TimerService.instance.start(activity, fields: fieldMap);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded, color: AppTheme.bg0, size: 22),
                      const SizedBox(width: 8),
                      Text(l.startTimer, style: AppTheme.display(16, color: AppTheme.bg0)),
                    ],
                  ),
                ),
              ),
            ),
            // Skip — start without fields
            const SizedBox(height: 8),
            Center(
              child: GestureDetector(
                onTap: () {
                  for (final c in controllers.values) {
                    c.dispose();
                  }
                  Navigator.pop(ctx);
                  TimerService.instance.start(activity);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    l.skip,
                    style: AppTheme.serif(12, color: AppTheme.mutedColor(context)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Open the proclamation counter screen.
  void _openProclamationCounter() {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        int count = 0;
        bool timerRunning = false;
        final stopwatch = Stopwatch();

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final elapsed = stopwatch.elapsed;
            final h = elapsed.inHours;
            final m = elapsed.inMinutes % 60;
            final s = elapsed.inSeconds % 60;
            final timerDisplay = h > 0
                ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
                : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20, 20, 20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Text('\uD83D\uDCE3', style: const TextStyle(fontSize: 36)),
                  const SizedBox(height: 8),
                  Text(l.proclamationCounter,
                      style: AppTheme.display(20, color: accent)),
                  const SizedBox(height: 4),
                  Text(l.proclamationSubtitle,
                      style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
                  const SizedBox(height: 24),

                  // Big counter display
                  Text(
                    '$count',
                    style: AppTheme.display(72, color: accent),
                  ),
                  const SizedBox(height: 8),
                  Text(l.proclamationTap,
                      style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
                  const SizedBox(height: 20),

                  // Big tap button
                  GestureDetector(
                    onTap: () {
                      setSheetState(() => count++);
                      // Auto-start timer on first tap
                      if (!timerRunning && !stopwatch.isRunning) {
                        stopwatch.start();
                        timerRunning = true;
                        // Update display every second
                        Future.doWhile(() async {
                          await Future.delayed(const Duration(seconds: 1));
                          if (ctx.mounted && stopwatch.isRunning) {
                            setSheetState(() {});
                            return true;
                          }
                          return false;
                        });
                      }
                    },
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.goldGradient,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.add, color: AppTheme.bg0, size: 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Timer display (auto-starts on first tap)
                  if (timerRunning || stopwatch.elapsed > Duration.zero)
                    Text(timerDisplay,
                        style: AppTheme.display(20, color: AppTheme.mutedColor(context))),
                  const SizedBox(height: 24),

                  // Controls: pause timer / save
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (stopwatch.isRunning)
                        _controlButton(
                          icon: Icons.pause_rounded,
                          color: AppTheme.goldSoft,
                          onTap: () => setSheetState(() => stopwatch.stop()),
                        ),
                      if (!stopwatch.isRunning && timerRunning)
                        _controlButton(
                          icon: Icons.play_arrow_rounded,
                          color: AppTheme.green,
                          onTap: () {
                            stopwatch.start();
                            setSheetState(() {});
                            Future.doWhile(() async {
                              await Future.delayed(const Duration(seconds: 1));
                              if (ctx.mounted && stopwatch.isRunning) {
                                setSheetState(() {});
                                return true;
                              }
                              return false;
                            });
                          },
                        ),
                      const SizedBox(width: 24),
                      // Save button
                      GestureDetector(
                        onTap: () async {
                          stopwatch.stop();
                          Navigator.pop(ctx);
                          if (count > 0) {
                            // Build duration string
                            String durationStr = '';
                            final d = stopwatch.elapsed;
                            if (d.inMinutes > 0) {
                              final dh = d.inHours;
                              final dm = d.inMinutes % 60;
                              if (dh > 0) {
                                durationStr = '${dh}h ${dm}min';
                              } else {
                                durationStr = '$dm minutes';
                              }
                            }
                            // Save to daily log directly
                            final dateKey = _todayKey;
                            final log = await StorageService.instance.getLog(dateKey) ??
                                DailyLog(dateKey: dateKey);
                            // Accumulate count if already has proclamations today
                            final existing = int.tryParse(log.proclamationCount) ?? 0;
                            log.proclamationCount = '${existing + count}';
                            if (durationStr.isNotEmpty) {
                              log.proclamationDuration = durationStr;
                            }
                            await StorageService.instance.saveLog(log);
                            widget.onTimerStopped?.call();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(l.proclamationSave,
                              style: AppTheme.display(16, color: AppTheme.bg0)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Stop handler that intercepts Bible reading to ask for end reference.
  Future<void> _stopActivity(ActivityType activity) async {
    final ts = TimerService.instance;
    final session = ts.getSession(activity);
    if (session == null) return;

    if (activity == ActivityType.bibleReading) {
      // Show dialog asking for end reference before finalizing
      await _showBibleEndDialog(session);
    } else {
      await ts.stop(activity);
    }
    widget.onTimerStopped?.call();
  }

  /// Show dialog after Bible reading timer stops asking where the user finished.
  Future<void> _showBibleEndDialog(TimerSession session) async {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final endRefCtrl = TextEditingController();
    final startRef = session.fields['bibleStartRef'] ?? '';
    final ts = TimerService.instance;

    // Pause the timer first so elapsed is finalized
    ts.pause(session.activity);
    final duration = session.formattedDuration;

    final locale = Localizations.localeOf(context).languageCode;
    final bookNames = BibleBooks.bookNames(locale);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        int? calculatedChapters;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20, 20, 20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('\uD83D\uDCD6', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l.sectionBible, style: AppTheme.display(18, color: accent)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(l.timerStoppedDuration(duration),
                    style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
                if (startRef.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('${l.bibleStartRef}: $startRef',
                      style: AppTheme.serif(12, color: AppTheme.mutedColor(context))),
                ],
                const SizedBox(height: 16),
                Text(l.enterEndReference,
                    style: AppTheme.serif(14, color: AppTheme.textColor(context))),
                const SizedBox(height: 8),
                Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return const [];
                    final input = textEditingValue.text.toLowerCase();
                    return bookNames.where((name) =>
                        name.toLowerCase().contains(input));
                  },
                  fieldViewBuilder: (ctx, controller, focusNode, onSubmitted) {
                    // Sync with our controller
                    controller.addListener(() {
                      endRefCtrl.text = controller.text;
                      // Try to calculate chapters in real-time
                      if (startRef.isNotEmpty && controller.text.isNotEmpty) {
                        final chapters = BibleBooks.calculateChapters(startRef, controller.text);
                        setSheetState(() => calculatedChapters = chapters);
                      } else {
                        setSheetState(() => calculatedChapters = null);
                      }
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: true,
                      style: AppTheme.serif(14, color: AppTheme.textColor(context)),
                      decoration: InputDecoration(
                        labelText: l.bibleEndRef,
                        hintText: l.bibleEndHint,
                        labelStyle: AppTheme.serif(12, color: accent),
                        hintStyle: AppTheme.serif(12, color: AppTheme.faintColor(context)),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: accent.withValues(alpha: 0.3)),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: accent),
                        ),
                      ),
                    );
                  },
                ),
                if (calculatedChapters != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '\u2705 ${l.bibleChaptersRead(calculatedChapters!)}',
                      style: AppTheme.serif(13, color: AppTheme.green),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () async {
                      final endRef = endRefCtrl.text.trim();
                      // Build the full reference
                      String fullRef = startRef;
                      if (endRef.isNotEmpty && startRef.isNotEmpty) {
                        fullRef = '$startRef – $endRef';
                      } else if (endRef.isNotEmpty) {
                        fullRef = endRef;
                      }

                      // Calculate chapters
                      final chapters = (startRef.isNotEmpty && endRef.isNotEmpty)
                          ? BibleBooks.calculateChapters(startRef, endRef)
                          : null;

                      // Update session fields before stopping
                      session.fields['bibleReference'] = fullRef;
                      if (chapters != null) {
                        session.fields['bibleChapters'] = '$chapters';
                      } else if (endRef.isNotEmpty) {
                        // If calculation fails, just keep what user entered
                        session.fields['bibleReference'] = fullRef;
                      }
                      // Remove the temporary startRef field
                      session.fields.remove('bibleStartRef');

                      Navigator.pop(ctx);
                      await ts.stop(ActivityType.bibleReading);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(l.done, style: AppTheme.display(16, color: AppTheme.bg0)),
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

  Widget _controlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _tileButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
