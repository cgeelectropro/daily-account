import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/activity_timer.dart';
import '../services/storage_service.dart';
import '../services/timer_service.dart';
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
    Navigator.of(context).pop();
    TimerService.instance.start(
      TimerKey.builtIn(ActivityType.proclamation),
      fields: {'proclamationTopic': topic},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
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
