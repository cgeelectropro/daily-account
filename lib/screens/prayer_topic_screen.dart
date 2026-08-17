import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/activity_timer.dart';
import '../services/storage_service.dart';
import '../services/timer_service.dart';
import '../theme/app_theme.dart';

/// Prompts for a prayer title/burden before starting the timer — same
/// pattern as ProclamationTopicScreen, parameterized for Prayer Alone or
/// Prayer with Others (both use PrayerSession.title with identical
/// case-insensitive/trimmed merge rules).
class PrayerTopicScreen extends StatefulWidget {
  final ActivityType activityType; // prayerAlone or prayerOthers

  const PrayerTopicScreen({super.key, required this.activityType});

  @override
  State<PrayerTopicScreen> createState() => _PrayerTopicScreenState();
}

class _PrayerTopicScreenState extends State<PrayerTopicScreen> {
  final _controller = TextEditingController();
  List<String> _recentTitles = [];
  String? _selected;
  String? _errorText;

  bool get _isAlone => widget.activityType == ActivityType.prayerAlone;

  @override
  void initState() {
    super.initState();
    _loadRecentTitles();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecentTitles() async {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final log = await StorageService.instance.getLog(todayKey);
    if (log == null || !mounted) return;
    final sessions = _isAlone ? log.prayerAloneSessions : log.prayerOthersSessions;
    setState(() {
      _recentTitles = sessions.map((s) => s.title).where((t) => t.isNotEmpty).toSet().toList();
    });
  }

  void _start() {
    final title = (_selected ?? _controller.text).trim();
    if (title.isEmpty) {
      setState(() => _errorText = S.of(context).fieldRequiredError);
      return;
    }
    Navigator.of(context).pop();
    TimerService.instance.start(
      TimerKey.builtIn(widget.activityType),
      fields: {_isAlone ? 'prayerAloneTitle' : 'prayerOthersTitle': title},
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
        title: Text(l.prayerTitlePrompt, style: AppTheme.display(18, color: accent)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              onChanged: (v) => setState(() { _selected = null; _errorText = null; }),
              style: AppTheme.serif(16, color: AppTheme.textColor(context)),
              decoration: InputDecoration(
                hintText: l.prayerTitleHint,
                errorText: _errorText,
                hintStyle: AppTheme.serif(14, color: AppTheme.faintColor(context)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent.withValues(alpha: 0.3))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
              ),
            ),
            if (_recentTitles.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(l.prayerRecentTitles,
                  style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentTitles.map((title) {
                  final selected = _selected == title;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selected = title;
                      _controller.text = title;
                      _errorText = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? accent : accent.withValues(alpha: 0.3)),
                      ),
                      child: Text(title, style: AppTheme.serif(13, color: AppTheme.textColor(context))),
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
                  child: Text(l.prayerStartButton, style: AppTheme.display(16, color: AppTheme.bg0)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
