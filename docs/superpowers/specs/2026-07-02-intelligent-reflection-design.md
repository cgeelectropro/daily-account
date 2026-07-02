# Intelligent Daily Reflection Engine

**Date:** 2026-07-02
**Status:** Approved
**Scope:** Rule-based offline reflection engine with provider interface for future AI integration

## Problem

The current reflection card in the log screen shows 3 static template strings based on discipline count (great/good/start) plus 4 hardcoded focus tips. Every user with the same number of filled disciplines sees the same message. There is no awareness of history, content, trends, time, or spiritual growth patterns.

## Design

### Provider Architecture

A `ReflectionService` singleton with a pluggable provider interface. The service accepts a `DailyLog` plus historical context and returns a structured `ReflectionResult`. Today ships with `RuleBasedReflectionProvider`; a future `AiReflectionProvider` can replace it without touching the UI.

```
ReflectionService.instance.generate(log, context) → ReflectionResult
  ├── RuleBasedReflectionProvider  (offline, ships now)
  └── AiReflectionProvider         (future — Gemini/Claude API)
```

The caller (log screen) calls `ReflectionService` and receives a `ReflectionResult`. It does not know which provider is active.

### Data Model

```dart
/// The output of the reflection engine.
class ReflectionResult {
  final String narrative;       // Growth paragraph
  final String encouragement;   // Specific praise for what was done
  final String suggestion;      // Tomorrow's focus / actionable next step
  final String? verse;          // Scripture text
  final String? verseReference; // e.g. "Psalm 119:105"

  String toJson();              // Serialize for caching in DailyLog.aiReflection
  factory ReflectionResult.fromJson(String json);
}

/// Historical context passed to the provider alongside today's log.
class ReflectionContext {
  final int streak;                        // Current consecutive-day streak
  final int weekDaysFilled;                // How many days logged this week so far
  final double weeklyAvgCompletion;        // Average completeness this week (0.0–1.0)
  final Map<String, double> disciplineRates; // Per-discipline consistency this week (0.0–1.0)
  final Map<String, double> monthRates;    // Per-discipline consistency last 30 days
  final String? bestDiscipline;            // Strongest this week
  final String? weakDiscipline;            // Weakest this week
  final int totalBibleChaptersThisWeek;
  final int totalEvangelismContactsThisWeek;
  final int totalPrayerMinutesThisWeek;
  final TimeOfDay timeOfDay;               // Current time for morning/evening awareness
}
```

### Provider Interface

```dart
abstract class ReflectionProvider {
  Future<ReflectionResult> generate(DailyLog log, ReflectionContext ctx, String locale);
}
```

The `ReflectionService` holds a `ReflectionProvider` field. Default is `RuleBasedReflectionProvider`. Settings screen or app init can swap it in the future.

### Rule Engine Logic

The `RuleBasedReflectionProvider` analyzes the log and context to build each paragraph independently, then combines them.

#### Input Signals

1. **Today's log** — which of 11 disciplines are filled, with content details (Bible reference, prayer notes, DDEG notes/scripture, evangelism contacts, durations, literature titles)
2. **ReflectionContext** — streak, weekly/monthly rates, best/weak disciplines, totals
3. **Time of day** — before noon = morning, after 6pm = evening, else = daytime
4. **Filled count** — number of disciplines completed today (0–11)

#### Narrative Generation (paragraph 1)

Selects ONE narrative template based on priority:

| Priority | Condition | Example |
|----------|-----------|---------|
| 1 | Streak ≥ 30 | "Day {n} of unbroken faithfulness — you are building something eternal." |
| 2 | Streak ≥ 7 | "A full week of consistency! {n} days and counting." |
| 3 | Comeback (streak=1, yesterday missed) | "Welcome back. Every new day is a fresh start with God." |
| 4 | Filled ≥ 9 (today) | "An extraordinary day — {n} disciplines covered. You're walking in fullness." |
| 5 | Filled ≥ 6 | "Solid day with {n} disciplines. Your consistency is growing." |
| 6 | Filled ≥ 3 | "You've started well with {n} disciplines. There's still time to add more." |
| 7 | Filled ≥ 1 | "Every step matters. You've taken {n} today — keep going." |
| 8 | Morning, nothing yet | "Good morning! A blank page awaits your faithfulness today." |
| 9 | Evening, nothing yet | "The day isn't over yet. Even one discipline logged is a seed planted." |
| 10 | Default | "Open your heart to today's disciplines. Start with one." |

