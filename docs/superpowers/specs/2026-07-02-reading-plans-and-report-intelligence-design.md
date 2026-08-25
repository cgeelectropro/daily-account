# Bible Reading Plans & Report Intelligence

**Date:** 2026-07-02
**Status:** Approved
**Scope:** Optional Bible reading plans with gentle daily suggestions + intelligent report narratives, trend signals, and growth milestones

## Problem

### Bible Reading
Users manually type Bible references every day. There is no way to follow a structured reading plan. Many CMFI members want to "read the Bible in 1 year" or follow other schedules, but must track this externally (paper calendars, other apps). The app should optionally support structured plans while keeping free reading as the default.

### Report Intelligence
Weekly reports sent to disciple makers are data dumps — every discipline listed day by day, with summary stats at the bottom. A disciple maker receiving 5 reports on Sunday evening has no quick way to understand: Is this person growing? What changed this week? What needs attention? Reports need a narrative layer that tells the story behind the data.

## Design

### Part 1: Bible Reading Plans

#### Philosophy
- **Default: Free reading.** Nothing changes for users who don't want a plan.
- **Optional: Structured plans.** Activated in Settings. Once active, a gentle suggestion appears on the log screen.
- **Pace-based, not date-locked.** Plans track "Day X of Y readings" — not calendar dates. Miss a day? Pick up where you left off. No guilt, no "days behind" counter.
- **One-tap fill.** The daily suggestion can auto-populate the Bible session with one tap.

#### Data Model

```dart
/// A single day's reading assignment within a plan.
class PlanReading {
  final int dayNumber;        // Day 1, 2, 3... of the plan
  final String startBook;     // English canonical name (locale-independent)
  final int startChapter;
  final String endBook;
  final int endChapter;

  const PlanReading({
    required this.dayNumber,
    required this.startBook,
    required this.startChapter,
    required this.endBook,
    required this.endChapter,
  });
}

/// A Bible reading plan template.
class ReadingPlan {
  final String id;            // e.g. 'bible_1yr', 'nt_90d'
  final String nameEn;
  final String nameFr;
  final String descriptionEn;
  final String descriptionFr;
  final int totalDays;        // Total readings in the plan
  final List<PlanReading> readings;

  String name(String locale) => locale.startsWith('fr') ? nameFr : nameEn;
  String description(String locale) => locale.startsWith('fr') ? descriptionFr : descriptionEn;
}

/// User's active plan state — persisted in SharedPreferences as JSON.
class ActivePlan {
  final String planId;
  final int totalDays;        // Copied from ReadingPlan.totalDays at activation
  final DateTime startedAt;   // When user activated the plan
  int currentDay;             // Next unread reading (1-indexed)
  final Set<int> completedDays; // Which readings are done (day numbers)

  double get progress => completedDays.length / totalDays;
  bool get isComplete => completedDays.length >= totalDays;

  Map<String, dynamic> toJson();
  factory ActivePlan.fromJson(Map<String, dynamic> m);
}
```

#### Built-in Plans (5)

| Plan | ID | Readings | Pace | Audience |
|------|----|----------|------|----------|
| Bible in 1 Year | `bible_1yr` | 365 | ~3-4 chapters/day | Committed readers |
| New Testament in 90 Days | `nt_90d` | 90 | ~3 chapters/day | Intermediate |
| Gospels in 30 Days | `gospels_30d` | 30 | ~3 chapters/day | New believers |
| Psalms & Proverbs in 30 Days | `psalms_prov_30d` | 30 | ~6 chapters/day | Devotional |
| Chronological Bible in 1 Year | `chrono_1yr` | 365 | ~3-4 chapters/day | Deep study |

Plan data is generated from `BibleBooks.all` chapter counts. Each plan is a `List<PlanReading>` computed at build time (not hardcoded per-day — algorithmically divided).

#### Plan Generation Algorithm

For "Bible in 1 Year" (canonical):
1. Total Bible chapters = 1,189
2. Divide into 365 readings of ~3.26 chapters each
3. Walk through books sequentially, accumulating chapters per day
4. Each reading starts where the previous one ended
5. Result: 365 `PlanReading` entries with exact book + chapter ranges

