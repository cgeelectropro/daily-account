# Activity Enhancements Design Spec

**Date:** 2026-06-30
**Scope:** 4 features — Evangelism labels, Time-conscious mode, Custom activity builder, Notification actions

---

## Feature 1: Evangelism Label Rename

**Type:** UI-only change. No model or DB migration.

### Field Mapping

| Internal field | Old label | New label |
|---|---|---|
| `evangelismContacts` | "Number of Contacts" | "Gospel tracts distributed" |
| `evangelismOutcome` | "Outcome" | "People reached by the gospel" |
| `evangelismNewBelievers` | "New Believers" | "Those who accepted Jesus" |
| `evangelismBeingDiscipled` | "Being Discipled" | unchanged |
| `evangelismNotes` | "Notes" | unchanged |
| `evangelismFollowUpNotes` | "Follow-Up Notes" | unchanged |

### Input Type Changes

- `evangelismContacts`: already numeric — no change
- `evangelismOutcome`: change from free-text to **numeric** keyboard (it's now a count)
- `evangelismNewBelievers`: already numeric — no change

### Report Text Changes

- Full report evangelism line: `"Tracts: X | Reached: X | Accepted Jesus: X"`
- Compact report: same condensed format
- Stats computation: variable names unchanged, display labels updated

### Files Changed

- `lib/screens/log_screen.dart` — label strings in evangelism SectionCard
- `lib/services/report_service.dart` — evangelism report text in full/compact/monthly reports

---

## Feature 2: Time-Conscious Mode

**Type:** New setting + model fields + DB migration + UI + report changes.

### Settings

- New toggle: **"Time-conscious mode"** in Settings screen
- SharedPreferences key: `timeConscious` (bool, default `false`)
- Description: "Track how much time you consecrate to each spiritual activity"

### Activities Affected

| Section | Already has duration? | New field when toggle ON |
|---|---|---|
| Bible Reading | No | `bibleDuration` |
| Literature | No | `literatureDuration` |
| Evangelism | No | `evangelismDuration` |
| Giving & Tithes | No | `givingDuration` |
| Church & Fellowship | No | `churchDuration` |
| DDEG | Yes (`ddegTime`) | — |
| Prayer (Alone) | Yes (`prayerAloneDuration`) | — |
| Prayer (Others) | Yes (`prayerOthersDuration`) | — |
| Discipleship | Yes (`discipleshipDuration`) | — |
| Proclamation | Yes (`proclamationDuration`) | — |
| Fasting | Has `fastingDuration` but it's days, not time | — (keep as-is, fasting duration is contextually different) |

### DailyLog Model Changes

Add 5 new `String` fields with empty defaults:
- `bibleDuration`
- `literatureDuration`
- `evangelismDuration`
- `churchDuration`
- `givingDuration`

### DB Migration (v10)

```sql
ALTER TABLE logs ADD COLUMN bibleDuration TEXT DEFAULT '';
ALTER TABLE logs ADD COLUMN literatureDuration TEXT DEFAULT '';
ALTER TABLE logs ADD COLUMN evangelismDuration TEXT DEFAULT '';
ALTER TABLE logs ADD COLUMN churchDuration TEXT DEFAULT '';
ALTER TABLE logs ADD COLUMN givingDuration TEXT DEFAULT '';
ALTER TABLE logs ADD COLUMN custom_activity_data TEXT DEFAULT '';
```

Note: `custom_activity_data` is included here for Feature 3 (single migration).

### LogScreen Behavior

- On build, read `timeConscious` from SharedPreferences
- If ON, inject a duration GoldField (with clock icon, "Duration" hint) at the bottom of each section that doesn't already have a duration field
- The duration field is editable manually OR auto-filled by the stopwatch

### Stopwatch Integration

- Extend the timer service activity-to-field mapping to include the 5 new duration fields
- When stopwatch stops for Bible Reading, write to `bibleDuration`; for Literature, to `literatureDuration`; etc.

### Report Aggregation

- New summary line in report header: **"Total time consecrated: Xh Ym"**
- Parse all duration fields (existing + new), sum total minutes
- Display in both full and compact reports
- Only shown when time-conscious mode is on OR when any duration field has data

### Files Changed

- `lib/models/daily_log.dart` — 5 new fields, toMap/fromMap
- `lib/services/storage_service.dart` — migration v10
- `lib/screens/log_screen.dart` — conditional duration fields
- `lib/screens/settings_screen.dart` — toggle
- `lib/services/timer_service.dart` — extended field mapping
- `lib/services/report_service.dart` — total time aggregation

---

## Feature 3: Custom Activity Builder

**Type:** Enhanced model + new UI + DB column + report integration.

### CustomActivity Model (revised)

```dart
class CustomActivity {
  String id;           // UUID, generated at creation
  String name;         // User-defined name
  String icon;         // Emoji
  List<CustomField> fields;  // Replaces old single fieldLabels
  bool countsForCompleteness; // Whether it counts toward progress ring
}

class CustomField {
  String label;        // Field display name
  CustomFieldType type; // text, number, duration, yesNo, notes
}

enum CustomFieldType { text, number, duration, yesNo, notes }
```

### Creation UI — Full Modal

When user taps "Add Activity" (in log_screen or stopwatch_screen), a modal opens with:

1. **Activity Name** — required text field
2. **Icon** — emoji selector, default ✨
3. **Quick Templates** — tappable chips at top:
   - "Simple" → no fields (just done/not-done toggle)
   - "Timed" → duration + notes
   - "Counted" → count (number) + notes
   - "Full" → duration + count + person (text) + notes
   Tapping a template pre-populates the fields list below.
4. **Custom Fields** — scrollable list:
   - Each row: label (text input) + type (dropdown) + delete (icon button)
   - "Add Field" button at bottom
   - Max 8 fields per activity
5. **Counts for progress** — toggle switch, default ON

### Data Storage

**Activity definitions:** SharedPreferences as JSON array (via StorageService). Updated serialization for new `CustomField` model.

**Activity log data per day:** New TEXT column `custom_activity_data` in logs table (added in migration v10 alongside Feature 2 columns).

JSON structure:
```json
{
  "activity_id_1": {
    "done": true,
    "fields": {
      "Duration": "30 minutes",
      "Notes": "Great session"
    }
  },
  "activity_id_2": {
    "done": false,
    "fields": {}
  }
}
```

### DailyLog Model Changes

- Add `Map<String, Map<String, dynamic>> customActivityData` field
- `toMap()`: JSON-encode to string for DB
- `fromMap()`: JSON-decode with fallback to empty map

### LogScreen Rendering

Each custom activity renders as its own SectionCard:
- Header: icon + name
- Toggle: done/not-done (always present)
- Fields rendered by type:
  - `text` → single-line GoldField
  - `number` → GoldField with numeric keyboard
  - `duration` → GoldField with clock icon (auto-filled by stopwatch)
  - `yesNo` → Switch widget
  - `notes` → multi-line GoldField (maxLines: 3)
- When time-conscious mode is ON and activity has no duration field, one is appended automatically

### Completeness Calculation

- `DailyLog.completeness` updated to include custom activities where `countsForCompleteness == true`
- An activity is "done" if its `done` flag is true in `customActivityData`
- Total sections = 11 built-in + N custom activities (where countsForCompleteness)

### Report Integration

Custom activities appear after built-in activities:
```
📌 Worship: Duration: 45min, Notes: Praise and adoration session
📌 Fasting Prayer: Count: 3, Person: Brother James, Notes: Intercession
```

All field values are shown. Duration fields included in total time aggregation.

### Stopwatch Integration

- Custom activities in the stopwatch grid (already exist)
- When stopped, duration writes to the activity's duration field in `customActivityData` instead of the generic `other` field
- Activity key format: `custom_<id>`

### Migration of Existing Custom Activity Data

- Existing custom activities with the old `fieldLabels: List<String>` format are auto-migrated to the new `fields: List<CustomField>` format on first load
- Each old field label becomes a `CustomField` with type `text`
- Existing `other` field data for custom activities is not migrated (it was unstructured semicolon-separated text)

### Files Changed

- `lib/models/custom_activity.dart` — new model with CustomField, CustomFieldType
- `lib/models/daily_log.dart` — customActivityData field, serialization, completeness
- `lib/services/storage_service.dart` — migration, updated custom activity CRUD
- `lib/screens/log_screen.dart` — custom activity SectionCards, creation modal
- `lib/screens/stopwatch_screen.dart` — creation modal (shared), duration write target
- `lib/services/timer_service.dart` — custom activity duration mapping
- `lib/services/report_service.dart` — custom activity in reports

---

## Feature 4: Notification Action Buttons + Cancel

**Type:** Notification fix + new actions + smart navigation.

### Problem

Notification action buttons (Pause/Stop) exist in code but don't render visibly. Likely because `Importance.low` suppresses action display on many Android devices.

### Fix: Notification Visibility

- Raise importance from `Importance.low` to `Importance.defaultImportance`
- Keep `playSound: false` and `enableVibration: false` (non-intrusive)
- Use `BigTextStyle` so notification expands by default
- Body text: "In progress — 12:34" (running) / "Paused — 12:34" (paused)

### Action Buttons

| State | Button 1 | Button 2 | Button 3 |
|-------|----------|----------|----------|
| Running | ⏸ Pause | ⏹ Stop | ✕ Cancel |
| Paused | ▶ Resume | ⏹ Stop | ✕ Cancel |

### Action Behaviors

**Pause** (`timer_pause`):
- Pauses timer, updates notification to show Resume button
- `showsUserInterface: false`

**Resume** (`timer_resume`):
- Resumes timer, updates notification to show Pause button
- `showsUserInterface: false`
- Internally same toggle as pause

**Stop** (`timer_stop`):
- Saves elapsed time to the appropriate log field
- **Bible Reading:** `showsUserInterface: true` → opens app, navigates to log screen (Bible section) so user can enter ending reference
- **All other activities:** `showsUserInterface: false` → stops silently, dismisses notification
- Activity type passed via notification payload

**Cancel** (`timer_cancel`):
- If elapsed < 10 seconds: cancel immediately, discard time, dismiss notification
- If elapsed >= 10 seconds: `showsUserInterface: true` → opens app, shows confirmation dialog: "Discard Xm Ys of [Activity Name]?" with "Discard" / "Keep timing" buttons
- On discard: reset timer without saving, dismiss notification
- On keep timing: resume timer as if nothing happened

### Stopwatch Screen UI Changes

- Add **Cancel** button (X icon, gray) alongside existing Pause/Stop buttons
- Same confirmation logic: < 10s immediate, >= 10s shows dialog
- Button layout: `[Cancel] [Pause/Resume] [Stop]`

### Timer Service Changes

- New `cancelTimer()` method: resets state without writing to log
- Handle `timer_resume` action ID (maps to existing pause toggle)
- Handle `timer_cancel` action ID
- Pass activity key in notification payload for smart Stop routing

### Navigation on Stop (Bible Reading)

- Notification response handler checks payload for activity type
- If Bible Reading: calls `onNotificationTap` with payload `"stopwatch_bible"`
- `HomeShell` handles this payload: switches to log tab, scrolls to Bible section
- A brief highlight animation on the Bible section draws attention

### Files Changed

- `lib/services/notification_service.dart` — importance, style, 3 action buttons, cancel action
- `lib/services/timer_service.dart` — cancelTimer(), resume handler, payload passing
- `lib/screens/stopwatch_screen.dart` — cancel button UI, confirmation dialog
- `lib/screens/home_shell.dart` — handle stopwatch_bible navigation payload

---

## DB Migration Summary (v10)

All schema changes in a single migration:

```sql
-- Feature 2: Time-conscious duration fields
ALTER TABLE logs ADD COLUMN bibleDuration TEXT DEFAULT '';
ALTER TABLE logs ADD COLUMN literatureDuration TEXT DEFAULT '';
ALTER TABLE logs ADD COLUMN evangelismDuration TEXT DEFAULT '';
ALTER TABLE logs ADD COLUMN churchDuration TEXT DEFAULT '';
ALTER TABLE logs ADD COLUMN givingDuration TEXT DEFAULT '';

-- Feature 3: Custom activity log data
ALTER TABLE logs ADD COLUMN custom_activity_data TEXT DEFAULT '';
```

Wrapped in a transaction for safety (per existing pattern).