Each condition has 3-4 template variations; one is picked randomly (seeded by dateKey for stability within a day, but varying day to day).

Additional narrative modifiers (appended as a second sentence):
- If today's filled count > weekly average: "That's above your weekly average — you're pushing higher."
- If a discipline is done today that hasn't been done all week: "First time this week for {discipline} — well done breaking new ground."
- If all 11 filled: "A perfect day. Every discipline touched. This is the altar fully ablaze."

#### Encouragement Generation (paragraph 2)

Content-aware praise. Scans today's log for the richest signal and generates specific encouragement:

| Signal | Condition | Example |
|--------|-----------|---------|
| Bible content | `bibleReference` or `bibleSessions` non-empty | "Reading {reference} today — the {testament} is rich ground for growth." |
| Bible chapters | `totalBibleChapters ≥ 5` | "{n} chapters today — you're devouring the Word!" |
| DDEG depth | `ddegNotes` length > 50 chars | "Your DDEG notes show deep reflection. God speaks to those who listen." |
| Prayer duration | parsed minutes ≥ 30 | "{duration} in prayer — that's {comparison} your weekly average." |
| Evangelism contacts | contacts ≥ 2 | "{n} souls reached today. The harvest field is responding." |
| Fasting active | `fastingType` non-empty | "Fasting today — denying the flesh to feed the spirit." |
| Literature | titles present | "Reading '{title}' — feeding your mind alongside your spirit." |
| Discipleship | `discipleshipWho` non-empty | "Pouring into {who} — multiplication is the heart of CMFI." |
| Proclamation | count ≥ 3 | "{n} proclamations today — declaring God's promises with boldness." |
| Duration total | all durations > 60min combined | "Over an hour of consecrated time today. That's devotion." |

If multiple signals are strong, the top 2 are combined: "{encouragement1} And {encouragement2}"

If no strong signal (all minimal), use a general encouragement: "Every discipline you touch, however briefly, is a seed planted in good soil."

#### Suggestion Generation (paragraph 3)

Identifies the most impactful next action:

| Priority | Condition | Example |
|----------|-----------|---------|
| 1 | User's weakest discipline (from monthRates) is missing today | "Your {discipline} has been quiet lately — even a small step today would build momentum." |
| 2 | A discipline done 0 times this week and missing today | "You haven't touched {discipline} this week. Today could be the day." |
| 3 | Filled < 6 and it's before 6pm | "You still have time — try adding {next_missing} before the day ends." |
| 4 | Filled ≥ 9 but not 11 | "You're so close to a perfect day! Just {missing} left." |
| 5 | All 11 filled | "All disciplines covered! Tomorrow, try going deeper in {weakest_this_week}." |
| 6 | Morning, nothing yet | "Start with {user's strongest discipline} — build momentum from strength." |

#### Verse Selection

A curated library of ~60 verses organized by tag. Each verse has EN and FR text.