For "NT in 90 Days":
- Same algorithm, but starting at Matthew (order 39) through Revelation (order 65)
- Total NT chapters = 260, divided into 90 readings (~2.9/day)

For "Gospels in 30 Days":
- Matthew through John only (89 chapters total, ~3/day)

For "Psalms & Proverbs in 30 Days":
- Psalms (150) + Proverbs (31) = 181 chapters, ~6/day

For "Chronological":
- Uses a predefined book order based on estimated historical sequence (e.g., Job before Psalms, prophets interspersed with Kings/Chronicles)
- The chronological order is stored as a `List<int>` of book indices in historical sequence
- Same chapter-division algorithm applied to this reordered list

#### UI: Log Screen — Gentle Suggestion

When an active plan exists, a small card appears **above** the Bible section in the log screen:

```
┌─────────────────────────────────────────┐
│ 📖  Today: 2 Kings 4–6  (3 ch.)  [Fill]│
│     Day 142 of 365 · 39% complete       │
└─────────────────────────────────────────┘
```

- **Collapsed by default** — one line: plan name + today's reading + "Fill" chip
- **Tap "Fill"** → auto-creates a Bible session with the plan's start/end reference
- **If user already logged Bible today** → the suggestion shows a checkmark instead of "Fill"
- **If user logged different chapters** → no conflict; plan reading stays as suggestion, user's actual reading is what's saved
- **Tap the card itself** → expands to show: plan name, progress bar, "Day X of Y", percentage

The card uses the same `AppTheme` styling — subtle, not loud. Same visual weight as the reflection card's collapsed state.

#### UI: Plan Selection (Settings)

In Settings, under a new "Bible Reading Plan" section:

- **No active plan** → shows available plans as a list, each with name + description + "Start" button
- **Active plan** → shows current plan with progress bar, "Day X of Y", option to "Pause" or "Reset"
- **Completed plan** → celebration message + option to start another plan
- No separate screen — this is a section within Settings, expandable like other settings sections

#### Persistence

- `activePlan` → SharedPreferences key storing JSON of `ActivePlan`
- When user taps "Fill" → the plan's current day is marked complete, `currentDay` advances
- When user manually logs Bible chapters that match the plan's current assignment → auto-detect and mark complete (fuzzy matching: if they read Genesis 1-3 and the plan says Genesis 1-3, it counts)
- Plan state survives app restart, backup/restore, and cloud sync

#### Integration with Reports

- If a plan is active, the weekly report includes one line: "Bible Reading Plan: Bible in 1 Year — Day 142/365 (39%)"
- Monthly report: "Bible plan progress: 28 readings completed this month"

### Part 2: Report Intelligence

#### Philosophy
- **Reports tell a story, not just list data.**
- **Disciple makers scan, not read.** The most important information comes first.
- **Trends matter more than absolutes.** "Prayer up 40%" is more useful than "Prayer: 3 days."
- **Celebrate growth.** Milestones and personal bests should be visible.
- **Keep it light.** Intelligence is added to existing report formats — no new screens.

#### Layer 1: Narrative Summary

A 2-3 sentence paragraph inserted at the **top** of both full and compact reports, right after the header. Generated by extending `ReportService`.

```
── Week Summary ──
Strong week — 6/7 days logged, Bible reading up 40% from last week
(12 chapters vs. 7). Prayer dropped to 2 days (usually 5). Evangelism
active with 4 contacts. 23-day streak continues.
```

**Generation logic:**

The narrative is built from signals, prioritized:

| Priority | Signal | Example output |
|----------|--------|----------------|
| 1 | Streak milestone this week (7, 30, 100) | "Reached a 30-day streak this week!" |
| 2 | Perfect week (7/7) | "Perfect week — every day logged." |
| 3 | Days logged vs. last week | "Strong week with 6/7 days" or "Lighter week: 3/7 days (down from 5)" |
| 4 | Biggest discipline change (up) | "Bible reading up 40% from last week" |
| 5 | Biggest discipline change (down) | "Prayer dropped to 2 days (usually 5)" |
| 6 | Notable activity | "4 evangelism contacts" or "Active fasting this week" |
| 7 | Streak status | "23-day streak continues" or "Streak reset after 12 days" |
| 8 | Plan progress (if active) | "Bible plan: 39% complete" |

