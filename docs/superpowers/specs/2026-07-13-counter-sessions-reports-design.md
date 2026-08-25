# Counter Field, Multi-Session Disciplines, RDQD Fix & Factual Reports

**Date:** 2026-07-13
**Status:** Approved

---

## 1. Counter Field Type for Custom Activities

### Problem

Custom activities with the "Counted" template use `CustomFieldType.number`, which renders as a plain text input. The user must type a number manually. Meanwhile, the built-in Proclamation has a rich tap-to-count modal with a big "+" button, live counter display, and integrated stopwatch. Users should be able to create custom counter activities with the same experience.

### Design

**Model change** in `custom_activity.dart`:
- Add `counter` to `CustomFieldType` enum: `text, number, duration, yesNo, notes, counter`

**LogScreen rendering** (inline on the log card):
- When a `counter` field is rendered, show a row with:
  - A "−" button (decrement, min 0)
  - The current count (large, gold text)
  - A "+" button (increment)
- This replaces the plain `GoldField` number input for counter fields
- Tapping +/- calls `_updateCustomField()` and `_persist()` as usual

**StopwatchScreen** (full tap-to-count modal):
- Generalize `_openProclamationCounter()` into a reusable method: `_openCounterModal({icon, title, subtitle, logFieldSetter})`
- Proclamation calls it with its hardcoded icon/title
- Custom activities with a `counter` field also call it with their own icon/name
- The modal saves the accumulated count back to `customActivityData[activityId]['fields'][fieldLabel]`

**Template update**:
- Change the "Counted" quick template from `CustomFieldType.number` to `CustomFieldType.counter`
- Existing activities with `number` fields are unaffected (backward compatible)

**Serialization**: `counter` serializes as the string `"counter"` in `CustomField.toMap()`. Old data with `"number"` fields continues to render as plain text input.

---

## 2. Multi-Session Support for DDEG, Prayer Alone & Prayer With Others

### Problem

Bible reading and Literature support multiple sessions per day (list-based models). But DDEG, Prayer Alone, and Prayer With Others are single-entry string fields. A disciple may have multiple prayer times or DDEG encounters in a day.

### Design

**New model classes** in `daily_log.dart`:

```dart
class DdegSession {
  String scripture;   // passage reference
  String time;        // duration string
  String notes;       // meditation notes
}

class PrayerSession {
  String duration;    // time spent
  String notes;       // for prayer alone: notes; for prayer with others: context/who
}
```

**DailyLog changes**:
- Add: `List<DdegSession> ddegSessions`
- Add: `List<PrayerAloneSession> prayerAloneSessions`
- Add: `List<PrayerOthersSession> prayerOthersSessions`
- Keep existing single-string fields (`ddegScripture`, `ddegTime`, `ddegNotes`, `prayerAloneDuration`, etc.) for backward compatibility
- On `fromMap()`: if the new list column is empty but old string fields have data, auto-migrate into a single-element list
- On `toMap()`: serialize lists as JSON (same pattern as `bibleSessions`)
- `completeness` getter: check `ddegSessions.isNotEmpty` (instead of `ddegScripture.isNotEmpty`)

**DB migration v11**:
- `ALTER TABLE logs ADD COLUMN ddegSessions TEXT DEFAULT ''`
- `ALTER TABLE logs ADD COLUMN prayerAloneSessions TEXT DEFAULT ''`
- `ALTER TABLE logs ADD COLUMN prayerOthersSessions TEXT DEFAULT ''`

**LogScreen UI**:
- Each section shows its sessions as indexed blocks (same pattern as Bible sessions)
- "Add session" button below each section
- Each session block has its own fields (scripture/duration/notes)
- **Daily total** displayed at the section header: sum of all session durations (e.g., "Total: 1h 15m")
- Remove button (×) on each session block (except the last one — always keep at least 1)

**Report output**: List each session on its own line (same as Bible sessions and Literature entries).

---

## 3. Fix DDEG → RDQD in French

### Problem

The French abbreviation for "Rencontre Dynamique Quotidienne avec Dieu" is **RDQD**, but several places in the app still use "DDEG" or the incomplete "RDQ" in French context.

### Fixes

| File | Line | Current | Fix |
|------|------|---------|-----|
| `app_fr.arb` | 218 | `"RDQ — Rencontre avec Dieu :"` | `"RDQD — Rencontre avec Dieu :"` |
| `report_intelligence_service.dart` | 619 | `'ddeg': 'DDEG'` (in French map) | `'ddeg': 'RDQD'` |

No English strings change — "DDEG" is correct in English.

---

## 4. Factual Reports Only (Remove Verdicts)

### Problem

The report sent to the Disciple Maker (DM) currently includes encouraging/judgmental language like "keep pressing on!", "ne vous découragez pas !", "perfect week — glory to God!", "beautiful sacrifice", and trend comparisons ("up 40% from last week"). This usurps the DM's role. The report should state facts only; the DM decides what to say.

### Design

**What to remove from sent reports** (buildFullReport, buildCompactReport, buildMonthlyReport):
- The entire `narrativeSummary` block (Priority 1-8 signals from `buildNarrativeSummary`)
- The milestone block (streak milestones, "praise God!" etc.)
- Trend arrows (↑ ↓ →) from summary lines
- All encouragement phrases from the report text

**What to keep in sent reports**:
- Factual header: name, week/month range
- Day-by-day activity data (what was done, duration, notes)
- Summary stats: active days count, total Bible chapters, total evangelism contacts, average completion %, total consecrated time
- Reading plan progress (factual: "Plan X: day Y of Z, N% complete")
- Report footer

**What stays unchanged**:
- The on-screen `ReportScreen` dashboard (stats, charts, intelligence) — this is for the disciple's own eyes
- The `ReflectionService` — generates the collapsible reflection card on LogScreen, for the disciple only
- The `ReportIntelligenceService` class itself — still used by the dashboard UI

**Implementation**:
- In `report_service.dart`: remove the narrative block, milestone block, and trend arrows from `buildFullReport()`, `buildCompactReport()`, and `buildMonthlyReport()`
- The report becomes a clean factual account of activities performed

---

## Migration & Backward Compatibility

- DB schema version 9 → 11 (v10 already added duration columns; v11 adds session list columns)
- Old single-field data auto-migrates to single-element lists on read
- Old `CustomFieldType.number` fields continue working as plain text inputs
- New `counter` type is additive, no breaking change
- Reports become factual immediately — no migration needed

## Files Changed

| Area | Files |
|------|-------|
| Model | `lib/models/daily_log.dart`, `lib/models/custom_activity.dart` |
| Services | `lib/services/report_service.dart`, `lib/services/report_intelligence_service.dart`, `lib/services/storage_service.dart` |
| Screens | `lib/screens/log_screen.dart`, `lib/screens/stopwatch_screen.dart` |
| L10n | `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb` |
| Tests | `test/storage_service_test.dart`, `test/notification_service_test.dart`, `test/report_service_test.dart` |