Tags and verse counts:
- `bible` (5): Verses about the Word (Ps 119:105, Josh 1:8, 2Tim 3:16, Heb 4:12, Ps 1:2)
- `prayer` (5): Verses about prayer (Phil 4:6, 1Thess 5:17, Matt 7:7, Jer 33:3, Ps 145:18)
- `evangelism` (5): Verses about witnessing (Matt 28:19, Rom 10:14, Acts 1:8, Mark 16:15, Prov 11:30)
- `fasting` (4): (Isa 58:6, Matt 6:17-18, Joel 2:12, Acts 13:2-3)
- `giving` (4): (2Cor 9:7, Prov 3:9, Mal 3:10, Luke 6:38)
- `church` (4): (Heb 10:25, Acts 2:42, Ps 133:1, Matt 18:20)
- `discipleship` (4): (2Tim 2:2, Matt 28:19-20, Prov 27:17, Col 3:16)
- `literature` (3): (Prov 4:7, Prov 18:15, 2Tim 2:15)
- `ddeg` (3): (Ps 46:10, Jer 29:13, John 10:27)
- `proclamation` (3): (Rom 10:9-10, Ps 107:2, Rev 12:11)
- `streak` (4): (Gal 6:9, 1Cor 15:58, Heb 12:1, Phil 3:14)
- `comeback` (3): (Lam 3:22-23, Mic 7:8, Ps 37:24)
- `balanced` (3): (Col 3:17, Eccl 3:1, 1Cor 10:31)
- `morning` (3): (Ps 5:3, Lam 3:22-23, Ps 143:8)
- `evening` (3): (Ps 4:8, Ps 63:6, Ps 119:148)

Selection logic:
1. If a discipline is the strongest signal today → pick from that discipline's tag
2. If streak ≥ 7 → pick from `streak`
3. If comeback day → pick from `comeback`
4. If all disciplines balanced → pick from `balanced`
5. Morning/evening fallback → pick from time-of-day tag
6. Random selection within the chosen tag, seeded by dateKey

### UI — Collapsible Rich Card

Replaces the current `_buildReflectionCard` in log_screen.dart.

**Collapsed state:**
- Gold-gradient border card
- ✨ icon + first sentence of narrative (truncated with "...")
- Tap-to-expand chevron

**Expanded state:**
- Full narrative paragraph
- Encouragement paragraph (slightly different styling — italic or indented)
- Suggestion paragraph with a subtle action-oriented style
- Scripture verse in a highlighted quote block with reference
- Smooth expand/collapse animation (200ms)

**Live updates:**
- The reflection regenerates when `_persist()` is called (debounced with a 2-second `Timer` to avoid regenerating on every keystroke)
- Result is cached in `_log.aiReflection` as JSON
- When revisiting a past day, the cached reflection is shown (not regenerated)

### Localization

All template strings go through ARB keys. Estimated ~80-100 new keys per language.

Template keys use a naming pattern: `reflect_{section}_{condition}_{variant}` e.g.:
- `reflectNarrativeStreak30_1`, `reflectNarrativeStreak30_2`
- `reflectEncourageBibleDeep_1`
- `reflectSuggestWeakest`
- `reflectVersePs119_105`

### Files to Create/Modify

| File | Change |
|------|--------|
| `lib/services/reflection_service.dart` | **New** — ReflectionService, ReflectionProvider interface, RuleBasedReflectionProvider, ReflectionResult, ReflectionContext |
| `lib/data/scripture_library.dart` | **New** — ScriptureVerse class, curated verse library with EN/FR text and tags |
| `lib/screens/log_screen.dart` | Replace `_buildReflectionCard` with collapsible card, add debounced regeneration |
| `lib/l10n/app_en.arb` | ~80-100 new reflection template keys |
| `lib/l10n/app_fr.arb` | French translations |

### Future AI Integration Path

When an AI provider is added:
1. Create `AiReflectionProvider implements ReflectionProvider`
2. It serializes `DailyLog` + `ReflectionContext` into a prompt
3. Calls Gemini/Claude API
4. Parses the response into `ReflectionResult`
5. Settings screen adds a toggle: "Use AI Reflection (requires internet)"
6. `ReflectionService` swaps provider based on setting
7. Falls back to `RuleBasedReflectionProvider` if API call fails

No UI changes needed. No log_screen changes needed. Just a new provider + a settings toggle.

### Verification

- Reflection updates live as disciplines are filled
- Collapsed/expanded toggle works smoothly
- Past days show cached reflection (not regenerated)
- French locale shows French templates and French verse text
- Verse is relevant to today's activity pattern
- Streak, comeback, and time-of-day awareness work correctly
- `flutter analyze` passes clean
