import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/prayer_request.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class PrayerRequestScreen extends StatefulWidget {
  const PrayerRequestScreen({super.key});

  @override
  State<PrayerRequestScreen> createState() => _PrayerRequestScreenState();
}

class _PrayerRequestScreenState extends State<PrayerRequestScreen> {
  List<PrayerRequest> _active = [];
  List<PrayerRequest> _answered = [];
  bool _showAnswered = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final active = await StorageService.instance.getPrayerRequests(answered: false);
    final answered = await StorageService.instance.getPrayerRequests(answered: true);
    if (mounted) setState(() { _active = active; _answered = answered; });
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: accent),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(l.prayerRequestsTitle, style: AppTheme.display(20, color: accent)),
          actions: [
            GestureDetector(
              onTap: () => _showAddDialog(),
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: AppTheme.bg0, size: 20),
              ),
            ),
          ],
        ),
        body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        // Subtitle
        Text(l.prayerRequestsSubtitle,
            style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
        const SizedBox(height: 16),

        // Stats row
        Row(
          children: [
            _statChip('\u{1F64F}', '${_active.length}', l.prayerActive, accent),
            const SizedBox(width: 10),
            _statChip('\u2705', '${_answered.length}', l.prayerAnswered, accent),
          ],
        ),
        const SizedBox(height: 16),

        // Active prayers
        if (_active.isEmpty && !_showAnswered)
          _emptyState(l.prayerEmptyActive, accent)
        else
          ..._active.asMap().entries.map((e) =>
            _requestCard(e.value, accent, e.key).animate().fadeIn(delay: (e.key * 60).ms),
          ),

        // Toggle answered section
        if (_answered.isNotEmpty) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _showAnswered = !_showAnswered),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.green.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Text('\u2705', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.prayerAnsweredSection(_answered.length),
                      style: AppTheme.serif(13, color: AppTheme.green),
                    ),
                  ),
                  Icon(
                    _showAnswered ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.green,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (_showAnswered) ...[
            const SizedBox(height: 8),
            ..._answered.map((r) => _requestCard(r, accent, 0, answered: true)),
          ],
        ],
      ],
    ),
      ),
    );
  }

  Widget _statChip(String emoji, String value, String label, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTheme.display(20, color: accent)),
                Text(label.toUpperCase(), style: AppTheme.label(9, color: AppTheme.mutedColor(context))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String text, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text('\u{1F54A}\uFE0F', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center,
              style: AppTheme.serif(14, color: AppTheme.mutedColor(context))),
        ],
      ),
    );
  }

  Widget _requestCard(PrayerRequest req, Color accent, int index, {bool answered = false}) {
    final dateFmt = DateFormat('MMM d, y');
    final created = DateTime.tryParse(req.createdAt);
    final daysAgo = created != null ? DateTime.now().difference(created).inDays : 0;

    final categoryEmoji = switch (req.category) {
      'family' => '\u{1F46A}',
      'church' => '\u26EA',
      'nation' => '\u{1F30D}',
      'health' => '\u{1F3E5}',
      _ => '\u{1F64F}',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: answered
            ? AppTheme.green.withValues(alpha: 0.06)
            : AppTheme.isDark(context)
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: answered
              ? AppTheme.green.withValues(alpha: 0.2)
              : accent.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(categoryEmoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  req.title,
                  style: AppTheme.serif(14,
                      color: AppTheme.textColor(context),
                      weight: FontWeight.w600),
                ),
              ),
              if (!answered) ...[
                // Mark as answered
                GestureDetector(
                  onTap: () => _markAnswered(req),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: AppTheme.green, size: 16),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              // Delete
              GestureDetector(
                onTap: () => _delete(req),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.rust.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: AppTheme.rust, size: 14),
                ),
              ),
            ],
          ),
          if (req.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(req.description,
                style: AppTheme.serif(12, color: AppTheme.mutedColor(context)),
                maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                created != null ? dateFmt.format(created) : '',
                style: AppTheme.label(9, color: AppTheme.faintColor(context)),
              ),
              if (!answered && daysAgo > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '$daysAgo days',
                  style: AppTheme.label(9, color: accent),
                ),
              ],
              if (answered && req.answerNote.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '\u2705 ${req.answerNote}',
                    style: AppTheme.serif(11, color: AppTheme.green),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'personal';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.prayerAddTitle, style: AppTheme.display(18, color: accent)),
              const SizedBox(height: 16),
              // Category chips
              Wrap(
                spacing: 8,
                children: ['personal', 'family', 'church', 'nation', 'health'].map((cat) {
                  final selected = category == cat;
                  final emoji = switch (cat) {
                    'family' => '\u{1F46A}',
                    'church' => '\u26EA',
                    'nation' => '\u{1F30D}',
                    'health' => '\u{1F3E5}',
                    _ => '\u{1F64F}',
                  };
                  final label = switch (cat) {
                    'personal' => l.prayerCatPersonal,
                    'family' => l.prayerCatFamily,
                    'church' => l.prayerCatChurch,
                    'nation' => l.prayerCatNation,
                    'health' => l.prayerCatHealth,
                    _ => cat,
                  };
                  return GestureDetector(
                    onTap: () => setSheetState(() => category = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? accent.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? accent : accent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text('$emoji $label',
                          style: AppTheme.serif(11, color: selected ? accent : AppTheme.mutedColor(context))),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                style: AppTheme.serif(14, color: AppTheme.textColor(context)),
                decoration: InputDecoration(
                  labelText: l.prayerTitleLabel,
                  hintText: l.prayerTitleHint,
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
                controller: descCtrl,
                maxLines: 3,
                style: AppTheme.serif(14, color: AppTheme.textColor(context)),
                decoration: InputDecoration(
                  labelText: l.prayerDescLabel,
                  hintText: l.prayerDescHint,
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
                    if (titleCtrl.text.trim().isEmpty) return;
                    final req = PrayerRequest(
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      category: category,
                      createdAt: DateTime.now().toIso8601String(),
                    );
                    await StorageService.instance.addPrayerRequest(req);
                    titleCtrl.dispose();
                    descCtrl.dispose();
                    if (mounted) {
                      Navigator.pop(ctx);
                      _load();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(l.prayerAddButton, style: AppTheme.display(16, color: AppTheme.bg0)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _markAnswered(PrayerRequest req) {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('\u{1F389} ${l.prayerMarkAnswered}',
                style: AppTheme.display(18, color: AppTheme.green)),
            const SizedBox(height: 4),
            Text(req.title, style: AppTheme.serif(14, color: AppTheme.textColor(context))),
            const SizedBox(height: 16),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              style: AppTheme.serif(14, color: AppTheme.textColor(context)),
              decoration: InputDecoration(
                labelText: l.prayerAnswerNote,
                hintText: l.prayerAnswerHint,
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
                  req.isAnswered = true;
                  req.answeredAt = DateTime.now().toIso8601String();
                  req.answerNote = noteCtrl.text.trim();
                  await StorageService.instance.updatePrayerRequest(req);
                  noteCtrl.dispose();
                  if (mounted) {
                    Navigator.pop(ctx);
                    _load();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.green.withValues(alpha: 0.4)),
                  ),
                  alignment: Alignment.center,
                  child: Text('\u2705 ${l.prayerConfirmAnswered}',
                      style: AppTheme.display(16, color: AppTheme.green)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _delete(PrayerRequest req) async {
    if (req.id == null) return;
    await StorageService.instance.deletePrayerRequest(req.id!);
    _load();
  }
}
