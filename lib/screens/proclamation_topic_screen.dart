import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/daily_log.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Prompts for a proclamation topic before starting the timer.
/// Reused both from the Stopwatch grid tile and from the home-screen
/// widget's "+" tap (via deep link), so it's a standalone routed screen
/// rather than a bottom sheet tied to StopwatchScreen's state.
class ProclamationTopicScreen extends StatefulWidget {
  const ProclamationTopicScreen({super.key});

  @override
  State<ProclamationTopicScreen> createState() => _ProclamationTopicScreenState();
}

class _ProclamationTopicScreenState extends State<ProclamationTopicScreen> {
  final _controller = TextEditingController();
  List<String> _recentTopics = [];
  String? _selected;
  bool _counting = false;
  String _chosenTopic = '';
  int _count = 0;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _loadRecentTopics();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecentTopics() async {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final log = await StorageService.instance.getLog(todayKey);
    if (log == null || !mounted) return;
    setState(() {
      _recentTopics = log.proclamationSessions
          .map((s) => s.topic)
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();
    });
  }

  void _start() {
    final topic = (_selected ?? _controller.text).trim();
    setState(() {
      _chosenTopic = topic;
      _counting = true;
    });
  }

  void _tapCount() {
    setState(() => _count++);
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
      _tickCounter();
    }
  }

  void _tickCounter() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_stopwatch.isRunning) return;
      setState(() {});
      _tickCounter();
    });
  }

  Future<void> _save() async {
    _stopwatch.stop();
    if (_count == 0) {
      Navigator.of(context).pop();
      return;
    }
    final durationStr = _formatStopwatchDuration(_stopwatch.elapsed);
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final log = await StorageService.instance.getLog(todayKey) ?? DailyLog(dateKey: todayKey);
    final idx = ProclamationSession.findMatchingIndex(log.proclamationSessions, _chosenTopic);
    if (idx != -1) {
      log.proclamationSessions[idx].count += _count;
      log.proclamationSessions[idx].duration =
          _accumulateDurationStrings(log.proclamationSessions[idx].duration, durationStr);
    } else {
      log.proclamationSessions.add(ProclamationSession(
        topic: _chosenTopic,
        count: _count,
        duration: durationStr,
      ));
    }
    await StorageService.instance.saveLog(log);
    if (mounted) Navigator.of(context).pop();
  }

  String _formatStopwatchDuration(Duration d) {
    if (d.inMinutes <= 0) return '';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m}min' : '${m}min';
  }

  /// Mirrors TimerService's private _accumulateDuration — duplicated here
  /// since this screen intentionally bypasses TimerService entirely (the
  /// counter is not a stopwatch-style timed activity in the TimerService
  /// sense; it's its own self-contained interaction, same as the original
  /// pre-regression implementation).
  String _accumulateDurationStrings(String existing, String added) {
    int parseMin(String s) {
      if (s.isEmpty) return 0;
      final hm = RegExp(r'(\d+)h\s*(\d+)?min?').firstMatch(s);
      if (hm != null) return (int.tryParse(hm.group(1)!) ?? 0) * 60 + (int.tryParse(hm.group(2) ?? '0') ?? 0);
      final mOnly = RegExp(r'(\d+)min').firstMatch(s);
      if (mOnly != null) return int.tryParse(mOnly.group(1)!) ?? 0;
      return 0;
    }
    final total = parseMin(existing) + parseMin(added);
    if (total <= 0) return '';
    final h = total ~/ 60;
    final m = total % 60;
    return h > 0 ? '${h}h ${m}min' : '${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);

    if (_counting) {
      final elapsed = _stopwatch.elapsed;
      final h = elapsed.inHours;
      final m = elapsed.inMinutes % 60;
      final s = elapsed.inSeconds % 60;
      final timerDisplay = h > 0
          ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
          : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

      return Scaffold(
        backgroundColor: AppTheme.bgColor(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _save, // saves if count > 0, else just pops — see _save
          ),
          title: Text(_chosenTopic.isEmpty ? l.sectionProclamation : _chosenTopic,
              style: AppTheme.display(18, color: accent)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$_count', style: AppTheme.display(72, color: accent)),
              const SizedBox(height: 8),
              Text(l.proclamationTap,
                  style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _tapCount,
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
                      child: Icon(Icons.add, color: AppTheme.bg0, size: 48)),
                ),
              ),
              const SizedBox(height: 16),
              if (_stopwatch.elapsed > Duration.zero)
                Text(timerDisplay,
                    style: AppTheme.display(20, color: AppTheme.mutedColor(context))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(l.proclamationSave,
                        style: AppTheme.display(16, color: AppTheme.bg0)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Stage 1: topic picker (unchanged from the existing implementation)
    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l.proclamationTopicPrompt, style: AppTheme.display(18, color: accent)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              onChanged: (v) => setState(() => _selected = null),
              style: AppTheme.serif(16, color: AppTheme.textColor(context)),
              decoration: InputDecoration(
                hintText: l.proclamationTopicHint,
                hintStyle: AppTheme.serif(14, color: AppTheme.faintColor(context)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent.withValues(alpha: 0.3))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
              ),
            ),
            if (_recentTopics.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(l.proclamationRecentTopics,
                  style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentTopics.map((topic) {
                  final selected = _selected == topic;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selected = topic;
                      _controller.text = topic;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? accent : accent.withValues(alpha: 0.3)),
                      ),
                      child: Text(topic, style: AppTheme.serif(13, color: AppTheme.textColor(context))),
                    ),
                  );
                }).toList(),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _start,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.goldGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(l.proclamationStartButton,
                      style: AppTheme.display(16, color: AppTheme.bg0)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
