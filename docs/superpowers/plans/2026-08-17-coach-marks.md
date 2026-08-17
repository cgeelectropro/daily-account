# Coach Marks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable spotlight coach-mark system and wire it into all four main screens (Stopwatch, Log, Report, Settings) so a first-time user is walked through each screen's key actions on first visit, with a skip option per sequence and a "Replay tutorial" recovery path in Settings.

**Architecture:** A single stateless-config, stateful-overlay widget pair — `CoachMarkStep` (data: target `GlobalKey`, caption, order) and `CoachMarkSequence` (an `Overlay` entry that walks a list of steps, drawing a spotlight hole around the current step's target via `CustomPainter` and a caption bubble positioned relative to it). Each screen owns a list of `GlobalKey`s already attached to its real widgets, builds its sequence in `initState` after first frame, and shows it only if a `StorageService` flag for that sequence hasn't been set. No new package dependency — built on `Overlay.of(context)`, `GlobalKey.currentContext`, and `RenderBox.localToGlobal`.

**Tech Stack:** Flutter/Dart, existing `StorageService` (SharedPreferences-backed key/value settings), existing `.arb`-based localization (`lib/l10n/app_en.arb` + `app_fr.arb` → generated `S` class via `flutter gen-l10n`).

**Spec:** [docs/superpowers/specs/2026-08-17-simplify-ux-design.md](../specs/2026-08-17-simplify-ux-design.md) — this plan implements spec section 3 ("First-run guided walkthrough (coach marks)") in full, including the four sequences (Stopwatch, Log, Report, Settings) and the Replay tutorial entry point. It intentionally does **not** implement spec sections 1, 1a, 2, or 4 (Settings grouping, Notifications sub-screen, Log Core/More split, Help screen) — those are a separate follow-up plan. Because that UI doesn't exist yet, the Settings sequence in this plan targets what exists in `SettingsScreen` today (Profile field, Notifications toggle) rather than the not-yet-built group headers or help icon described in spec section 3's original step list.

## Global Constraints

- Every coach-mark step must be **skippable**: a visible "Skip" action dismisses the *entire* sequence immediately, not just the current step (spec §3).
- Skipping a sequence still persists its "shown" flag — skip means "don't show again this way," not "ask again next launch" (spec §3).
- A single **"Replay tutorial"** control must clear all four sequence flags at once, added to the existing Settings screen (temporary location: a new small section near the bottom of `SettingsScreen`, since the "Advanced" group from the deferred spec sections doesn't exist yet).
- No new package dependency — build on `Overlay`/`CustomPainter`/`GlobalKey`, all already available via `package:flutter/material.dart`.
- No new persistence beyond string flags via the existing `StorageService.getSetting`/`setSetting` (see `lib/services/storage_service.dart:352,357`) — same mechanism already used for `onboarding_complete`. The four "shown" flag keys are fixed across every task: `coachmark_stopwatch_shown`, `coachmark_log_shown`, `coachmark_report_shown`, `coachmark_settings_shown` — use these exact strings, no variation.
- Every new user-facing string needs an entry in **both** `lib/l10n/app_en.arb` and `lib/l10n/app_fr.arb`, followed by running `flutter gen-l10n` to regenerate `lib/l10n/generated/app_localizations*.dart` before the code that references the new `S.of(context).xxx` getter will compile.
- **Coach-mark captions must never be hardcoded English strings.** Every `CoachMarkStep(caption: ...)` call must source its text from `S.of(context).coachXxx` (never a literal string), so captions automatically follow the app's currently selected language (English or French, set via `DailyAccountApp.setLocale` in Settings) with no separate coach-mark language setting — identical to how every other screen in the app already localizes.
- If a coach mark's target `GlobalKey.currentContext` is null when the sequence tries to show a step (widget not mounted/laid out yet, e.g. mid-rebuild), skip that step rather than throw — mirrors the "never crash from X" defensive style already used in `lib/screens/home_shell.dart` (e.g. `_syncWidgetChangesToDb`).
- No test suite exists in this project (per `CLAUDE.md`); verification throughout is manual via `flutter run`.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/widgets/coach_mark.dart` | New. `CoachMarkStep` data class, `CoachMarkController` (shows/advances/dismisses an `OverlayEntry`), `_CoachMarkOverlay` (the spotlight + caption painter/widget), `showCoachMarkSequence()` entry-point function. |
| `lib/services/storage_service.dart` | No changes — reused as-is (`getSetting`/`setSetting`). |
| `lib/screens/stopwatch_screen.dart` | Modify — add 3 `GlobalKey`s (first timer tile, proclamation tile, add-activity tile), trigger sequence in `initState`. |
| `lib/screens/log_screen.dart` | Modify — add 2 `GlobalKey`s (Bible section, an existing "flash"/quick element), trigger sequence in `initState`. |
| `lib/screens/report_screen.dart` | Modify — add 2 `GlobalKey`s (stats row, send-buttons block), trigger sequence in `initState`. |
| `lib/screens/settings_screen.dart` | Modify — add 2 `GlobalKey`s (Profile section, Notifications section), trigger sequence in `initState`; add "Replay tutorial" button. |
| `lib/l10n/app_en.arb` / `app_fr.arb` | Modify — add coach-mark caption strings, Skip/Next/Got it button labels, Replay tutorial strings. |

---

## Task 1: `CoachMark` reusable widget

**Files:**
- Create: `lib/widgets/coach_mark.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb` (add `coachMarkNext`, `coachMarkGotIt`, `coachMarkSkip`, `coachMarkStepCount`)

**Interfaces:**
- Produces:
  - `class CoachMarkStep { final GlobalKey targetKey; final String caption; const CoachMarkStep({required this.targetKey, required this.caption}); }`
  - `Future<void> showCoachMarkSequence(BuildContext context, {required List<CoachMarkStep> steps})` — inserts an `OverlayEntry` that walks the steps; resolves when the sequence finishes or is skipped. Steps whose `targetKey.currentContext` is null at the time they'd be shown are silently skipped (not shown, not counted as an error).

- [ ] **Step 1: Add localization strings**

Add to `lib/l10n/app_en.arb` (anywhere after the `"tabSettings"` block, e.g. right after line 11):

```json
  "coachMarkNext": "Next",
  "coachMarkGotIt": "Got it",
  "coachMarkSkip": "Skip",
  "coachMarkStepCount": "{current} of {total}",
  "@coachMarkStepCount": { "placeholders": { "current": { "type": "int" }, "total": { "type": "int" } } },
```

Add to `lib/l10n/app_fr.arb` at the equivalent position:

```json
  "coachMarkNext": "Suivant",
  "coachMarkGotIt": "Compris",
  "coachMarkSkip": "Passer",
  "coachMarkStepCount": "{current} sur {total}",
  "@coachMarkStepCount": { "placeholders": { "current": { "type": "int" }, "total": { "type": "int" } } },
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors; `lib/l10n/generated/app_localizations_en.dart` and `_fr.dart` now contain `coachMarkNext`, `coachMarkGotIt`, `coachMarkSkip`, `coachMarkStepCount`.

- [ ] **Step 3: Write the widget file**

Create `lib/widgets/coach_mark.dart`:

```dart
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
  int _index = 0;

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
    final first = _nextShowableIndex(0);
    if (first == null) {
      // Nothing in the whole sequence is showable — end immediately.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
    } else if (first != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = first);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);
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
```

Add the missing `dart:async` import for `Completer`:

```dart
import 'dart:async';
```

(insert as the first line of the file, above the `flutter/material.dart` import).

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/widgets/coach_mark.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/coach_mark.dart lib/l10n/app_en.arb lib/l10n/app_fr.arb lib/l10n/generated
git commit -m "feat: add reusable CoachMark spotlight overlay widget"
```

---

## Task 2: Stopwatch screen coach marks

**Files:**
- Modify: `lib/screens/stopwatch_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`

**Interfaces:**
- Consumes: `CoachMarkStep`, `showCoachMarkSequence` from `lib/widgets/coach_mark.dart` (Task 1).
- Produces: nothing consumed by later tasks — each screen's sequence is independent.

- [ ] **Step 1: Add localization strings**

Add to `lib/l10n/app_en.arb`:

```json
  "coachStopwatchTimer": "Tap the play button to start timing a discipline — like Bible reading or prayer.",
  "coachStopwatchProclamation": "Tap here to log a proclamation moment.",
  "coachStopwatchAddActivity": "Track something not listed here — tap + to add your own activity.",
```

Add to `lib/l10n/app_fr.arb`:

```json
  "coachStopwatchTimer": "Appuyez sur lecture pour chronométrer une discipline — comme la lecture biblique ou la prière.",
  "coachStopwatchProclamation": "Appuyez ici pour enregistrer un moment de proclamation.",
  "coachStopwatchAddActivity": "Suivez autre chose : appuyez sur + pour ajouter votre propre activité.",
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors.

- [ ] **Step 3: Add GlobalKeys and wire the sequence**

In `lib/screens/stopwatch_screen.dart`, add three keys as state fields right after the existing `_customActivities` field (around line 26):

```dart
class _StopwatchScreenState extends State<StopwatchScreen> {
  List<CustomActivity> _customActivities = [];
  final _firstTimerKey = GlobalKey();
  final _proclamationKey = GlobalKey();
  final _addActivityKey = GlobalKey();
```

In `initState` (currently lines 28-33), add the coach-mark trigger after the existing calls:

```dart
  @override
  void initState() {
    super.initState();
    TimerService.instance.addListener(_onTick);
    _loadCustomActivities();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowCoachMarks());
  }

  Future<void> _maybeShowCoachMarks() async {
    const flag = 'coachmark_stopwatch_shown';
    final shown = await StorageService.instance.getSetting(flag, fallback: '');
    if (shown == 'true' || !mounted) return;
    final l = S.of(context);
    await showCoachMarkSequence(context, steps: [
      CoachMarkStep(targetKey: _firstTimerKey, caption: l.coachStopwatchTimer),
      CoachMarkStep(targetKey: _proclamationKey, caption: l.coachStopwatchProclamation),
      CoachMarkStep(targetKey: _addActivityKey, caption: l.coachStopwatchAddActivity),
    ]);
    await StorageService.instance.setSetting(flag, 'true');
  }
```

Add the import at the top of the file (after the existing `import '../services/storage_service.dart';` at line 9):

```dart
import '../widgets/coach_mark.dart';
```

Now attach the three keys to real widgets. In `_activityGrid` (line 222), the grid renders `_activityTile` for each `ActivityType` in order and `_addActivityTile` last. `ActivityType.values.where((a) => a != ActivityType.fasting)` — proclamation and the first tile (bibleReading, per the enum's declared order) are both within this list. Modify `_activityTile` (starting line 249) to accept and apply an optional key:

```dart
  Widget _activityTile(
      ActivityType activity, S l, TimerService ts, Color accent) {
    final key = TimerKey.builtIn(activity);
    final session = ts.getSession(key);
    final isRunning = session?.isRunning ?? false;
    final isPaused = session?.paused ?? false;
    final hasElapsed = session != null && session.currentElapsed > Duration.zero;
    final dark = AppTheme.isDark(context);
    final wrapperKey = activity == ActivityType.bibleReading
        ? _firstTimerKey
        : activity == ActivityType.proclamation
            ? _proclamationKey
            : null;

    return Container(
      key: wrapperKey,
      padding: const EdgeInsets.all(12),
```

(the rest of `_activityTile`'s body is unchanged — only the `Container`'s opening two lines change, from `padding:` starting the widget to now having `key: wrapperKey,` first).

Modify `_addActivityTile` (line 429) to attach `_addActivityKey` to its outer `GestureDetector`'s child `Container`:

```dart
  Widget _addActivityTile(S l, Color accent) {
    return GestureDetector(
      onTap: () => _showAddActivityDialog(l, accent),
      child: Container(
        key: _addActivityKey,
        padding: const EdgeInsets.all(12),
```

- [ ] **Step 4: Verify it compiles and run manually**

Run: `flutter analyze lib/screens/stopwatch_screen.dart`
Expected: `No issues found!`

Run: `flutter run` (or hot-reload if already running), navigate to a fresh app state (see Task 6 for how to reset flags), land on the Stopwatch tab.
Expected: three-step coach mark appears pointing at the Bible timer tile, then the Proclamation tile, then the Add Activity tile; tapping Skip at any point dismisses immediately; revisiting the tab afterward shows nothing.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/stopwatch_screen.dart lib/l10n/app_en.arb lib/l10n/app_fr.arb lib/l10n/generated
git commit -m "feat: add first-run coach marks to Stopwatch screen"
```

---

## Task 3: Log screen coach marks

**Files:**
- Modify: `lib/screens/log_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`

**Interfaces:**
- Consumes: `CoachMarkStep`, `showCoachMarkSequence` from `lib/widgets/coach_mark.dart` (Task 1).

- [ ] **Step 1: Add localization strings**

Add to `lib/l10n/app_en.arb`:

```json
  "coachLogBible": "Log today's Bible reading here — this is where your daily entry starts.",
  "coachLogQuickLog": "In a hurry? Tap the Quick Log flash button in the header to check off disciplines fast.",
```

Add to `lib/l10n/app_fr.arb`:

```json
  "coachLogBible": "Enregistrez votre lecture biblique du jour ici — c'est le début de votre entrée quotidienne.",
  "coachLogQuickLog": "Pressé ? Appuyez sur le bouton Journal Rapide dans l'en-tête pour cocher rapidement vos disciplines.",
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors.

- [ ] **Step 3: Add GlobalKeys and wire the sequence**

The Log screen's coach mark needs to spotlight the Bible `SectionCard` (owned by `LogScreen` itself, `lib/screens/log_screen.dart:918`) and the Quick Log button (owned by the parent `HomeShell`, `lib/screens/home_shell.dart:1066`, only rendered `if (_tab == 1)`). Since these live in different widgets, this sequence is triggered from `LogScreen` but needs a key `HomeShell` exposes.

In `lib/screens/home_shell.dart`, add a static key so `LogScreen` can reference the same key instance without a new callback plumbing layer:

```dart
class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  static final quickLogButtonKey = GlobalKey();
```

(insert as the first field, right after the `class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {` line — currently line 37).

Attach it to the Quick Log button's `Material` widget (currently starting line 1060):

```dart
              if (_tab == 1) ...[
                const SizedBox(width: 8),
                Material(
                  key: _HomeShellState.quickLogButtonKey,
                  color: accent.withValues(alpha: 0.12),
```

In `lib/screens/log_screen.dart`, add a key field near the top of `_LogScreenState` (after `List<CustomActivity> _customActivities = [];` at line 37):

```dart
  final _bibleSectionKey = GlobalKey();
```

Add the import:

```dart
import 'home_shell.dart';
import '../widgets/coach_mark.dart';
```

In `initState` (lines 69-75), add the trigger:

```dart
  @override
  void initState() {
    super.initState();
    _load();
    _loadCustomActivities();
    _loadActiveFast();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowCoachMarks());
  }

  Future<void> _maybeShowCoachMarks() async {
    const flag = 'coachmark_log_shown';
    final shown = await StorageService.instance.getSetting(flag, fallback: '');
    if (shown == 'true' || !mounted) return;
    final l = S.of(context);
    await showCoachMarkSequence(context, steps: [
      CoachMarkStep(targetKey: _bibleSectionKey, caption: l.coachLogBible),
      CoachMarkStep(targetKey: _HomeShellState.quickLogButtonKey, caption: l.coachLogQuickLog),
    ]);
    await StorageService.instance.setSetting(flag, 'true');
  }
```

Attach `_bibleSectionKey` to the Bible `SectionCard` (currently `lib/screens/log_screen.dart:918-923`):

```dart
        SectionCard(
          key: _bibleSectionKey,
          icon: '\u{1F4D6}',
          title: t.sectionBible,
```

- [ ] **Step 4: Verify it compiles and run manually**

Run: `flutter analyze lib/screens/log_screen.dart lib/screens/home_shell.dart`
Expected: `No issues found!`

Run: `flutter run`, reset flags (Task 6), navigate to the Log tab.
Expected: two-step coach mark — Bible section first, then Quick Log button in the header. If the Log screen is reached without ever visiting the Log tab first (so the Quick Log button was never laid out because `_tab != 1` at some point mid-sequence), the second step is skipped gracefully rather than crashing — confirm this by rapidly switching tabs during the sequence.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/log_screen.dart lib/screens/home_shell.dart lib/l10n/app_en.arb lib/l10n/app_fr.arb lib/l10n/generated
git commit -m "feat: add first-run coach marks to Log screen"
```

---

## Task 4: Report screen coach marks

**Files:**
- Modify: `lib/screens/report_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`

**Interfaces:**
- Consumes: `CoachMarkStep`, `showCoachMarkSequence` from `lib/widgets/coach_mark.dart` (Task 1).

- [ ] **Step 1: Add localization strings**

Add to `lib/l10n/app_en.arb`:

```json
  "coachReportStats": "Your week at a glance — days logged, chapters read, souls reached.",
  "coachReportSend": "When you're ready, send your report here — by email, WhatsApp, or share it directly.",
```

Add to `lib/l10n/app_fr.arb`:

```json
  "coachReportStats": "Votre semaine en un coup d'œil — jours enregistrés, chapitres lus, âmes touchées.",
  "coachReportSend": "Quand vous êtes prêt, envoyez votre rapport ici — par email, WhatsApp, ou partagez-le directement.",
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors.

- [ ] **Step 3: Add GlobalKeys and wire the sequence**

In `lib/screens/report_screen.dart`, add two key fields to `_ReportScreenState` (after `bool _sending = false;` at line 40):

```dart
  final _statsRowKey = GlobalKey();
  final _sendButtonsKey = GlobalKey();
```

Add the import (near the top, after `import '../widgets/common_widgets.dart';` at line 19):

```dart
import '../services/storage_service.dart';
import '../widgets/coach_mark.dart';
```

(`storage_service.dart` may already be imported for other reasons — check before duplicating; if it's already present, only add the `coach_mark.dart` import.)

Find `_ReportScreenState`'s `initState` and add the trigger after existing setup calls (mirroring the pattern used in Tasks 3–4):

```dart
  Future<void> _maybeShowCoachMarks() async {
    const flag = 'coachmark_report_shown';
    final shown = await StorageService.instance.getSetting(flag, fallback: '');
    if (shown == 'true' || !mounted) return;
    final l = S.of(context);
    await showCoachMarkSequence(context, steps: [
      CoachMarkStep(targetKey: _statsRowKey, caption: l.coachReportStats),
      CoachMarkStep(targetKey: _sendButtonsKey, caption: l.coachReportSend),
    ]);
    await StorageService.instance.setSetting(flag, 'true');
  }
```

Call it at the end of `initState` via `WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowCoachMarks());` — add this line to the existing `initState` method body (do not replace existing setup calls already there).

Attach `_statsRowKey` by wrapping the stats `Row` that contains the `StatTile`s (the row starting near line 548, containing `StatTile(value: '${_stats!.daysLogged}/7', ...)`). Wrap that `Row` in a `Container(key: _statsRowKey, child: Row(...))` — i.e. change:

```dart
            Expanded(child: StatTile(value: '${_stats!.daysLogged}/7', label: l.daysLogged, icon: '✅')),
```
and its enclosing `Row(...)` from:
```dart
        Row(
          children: [
            Expanded(child: StatTile(value: '${_stats!.daysLogged}/7', ...
```
to:
```dart
        Container(
          key: _statsRowKey,
          child: Row(
            children: [
              Expanded(child: StatTile(value: '${_stats!.daysLogged}/7', ...
```
adjusting the closing brackets to match (add one closing `)` for the new `Container`, and re-indent the `Row`'s existing children one level — mechanical, no logic change).

Attach `_sendButtonsKey` to the send-buttons block in `_buildReportPreviewAndButtons` (`lib/screens/report_screen.dart:1102`). Wrap the two `_bigButton` calls (lines 1131-1133) in a keyed `Column`:

```dart
        // Send buttons
        Column(
          key: _sendButtonsKey,
          children: [
            _bigButton('📧  ${l.sendEmail}', AppTheme.goldGradient, AppTheme.bg0, _sending ? null : () => _sendEmail()),
            const SizedBox(height: 10),
            _bigButton('💬  ${l.sendWhatsApp}', AppTheme.goldGradient, AppTheme.bg0, _sending ? null : () => _sendWhatsApp()),
          ],
        ),
        const SizedBox(height: 10),
```

- [ ] **Step 4: Verify it compiles and run manually**

Run: `flutter analyze lib/screens/report_screen.dart`
Expected: `No issues found!`

Run: `flutter run`, reset flags (Task 6), navigate to the Report tab.
Expected: two-step coach mark — stats row, then send buttons.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/report_screen.dart lib/l10n/app_en.arb lib/l10n/app_fr.arb lib/l10n/generated
git commit -m "feat: add first-run coach marks to Report screen"
```

---

## Task 5: Settings screen coach marks + Replay tutorial

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`

**Interfaces:**
- Consumes: `CoachMarkStep`, `showCoachMarkSequence` from `lib/widgets/coach_mark.dart` (Task 1).

- [ ] **Step 1: Add localization strings**

Add to `lib/l10n/app_en.arb`:

```json
  "coachSettingsProfile": "Start here — your name and your disciple maker's contact are how your reports get delivered.",
  "coachSettingsNotifications": "Turn on reminders so you never forget to log your day.",
  "replayTutorialSection": "Tutorial",
  "replayTutorialButton": "Replay app tutorial",
  "replayTutorialDone": "Tutorial will show again next time you visit each screen",
```

Add to `lib/l10n/app_fr.arb`:

```json
  "coachSettingsProfile": "Commencez ici — votre nom et le contact de votre formateur déterminent comment vos rapports sont envoyés.",
  "coachSettingsNotifications": "Activez les rappels pour ne jamais oublier d'enregistrer votre journée.",
  "replayTutorialSection": "Tutoriel",
  "replayTutorialButton": "Revoir le tutoriel de l'application",
  "replayTutorialDone": "Le tutoriel réapparaîtra lors de votre prochaine visite sur chaque écran",
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: no errors.

- [ ] **Step 3: Add GlobalKeys and wire the sequence**

In `lib/screens/settings_screen.dart`, add two key fields to `_SettingsScreenState` (after the `_disciplineIcons` static list, around line 79):

```dart
  final _profileSectionKey = GlobalKey();
  final _notificationsSectionKey = GlobalKey();
```

Add the import (near the top, after `import '../widgets/common_widgets.dart';` at line 19):

```dart
import '../widgets/coach_mark.dart';
```

In `initState` (currently lines 81-85), add the trigger:

```dart
  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowCoachMarks());
  }

  Future<void> _maybeShowCoachMarks() async {
    const flag = 'coachmark_settings_shown';
    final shown = await StorageService.instance.getSetting(flag, fallback: '');
    if (shown == 'true' || !mounted) return;
    final l = S.of(context);
    await showCoachMarkSequence(context, steps: [
      CoachMarkStep(targetKey: _profileSectionKey, caption: l.coachSettingsProfile),
      CoachMarkStep(targetKey: _notificationsSectionKey, caption: l.coachSettingsNotifications),
    ]);
    await StorageService.instance.setSetting(flag, 'true');
  }
```

Attach `_profileSectionKey` to the Profile `SectionCard` (`lib/screens/settings_screen.dart:844`):

```dart
        SectionCard(key: _profileSectionKey, icon: '👤', title: l.profileSection, children: [
```

Attach `_notificationsSectionKey` to the Notifications `SectionCard` (`lib/screens/settings_screen.dart:997`):

```dart
        SectionCard(key: _notificationsSectionKey, icon: '🔔', title: l.notificationsSection, children: [
```

Note: `SectionCard` (defined in `lib/widgets/common_widgets.dart:7-25`) already accepts `key` as its first constructor parameter (`super.key`), so no change to `SectionCard` itself is needed.

- [ ] **Step 4: Add the "Replay tutorial" action**

Add a method to `_SettingsScreenState`:

```dart
  Future<void> _replayTutorial() async {
    final s = StorageService.instance;
    await s.setSetting('coachmark_stopwatch_shown', '');
    await s.setSetting('coachmark_log_shown', '');
    await s.setSetting('coachmark_report_shown', '');
    await s.setSetting('coachmark_settings_shown', '');
    if (mounted) _toast(S.of(context).replayTutorialDone);
  }
```

Add a small section rendering the button. Insert it into the settings `ListView` right before the "── Report Archive ──" `SectionCard` (`lib/screens/settings_screen.dart:1480`):

```dart
        // ── Replay Tutorial ──
        SectionCard(icon: '🎓', title: l.replayTutorialSection, initiallyExpanded: false, children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _replayTutorial,
              icon: Icon(Icons.replay, color: accent),
              label: Text(l.replayTutorialButton, style: TextStyle(color: accent)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: accent.withValues(alpha: 0.3))),
            ),
          ),
        ]),

        // ── Report Archive ──
        SectionCard(icon: '📜', title: l.reportHistorySection, initiallyExpanded: false, children: [
```

(this inserts a new `SectionCard` immediately before the existing Report Archive one — the Report Archive card and everything after it is otherwise unchanged.)

- [ ] **Step 5: Verify it compiles and run manually**

Run: `flutter analyze lib/screens/settings_screen.dart`
Expected: `No issues found!`

Run: `flutter run`, reset flags (Task 6), navigate to the Settings tab.
Expected: two-step coach mark — Profile section, then Notifications section. Then scroll down, find "Tutorial" section, tap "Replay app tutorial", confirm toast appears, navigate to Stopwatch/Log/Report/Settings tabs in turn and confirm every sequence replays.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/settings_screen.dart lib/l10n/app_en.arb lib/l10n/app_fr.arb lib/l10n/generated
git commit -m "feat: add Settings coach marks and Replay tutorial action"
```

---

## Task 6: End-to-end manual verification

**Files:** none (verification only).

- [ ] **Step 1: Reset all coach-mark and onboarding flags**

The fastest reset is a full app data clear (equivalent to a fresh install), since `onboarding_complete` also gates the app's existing onboarding flow and should be exercised too:

Run: `flutter run`, then either uninstall/reinstall the debug build on the device/emulator, or clear app storage via the device settings, or (fastest for iteration) temporarily call in a debug console / add a one-off button:
```dart
await StorageService.instance.setSetting('onboarding_complete', '');
await StorageService.instance.setSetting('coachmark_stopwatch_shown', '');
await StorageService.instance.setSetting('coachmark_log_shown', '');
await StorageService.instance.setSetting('coachmark_report_shown', '');
await StorageService.instance.setSetting('coachmark_settings_shown', '');
```
then hot-restart (not hot-reload — `initState` must re-run from a clean app launch).

- [ ] **Step 2: Walk the full first-run experience**

Expected sequence:
1. Onboarding (Welcome → How It Works → Profile → Language) — unchanged, existing behavior.
2. Land on Stopwatch tab (index 0) — 3-step coach mark appears automatically.
3. Switch to Log tab — 2-step coach mark appears automatically.
4. Switch to Report tab — 2-step coach mark appears automatically.
5. Switch to Settings tab — 2-step coach mark appears automatically.
6. Switch back to Stopwatch — no coach mark (already shown).

- [ ] **Step 3: Verify Skip semantics**

Reset flags again. This time, on the Stopwatch tab's first step, tap "Skip" instead of "Next".
Expected: overlay disappears immediately (steps 2 and 3 never show). Revisit the Stopwatch tab — no coach mark reappears (flag was still written on skip).

- [ ] **Step 4: Verify Replay tutorial**

With all four sequences already shown/skipped, go to Settings → Tutorial → "Replay app tutorial". Confirm toast. Visit all four tabs in turn — every sequence replays from step 1.

- [ ] **Step 5: Verify no crash on rapid navigation**

Reset flags. Rapidly tap between tabs (Stopwatch → Log → Report → Settings → Stopwatch) faster than each coach mark can finish, several times.
Expected: no exceptions in the debug console, no stuck overlays, app remains responsive. (This exercises the "skip step if target unmounted" and "end gracefully if target disappears mid-frame" guards built into `_CoachMarkOverlay` in Task 1.)

- [ ] **Step 6: Verify captions follow the selected language**

Reset flags. In Settings → Language, switch to French (🇫🇷). Replay tutorial (Settings → Tutorial → "Replay app tutorial"). Visit all four tabs in turn.
Expected: every coach-mark caption, the "Suivant"/"Compris"/"Passer" buttons, and the step counter ("1 sur 3" etc.) appear in French — matching whatever the rest of the app's UI shows in French, with no leftover English text anywhere in the overlay. Switch back to English and repeat — confirm captions and buttons revert to English immediately (no stale cached French strings).

- [ ] **Step 7: Final full analyze pass**

Run: `flutter analyze`
Expected: `No issues found!` across the whole project (not just the files touched in this plan).

No commit for this task — it's verification-only. If any step reveals a bug, fix it as a new commit referencing which task's code it corrects, then re-run the failed verification step.

---

## Follow-up (not in this plan)

Spec sections 1, 1a, 2, and 4 (Settings grouping into categories, Notifications → sub-screen split, Log screen Core/More disciplines split, global Help/FAQ screen) remain unimplemented. Once that work lands, the Settings sequence's first step should be retargeted from the Profile `SectionCard` to whatever becomes the new "Profile & Contacts" group header, and a new step can be added pointing at the header `?` help icon once it exists — both are one-line `GlobalKey` swaps in Task 5, not a redesign of the coach-mark system itself.
