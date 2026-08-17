import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';

/// One step in a coach-mark sequence: a widget to spotlight and a caption
/// to show beside it.
class CoachMarkStep {
  final GlobalKey targetKey;
  final String caption;
  const CoachMarkStep({required this.targetKey, required this.caption});
}

/// Shows a spotlight coach-mark sequence over [steps], one at a time.
///
/// Steps whose target isn't currently laid out (`targetKey.currentContext`
/// is null) are skipped rather than shown or treated as an error — a coach
/// mark must never crash the screen it's meant to help.
///
/// Returns when the sequence completes or the user taps Skip.
Future<void> showCoachMarkSequence(
  BuildContext context, {
  required List<CoachMarkStep> steps,
}) {
  final completer = Completer<void>();
  late OverlayEntry entry;
  final overlay = Overlay.of(context);

  entry = OverlayEntry(
    builder: (ctx) => _CoachMarkOverlay(
      steps: steps,
      onDone: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _CoachMarkOverlay extends StatefulWidget {
  final List<CoachMarkStep> steps;
  final VoidCallback onDone;
  const _CoachMarkOverlay({required this.steps, required this.onDone});

  @override
  State<_CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<_CoachMarkOverlay> {
  late int _index;

  /// Finds the first step from [_index] onward whose target is currently
  /// mounted and laid out. Returns null if none remain.
  int? _nextShowableIndex(int from) {
    for (var i = from; i < widget.steps.length; i++) {
      final ctx = widget.steps[i].targetKey.currentContext;
      if (ctx != null && ctx.findRenderObject() is RenderBox) return i;
    }
    return null;
  }

  Rect? _targetRect(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  void _advance() {
    final next = _nextShowableIndex(_index + 1);
    if (next == null) {
      widget.onDone();
    } else {
      setState(() => _index = next);
    }
  }

  @override
  void initState() {
    super.initState();
    // Resolve the starting index synchronously before the first build().
    // This prevents a race where the initial build() sees _index == 0,
    // finds no target, and calls onDone() before a post-frame callback
    // could correct the index.
    final first = _nextShowableIndex(0);
    if (first == null) {
      // Nothing in the whole sequence is showable — schedule end for after
      // the first frame (to avoid calling onDone() from initState).
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
    } else {
      // first is now the correct starting index; use it immediately.
      _index = first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);

    // Guard against empty list or out-of-range index. This can occur if
    // steps is empty (a legal call per the public signature) or if _index
    // was somehow invalidated mid-sequence.
    if (_index < 0 || _index >= widget.steps.length) {
      return const SizedBox.shrink();
    }

    final rect = _targetRect(widget.steps[_index].targetKey);

    if (rect == null) {
      // Target disappeared between frames — end gracefully rather than
      // draw a spotlight around nothing.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;
    final captionBelow = rect.top < screenSize.height / 2;
    final isLast = _nextShowableIndex(_index + 1) == null;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _advance,
            child: CustomPaint(
              painter: _SpotlightPainter(rect.inflate(8)),
              size: Size.infinite,
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: captionBelow ? rect.bottom + 20 : null,
          bottom: captionBelow ? null : screenSize.height - rect.top + 20,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.isDark(context) ? AppTheme.bg1 : AppTheme.lightBg1,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.steps[_index].caption,
                    style: AppTheme.serif(14, color: AppTheme.textColor(context)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        l.coachMarkStepCount(_index + 1, widget.steps.length),
                        style: AppTheme.label(10, color: AppTheme.mutedColor(context)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: widget.onDone,
                        child: Text(l.coachMarkSkip,
                            style: TextStyle(color: AppTheme.mutedColor(context))),
                      ),
                      TextButton(
                        onPressed: _advance,
                        child: Text(
                          isLast ? l.coachMarkGotIt : l.coachMarkNext,
                          style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect hole;
  _SpotlightPainter(this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(12)));
    final combined = Path.combine(PathOperation.difference, overlayPath, holePath);
    canvas.drawPath(combined, Paint()..color = Colors.black.withValues(alpha: 0.65));
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole;
}