The narrative picks the top 3-4 signals and combines them into natural prose. Both EN and FR versions generated.

#### Layer 2: Trend Signals

Small indicators added to the **day-by-day** section of full reports and to the **summary stats** section:

**In text reports:**
```
📖 Bible: 12 chapters ↑ (7 last week)
🙏 Prayer: 2 days ↓ (5 last week)  
📢 Evangelism: 4 contacts → (4 last week)
```

**Arrows:** `↑` (improved ≥20%), `↓` (declined ≥20%), `→` (steady)

**In PDF reports:** Same arrows with color coding (green ↑, red ↓, gray →)

**Calculation:** Compare this week's discipline stats to the average of the previous 4 weeks. This smooths out single-week anomalies.

#### Layer 3: Growth Milestones

Milestones appear in the report when earned **this week**. They are calculated from cumulative data.

| Milestone | Condition | Report text |
|-----------|-----------|-------------|
| Chapter milestone | Total chapters reaches 100, 250, 500, 1000 | "📖 Milestone: 500th Bible chapter read!" |
| Streak record | Current streak exceeds all-time personal best | "🔥 New personal record: 45-day streak!" |
| Perfect week | All 7 days logged with ≥70% completeness | "⭐ Perfect week achieved!" |
| Consistency milestone | 4 consecutive weeks with ≥5 days logged | "🏆 1 month of consistent accountability!" |
| Evangelism milestone | Cumulative contacts reaches 50, 100, 250 | "📢 100 souls reached since you started!" |
| First plan completion | Finished a Bible reading plan | "📖 Completed: Bible in 1 Year!" |

**In text reports:** Milestones appear as a short section after the narrative summary.

**In compact/WhatsApp reports:** One-line mention only (e.g., "🏆 500th chapter milestone!")

**In PDF reports:** Gold badge icon in the summary section.

**Storage:** Milestone events stored in SharedPreferences with dateKey to avoid re-announcing. Key pattern: `milestone_{type}_{value}` → `'true'`.

#### Cumulative Stats Computation

New method in `ReportService`:

```dart
Future<CumulativeStats> computeAllTimeStats() async {
  // Query all logs ever
  // Sum: total chapters, total evangelism contacts, total days logged
  // Find: longest streak ever, total prayer minutes, total literature items
  // Return structured result for milestone checking
}
```

This is called once per report generation (not on every persist).

### Files to Create/Modify

| File | Change |
|------|--------|
| `lib/data/reading_plans.dart` | **New** — `PlanReading`, `ReadingPlan`, `ActivePlan` classes, 5 built-in plans with generation algorithms |
| `lib/services/reading_plan_service.dart` | **New** — `ReadingPlanService` singleton: activate/pause/reset plan, get today's reading, mark complete, fuzzy match detection |
| `lib/services/report_service.dart` | **Modify** — Add `buildNarrativeSummary()`, `computeTrendSignals()`, `computeAllTimeStats()`, `checkMilestones()`. Integrate into `buildFullReport()` and `buildCompactReport()` |
| `lib/services/pdf_report_service.dart` | **Modify** — Add narrative summary section, trend arrows, milestone badges to PDF |
| `lib/screens/log_screen.dart` | **Modify** — Add plan suggestion card above Bible section |
| `lib/screens/settings_screen.dart` | **Modify** — Add "Bible Reading Plan" section |
| `lib/screens/report_screen.dart` | **Modify** — Display narrative summary in the report preview UI |
| `lib/l10n/app_en.arb` | **Modify** — Add ARB keys for plans, narrative templates, trend labels, milestone texts |
| `lib/l10n/app_fr.arb` | **Modify** — French translations |

### Verification

- Free reading still works exactly as before (no plan active)
- Plan suggestion appears only when a plan is active
- Tapping "Fill" creates correct Bible session with right references
- Plan progress persists across app restart
- Marking a reading complete advances the plan
- Narrative summary appears at top of weekly report
- Trend arrows are accurate (compared to 4-week rolling average)
- Milestones fire only once (not re-announced)
- French locale shows French plan names, narrative, and milestone text
- `flutter analyze` passes clean
