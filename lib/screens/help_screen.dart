import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// A usage guide and FAQ, reached from the `?` icon present in the header
/// on every screen. Collects answers to common questions in one scrollable
/// place instead of requiring the user to hunt through Settings.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);

    final faqs = <(String, String, String)>[
      ('📚', l.helpFaqDisciplinesTitle, l.helpFaqDisciplinesBody),
      ('🔥', l.helpFaqDdegTitle, l.helpFaqDdegBody),
      ('⚡', l.helpFaqQuickLogTitle, l.helpFaqQuickLogBody),
      ('📤', l.helpFaqReportsTitle, l.helpFaqReportsBody),
      ('🗓️', l.helpFaqCadenceTitle, l.helpFaqCadenceBody),
      ('🔔', l.helpFaqRemindersTitle, l.helpFaqRemindersBody),
      ('🔒', l.helpFaqPrivacyTitle, l.helpFaqPrivacyBody),
      ('🎓', l.helpFaqCoachMarksTitle, l.helpFaqCoachMarksBody),
      ('💬', l.helpFaqMoreTitle, l.helpFaqMoreBody),
    ];

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
          title: Text(l.helpScreenTitle, style: AppTheme.display(20, color: accent)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(l.helpScreenSubtitle,
                style: AppTheme.serif(13, color: AppTheme.mutedColor(context))),
            const SizedBox(height: 16),
            ...faqs.asMap().entries.map((e) {
              final (icon, title, body) = e.value;
              return SectionCard(
                icon: icon,
                title: title,
                initiallyExpanded: false,
                children: [
                  Text(body, style: AppTheme.serif(13, color: AppTheme.textColor(context))),
                ],
              ).animate().fadeIn(delay: (e.key * 40).ms);
            }),
          ],
        ),
      ),
    );
  }
}
