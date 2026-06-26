import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/custom_activity.dart';
import '../models/daily_log.dart';
import '../models/fasting_period.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/bible_books.dart';
import '../widgets/common_widgets.dart';

class LogScreen extends StatefulWidget {
  final DateTime date;
  final VoidCallback onChanged;
  const LogScreen({super.key, required this.date, required this.onChanged});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  late DailyLog _log;
  bool _loading = true;
  List<CustomActivity> _customActivities = [];
  String get _key => DateFormat('yyyy-MM-dd').format(widget.date);

  // Active fasting period
  FastingPeriod? _activeFast;

  // Auto-fill
  bool _autoFilled = false;
  DailyLog? _preAutoFillSnapshot;

  // Voice note
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  // Debounce for auto-persist
  Timer? _persistDebounce;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCustomActivities();
    _loadActiveFast();
  }

  @override
  void didUpdateWidget(LogScreen old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date) _load();
  }

  Future<void> _load() async {
    final existing = await StorageService.instance.getLog(_key);
    final isNew = existing == null;
    _log = existing ?? DailyLog(dateKey: _key);
    if (isNew) await _tryAutoFill();
    if (mounted) setState(() => _loading = false);
  }

  /// Look at last 7 days' logs and pre-fill recurring values into a new log.
  Future<void> _tryAutoFill() async {
    final storage = StorageService.instance;
    final recentLogs = <DailyLog>[];
    for (int i = 1; i <= 7; i++) {
      final d = widget.date.subtract(Duration(days: i));
      final log = await storage.getLog(DateFormat('yyyy-MM-dd').format(d));
      if (log != null && log.completeness > 0) recentLogs.add(log);
    }
    if (recentLogs.length < 2) return; // not enough data

    // Find the most common non-empty literature title
    final litTitles = recentLogs
        .expand((l) => l.literature)
        .map((e) => e.title)
        .where((t) => t.isNotEmpty && t != '\u2713')
        .toList();
    if (litTitles.isNotEmpty) {
      final freq = <String, int>{};
      for (final t in litTitles) freq[t] = (freq[t] ?? 0) + 1;
      final topTitle = freq.entries.reduce((a, b) => a.value >= b.value ? a : b);
      if (topTitle.value >= 2 && _log.literature.every((l) => l.title.isEmpty)) {
        _log.literature = [LiteratureEntry(title: topTitle.key)];
      }
    }

    // Pre-fill prayer duration if consistent
    final prayerDurations = recentLogs
        .map((l) => l.prayerAloneDuration)
        .where((d) => d.isNotEmpty && d != '\u2713')
        .toList();
    if (prayerDurations.length >= 3 && _log.prayerAloneDuration.isEmpty) {
      final freq = <String, int>{};
      for (final d in prayerDurations) freq[d] = (freq[d] ?? 0) + 1;
      final top = freq.entries.reduce((a, b) => a.value >= b.value ? a : b);
      if (top.value >= 3) _log.prayerAloneDuration = top.key;
    }

    // Pre-fill DDEG scripture pattern
    final ddegScriptures = recentLogs
        .map((l) => l.ddegScripture)
        .where((s) => s.isNotEmpty && s != '\u2713')
        .toList();
    if (ddegScriptures.isNotEmpty && _log.ddegScripture.isEmpty) {
      // If all recent ones are the same book prefix, suggest it
      final lastScripture = ddegScriptures.first;
      final bookMatch = RegExp(r'^[A-Za-z\s]+').firstMatch(lastScripture);
      if (bookMatch != null) {
        final book = bookMatch.group(0)!.trim();
        final sameBook = ddegScriptures.where((s) => s.startsWith(book)).length;
        if (sameBook >= 2) _log.ddegScripture = book;
      }
    }

    final didFill = _log.literature.any((l) => l.title.isNotEmpty) ||
        _log.prayerAloneDuration.isNotEmpty ||
        _log.ddegScripture.isNotEmpty;

    if (didFill) {
      _preAutoFillSnapshot = DailyLog(dateKey: _key); // empty snapshot for undo
      _autoFilled = true;
      _persist();
    }
  }

  void _undoAutoFill() {
    setState(() {
      _log = _preAutoFillSnapshot ?? DailyLog(dateKey: _key);
      _autoFilled = false;
      _preAutoFillSnapshot = null;
    });
    _persist();
  }

  Future<void> _loadActiveFast() async {
    final fast = await StorageService.instance.getActiveFastingPeriod();
    if (mounted) setState(() => _activeFast = fast);
  }

  Future<void> _startNewFast(S t) async {
    final accent = AppTheme.accentGold(context);
    FastType selectedType = FastType.complete;
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 2));
    String prayerFocus = '';

    final result = await showModalBottomSheet<FastingPeriod>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.startFast, style: AppTheme.display(20, color: accent)),
              const SizedBox(height: 16),
              // Fast type selector
              Row(
                children: FastType.values.map((ft) {
                  final isSelected = selectedType == ft;
                  final label = ft == FastType.complete ? t.fastingTypeComplete
                      : ft == FastType.partial ? t.fastingTypePartial
                      : t.fastingTypeEsther;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setSheetState(() => selectedType = ft),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? accent.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? accent : accent.withValues(alpha: 0.2),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(label,
                            style: AppTheme.serif(12, color: isSelected ? accent : AppTheme.textColor(context)),
                            textAlign: TextAlign.center),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Date range
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: startDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 7)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setSheetState(() {
                            startDate = picked;
                            if (endDate.isBefore(startDate)) endDate = startDate;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accent.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            Text(t.fastingStartDate, style: AppTheme.label(9, color: AppTheme.mutedColor(context))),
                            const SizedBox(height: 4),
                            Text('${startDate.day}/${startDate.month}/${startDate.year}',
                                style: AppTheme.serif(14, color: AppTheme.textColor(context))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, color: accent, size: 18),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: endDate,
                          firstDate: startDate,
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setSheetState(() => endDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accent.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            Text(t.fastingEndDate, style: AppTheme.label(9, color: AppTheme.mutedColor(context))),
                            const SizedBox(height: 4),
                            Text('${endDate.day}/${endDate.month}/${endDate.year}',
                                style: AppTheme.serif(14, color: AppTheme.textColor(context))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Prayer focus
              TextField(
                onChanged: (v) => prayerFocus = v,
                maxLines: 2,
                style: AppTheme.serif(14, color: AppTheme.textColor(context)),
                decoration: InputDecoration(
                  labelText: t.fastingPrayerFocusLabel,
                  hintText: t.fastingPrayerFocusHint,
                  labelStyle: AppTheme.label(11, color: accent),
                  hintStyle: AppTheme.serif(13, color: AppTheme.faintColor(context)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: accent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Start button
              GestureDetector(
                onTap: () {
                  final fmt = (DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                  Navigator.pop(ctx, FastingPeriod(
                    startDate: fmt(startDate),
                    endDate: fmt(endDate),
                    type: selectedType,
                    prayerFocus: prayerFocus,
                  ));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(t.startFast, style: AppTheme.display(16, color: AppTheme.bg0)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      await StorageService.instance.addFastingPeriod(result);
      // Also update today's log fasting fields
      final typeLabel = result.type == FastType.complete ? t.fastingTypeComplete
          : result.type == FastType.partial ? t.fastingTypePartial
          : t.fastingTypeEsther;
      setState(() {
        _log.fastingType = typeLabel;
        _log.fastingDuration = '${result.totalDays} days';
        _log.fastingPrayerFocus = result.prayerFocus;
      });
      _persist();
      _loadActiveFast();
    }
  }

  Future<void> _endCurrentFast(S t) async {
    if (_activeFast?.id == null) return;
    await StorageService.instance.endFastingPeriod(_activeFast!.id!);
    _loadActiveFast();
  }

  Future<void> _loadCustomActivities() async {
    final list = await StorageService.instance.getCustomActivities();
    if (mounted) setState(() => _customActivities = list);
  }

  @override
  void dispose() {
    // Flush any pending debounced save before disposing
    if (_persistDebounce?.isActive ?? false) {
      _persistDebounce!.cancel();
      StorageService.instance.saveLog(_log);
    }
    _recordTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  void _persist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 500), () {
      StorageService.instance.saveLog(_log);
      widget.onChanged();
    });
  }

  // ── Voice Note ──────────────────────────────────────────────

  Future<String> _voiceNotePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/voice_notes/voice_$_key.m4a';
  }

  bool get _hasVoiceNote => _log.voiceNotePath.isNotEmpty && File(_log.voiceNotePath).existsSync();

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final path = await _voiceNotePath();
    final voiceDir = Directory(path).parent;
    if (!voiceDir.existsSync()) voiceDir.createSync(recursive: true);
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    if (path != null && mounted) {
      setState(() {
        _isRecording = false;
        _log.voiceNotePath = path;
      });
      _persist();
    }
  }

  Future<void> _playVoiceNote() async {
    if (_isPlaying) {
      await _player.stop();
      setState(() => _isPlaying = false);
      return;
    }
    await _player.play(DeviceFileSource(_log.voiceNotePath));
    setState(() => _isPlaying = true);
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _deleteVoiceNote() async {
    final l = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text(l.voiceNoteDelete, style: AppTheme.display(18, color: AppTheme.accentGold(context))),
        content: Text(l.voiceNoteDeleteConfirm, style: AppTheme.serif(14, color: AppTheme.textColor(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel, style: TextStyle(color: AppTheme.mutedColor(context)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.delete, style: const TextStyle(color: AppTheme.rust))),
        ],
      ),
    );
    if (confirmed != true) return;
    final file = File(_log.voiceNotePath);
    if (file.existsSync()) file.deleteSync();
    setState(() => _log.voiceNotePath = '');
    _persist();
  }

  void _markComplete() {
    final t = S.of(context);
    HapticFeedback.mediumImpact();
    setState(() => _log.completed = true);
    _persist();
    // Cancel follow-up reminders — user has logged their account
    NotificationService.instance.cancelDailyFollowUps();
    ScaffoldMessenger.of(context).showSnackBar(
      _snack('\u2705 ${t.markedComplete}'),
    );
  }

  Future<void> _copyFromYesterday() async {
    final t = S.of(context);
    final yesterday = widget.date.subtract(const Duration(days: 1));
    final yKey = DateFormat('yyyy-MM-dd').format(yesterday);
    final prev = await StorageService.instance.getLog(yKey);
    if (prev == null || prev.completeness == 0) {
      ScaffoldMessenger.of(context).showSnackBar(_snack(t.nothingToCopy));
      return;
    }
    setState(() {
      _log.bibleReference = prev.bibleReference;
      _log.bibleChapters = prev.bibleChapters;
      _log.bibleSessions = prev.bibleSessions.map((s) => BibleReadingEntry(
        startBook: s.startBook, startChapter: s.startChapter,
        endBook: s.endBook, endChapter: s.endChapter,
        chaptersRead: s.chaptersRead,
      )).toList();
      _log.literature = prev.literature.map((e) => LiteratureEntry(title: e.title, amount: e.amount, unit: e.unit)).toList();
      _log.ddegScripture = prev.ddegScripture;
      _log.ddegTime = prev.ddegTime;
      _log.prayerAloneDuration = prev.prayerAloneDuration;
      _log.prayerOthersDuration = prev.prayerOthersDuration;
      _log.prayerOthersContext = prev.prayerOthersContext;
      _log.fastingType = prev.fastingType;
      _log.fastingDuration = prev.fastingDuration;
      _log.givingType = prev.givingType;
      _log.churchType = prev.churchType;
      _log.discipleshipWho = prev.discipleshipWho;
      _log.discipleshipTopic = prev.discipleshipTopic;
      _log.discipleshipDuration = prev.discipleshipDuration;
      // Don't copy: ddegNotes, prayerAloneNotes, evangelism*, fastingPrayerFocus,
      // givingAmount, givingPurpose, churchNotes, other — those are day-specific
    });
    _persist();
    ScaffoldMessenger.of(context).showSnackBar(_snack('\u2705 ${t.copiedFromYesterday}'));
  }

  SnackBar _snack(String msg) => SnackBar(
        content: Text(msg, style: AppTheme.serif(14, color: AppTheme.textColor(context))),
        backgroundColor: AppTheme.surfaceColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.accentGold(context)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.accentGold(context)));
    }

    final t = S.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final bibleBookNames = BibleBooks.bookNames(locale);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        // Auto-fill banner
        if (_autoFilled)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Text('\u2728', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(t.autoFillBanner,
                      style: AppTheme.serif(12, color: AppTheme.green)),
                ),
                GestureDetector(
                  onTap: _undoAutoFill,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(t.autoFillUndo,
                        style: AppTheme.label(10, color: AppTheme.green)),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),

        // Date header + completeness ring
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('EEEE').format(widget.date),
                      style: AppTheme.display(24, color: AppTheme.accentGold(context))),
                  Text(DateFormat('MMMM d, y').format(widget.date),
                      style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
                ],
              ),
            ),
            ProgressRing(
              progress: _log.completeness,
              centerText: '${(_log.completeness * 100).round()}%',
              onTap: () => _showMissingDisciplines(t),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
        const SizedBox(height: 10),

        // Copy from yesterday button (only if today's log is mostly empty)
        if (_log.completeness < 0.1)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _copyFromYesterday,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accentGold(context).withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.content_copy, size: 14, color: AppTheme.accentGold(context)),
                    const SizedBox(width: 6),
                    Text(t.copyFromYesterday, style: AppTheme.serif(12, color: AppTheme.accentGold(context))),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),

        // Bible (multi-session with auto-calculate)
        SectionCard(
          icon: '\u{1F4D6}',
          title: t.sectionBible,
          initiallyExpanded: _log.bibleSessions.any((s) => s.isNotEmpty) ||
              _log.bibleReference.isNotEmpty || _log.bibleChapters.isNotEmpty,
          children: [
            // Structured sessions
            ..._bibleSessionWidgets(t, bibleBookNames),
            // Legacy fields (shown only if old data exists without sessions)
            if (_log.bibleReference.isNotEmpty && _log.bibleSessions.every((s) => s.isEmpty)) ...[
              const SizedBox(height: 8),
              GoldField(
                label: t.bibleRefLabel,
                hint: t.bibleRefHint,
                value: _log.bibleReference,
                suggestions: bibleBookNames,
                onChanged: (v) { _log.bibleReference = v; _persist(); },
              ),
              GoldField(
                label: t.bibleChaptersLabel,
                hint: t.bibleChaptersHint,
                value: _log.bibleChapters,
                keyboardType: TextInputType.number,
                onChanged: (v) { _log.bibleChapters = v; _persist(); },
              ),
            ],
          ],
        ).animate().fadeIn(delay: 80.ms),

        // Literature (multiple)
        SectionCard(
          icon: '\u{1F4DA}',
          title: t.sectionLiterature,
          initiallyExpanded: _log.literature.any((l) => l.title.isNotEmpty),
          children: [
            ..._log.literature.asMap().entries.map((entry) {
              final i = entry.key;
              final lit = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.isDark(context)
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accentGold(context).withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    GoldField(
                      label: t.bookTitleLabel,
                      hint: t.bookTitleHint,
                      value: lit.title,
                      onChanged: (v) { lit.title = v; _persist(); },
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GoldField(
                            label: t.amountLabel,
                            hint: t.amountHint,
                            value: lit.amount,
                            keyboardType: TextInputType.number,
                            onChanged: (v) { lit.amount = v; _persist(); },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _unitDropdown(lit)),
                      ],
                    ),
                    if (_log.literature.length > 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() => _log.literature.removeAt(i));
                            _persist();
                          },
                          icon: const Icon(Icons.remove_circle_outline, size: 16, color: AppTheme.rust),
                          label: Text(t.remove, style: AppTheme.serif(12, color: AppTheme.rust)),
                        ),
                      ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _log.literature.add(LiteratureEntry()));
                },
                icon: Icon(Icons.add_circle_outline, size: 18, color: AppTheme.accentGold(context)),
                label: Text(t.addAnotherBook, style: AppTheme.serif(13, color: AppTheme.accentGold(context))),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 120.ms),

        // DDEG
        SectionCard(
          icon: '\u{1F525}',
          title: t.sectionDDEG,
          initiallyExpanded: _log.ddegScripture.isNotEmpty || _log.ddegNotes.isNotEmpty,
          children: [
            GoldField(
              label: t.ddegScriptureLabel,
              hint: t.ddegScriptureHint,
              value: _log.ddegScripture,
              suggestions: bibleBookNames,
              onChanged: (v) { _log.ddegScripture = v; _persist(); },
            ),
            DurationQuickPick(
              label: t.ddegTimeLabel,
              customLabel: t.durationCustom,
              value: _log.ddegTime,
              onChanged: (v) { _log.ddegTime = v; _persist(); },
            ),
            GoldField(
              label: t.ddegNotesLabel,
              hint: t.ddegNotesHint,
              value: _log.ddegNotes,
              maxLines: 4,
              onChanged: (v) { _log.ddegNotes = v; _persist(); },
            ),
          ],
        ).animate().fadeIn(delay: 160.ms),

        // Prayer alone
        SectionCard(
          icon: '\u{1F64F}',
          title: t.sectionPrayerAlone,
          initiallyExpanded: _log.prayerAloneDuration.isNotEmpty || _log.prayerAloneNotes.isNotEmpty,
          children: [
            DurationQuickPick(
              label: t.durationLabel,
              customLabel: t.durationCustom,
              value: _log.prayerAloneDuration,
              onChanged: (v) { _log.prayerAloneDuration = v; _persist(); },
            ),
            GoldField(
              label: t.prayerAloneNotesLabel,
              hint: t.prayerAloneNotesHint,
              value: _log.prayerAloneNotes,
              maxLines: 3,
              onChanged: (v) { _log.prayerAloneNotes = v; _persist(); },
            ),
          ],
        ).animate().fadeIn(delay: 200.ms),

        // Prayer with others
        SectionCard(
          icon: '\u{1F91D}',
          title: t.sectionPrayerOthers,
          initiallyExpanded: _log.prayerOthersDuration.isNotEmpty || _log.prayerOthersContext.isNotEmpty,
          children: [
            DurationQuickPick(
              label: t.durationLabel,
              customLabel: t.durationCustom,
              value: _log.prayerOthersDuration,
              onChanged: (v) { _log.prayerOthersDuration = v; _persist(); },
            ),
            GoldField(
              label: t.prayerOthersContextLabel,
              hint: t.prayerOthersContextHint,
              value: _log.prayerOthersContext,
              onChanged: (v) { _log.prayerOthersContext = v; _persist(); },
            ),
          ],
        ).animate().fadeIn(delay: 240.ms),

        // Evangelism
        SectionCard(
          icon: '\u{1F4E2}',
          title: t.sectionEvangelism,
          initiallyExpanded: _log.evangelismContacts.isNotEmpty || _log.evangelismOutcome.isNotEmpty,
          children: [
            GoldField(
              label: t.evangelismContactsLabel,
              hint: t.evangelismContactsHint,
              value: _log.evangelismContacts,
              keyboardType: TextInputType.number,
              onChanged: (v) { _log.evangelismContacts = v; _persist(); },
            ),
            GoldField(
              label: t.evangelismOutcomeLabel,
              hint: t.evangelismOutcomeHint,
              value: _log.evangelismOutcome,
              onChanged: (v) { _log.evangelismOutcome = v; _persist(); },
            ),
            GoldField(
              label: t.evangelismNotesLabel,
              hint: t.evangelismNotesHint,
              value: _log.evangelismNotes,
              maxLines: 3,
              onChanged: (v) { _log.evangelismNotes = v; _persist(); },
            ),
            // ── Follow-up tracking ──
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                t.evangelismFollowUp.toUpperCase(),
                style: AppTheme.label(11, color: AppTheme.accentGold(context).withValues(alpha: 0.7)),
              ),
            ),
            GoldField(
              label: t.evangelismNewBelievers,
              hint: t.evangelismNewBelieversHint,
              value: _log.evangelismNewBelievers,
              keyboardType: TextInputType.number,
              onChanged: (v) { _log.evangelismNewBelievers = v; _persist(); },
            ),
            GoldField(
              label: t.evangelismBeingDiscipled,
              hint: t.evangelismBeingDiscipledHint,
              value: _log.evangelismBeingDiscipled,
              keyboardType: TextInputType.number,
              onChanged: (v) { _log.evangelismBeingDiscipled = v; _persist(); },
            ),
            GoldField(
              label: t.evangelismFollowUpNotes,
              hint: t.evangelismFollowUpHint,
              value: _log.evangelismFollowUpNotes,
              maxLines: 3,
              onChanged: (v) { _log.evangelismFollowUpNotes = v; _persist(); },
            ),
          ],
        ).animate().fadeIn(delay: 280.ms),

        // Fasting (multi-day period support)
        SectionCard(
          icon: '\u{1F37D}\uFE0F',
          title: t.sectionFasting,
          initiallyExpanded: _activeFast != null || _log.fastingType.isNotEmpty,
          children: [
            if (_activeFast != null) ...[
              // Active fast status card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('\u2705', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(t.fastingActive,
                              style: AppTheme.display(16, color: AppTheme.green)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Fast type badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _activeFast!.type == FastType.complete ? t.fastingTypeComplete
                            : _activeFast!.type == FastType.partial ? t.fastingTypePartial
                            : t.fastingTypeEsther,
                        style: AppTheme.label(11, color: AppTheme.accentGold(context)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Day counter with progress bar
                    Text(t.fastingDayOf(_activeFast!.currentDay(), _activeFast!.totalDays),
                        style: AppTheme.serif(14, color: AppTheme.textColor(context))),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _activeFast!.currentDay() / _activeFast!.totalDays,
                        minHeight: 6,
                        backgroundColor: AppTheme.green.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.green),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(t.fastingDaysRemaining(
                        _activeFast!.totalDays - _activeFast!.currentDay()),
                        style: AppTheme.label(10, color: AppTheme.mutedColor(context))),
                    if (_activeFast!.prayerFocus.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(t.fastingPrayerFocusLabel.toUpperCase(),
                          style: AppTheme.label(9, color: AppTheme.accentGold(context).withValues(alpha: 0.7))),
                      const SizedBox(height: 4),
                      Text(_activeFast!.prayerFocus,
                          style: AppTheme.serif(13, color: AppTheme.textColor(context))),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // End fast button
              GestureDetector(
                onTap: () => _endCurrentFast(t),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.rust.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.rust.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Text(t.endFast,
                      style: AppTheme.serif(14, color: AppTheme.rust)),
                ),
              ),
            ] else ...[
              // No active fast — show start button + legacy fields
              GestureDetector(
                onTap: () => _startNewFast(t),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold(context).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentGold(context).withValues(alpha: 0.25)),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline,
                          color: AppTheme.accentGold(context), size: 20),
                      const SizedBox(width: 8),
                      Text(t.startFast,
                          style: AppTheme.serif(14, color: AppTheme.accentGold(context))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Legacy single-day fields for quick fasting notes
              GoldField(
                label: t.fastingTypeLabel,
                hint: t.fastingTypeHint,
                value: _log.fastingType,
                onChanged: (v) { _log.fastingType = v; _persist(); },
              ),
              GoldField(
                label: t.fastingPrayerFocusLabel,
                hint: t.fastingPrayerFocusHint,
                value: _log.fastingPrayerFocus,
                maxLines: 3,
                onChanged: (v) { _log.fastingPrayerFocus = v; _persist(); },
              ),
            ],
          ],
        ).animate().fadeIn(delay: 320.ms),

        // Giving & Tithes
        SectionCard(
          icon: '\u{1F4B0}',
          title: t.sectionGiving,
          initiallyExpanded: _log.givingType.isNotEmpty || _log.givingAmount.isNotEmpty,
          children: [
            GoldField(
              label: t.givingTypeLabel,
              hint: t.givingTypeHint,
              value: _log.givingType,
              onChanged: (v) { _log.givingType = v; _persist(); },
            ),
            GoldField(
              label: t.givingAmountLabel,
              hint: t.givingAmountHint,
              value: _log.givingAmount,
              onChanged: (v) { _log.givingAmount = v; _persist(); },
            ),
            GoldField(
              label: t.givingPurposeLabel,
              hint: t.givingPurposeHint,
              value: _log.givingPurpose,
              onChanged: (v) { _log.givingPurpose = v; _persist(); },
            ),
          ],
        ).animate().fadeIn(delay: 360.ms),

        // Church & Fellowship
        SectionCard(
          icon: '\u26EA',
          title: t.sectionChurch,
          initiallyExpanded: _log.churchType.isNotEmpty || _log.churchNotes.isNotEmpty,
          children: [
            GoldField(
              label: t.churchTypeLabel,
              hint: t.churchTypeHint,
              value: _log.churchType,
              onChanged: (v) { _log.churchType = v; _persist(); },
            ),
            GoldField(
              label: t.churchNotesLabel,
              hint: t.churchNotesHint,
              value: _log.churchNotes,
              maxLines: 3,
              onChanged: (v) { _log.churchNotes = v; _persist(); },
            ),
          ],
        ).animate().fadeIn(delay: 400.ms),

        // Discipleship
        SectionCard(
          icon: '\u{1F465}',
          title: t.sectionDiscipleship,
          initiallyExpanded: _log.discipleshipWho.isNotEmpty || _log.discipleshipTopic.isNotEmpty,
          children: [
            GoldField(
              label: t.discipleshipWhoLabel,
              hint: t.discipleshipWhoHint,
              value: _log.discipleshipWho,
              onChanged: (v) { _log.discipleshipWho = v; _persist(); },
            ),
            GoldField(
              label: t.discipleshipTopicLabel,
              hint: t.discipleshipTopicHint,
              value: _log.discipleshipTopic,
              onChanged: (v) { _log.discipleshipTopic = v; _persist(); },
            ),
            DurationQuickPick(
              label: t.discipleshipDurationLabel,
              customLabel: t.durationCustom,
              value: _log.discipleshipDuration,
              onChanged: (v) { _log.discipleshipDuration = v; _persist(); },
            ),
          ],
        ).animate().fadeIn(delay: 440.ms),

        // Proclamation
        SectionCard(
          icon: '\u{1F4E3}',
          title: t.sectionProclamation,
          initiallyExpanded: _log.proclamationCount.isNotEmpty || _log.proclamationDuration.isNotEmpty,
          children: [
            GoldField(
              label: t.proclamationCountLabel,
              hint: t.proclamationCountHint,
              value: _log.proclamationCount,
              keyboardType: TextInputType.number,
              onChanged: (v) { _log.proclamationCount = v; _persist(); },
            ),
            DurationQuickPick(
              label: t.proclamationDurationLabel,
              customLabel: t.durationCustom,
              value: _log.proclamationDuration,
              onChanged: (v) { _log.proclamationDuration = v; _persist(); },
            ),
          ],
        ).animate().fadeIn(delay: 480.ms),

        // Other + Custom Activities
        SectionCard(
          icon: '\u2795',
          title: t.sectionOther,
          initiallyExpanded: _log.other.isNotEmpty || _customActivities.isNotEmpty,
          children: [
            // Custom activity entries
            ..._customActivities.map((ca) => _customActivityEntry(ca, t)),
            // Add activity button
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showAddActivityDialog(t),
                icon: Icon(Icons.add_circle_outline, size: 18, color: AppTheme.accentGold(context)),
                label: Text(t.addActivity, style: AppTheme.serif(13, color: AppTheme.accentGold(context))),
              ),
            ),
            const SizedBox(height: 8),
            // Free-form other notes
            GoldField(
              label: t.otherLabel,
              hint: t.otherHint,
              value: _log.other,
              maxLines: 3,
              onChanged: (v) { _log.other = v; _persist(); },
            ),
          ],
        ).animate().fadeIn(delay: 520.ms),

        const SizedBox(height: 8),

        // Voice Note
        _buildVoiceNoteCard(t),

        // Daily Reflection
        _buildReflectionCard(t),

        // Complete button (delay after Other = 520 + 40)
        Semantics(
          label: _log.completed ? t.markedComplete : t.markComplete,
          button: true,
          child: GestureDetector(
          onTap: _markComplete,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: _log.completed ? null : AppTheme.goldGradient,
              color: _log.completed ? AppTheme.green.withOpacity(0.18) : null,
              borderRadius: BorderRadius.circular(14),
              border: _log.completed
                  ? Border.all(color: AppTheme.green.withOpacity(0.5))
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              _log.completed ? '\u2713 ${t.markedComplete}' : '\u2705 ${t.markComplete}',
              style: AppTheme.display(17,
                  color: _log.completed ? AppTheme.green : AppTheme.bg0),
            ),
          ),
        )).animate().fadeIn(delay: 560.ms),
      ],
    );
  }

  /// A compact row for each custom activity — shows icon, name, and a check toggle.
  Widget _customActivityEntry(CustomActivity ca, S t) {
    // Check if this activity was logged today (name appears in "other" field)
    final isLogged = _log.other.contains(ca.name);
    final accent = AppTheme.accentGold(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isLogged) {
            // Remove this activity's entry from "other"
            final parts = _log.other.split('; ')
                .where((p) => !p.startsWith(ca.name))
                .toList();
            _log.other = parts.join('; ');
          } else {
            // Add this activity name to "other"
            if (_log.other.isEmpty) {
              _log.other = ca.name;
            } else {
              _log.other = '${_log.other}; ${ca.name}';
            }
          }
        });
        _persist();
      },
      onLongPress: () => _confirmDeleteActivity(ca, t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isLogged
              ? AppTheme.green.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isLogged
                ? AppTheme.green.withValues(alpha: 0.4)
                : accent.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Text(ca.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(ca.name,
                  style: AppTheme.serif(13, color: AppTheme.textColor(context))),
            ),
            Icon(
              isLogged ? Icons.check_circle : Icons.circle_outlined,
              color: isLogged ? AppTheme.green : AppTheme.faintColor(context),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddActivityDialog(S t) {
    final accent = AppTheme.accentGold(context);
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
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.addActivity, style: AppTheme.display(18, color: accent)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: AppTheme.serif(14, color: AppTheme.textColor(context)),
              decoration: InputDecoration(
                labelText: t.activityName,
                hintText: t.activityNameHint,
                labelStyle: AppTheme.serif(12, color: accent),
                hintStyle: AppTheme.serif(12, color: AppTheme.faintColor(context)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent.withValues(alpha: 0.3))),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: iconCtrl,
              style: const TextStyle(fontSize: 24),
              decoration: InputDecoration(
                labelText: t.activityIcon,
                labelStyle: AppTheme.serif(12, color: accent),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent.withValues(alpha: 0.3))),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fieldCtrl,
              style: AppTheme.serif(14, color: AppTheme.textColor(context)),
              decoration: InputDecoration(
                labelText: t.customFieldLabel,
                hintText: t.customFieldHint,
                labelStyle: AppTheme.serif(12, color: accent),
                hintStyle: AppTheme.serif(12, color: AppTheme.faintColor(context)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent.withValues(alpha: 0.3))),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent)),
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
                    icon: iconCtrl.text.trim().isEmpty
                        ? '\u2728'
                        : iconCtrl.text.trim(),
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
                  child: Text(t.addActivity,
                      style: AppTheme.display(16, color: AppTheme.bg0)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMissingDisciplines(S t) {
    final accent = AppTheme.accentGold(context);
    final disciplines = <(String, String, bool)>[
      ('\uD83D\uDCD6', t.sectionBible, _log.bibleReference.isNotEmpty || _log.bibleChapters.isNotEmpty || _log.bibleSessions.any((s) => s.isNotEmpty)),
      ('\uD83D\uDCDA', t.sectionLiterature, _log.literature.any((l) => l.title.isNotEmpty)),
      ('\uD83D\uDD25', t.sectionDDEG, _log.ddegScripture.isNotEmpty || _log.ddegNotes.isNotEmpty),
      ('\uD83D\uDE4F', t.sectionPrayerAlone, _log.prayerAloneDuration.isNotEmpty),
      ('\uD83E\uDD1D', t.sectionPrayerOthers, _log.prayerOthersDuration.isNotEmpty),
      ('\uD83D\uDCE2', t.sectionEvangelism, _log.evangelismContacts.isNotEmpty),
      ('\uD83C\uDF7D\uFE0F', t.sectionFasting, _log.fastingType.isNotEmpty || _log.fastingDuration.isNotEmpty),
      ('\uD83D\uDCB0', t.sectionGiving, _log.givingType.isNotEmpty),
      ('\u26EA', t.sectionChurch, _log.churchType.isNotEmpty),
      ('\uD83D\uDC65', t.sectionDiscipleship, _log.discipleshipWho.isNotEmpty),
      ('\uD83D\uDCE3', t.sectionProclamation, _log.proclamationCount.isNotEmpty),
    ];
    final allDone = disciplines.every((d) => d.$3);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.missingDisciplinesTitle,
                style: AppTheme.display(20, color: accent)),
            const SizedBox(height: 4),
            Text(allDone ? t.allDisciplinesDone : t.missingDisciplinesSubtitle,
                style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
            const SizedBox(height: 16),
            ...disciplines.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(d.$1, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(d.$2,
                        style: AppTheme.serif(14, color: AppTheme.textColor(context))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: d.$3
                          ? AppTheme.green.withValues(alpha: 0.15)
                          : AppTheme.rust.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      d.$3 ? t.disciplineDone : t.disciplineMissing,
                      style: AppTheme.label(10,
                          color: d.$3 ? AppTheme.green : AppTheme.rust),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteActivity(CustomActivity ca, S t) {
    final accent = AppTheme.accentGold(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text(t.deleteActivityConfirm,
            style: AppTheme.display(18, color: accent)),
        content: Text('${ca.icon} ${ca.name}',
            style: AppTheme.serif(14, color: AppTheme.textColor(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel,
                style: TextStyle(color: AppTheme.mutedColor(context))),
          ),
          TextButton(
            onPressed: () async {
              await StorageService.instance.removeCustomActivity(ca.id);
              Navigator.pop(ctx);
              _loadCustomActivities();
            },
            child: Text(t.deleteReport,
                style: const TextStyle(color: AppTheme.rust)),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceNoteCard(S t) {
    final accent = AppTheme.accentGold(context);
    final hasNote = _hasVoiceNote;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          Row(
            children: [
              Text('\uD83C\uDF99\uFE0F', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(t.voiceNote.toUpperCase(),
                  style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
            ],
          ),
          const SizedBox(height: 12),
          if (_isRecording) ...[
            // Recording indicator
            Row(
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: const BoxDecoration(
                    color: AppTheme.rust,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(t.voiceNoteRecording,
                    style: AppTheme.serif(14, color: AppTheme.rust)),
                const Spacer(),
                Text(
                  '${_recordDuration.inMinutes.toString().padLeft(2, '0')}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: AppTheme.display(16, color: AppTheme.rust),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.rust.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.rust.withValues(alpha: 0.4)),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stop_circle, color: AppTheme.rust, size: 20),
                    const SizedBox(width: 8),
                    Text(t.voiceNoteSaved,
                        style: AppTheme.serif(14, color: AppTheme.rust)),
                  ],
                ),
              ),
            ),
          ] else if (hasNote) ...[
            // Playback controls
            Row(
              children: [
                GestureDetector(
                  onTap: _playVoiceNote,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _isPlaying ? Icons.stop : Icons.play_arrow,
                      color: AppTheme.bg0, size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.voiceNote,
                          style: AppTheme.serif(14, color: AppTheme.textColor(context))),
                      Text(
                        _isPlaying ? t.voiceNoteRecording : t.voiceNotePlay,
                        style: AppTheme.label(10, color: AppTheme.mutedColor(context)),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _deleteVoiceNote,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.rust.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.delete_outline, color: AppTheme.rust, size: 18),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Record button
            GestureDetector(
              onTap: _startRecording,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, color: accent, size: 20),
                    const SizedBox(width: 8),
                    Text(t.voiceNoteRecord,
                        style: AppTheme.serif(14, color: accent)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 540.ms);
  }

  Widget _buildReflectionCard(S t) {
    final completeness = _log.completeness;
    final filled = (completeness * 11).round();

    if (filled == 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.isDark(context)
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.accentGold(context).withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Text('\uD83D\uDCAD', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.reflectionTitle,
                        style: AppTheme.display(16, color: AppTheme.accentGold(context))),
                    const SizedBox(height: 4),
                    Text(t.reflectionEmpty,
                        style: AppTheme.serif(12, color: AppTheme.mutedColor(context))),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 540.ms),
      );
    }

    // Build contextual reflection
    final accent = AppTheme.accentGold(context);
    String mainMessage;
    if (filled >= 9) {
      mainMessage = t.reflectionGreatDay(filled);
    } else if (filled >= 5) {
      mainMessage = t.reflectionGoodDay(filled);
    } else {
      mainMessage = t.reflectionStartDay(filled);
    }

    // Add a focus suggestion
    String? focusTip;
    if (_log.prayerAloneDuration.isEmpty && _log.prayerOthersDuration.isEmpty) {
      focusTip = t.reflectionPrayerFocus;
    } else if (_log.bibleReference.isEmpty && _log.bibleChapters.isEmpty && _log.bibleSessions.every((s) => s.isEmpty)) {
      focusTip = t.reflectionBibleFocus;
    } else if (_log.evangelismContacts.isEmpty) {
      focusTip = t.reflectionEvangelismFocus;
    } else if (filled >= 7) {
      focusTip = t.reflectionBalanced;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.10),
              accent.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('\u2728', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(t.reflectionTitle,
                    style: AppTheme.display(16, color: accent)),
              ],
            ),
            const SizedBox(height: 10),
            Text(mainMessage,
                style: AppTheme.serif(14, color: AppTheme.textColor(context))),
            if (focusTip != null) ...[
              const SizedBox(height: 8),
              Text(focusTip,
                  style: AppTheme.serif(12, color: AppTheme.mutedColor(context))),
            ],
          ],
        ),
      ).animate().fadeIn(delay: 540.ms),
    );
  }

  // ── Bible reading sessions (multi-session with auto-calculate) ──

  /// Ensure at least one session exists for UI rendering.
  void _ensureBibleSession() {
    if (_log.bibleSessions.isEmpty) {
      _log.bibleSessions = [BibleReadingEntry()];
    }
  }

  /// Recalculate a session and sync legacy fields for backward compat.
  void _recalcSession(BibleReadingEntry session) {
    session.recalculate();
    // Sync legacy fields so reports/widgets still work
    final locale = Localizations.localeOf(context).languageCode;
    _log.bibleChapters = '${_log.totalBibleChapters}';
    _log.bibleReference = _log.combinedBibleReference(locale);
    _persist();
  }

  /// Resolve a user-typed book name (possibly localized) to the English canonical name.
  String _resolveBookName(String typed) {
    final book = BibleBooks.findBook(typed);
    return book?.nameEn ?? typed;
  }

  /// Get the localized display name for a canonical English book name.
  String _localizedBookName(String canonicalName) {
    if (canonicalName.isEmpty) return '';
    final book = BibleBooks.findBook(canonicalName);
    if (book == null) return canonicalName;
    final locale = Localizations.localeOf(context).languageCode;
    return locale.startsWith('fr') ? book.nameFr : book.nameEn;
  }

  List<Widget> _bibleSessionWidgets(S t, List<String> bibleBookNames) {
    _ensureBibleSession();
    final accent = AppTheme.accentGold(context);
    final dark = AppTheme.isDark(context);
    final textCol = AppTheme.textColor(context);
    final mutedCol = textCol.withValues(alpha: 0.5);

    return [
      ..._log.bibleSessions.asMap().entries.map((entry) {
        final i = entry.key;
        final session = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── FROM row ──
              Text(t.bibleSessionFrom.toUpperCase(),
                  style: AppTheme.label(10, color: mutedCol)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: GoldField(
                      label: t.bibleSessionBook,
                      hint: '',
                      value: _localizedBookName(session.startBook),
                      suggestions: bibleBookNames,
                      onChanged: (v) {
                        session.startBook = _resolveBookName(v);
                        // Auto-fill end book with same book for convenience
                        if (session.endBook.isEmpty) {
                          session.endBook = session.startBook;
                        }
                        _recalcSession(session);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: GoldField(
                      label: t.bibleSessionChapter,
                      hint: '1',
                      value: session.startChapter > 0 ? '${session.startChapter}' : '',
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        session.startChapter = int.tryParse(v) ?? 0;
                        // If single-chapter entry, sync end chapter
                        if (session.endChapter < 1) {
                          session.endChapter = session.startChapter;
                        }
                        _recalcSession(session);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // ── TO row ──
              Text(t.bibleSessionTo.toUpperCase(),
                  style: AppTheme.label(10, color: mutedCol)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: GoldField(
                      label: t.bibleSessionBook,
                      hint: '',
                      value: _localizedBookName(session.endBook),
                      suggestions: bibleBookNames,
                      onChanged: (v) {
                        session.endBook = _resolveBookName(v);
                        _recalcSession(session);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: GoldField(
                      label: t.bibleSessionChapter,
                      hint: '1',
                      value: session.endChapter > 0 ? '${session.endChapter}' : '',
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        session.endChapter = int.tryParse(v) ?? 0;
                        _recalcSession(session);
                      },
                    ),
                  ),
                ],
              ),
              // ── Auto-calculated result ──
              if (session.chaptersRead > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t.bibleSessionChaptersResult(session.chaptersRead),
                      style: AppTheme.serif(13, color: AppTheme.green),
                    ),
                  ),
                ),
              // ── Remove button ──
              if (_log.bibleSessions.length > 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => _log.bibleSessions.removeAt(i));
                      _recalcSession(_log.bibleSessions.isNotEmpty
                          ? _log.bibleSessions.first
                          : BibleReadingEntry());
                    },
                    icon: const Icon(Icons.remove_circle_outline, size: 16, color: AppTheme.rust),
                    label: Text(t.removeSession, style: AppTheme.serif(12, color: AppTheme.rust)),
                  ),
                ),
            ],
          ),
        );
      }),
      // ── Total chapters badge (when multiple sessions) ──
      if (_log.bibleSessions.where((s) => s.chaptersRead > 0).length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${t.bibleChaptersLabel}: ${_log.totalSessionChapters}',
              style: AppTheme.serif(13, color: accent),
            ),
          ),
        ),
      // ── Add session button ──
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            setState(() => _log.bibleSessions.add(BibleReadingEntry()));
          },
          icon: Icon(Icons.add_circle_outline, size: 18, color: accent),
          label: Text(t.addReadingSession, style: AppTheme.serif(13, color: accent)),
        ),
      ),
    ];
  }

  Widget _unitDropdown(LiteratureEntry lit) {
    final t = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.unitLabel, style: AppTheme.label(11, color: AppTheme.accentGold(context).withValues(alpha: 0.7))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.isDark(context)
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.accentGold(context).withValues(alpha: 0.25)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: lit.unit,
              isExpanded: true,
              dropdownColor: AppTheme.surfaceColor(context),
              style: AppTheme.serif(15, color: AppTheme.textColor(context)),
              items: [
                DropdownMenuItem(value: 'pages', child: Text(t.unitPages)),
                DropdownMenuItem(value: 'chapters', child: Text(t.unitChapters)),
                DropdownMenuItem(value: 'books', child: Text(t.unitBooks)),
              ],
              onChanged: (v) { setState(() => lit.unit = v ?? 'pages'); _persist(); },
            ),
          ),
        ),
      ],
    );
  }
}
