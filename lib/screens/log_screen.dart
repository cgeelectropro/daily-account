import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../l10n/generated/app_localizations.dart';
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
    final t = S.of(context);
    setState(() => _log.completed = true);
    _persist();
    ScaffoldMessenger.of(context).showSnackBar(
      _snack('\u2705 ${t.markedComplete}'),
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

    final t = S.of(context);

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
        SectionCard(
          icon: '\u{1F4D6}',
          title: t.sectionBible,
          initiallyExpanded: _log.bibleReference.isNotEmpty || _log.bibleChapters.isNotEmpty,
          children: [
            GoldField(
              label: t.bibleRefLabel,
              hint: t.bibleRefHint,
              value: _log.bibleReference,
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
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.gold.withOpacity(0.1)),
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
                icon: const Icon(Icons.add_circle_outline, size: 18, color: AppTheme.gold),
                label: Text(t.addAnotherBook, style: AppTheme.serif(13, color: AppTheme.gold)),
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
              onChanged: (v) { _log.ddegScripture = v; _persist(); },
            ),
            GoldField(
              label: t.ddegTimeLabel,
              hint: t.ddegTimeHint,
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
            GoldField(
              label: t.durationLabel,
              hint: t.durationHint,
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
            GoldField(
              label: t.durationLabel,
              hint: t.durationHint,
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
          ],
        ).animate().fadeIn(delay: 280.ms),

        // Fasting
        SectionCard(
          icon: '\u{1F37D}\uFE0F',
          title: t.sectionFasting,
          initiallyExpanded: _log.fastingType.isNotEmpty || _log.fastingDuration.isNotEmpty,
          children: [
            GoldField(
              label: t.fastingTypeLabel,
              hint: t.fastingTypeHint,
              value: _log.fastingType,
              onChanged: (v) { _log.fastingType = v; _persist(); },
            ),
            GoldField(
              label: t.fastingDurationLabel,
              hint: t.fastingDurationHint,
              value: _log.fastingDuration,
              onChanged: (v) { _log.fastingDuration = v; _persist(); },
            ),
            GoldField(
              label: t.fastingPrayerFocusLabel,
              hint: t.fastingPrayerFocusHint,
              value: _log.fastingPrayerFocus,
              maxLines: 3,
              onChanged: (v) { _log.fastingPrayerFocus = v; _persist(); },
            ),
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
            GoldField(
              label: t.discipleshipDurationLabel,
              hint: t.discipleshipDurationHint,
              value: _log.discipleshipDuration,
              onChanged: (v) { _log.discipleshipDuration = v; _persist(); },
            ),
          ],
        ).animate().fadeIn(delay: 440.ms),

        // Other
        SectionCard(
          icon: '\u2795',
          title: t.sectionOther,
          initiallyExpanded: _log.other.isNotEmpty,
          children: [
            GoldField(
              label: t.otherLabel,
              hint: t.otherHint,
              value: _log.other,
              maxLines: 3,
              onChanged: (v) { _log.other = v; _persist(); },
            ),
          ],
        ).animate().fadeIn(delay: 480.ms),

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
              _log.completed ? '\u2713 ${t.markedComplete}' : '\u2705 ${t.markComplete}',
              style: AppTheme.display(17,
                  color: _log.completed ? AppTheme.green : AppTheme.bg0),
            ),
          ),
        ).animate().fadeIn(delay: 520.ms),
      ],
    );
  }

  Widget _unitDropdown(LiteratureEntry lit) {
    final t = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.unitLabel, style: AppTheme.label(11, color: AppTheme.gold.withOpacity(0.7))),
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
