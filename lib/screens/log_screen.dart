import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/daily_log.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
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
  String get _key => DateFormat('yyyy-MM-dd').format(widget.date);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LogScreen old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date) _load();
  }

  Future<void> _load() async {
    final existing = await StorageService.instance.getLog(_key);
    setState(() {
      _log = existing ?? DailyLog(dateKey: _key);
      _loading = false;
    });
  }

  void _persist() {
    StorageService.instance.saveLog(_log);
    widget.onChanged();
  }

  void _markComplete() {
    setState(() => _log.completed = true);
    _persist();
    ScaffoldMessenger.of(context).showSnackBar(
      _snack('✅ Day marked complete. Well done, good and faithful servant!'),
    );
  }

  SnackBar _snack(String msg) => SnackBar(
        content: Text(msg, style: AppTheme.serif(14, color: AppTheme.cream)),
        backgroundColor: AppTheme.bg2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.gold),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.gold));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        // Date header + completeness ring
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('EEEE').format(widget.date),
                      style: AppTheme.display(24, color: AppTheme.gold)),
                  Text(DateFormat('MMMM d, y').format(widget.date),
                      style: AppTheme.serif(13, color: AppTheme.sand)),
                ],
              ),
            ),
            ProgressRing(
              progress: _log.completeness,
              centerText: '${(_log.completeness * 100).round()}%',
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
        const SizedBox(height: 20),

        // Bible
        SectionCard(icon: '📖', title: 'Bible Reading', children: [
          GoldField(
            label: 'Passage / Reference',
            hint: 'e.g. John 3; Romans 8',
            value: _log.bibleReference,
            onChanged: (v) { _log.bibleReference = v; _persist(); },
          ),
          GoldField(
            label: 'Number of Chapters',
            hint: 'e.g. 3',
            value: _log.bibleChapters,
            keyboardType: TextInputType.number,
            onChanged: (v) { _log.bibleChapters = v; _persist(); },
          ),
        ]).animate().fadeIn(delay: 80.ms),

        // Literature (multiple)
        SectionCard(icon: '📚', title: 'Christian Literature', children: [
          ..._log.literature.asMap().entries.map((entry) {
            final i = entry.key;
            final lit = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.gold.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  GoldField(
                    label: 'Book Title',
                    hint: 'e.g. The Normal Christian Life',
                    value: lit.title,
                    onChanged: (v) { lit.title = v; _persist(); },
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: GoldField(
                          label: 'Amount',
                          hint: 'e.g. 15',
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
                        label: Text('Remove', style: AppTheme.serif(12, color: AppTheme.rust)),
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
              icon: const Icon(Icons.add_circle_outline, size: 18, color: AppTheme.gold),
              label: Text('Add another book', style: AppTheme.serif(13, color: AppTheme.gold)),
            ),
          ),
        ]).animate().fadeIn(delay: 120.ms),

        // DDEG
        SectionCard(icon: '🔥', title: 'Dynamic Encounter with God', children: [
          GoldField(
            label: 'Scripture Meditated On',
            hint: 'e.g. Psalm 23:1',
            value: _log.ddegScripture,
            onChanged: (v) { _log.ddegScripture = v; _persist(); },
          ),
          GoldField(
            label: 'Time Spent',
            hint: 'e.g. 30 minutes',
            value: _log.ddegTime,
            onChanged: (v) { _log.ddegTime = v; _persist(); },
          ),
          GoldField(
            label: 'What God Spoke to You',
            hint: 'Write what the Lord revealed or impressed...',
            value: _log.ddegNotes,
            maxLines: 4,
            onChanged: (v) { _log.ddegNotes = v; _persist(); },
          ),
        ]).animate().fadeIn(delay: 160.ms),

        // Prayer alone
        SectionCard(icon: '🙏', title: 'Prayer — Alone with God', children: [
          GoldField(
            label: 'Duration',
            hint: 'e.g. 45 minutes',
            value: _log.prayerAloneDuration,
            onChanged: (v) { _log.prayerAloneDuration = v; _persist(); },
          ),
          GoldField(
            label: 'How was your prayer time?',
            hint: 'Burdens, intercessions, breakthroughs...',
            value: _log.prayerAloneNotes,
            maxLines: 3,
            onChanged: (v) { _log.prayerAloneNotes = v; _persist(); },
          ),
        ]).animate().fadeIn(delay: 200.ms),

        // Prayer with others
        SectionCard(icon: '🤝', title: 'Prayer with Others', children: [
          GoldField(
            label: 'Duration',
            hint: 'e.g. 1 hour',
            value: _log.prayerOthersDuration,
            onChanged: (v) { _log.prayerOthersDuration = v; _persist(); },
          ),
          GoldField(
            label: 'Context (Who / Where)',
            hint: 'e.g. Cell group, prayer meeting',
            value: _log.prayerOthersContext,
            onChanged: (v) { _log.prayerOthersContext = v; _persist(); },
          ),
        ]).animate().fadeIn(delay: 240.ms),

        // Evangelism
        SectionCard(icon: '📢', title: 'Evangelism', children: [
          GoldField(
            label: 'Number of Contacts',
            hint: 'e.g. 2',
            value: _log.evangelismContacts,
            keyboardType: TextInputType.number,
            onChanged: (v) { _log.evangelismContacts = v; _persist(); },
          ),
          GoldField(
            label: 'Outcome / Response',
            hint: 'e.g. One received the gospel',
            value: _log.evangelismOutcome,
            onChanged: (v) { _log.evangelismOutcome = v; _persist(); },
          ),
          GoldField(
            label: 'Notes / Follow-up',
            hint: 'Names, conversations, next steps...',
            value: _log.evangelismNotes,
            maxLines: 3,
            onChanged: (v) { _log.evangelismNotes = v; _persist(); },
          ),
        ]).animate().fadeIn(delay: 280.ms),

        // Other
        SectionCard(icon: '➕', title: 'Other Spiritual Activities', children: [
          GoldField(
            label: 'Fasting, fellowship, service, discipleship...',
            hint: 'Describe any other significant activity today...',
            value: _log.other,
            maxLines: 3,
            onChanged: (v) { _log.other = v; _persist(); },
          ),
        ]).animate().fadeIn(delay: 320.ms),

        const SizedBox(height: 8),

        // Complete button
        GestureDetector(
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
              _log.completed ? '✓ Completed' : '✅ Mark Day Complete',
              style: AppTheme.display(17,
                  color: _log.completed ? AppTheme.green : AppTheme.bg0),
            ),
          ),
        ).animate().fadeIn(delay: 360.ms),
      ],
    );
  }

  Widget _unitDropdown(LiteratureEntry lit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('UNIT', style: AppTheme.label(11, color: AppTheme.gold.withOpacity(0.7))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.gold.withOpacity(0.25)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: lit.unit,
              isExpanded: true,
              dropdownColor: AppTheme.bg2,
              style: AppTheme.serif(15, color: AppTheme.cream),
              items: const [
                DropdownMenuItem(value: 'pages', child: Text('Pages')),
                DropdownMenuItem(value: 'chapters', child: Text('Chapters')),
                DropdownMenuItem(value: 'books', child: Text('Books')),
              ],
              onChanged: (v) { setState(() => lit.unit = v ?? 'pages'); _persist(); },
            ),
          ),
        ),
      ],
    );
  }
}
