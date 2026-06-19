import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A frosted card that groups a spiritual discipline section.
/// Supports expand/collapse via tap on the header.
class SectionCard extends StatefulWidget {
  final String icon;
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;
  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.initiallyExpanded = true,
  });

  @override
  State<SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<SectionCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.title,
      expanded: _expanded,
      child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.accentGold(context).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text(widget.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.title, style: AppTheme.display(18, color: AppTheme.accentGold(context))),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.faintColor(context),
                  size: 22,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 16),
            ...widget.children,
          ],
        ],
      ),
      ),
    );
  }
}

/// A gold-labelled text field with optional autocomplete suggestions.
///
/// When [suggestions] is provided, the field becomes an autocomplete field
/// that proposes matching options as the user types.
class GoldField extends StatelessWidget {
  final String label;
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  /// Optional list of suggestion strings. When provided, the field shows
  /// autocomplete proposals as the user types.
  final List<String>? suggestions;

  const GoldField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint = '',
    this.keyboardType,
    this.maxLines = 1,
    this.suggestions,
  });

  InputDecoration _decoration(BuildContext context, Color accent, bool dark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTheme.serif(14, color: AppTheme.faintColor(context)),
      filled: true,
      fillColor: dark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: accent.withValues(alpha: 0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: accent, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentGold(context);
    final dark = AppTheme.isDark(context);

    if (suggestions != null && suggestions!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
            const SizedBox(height: 6),
            _GoldFieldAutocomplete(
              initialValue: value,
              suggestions: suggestions!,
              onChanged: onChanged,
              keyboardType: keyboardType,
              maxLines: maxLines,
              decoration: _decoration(context, accent, dark),
              textStyle: AppTheme.serif(15, color: AppTheme.textColor(context)),
            ),
          ],
        ),
      );
    }

    return Semantics(
      label: label,
      textField: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: AppTheme.label(11, color: accent.withValues(alpha: 0.7))),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: value,
              onChanged: onChanged,
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: AppTheme.serif(15, color: AppTheme.textColor(context)),
              decoration: _decoration(context, accent, dark),
            ),
          ],
        ),
      ),
    );
  }
}

/// A circular progress ring with a label in the centre.
class ProgressRing extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final String centerText;
  /// Optional callback when user taps the ring.
  final VoidCallback? onTap;
  const ProgressRing({super.key, required this.progress, this.size = 64, this.centerText = '', this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentGold(context);
    return Semantics(
      label: 'Progress ${(progress * 100).round()} percent',
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(progress, accent),
            child: Center(
              child: Text(centerText,
                  style: AppTheme.display(size * 0.28, color: accent)),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color accent;
  _RingPainter(this.progress, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    final bgPaint = Paint()
      ..color = accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    final fgPaint = Paint()
      ..shader = LinearGradient(colors: [accent.withValues(alpha: 0.7), accent])
          .createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.accent != accent;
}

/// A small stat tile for the dashboard.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final String icon;
  const StatTile({super.key, required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentGold(context);
    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            ExcludeSemantics(child: Text(icon, style: const TextStyle(fontSize: 20))),
            const SizedBox(height: 6),
            Text(value, style: AppTheme.display(22, color: accent)),
            const SizedBox(height: 2),
            Text(label.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppTheme.label(9, color: AppTheme.mutedColor(context))),
          ],
        ),
      ),
    );
  }
}

/// Stateful wrapper for Autocomplete inside GoldField.
/// Ensures the controller listener is added only once.
class _GoldFieldAutocomplete extends StatefulWidget {
  final String initialValue;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  final InputDecoration decoration;
  final TextStyle textStyle;

  const _GoldFieldAutocomplete({
    required this.initialValue,
    required this.suggestions,
    required this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
    required this.decoration,
    required this.textStyle,
  });

  @override
  State<_GoldFieldAutocomplete> createState() => _GoldFieldAutocompleteState();
}

class _GoldFieldAutocompleteState extends State<_GoldFieldAutocomplete> {
  bool _listenerAdded = false;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.initialValue),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return const [];
        final input = textEditingValue.text.toLowerCase();
        return widget.suggestions.where(
            (s) => s.toLowerCase().contains(input));
      },
      onSelected: widget.onChanged,
      fieldViewBuilder: (ctx, controller, focusNode, onSubmitted) {
        if (!_listenerAdded) {
          controller.addListener(() => widget.onChanged(controller.text));
          _listenerAdded = true;
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: widget.keyboardType,
          maxLines: widget.maxLines,
          style: widget.textStyle,
          decoration: widget.decoration,
        );
      },
    );
  }
}
