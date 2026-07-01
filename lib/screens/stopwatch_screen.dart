import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    if (!mounted) return;
    setState(() {});
    final ts = TimerService.instance;
    if (ts.pendingCancelKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pendingKey = ts.pendingCancelKey;
        if (pendingKey != null) {
          ts.clearPendingCancel();
          _cancelTimer(pendingKey);
        }
      });
    }
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
      case ActivityType.literature:
        return l.sectionLiterature;
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
    final runningKey = ts.activeKey;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        // Title
        Text(l.stopwatchTitle, style: AppTheme.display(24, color: accent)),
        Text(l.stopwatchSubtitle,
            style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
        const SizedBox(height: 16),

        // Active timer hero (if running)
        if (runningKey != null) ...[
          _activeTimerHero(runningKey, ts, accent),
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

  Widget _activeTimerHero(TimerKey key, TimerService ts, Color accent) {
    final session = ts.getSession(key)!;
    final icon = key.isBuiltIn
        ? key.builtIn!.icon
        : _customActivities
            .where((c) => c.id == key.customId)
            .map((c) => c.icon)
            .firstOrNull ?? '\u2728';
    final label = key.isBuiltIn
        ? _label(S.of(context), key.builtIn!)
        : _customActivities
            .where((c) => c.id == key.customId)
            .map((c) => c.name)
            .firstOrNull ?? '';

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
          Text(icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(label,
              style: AppTheme.serif(14, color: AppTheme.textColor(context))),
          const SizedBox(height: 12),
          Text(session.stopwatchDisplay,
              style: AppTheme.display(48, color: accent)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _controlButton(
                icon: Icons.pause_rounded,
                color: AppTheme.goldSoft,
                onTap: () => ts.pause(key),
              ),
              const SizedBox(width: 24),
              _controlButton(
                icon: Icons.stop_rounded,
                color: AppTheme.rust,
                onTap: () => _stopTimer(key),
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
          const Text('\u23F1\uFE0F', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(S.of(context).todayTotal,
                style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
          ),
          Text(display, style: AppTheme.display(20, color: accent)),
        ],
      ),
    );
  }

  Widget _activityGrid(S l, TimerService ts, Color accent) {
    final builtIn = ActivityType.values;
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
        return _addActivityTile(l, accent);
      },
    );
  }

  Widget _activityTile(
      ActivityType activity, S l, TimerService ts, Color accent) {
    final key = TimerKey.builtIn(activity);
    final session = ts.getSession(key);
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
          Row(
            children: [
              Text(activity.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_label(l, activity),
                    style:
                        AppTheme.serif(11, color: AppTheme.textColor(context)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const Spacer(),
          if (hasElapsed)
            Text(session.formattedDuration,
                style: AppTheme.display(16, color: accent)),
          const Spacer(),
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
                _tileButton(Icons.close_rounded, Colors.grey, () => _cancelTimer(key)),
                const SizedBox(width: 8),
                _tileButton(Icons.pause_rounded, AppTheme.goldSoft, () {
                  ts.pause(key);
                }),
                const SizedBox(width: 8),
                _tileButton(
                    Icons.stop_rounded, AppTheme.rust, () => _stopTimer(key)),
              ],
              if (isPaused) ...[
                _tileButton(Icons.close_rounded, Colors.grey, () => _cancelTimer(key)),
                const SizedBox(width: 8),
                _tileButton(Icons.play_arrow_rounded, AppTheme.green, () {
                  ts.start(key);
                }),
                const SizedBox(width: 8),
                _tileButton(
                    Icons.stop_rounded, AppTheme.rust, () => _stopTimer(key)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Custom activity tiles ────────────────────────────────────

  Widget _customActivityTile(
      CustomActivity ca, TimerService ts, Color accent) {
    final key = TimerKey.custom(ca.id);
    final session = ts.getSession(key);
    final isRunning = session?.isRunning ?? false;
    final isPaused = session?.paused ?? false;
    final hasElapsed = session != null && session.currentElapsed > Duration.zero;
    final dark = AppTheme.isDark(context);

    return GestureDetector(
      onLongPress: () => _confirmDeleteActivity(ca),
      child: Container(
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
            Row(
              children: [
                Text(ca.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(ca.name,
                      style: AppTheme.serif(11,
                          color: AppTheme.textColor(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const Spacer(),
            if (hasElapsed)
              Text(session.formattedDuration,
                  style: AppTheme.display(16, color: accent)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isRunning && !isPaused)
                  _tileButton(Icons.play_arrow_rounded, AppTheme.green, () {
                    _showCustomFieldsAndStart(ca);
                  }),
                if (isRunning) ...[
                  _tileButton(Icons.close_rounded, Colors.grey, () => _cancelTimer(key)),
                  const SizedBox(width: 8),
                  _tileButton(Icons.pause_rounded, AppTheme.goldSoft, () {
                    ts.pause(key);
                  }),
                  const SizedBox(width: 8),
                  _tileButton(
                      Icons.stop_rounded, AppTheme.rust, () => _stopTimer(key)),
                ],
                if (isPaused) ...[
                  _tileButton(Icons.close_rounded, Colors.grey, () => _cancelTimer(key)),
                  const SizedBox(width: 8),
                  _tileButton(Icons.play_arrow_rounded, AppTheme.green, () {
                    ts.start(key);
                  }),
                  const SizedBox(width: 8),
                  _tileButton(
                      Icons.stop_rounded, AppTheme.rust, () => _stopTimer(key)),
                ],
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
            Text(l.addActivity,
                style: AppTheme.serif(11, color: accent),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showAddActivityDialog(S l, Color accent) {
    String name = '';
    String icon = '\u2728';
    final fields = <CustomField>[];
    bool countsForProgress = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.isDark(context) ? AppTheme.bg1 : AppTheme.lightBg1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(l.customActivityTitle,
                    style: AppTheme.display(18, color: AppTheme.accentGold(ctx))),
                const SizedBox(height: 16),

                // Name + Icon row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: AppTheme.serif(14, color: AppTheme.textColor(ctx)),
                        decoration: InputDecoration(
                          labelText: l.customActivityName,
                          hintText: l.customActivityNameHint,
                          labelStyle: AppTheme.serif(12, color: AppTheme.accentGold(ctx)),
                          hintStyle: AppTheme.serif(12, color: AppTheme.faintColor(ctx)),
                          enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: AppTheme.accentGold(ctx).withValues(alpha: 0.3))),
                          focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: AppTheme.accentGold(ctx))),
                        ),
                        onChanged: (v) => setModalState(() => name = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        final emojis = ['\u2728', '\uD83D\uDE4F', '\uD83C\uDFB5',
                          '\uD83D\uDCAA', '\u2764\uFE0F', '\uD83D\uDD25', '\u2B50',
                          '\uD83C\uDF1F', '\uD83D\uDC51', '\uD83C\uDF3F',
                          '\uD83D\uDCA1', '\uD83C\uDFAF', '\u270D\uFE0F', '\uD83D\uDCD6'];
                        final picked = await showDialog<String>(
                          context: ctx,
                          builder: (_) => AlertDialog(
                            title: Text(l.customActivityIcon),
                            content: Wrap(
                              spacing: 12, runSpacing: 12,
                              children: emojis.map((e) => GestureDetector(
                                onTap: () => Navigator.pop(ctx, e),
                                child: Text(e, style: const TextStyle(fontSize: 28)),
                              )).toList(),
                            ),
                          ),
                        );
                        if (picked != null) setModalState(() => icon = picked);
                      },
                      child: Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppTheme.accentGold(ctx).withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                            child: Text(icon, style: const TextStyle(fontSize: 28))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quick templates
                Text(l.customActivityTemplates,
                    style: AppTheme.label(12,
                        color: AppTheme.textColor(ctx).withValues(alpha: 0.6))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _templateChip(l.customActivityTemplateSimple, [], fields, setModalState),
                    _templateChip(l.customActivityTemplateTimed, [
                      CustomField(label: 'Duration', type: CustomFieldType.duration),
                      CustomField(label: 'Notes', type: CustomFieldType.notes),
                    ], fields, setModalState),
                    _templateChip(l.customActivityTemplateCounted, [
                      CustomField(label: 'Count', type: CustomFieldType.number),
                      CustomField(label: 'Notes', type: CustomFieldType.notes),
                    ], fields, setModalState),
                    _templateChip(l.customActivityTemplateFull, [
                      CustomField(label: 'Duration', type: CustomFieldType.duration),
                      CustomField(label: 'Count', type: CustomFieldType.number),
                      CustomField(label: 'Person', type: CustomFieldType.text),
                      CustomField(label: 'Notes', type: CustomFieldType.notes),
                    ], fields, setModalState),
                  ],
                ),
                const SizedBox(height: 16),

                // Custom fields list
                ...fields.asMap().entries.map((entry) {
                  final i = entry.key;
                  final f = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: l.customActivityFieldLabel,
                              isDense: true,
                            ),
                            controller: TextEditingController(text: f.label),
                            onChanged: (v) => f.label = v,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<CustomFieldType>(
                            initialValue: f.type,
                            isDense: true,
                            decoration: const InputDecoration(isDense: true),
                            items: CustomFieldType.values
                                .map((ft) => DropdownMenuItem(
                                    value: ft,
                                    child: Text(_fieldTypeName(ft, ctx, l))))
                                .toList(),
                            onChanged: (v) =>
                                setModalState(() => f.type = v!),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setModalState(() => fields.removeAt(i)),
                        ),
                      ],
                    ),
                  );
                }),

                // Add field button
                if (fields.length < 8)
                  TextButton.icon(
                    onPressed: () => setModalState(() => fields
                        .add(CustomField(label: '', type: CustomFieldType.text))),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l.customActivityAddField),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(l.customActivityMaxFields,
                        style: AppTheme.serif(11, color: AppTheme.rust)),
                  ),
                const SizedBox(height: 8),

                // Counts for progress toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Text(l.customActivityCountsForProgress,
                            style: AppTheme.serif(14,
                                color: AppTheme.textColor(ctx)))),
                    Switch.adaptive(
                      value: countsForProgress,
                      activeTrackColor: AppTheme.accentGold(ctx),
                      onChanged: (v) =>
                          setModalState(() => countsForProgress = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGold(ctx),
                      foregroundColor: AppTheme.bg0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: name.trim().isEmpty
                        ? null
                        : () async {
                            fields.removeWhere((f) => f.label.trim().isEmpty);
                            final activity = CustomActivity(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              name: name.trim(),
                              icon: icon,
                              fields: List<CustomField>.from(fields),
                              countsForCompleteness: countsForProgress,
                            );
                            final nav = Navigator.of(ctx);
                            await StorageService.instance
                                .addCustomActivity(activity);
                            if (!mounted) return;
                            nav.pop();
                            _loadCustomActivities();
                          },
                    child: Text(l.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _templateChip(String label, List<CustomField> template,
      List<CustomField> target, StateSetter setModalState) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () => setModalState(() {
        target.clear();
        target.addAll(
            template.map((f) => CustomField(label: f.label, type: f.type)));
      }),
    );
  }

  String _fieldTypeName(CustomFieldType type, BuildContext ctx, S l) {
    switch (type) {
      case CustomFieldType.text:
        return l.customFieldTypeText;
      case CustomFieldType.number:
        return l.customFieldTypeNumber;
      case CustomFieldType.duration:
        return l.customFieldTypeDuration;
      case CustomFieldType.yesNo:
        return l.customFieldTypeYesNo;
      case CustomFieldType.notes:
        return l.customFieldTypeNotes;
    }
  }

  void _confirmDeleteActivity(CustomActivity ca) {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text(l.deleteActivityConfirm,
            style: AppTheme.display(18, color: accent)),
        content: Text('${ca.icon} ${ca.name}',
            style: AppTheme.serif(14, color: AppTheme.textColor(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel,
                style: TextStyle(color: AppTheme.mutedColor(context))),
          ),
          TextButton(
            onPressed: () async {
              await StorageService.instance.removeCustomActivity(ca.id);
              Navigator.pop(ctx);
              _loadCustomActivities();
            },
            child: Text(l.deleteReport,
                style: const TextStyle(color: AppTheme.rust)),
          ),
        ],
      ),
    );
  }

  /// Show fields for a custom activity, then start its timer.
  void _showCustomFieldsAndStart(CustomActivity ca) {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final key = TimerKey.custom(ca.id);
    final controllers = List.generate(
        ca.fields.length, (_) => TextEditingController());

    if (ca.fields.isEmpty) {
      // No fields — start directly
      TimerService.instance.start(key, fields: {'_customName': ca.name});
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
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(ca.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(ca.name,
                        style: AppTheme.display(18, color: accent))),
              ],
            ),
            const SizedBox(height: 4),
            Text(l.stopwatchFillFields,
                style:
                    AppTheme.serif(12, color: AppTheme.mutedColor(context))),
            const SizedBox(height: 16),
            ...List.generate(
              ca.fields.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controllers[i],
                  style: AppTheme.serif(14,
                      color: AppTheme.textColor(context)),
                  decoration: InputDecoration(
                    labelText: ca.fields[i].label,
                    labelStyle: AppTheme.serif(12, color: accent),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: accent.withValues(alpha: 0.3))),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: accent)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  final fieldMap = <String, String>{
                    '_customName': ca.name,
                  };
                  for (var i = 0; i < controllers.length; i++) {
                    if (controllers[i].text.isNotEmpty) {
                      fieldMap[ca.fields[i].label] = controllers[i].text;
                    }
                  }
                  for (final c in controllers) {
                    c.dispose();
                  }
                  Navigator.pop(ctx);
                  TimerService.instance.start(key, fields: fieldMap);
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
                      const Icon(Icons.play_arrow_rounded,
                          color: AppTheme.bg0, size: 22),
                      const SizedBox(width: 8),
                      Text(l.startTimer,
                          style: AppTheme.display(16, color: AppTheme.bg0)),
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

  List<(String, String, String)> _fieldsFor(S l, ActivityType type) {
    switch (type) {
      case ActivityType.bibleReading:
        return [('bibleStartRef', l.bibleStartRef, l.bibleStartHint)];
      case ActivityType.literature:
        return [('literatureTitle', l.bookTitleLabel, l.bookTitleHint)];
      case ActivityType.ddeg:
        return [('ddegScripture', l.ddegScriptureLabel, l.ddegScriptureHint)];
      case ActivityType.prayerAlone:
        return [
          ('prayerAloneNotes', l.prayerAloneNotesLabel, l.prayerAloneNotesHint)
        ];
      case ActivityType.prayerOthers:
        return [
          ('prayerOthersContext', l.prayerOthersContextLabel,
              l.prayerOthersContextHint)
        ];
      case ActivityType.evangelism:
        return [
          ('evangelismContacts', l.evangelismContactsLabel,
              l.evangelismContactsHint),
          ('evangelismNotes', l.evangelismNotesLabel, l.evangelismNotesHint),
        ];
      case ActivityType.fasting:
        return [
          ('fastingType', l.fastingTypeLabel, l.fastingTypeHint),
          ('fastingPrayerFocus', l.fastingPrayerFocusLabel,
              l.fastingPrayerFocusHint),
        ];
      case ActivityType.discipleship:
        return [
          ('discipleshipWho', l.discipleshipWhoLabel, l.discipleshipWhoHint),
          ('discipleshipTopic', l.discipleshipTopicLabel,
              l.discipleshipTopicHint),
        ];
      case ActivityType.church:
        return [('churchType', l.churchTypeLabel, l.churchTypeHint)];
      case ActivityType.proclamation:
        return [];
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

    final key = TimerKey.builtIn(activity);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(activity.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(_label(l, activity),
                        style: AppTheme.display(18, color: accent))),
              ],
            ),
            const SizedBox(height: 4),
            Text(l.stopwatchFillFields,
                style:
                    AppTheme.serif(12, color: AppTheme.mutedColor(context))),
            const SizedBox(height: 16),
            ...fields.map((f) {
              final needsAutocomplete =
                  f.$1 == 'bibleStartRef' || f.$1 == 'ddegScripture';
              if (needsAutocomplete) {
                final locale = Localizations.localeOf(context).languageCode;
                final bookNames = BibleBooks.bookNames(locale);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return const [];
                      final input = textEditingValue.text.toLowerCase();
                      return bookNames
                          .where((name) => name.toLowerCase().contains(input));
                    },
                    fieldViewBuilder:
                        (ctx2, controller, focusNode, onSubmitted) {
                      controller.addListener(() {
                        controllers[f.$1]!.text = controller.text;
                      });
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        style: AppTheme.serif(14,
                            color: AppTheme.textColor(context)),
                        decoration: InputDecoration(
                          labelText: f.$2,
                          hintText: f.$3,
                          labelStyle: AppTheme.serif(12, color: accent),
                          hintStyle: AppTheme.serif(12,
                              color: AppTheme.faintColor(context)),
                          enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: accent.withValues(alpha: 0.3))),
                          focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: accent)),
                        ),
                      );
                    },
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controllers[f.$1],
                  style:
                      AppTheme.serif(14, color: AppTheme.textColor(context)),
                  decoration: InputDecoration(
                    labelText: f.$2,
                    hintText: f.$3,
                    labelStyle: AppTheme.serif(12, color: accent),
                    hintStyle: AppTheme.serif(12,
                        color: AppTheme.faintColor(context)),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: accent.withValues(alpha: 0.3))),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: accent)),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
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
                  TimerService.instance.start(key, fields: fieldMap);
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
                      const Icon(Icons.play_arrow_rounded,
                          color: AppTheme.bg0, size: 22),
                      const SizedBox(width: 8),
                      Text(l.startTimer,
                          style: AppTheme.display(16, color: AppTheme.bg0)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: GestureDetector(
                onTap: () {
                  for (final c in controllers.values) {
                    c.dispose();
                  }
                  Navigator.pop(ctx);
                  TimerService.instance.start(key);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(l.skip,
                      style: AppTheme.serif(12,
                          color: AppTheme.mutedColor(context))),
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
                  20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('\uD83D\uDCE3',
                      style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 8),
                  Text(l.proclamationCounter,
                      style: AppTheme.display(20, color: accent)),
                  const SizedBox(height: 4),
                  Text(l.proclamationSubtitle,
                      style: AppTheme.serif(13,
                          color: AppTheme.mutedColor(context))),
                  const SizedBox(height: 24),
                  Text('$count', style: AppTheme.display(72, color: accent)),
                  const SizedBox(height: 8),
                  Text(l.proclamationTap,
                      style: AppTheme.serif(13,
                          color: AppTheme.mutedColor(context))),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      setSheetState(() => count++);
                      if (!timerRunning && !stopwatch.isRunning) {
                        stopwatch.start();
                        timerRunning = true;
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
                          child:
                              Icon(Icons.add, color: AppTheme.bg0, size: 48)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (timerRunning || stopwatch.elapsed > Duration.zero)
                    Text(timerDisplay,
                        style: AppTheme.display(20,
                            color: AppTheme.mutedColor(context))),
                  const SizedBox(height: 24),
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
                              await Future.delayed(
                                  const Duration(seconds: 1));
                              if (ctx.mounted && stopwatch.isRunning) {
                                setSheetState(() {});
                                return true;
                              }
                              return false;
                            });
                          },
                        ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: () async {
                          stopwatch.stop();
                          Navigator.pop(ctx);
                          if (count > 0) {
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
                            final dateKey = _todayKey;
                            final log = await StorageService.instance
                                    .getLog(dateKey) ??
                                DailyLog(dateKey: dateKey);
                            final existing =
                                int.tryParse(log.proclamationCount) ?? 0;
                            log.proclamationCount = '${existing + count}';
                            if (durationStr.isNotEmpty) {
                              log.proclamationDuration = durationStr;
                            }
                            await StorageService.instance.saveLog(log);
                            widget.onTimerStopped?.call();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(l.proclamationSave,
                              style:
                                  AppTheme.display(16, color: AppTheme.bg0)),
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

  /// Cancel a timer without saving — shows confirmation for timers >= 10s.
  void _cancelTimer(TimerKey key) {
    final ts = TimerService.instance;
    final session = ts.sessions[key];
    if (session == null) return;

    if (session.currentElapsed.inSeconds < 10) {
      ts.cancelTimer(key);
      return;
    }

    final l = S.of(context);
    final elapsed = session.formattedDuration;
    final name = key.isBuiltIn
        ? _label(l, key.builtIn!)
        : (session.fields['_customName'] ?? 'Activity');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.cancelTimerTitle),
        content: Text(l.cancelTimerContent(elapsed, name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancelTimerKeep),
          ),
          TextButton(
            onPressed: () {
              ts.cancelTimer(key);
              Navigator.pop(ctx);
            },
            child: Text(l.cancelTimerDiscard, style: const TextStyle(color: AppTheme.rust)),
          ),
        ],
      ),
    );
  }

  /// Unified stop handler for both built-in and custom activities.
  Future<void> _stopTimer(TimerKey key) async {
    HapticFeedback.mediumImpact();
    final ts = TimerService.instance;
    final session = ts.getSession(key);
    if (session == null) return;

    if (key.isBuiltIn) {
      if (key.builtIn == ActivityType.bibleReading) {
        await _showBibleEndDialog(session);
      } else if (key.builtIn == ActivityType.literature) {
        await _showLiteratureEndDialog(session);
      } else {
        await ts.stop(key);
      }
    } else {
      // Custom activity — just stop, data goes to customActivityData
      await ts.stop(key);
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

    ts.pause(session.key);
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
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('\uD83D\uDCD6',
                        style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(l.sectionBible,
                            style: AppTheme.display(18, color: accent))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(l.timerStoppedDuration(duration),
                    style: AppTheme.serif(13,
                        color: AppTheme.mutedColor(context))),
                if (startRef.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('${l.bibleStartRef}: $startRef',
                      style: AppTheme.serif(12,
                          color: AppTheme.mutedColor(context))),
                ],
                const SizedBox(height: 16),
                Text(l.enterEndReference,
                    style: AppTheme.serif(14,
                        color: AppTheme.textColor(context))),
                const SizedBox(height: 8),
                Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return const [];
                    final input = textEditingValue.text.toLowerCase();
                    return bookNames
                        .where((name) => name.toLowerCase().contains(input));
                  },
                  fieldViewBuilder:
                      (ctx, controller, focusNode, onSubmitted) {
                    controller.addListener(() {
                      endRefCtrl.text = controller.text;
                      if (startRef.isNotEmpty &&
                          controller.text.isNotEmpty) {
                        final chapters = BibleBooks.calculateChapters(
                            startRef, controller.text);
                        setSheetState(() => calculatedChapters = chapters);
                      } else {
                        setSheetState(() => calculatedChapters = null);
                      }
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: true,
                      style: AppTheme.serif(14,
                          color: AppTheme.textColor(context)),
                      decoration: InputDecoration(
                        labelText: l.bibleEndRef,
                        hintText: l.bibleEndHint,
                        labelStyle: AppTheme.serif(12, color: accent),
                        hintStyle: AppTheme.serif(12,
                            color: AppTheme.faintColor(context)),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: accent.withValues(alpha: 0.3))),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: accent)),
                      ),
                    );
                  },
                ),
                if (calculatedChapters != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
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
                      String fullRef = startRef;
                      if (endRef.isNotEmpty && startRef.isNotEmpty) {
                        fullRef = '$startRef – $endRef';
                      } else if (endRef.isNotEmpty) {
                        fullRef = endRef;
                      }

                      final chapters =
                          (startRef.isNotEmpty && endRef.isNotEmpty)
                              ? BibleBooks.calculateChapters(
                                  startRef, endRef)
                              : null;

                      session.fields['bibleReference'] = fullRef;
                      if (chapters != null) {
                        session.fields['bibleChapters'] = '$chapters';
                      }
                      session.fields.remove('bibleStartRef');

                      Navigator.pop(ctx);
                      await ts.stop(TimerKey.builtIn(ActivityType.bibleReading));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(l.done,
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

  /// Show dialog after Literature timer stops asking how much was read.
  Future<void> _showLiteratureEndDialog(TimerSession session) async {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final amountCtrl = TextEditingController();
    final ts = TimerService.instance;
    final title = session.fields['literatureTitle'] ?? '';

    ts.pause(session.key);
    final duration = session.formattedDuration;

    String selectedUnit = 'pages';

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
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('\uD83D\uDCDA',
                        style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(l.sectionLiterature,
                            style: AppTheme.display(18, color: accent))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(l.timerStoppedDuration(duration),
                    style: AppTheme.serif(13,
                        color: AppTheme.mutedColor(context))),
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('${l.bookTitleLabel}: $title',
                      style: AppTheme.serif(12,
                          color: AppTheme.mutedColor(context))),
                ],
                const SizedBox(height: 16),
                Text(l.amountLabel,
                    style: AppTheme.serif(14,
                        color: AppTheme.textColor(context))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amountCtrl,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        style: AppTheme.serif(14,
                            color: AppTheme.textColor(context)),
                        decoration: InputDecoration(
                          hintText: l.amountHint,
                          hintStyle: AppTheme.serif(12,
                              color: AppTheme.faintColor(context)),
                          enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: accent.withValues(alpha: 0.3))),
                          focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: accent)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.isDark(context)
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.25)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedUnit,
                          dropdownColor: AppTheme.surfaceColor(context),
                          style: AppTheme.serif(14,
                              color: AppTheme.textColor(context)),
                          items: [
                            DropdownMenuItem(
                                value: 'pages', child: Text(l.unitPages)),
                            DropdownMenuItem(
                                value: 'chapters',
                                child: Text(l.unitChapters)),
                            DropdownMenuItem(
                                value: 'books', child: Text(l.unitBooks)),
                          ],
                          onChanged: (v) =>
                              setSheetState(() => selectedUnit = v ?? 'pages'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);

                      final dateKey = _todayKey;
                      final log =
                          await StorageService.instance.getLog(dateKey) ??
                              DailyLog(dateKey: dateKey);

                      final amount = amountCtrl.text.trim();
                      if (title.isNotEmpty || amount.isNotEmpty) {
                        if (log.literature.length == 1 &&
                            log.literature.first.title.isEmpty) {
                          log.literature[0] = LiteratureEntry(
                            title: title,
                            amount: amount,
                            unit: selectedUnit,
                          );
                        } else {
                          log.literature.add(LiteratureEntry(
                            title: title,
                            amount: amount,
                            unit: selectedUnit,
                          ));
                        }
                      }
                      await StorageService.instance.saveLog(log);

                      await ts.stop(TimerKey.builtIn(ActivityType.literature));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppTheme.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(l.done,
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
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
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
