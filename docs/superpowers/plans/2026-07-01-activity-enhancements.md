# Activity Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 4 features — evangelism label rename, time-conscious mode, custom activity builder, and notification action buttons with cancel.

**Architecture:** All changes follow the existing singleton service pattern. Features 2 and 3 share a single DB migration (v10). The localization layer (ARB files + generated code) handles all user-facing strings. Timer and notification services are extended, not replaced.

**Tech Stack:** Flutter/Dart, SQLite (sqflite), SharedPreferences, flutter_local_notifications, flutter_animate, google_fonts

## Global Constraints

- DB version bumps from 9 → 10
- All migrations wrapped in `db.transaction()` (existing pattern)
- Labels go through ARB localization files (`app_en.arb`, `app_fr.arb`) then `flutter gen-l10n`
- No new dependencies — everything uses existing packages
- Existing field variable names (`evangelismContacts`, etc.) are NOT renamed — only UI labels change
- Auto-persist pattern: every field change calls `_persist()` (debounced 500ms)

---

### Task 1: Evangelism Label Rename (ARB + LogScreen + Reports)

**Files:**
- Modify: `lib/l10n/app_en.arb:62-67, 575-581`
- Modify: `lib/l10n/app_fr.arb:62-67, 575-581`
- Modify: `lib/screens/log_screen.dart:789-793`
- Modify: `lib/services/report_service.dart:430-441`
- Regenerate: `lib/l10n/generated/*` (via `flutter gen-l10n`)

**Interfaces:**
- Consumes: existing `DailyLog` model fields (unchanged)
- Produces: updated localized label strings used by log_screen and report_service

- [ ] **Step 1: Update English ARB labels**

In `lib/l10n/app_en.arb`, change these entries:

```json
"evangelismContactsLabel": "Gospel tracts distributed",
"evangelismContactsHint": "e.g. 5",
"evangelismOutcomeLabel": "People reached by the gospel",
"evangelismOutcomeHint": "e.g. 3",
"evangelismNewBelievers": "Those who accepted Jesus",
"evangelismNewBelieversHint": "Number who accepted Christ in their hearts",
```

- [ ] **Step 2: Update French ARB labels**

In `lib/l10n/app_fr.arb`, change these entries:

```json
"evangelismContactsLabel": "Tracts d'évangile distribués",
"evangelismContactsHint": "ex. 5",
"evangelismOutcomeLabel": "Personnes atteintes par l'évangile",
"evangelismOutcomeHint": "ex. 3",
"evangelismNewBelievers": "Ceux qui ont accepté Jésus",
"evangelismNewBelieversHint": "Nombre de personnes qui ont accepté Christ dans leur cœur",
```

- [ ] **Step 3: Regenerate l10n**

Run: `flutter gen-l10n`
Expected: generated files updated in `lib/l10n/generated/`

- [ ] **Step 4: Make evangelismOutcome field numeric in log_screen**

In `lib/screens/log_screen.dart`, the GoldField for `evangelismOutcome` (around line 789-793) currently has no `keyboardType`. Add `keyboardType: TextInputType.number`:

```dart
GoldField(
  label: t.evangelismOutcomeLabel,
  hint: t.evangelismOutcomeHint,
  value: _log.evangelismOutcome,
  keyboardType: TextInputType.number,
  onChanged: (v) { _log.evangelismOutcome = v; _persist(); },
),
```

- [ ] **Step 5: Update report evangelism text in report_service**

In `lib/services/report_service.dart`, the evangelism section in the full report (around line 430-441) uses localization methods. Find the `reportEvangelism` method references and update them. The localization keys (`reportEvangelism`, `evangelismNewBelievers`, `evangelismBeingDiscipled`) already pull from the ARB files, so the label changes in steps 1-2 will propagate automatically through the `S` class.

Verify by searching for any hardcoded evangelism strings in report_service.dart that bypass localization. If any exist, replace them with the `l.` localized equivalents.

- [ ] **Step 6: Verify with flutter analyze**

Run: `flutter analyze`
Expected: no new errors

- [ ] **Step 7: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_fr.arb lib/l10n/generated/ lib/screens/log_screen.dart lib/services/report_service.dart
git commit -m "feat: rename evangelism labels to gospel tracts/reached/accepted Jesus"
```

---

### Task 2: DB Migration v10 + DailyLog Model Fields

**Files:**
- Modify: `lib/models/daily_log.dart:117-123, 159-196, 218-254, 275-332, 200-216`
- Modify: `lib/services/storage_service.dart:28-30, 31-70, 75-144`
- Modify: `lib/models/custom_activity.dart` (full rewrite)

**Interfaces:**
- Consumes: nothing new
- Produces:
  - `DailyLog.bibleDuration`, `.literatureDuration`, `.evangelismDuration`, `.churchDuration`, `.givingDuration` (String fields)
  - `DailyLog.customActivityData` (Map<String, Map<String, dynamic>>)
  - `CustomActivity.fields` (List<CustomField>), `.countsForCompleteness` (bool)
  - `CustomField` class with `label` (String) and `type` (CustomFieldType enum)
  - `CustomFieldType` enum: `text, number, duration, yesNo, notes`
  - DB version 10 with 6 new columns

- [ ] **Step 1: Rewrite custom_activity.dart with new model**

Replace the entire contents of `lib/models/custom_activity.dart`:

```dart
import 'dart:convert';

/// Field types available for custom activities.
enum CustomFieldType { text, number, duration, yesNo, notes }

/// A single configurable field within a custom activity.
class CustomField {
  String label;
  CustomFieldType type;

  CustomField({required this.label, this.type = CustomFieldType.text});

  Map<String, dynamic> toMap() => {
        'label': label,
        'type': type.name,
      };

  factory CustomField.fromMap(Map<String, dynamic> m) => CustomField(
        label: m['label'] as String,
        type: CustomFieldType.values.byName(
          m['type'] as String? ?? 'text',
        ),
      );
}

/// A user-defined spiritual activity for stopwatch tracking.
class CustomActivity {
  final String id;
  String name;
  String icon;
  List<CustomField> fields;
  bool countsForCompleteness;

  CustomActivity({
    required this.id,
    required this.name,
    this.icon = '\u2728',
    List<CustomField>? fields,
    this.countsForCompleteness = true,
  }) : fields = fields ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'fields': fields.map((f) => f.toMap()).toList(),
        'countsForCompleteness': countsForCompleteness,
      };

  factory CustomActivity.fromMap(Map<String, dynamic> m) {
    // Migrate old fieldLabels format to new fields format
    List<CustomField> fields;
    if (m.containsKey('fields') && m['fields'] is List) {
      fields = (m['fields'] as List)
          .map((f) => f is Map<String, dynamic>
              ? CustomField.fromMap(f)
              : CustomField(label: f.toString()))
          .toList();
    } else if (m.containsKey('fieldLabels') && m['fieldLabels'] is List) {
      fields = (m['fieldLabels'] as List)
          .cast<String>()
          .map((l) => CustomField(label: l))
          .toList();
    } else {
      fields = [];
    }

    return CustomActivity(
      id: m['id'] as String,
      name: m['name'] as String,
      icon: m['icon'] as String? ?? '\u2728',
      fields: fields,
      countsForCompleteness: m['countsForCompleteness'] as bool? ?? true,
    );
  }
}
```

- [ ] **Step 2: Add new fields to DailyLog model**

In `lib/models/daily_log.dart`, add after line 123 (after `evangelismFollowUpNotes`... before `// Other`):

No — add the 5 duration fields after line 126 (`String other;`), grouped logically. And add `customActivityData` as a new Map field.

Add these field declarations after `String other;` (line 126):

```dart
  // ── Time-conscious duration fields ──
  String bibleDuration;
  String literatureDuration;
  String evangelismDuration;
  String givingDuration;
  String churchDuration;

  // ── Custom activity log data (JSON) ──
  Map<String, Map<String, dynamic>> customActivityData;
```

- [ ] **Step 3: Update DailyLog constructor**

In the constructor (lines 159-196), add the new fields with defaults. After `this.other = '',` add:

```dart
    this.bibleDuration = '',
    this.literatureDuration = '',
    this.evangelismDuration = '',
    this.givingDuration = '',
    this.churchDuration = '',
    Map<String, Map<String, dynamic>>? customActivityData,
```

Update the initializer list (line 195-196) to include:

```dart
  }) : bibleSessions = bibleSessions ?? [],
       literature = literature ?? [LiteratureEntry()],
       customActivityData = customActivityData ?? {};
```

- [ ] **Step 4: Update DailyLog.toMap()**

In `toMap()` (lines 218-254), add after `'other': other,`:

```dart
        'bibleDuration': bibleDuration,
        'literatureDuration': literatureDuration,
        'evangelismDuration': evangelismDuration,
        'givingDuration': givingDuration,
        'churchDuration': churchDuration,
        'custom_activity_data': jsonEncode(customActivityData),
```

- [ ] **Step 5: Update DailyLog.fromMap()**

In `fromMap()` (lines 275-332), add after `other: m['other'] ?? '',`:

```dart
      bibleDuration: m['bibleDuration'] ?? '',
      literatureDuration: m['literatureDuration'] ?? '',
      evangelismDuration: m['evangelismDuration'] ?? '',
      givingDuration: m['givingDuration'] ?? '',
      churchDuration: m['churchDuration'] ?? '',
```

And before the closing `);` of the return statement, add parsing for `customActivityData`. This needs a try-catch since it's JSON:

Add a local variable before the `return` statement:

```dart
    Map<String, Map<String, dynamic>> customData = {};
    try {
      final rawCustom = m['custom_activity_data'];
      if (rawCustom != null && rawCustom.toString().isNotEmpty) {
        final decoded = jsonDecode(rawCustom) as Map<String, dynamic>;
        customData = decoded.map((k, v) =>
            MapEntry(k, Map<String, dynamic>.from(v as Map)));
      }
    } catch (_) {}
```

Then pass `customActivityData: customData,` in the constructor call.

- [ ] **Step 6: Update completeness getter**

In the `completeness` getter (lines 200-216), update to include custom activities. After line 213 (`final filled = checks.where((c) => c).length;`), compute custom activity contribution:

```dart
  double get completeness {
    final checks = <bool>[
      bibleReference.isNotEmpty || bibleChapters.isNotEmpty || bibleSessions.any((s) => s.isNotEmpty),
      literature.any((l) => l.title.isNotEmpty),
      ddegScripture.isNotEmpty || ddegNotes.isNotEmpty,
      prayerAloneDuration.isNotEmpty,
      prayerOthersDuration.isNotEmpty,
      evangelismContacts.isNotEmpty,
      fastingType.isNotEmpty || fastingDuration.isNotEmpty,
      givingType.isNotEmpty,
      churchType.isNotEmpty,
      discipleshipWho.isNotEmpty,
      proclamationCount.isNotEmpty,
    ];
    final filled = checks.where((c) => c).length;

    // Count custom activities that affect completeness
    // This requires knowing which custom activities have countsForCompleteness.
    // Since DailyLog doesn't hold activity definitions, count based on
    // customActivityData entries that have a 'done' flag set to true.
    int customTotal = 0;
    int customFilled = 0;
    for (final entry in customActivityData.values) {
      if (entry['countsForCompleteness'] == true) {
        customTotal++;
        if (entry['done'] == true) customFilled++;
      }
    }

    final totalSections = 11 + customTotal;
    return totalSections > 0 ? (filled + customFilled) / totalSections : 0.0;
  }
```

- [ ] **Step 7: Add DB migration v10 in storage_service**

In `lib/services/storage_service.dart`, change version from `9` to `10` (line 30):

```dart
      version: 10,
```

Add the new columns to `onCreate` (inside the CREATE TABLE, after `bibleSessions TEXT DEFAULT ''` on line 68):

```sql
            bibleDuration TEXT DEFAULT '',
            literatureDuration TEXT DEFAULT '',
            evangelismDuration TEXT DEFAULT '',
            givingDuration TEXT DEFAULT '',
            churchDuration TEXT DEFAULT '',
            custom_activity_data TEXT DEFAULT ''
```

Add migration block after `if (oldVersion < 9)` block (after line 142):

```dart
          if (oldVersion < 10) {
            for (final col in [
              'bibleDuration', 'literatureDuration', 'evangelismDuration',
              'givingDuration', 'churchDuration', 'custom_activity_data',
            ]) {
              await txn.execute("ALTER TABLE logs ADD COLUMN $col TEXT DEFAULT ''");
            }
          }
```

- [ ] **Step 8: Verify with flutter analyze**

Run: `flutter analyze`
Expected: no new errors (warnings from existing code OK)

- [ ] **Step 9: Commit**

```bash
git add lib/models/daily_log.dart lib/models/custom_activity.dart lib/services/storage_service.dart
git commit -m "feat: add time-conscious duration fields, custom activity data column, and DB migration v10"
```

---

### Task 3: Time-Conscious Mode (Settings Toggle + LogScreen Duration Fields)

**Files:**
- Modify: `lib/screens/settings_screen.dart:29, 70-84` (add toggle state + load/save)
- Modify: `lib/screens/log_screen.dart` (add conditional duration fields in sections)
- Modify: `lib/l10n/app_en.arb` (add new label keys)
- Modify: `lib/l10n/app_fr.arb` (add new label keys)
- Regenerate: `lib/l10n/generated/*`

**Interfaces:**
- Consumes: `DailyLog.bibleDuration`, `.literatureDuration`, `.evangelismDuration`, `.givingDuration`, `.churchDuration` from Task 2
- Produces: `timeConscious` SharedPreferences key read by LogScreen; duration GoldFields in 5 sections

- [ ] **Step 1: Add ARB keys for time-conscious mode**

In `lib/l10n/app_en.arb`, add:

```json
"timeConsciousLabel": "Time-conscious mode",
"timeConsciousDescription": "Track how much time you consecrate to each spiritual activity",
"durationLabel": "Duration",
"durationHint": "e.g. 30 minutes",
"totalTimeConsecrated": "Total time consecrated: {time}",
"@totalTimeConsecrated": {
  "placeholders": {
    "time": {"type": "String"}
  }
},
```

In `lib/l10n/app_fr.arb`, add:

```json
"timeConsciousLabel": "Mode temps conscient",
"timeConsciousDescription": "Suivre le temps que vous consacrez à chaque activité spirituelle",
"durationLabel": "Durée",
"durationHint": "ex. 30 minutes",
"totalTimeConsecrated": "Temps total consacré: {time}",
"@totalTimeConsecrated": {
  "placeholders": {
    "time": {"type": "String"}
  }
},
```

- [ ] **Step 2: Regenerate l10n**

Run: `flutter gen-l10n`

- [ ] **Step 3: Add toggle state to SettingsScreen**

In `lib/screens/settings_screen.dart`, add a new boolean field after `_reportLanguage` (around line 38):

```dart
  bool _timeConscious = false;
```

In `_load()`, add after loading other settings:

```dart
    _timeConscious = (await s.getSetting('timeConscious', fallback: 'false')) == 'true';
```

- [ ] **Step 4: Add toggle widget to Settings UI**

In the Settings build method, find the section with other toggles (like dark mode, app lock) and add a new `_switchRow` for time-conscious mode. Add it in the "Preferences" or "General" section:

```dart
_switchRow(t.timeConsciousLabel, _timeConscious, (v) async {
  setState(() => _timeConscious = v);
  await StorageService.instance.setSetting('timeConscious', v.toString());
}),
Padding(
  padding: const EdgeInsets.only(left: 4, bottom: 8),
  child: Text(
    t.timeConsciousDescription,
    style: AppTheme.serif(11, color: AppTheme.textColor(context).withValues(alpha: 0.5)),
  ),
),
```

- [ ] **Step 5: Load timeConscious in LogScreen and show duration fields**

In `lib/screens/log_screen.dart`, add a `_timeConscious` boolean field in the State class:

```dart
bool _timeConscious = false;
```

In `initState` or the existing load method, read the setting:

```dart
_timeConscious = (await StorageService.instance.getSetting('timeConscious', fallback: 'false')) == 'true';
```

Then, in each SectionCard that doesn't already have a duration field, add a conditional GoldField at the end of the `children` list. For Bible Reading section:

```dart
if (_timeConscious)
  GoldField(
    label: t.durationLabel,
    hint: t.durationHint,
    value: _log.bibleDuration,
    icon: Icons.access_time,
    onChanged: (v) { _log.bibleDuration = v; _persist(); },
  ),
```

Repeat the same pattern for these sections:
- **Literature** section → `_log.literatureDuration`
- **Evangelism** section → `_log.evangelismDuration`
- **Giving & Tithes** section → `_log.givingDuration`
- **Church & Fellowship** section → `_log.churchDuration`

Do NOT add to DDEG, Prayer (Alone/Others), Discipleship, Proclamation, or Fasting — they already have duration fields.

- [ ] **Step 6: Verify with flutter analyze**

Run: `flutter analyze`
Expected: no new errors

- [ ] **Step 7: Commit**

```bash
git add lib/l10n/ lib/screens/settings_screen.dart lib/screens/log_screen.dart
git commit -m "feat: add time-conscious mode toggle with conditional duration fields"
```

---

### Task 4: Time-Conscious Report Aggregation + Stopwatch Integration

**Files:**
- Modify: `lib/services/report_service.dart:82-96, 460-470`
- Modify: `lib/models/activity_timer.dart:53-72`
- Modify: `lib/services/timer_service.dart:365-410`

**Interfaces:**
- Consumes: `DailyLog` duration fields from Task 2, `_parseDurationMinutes()` from report_service, `ActivityTypeMapping.logDurationField` from activity_timer
- Produces: "Total time consecrated" line in reports; stopwatch writes to new duration fields

- [ ] **Step 1: Extend ActivityTypeMapping for new duration fields**

In `lib/models/activity_timer.dart`, update the `logDurationField` getter (lines 55-72) to return the new fields for Bible, Literature, Evangelism, Church:

```dart
  String? get logDurationField {
    switch (this) {
      case ActivityType.bibleReading:
        return 'bibleDuration';
      case ActivityType.literature:
        return 'literatureDuration';
      case ActivityType.ddeg:
        return 'ddegTime';
      case ActivityType.prayerAlone:
        return 'prayerAloneDuration';
      case ActivityType.prayerOthers:
        return 'prayerOthersDuration';
      case ActivityType.evangelism:
        return 'evangelismDuration';
      case ActivityType.fasting:
        return 'fastingDuration';
      case ActivityType.discipleship:
        return 'discipleshipDuration';
      case ActivityType.church:
        return 'churchDuration';
      case ActivityType.proclamation:
        return 'proclamationDuration';
    }
  }
```

Note: `giving` has no `ActivityType` enum value and no stopwatch tile, so `givingDuration` is manual-entry only.

- [ ] **Step 2: Update _writeToDailyLog to handle new fields**

In `lib/services/timer_service.dart`, the `_writeToDailyLog` method (line 358-410) already uses a switch on `field` string values. Add the new cases in the switch:

```dart
          case 'bibleDuration':
            log.bibleDuration =
                _accumulateDuration(log.bibleDuration, durationStr);
          case 'literatureDuration':
            log.literatureDuration =
                _accumulateDuration(log.literatureDuration, durationStr);
          case 'evangelismDuration':
            log.evangelismDuration =
                _accumulateDuration(log.evangelismDuration, durationStr);
          case 'churchDuration':
            log.churchDuration =
                _accumulateDuration(log.churchDuration, durationStr);
```

- [ ] **Step 3: Add total time aggregation to report_service**

In `lib/services/report_service.dart`, create a helper method that sums all duration fields:

```dart
  /// Sum all duration fields across a list of logs.
  static int _totalConsecratedMinutes(List<DailyLog> logs) {
    int total = 0;
    for (final log in logs) {
      for (final d in [
        log.ddegTime,
        log.prayerAloneDuration,
        log.prayerOthersDuration,
        log.discipleshipDuration,
        log.proclamationDuration,
        log.bibleDuration,
        log.literatureDuration,
        log.evangelismDuration,
        log.givingDuration,
        log.churchDuration,
      ]) {
        total += _parseDurationMinutes(d);
      }
    }
    return total;
  }

  /// Format minutes as "Xh Ym".
  static String _formatTotalTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }
```

- [ ] **Step 4: Add total time line to full report**

In the full report builder, after the summary section header (around line 462-467), add the total time line. After `buf.writeln(l.reportSummaryCompletion(avgPct));`:

```dart
    final totalMins = _totalConsecratedMinutes(logs);
    if (totalMins > 0) {
      buf.writeln(l.totalTimeConsecrated(_formatTotalTime(totalMins)));
    }
```

Where `logs` is the list of DailyLog objects used in the report. Make sure the variable is accessible at this point (it is — it's the `logs` list built earlier in the method).

- [ ] **Step 5: Add total time line to compact report**

Add the same total time line to the compact report builder, in the summary section.

- [ ] **Step 6: Verify with flutter analyze**

Run: `flutter analyze`
Expected: no new errors

- [ ] **Step 7: Commit**

```bash
git add lib/models/activity_timer.dart lib/services/timer_service.dart lib/services/report_service.dart
git commit -m "feat: stopwatch writes to new duration fields, report shows total time consecrated"
```

---

### Task 5: Custom Activity Builder UI (Creation Modal)

**Files:**
- Modify: `lib/screens/log_screen.dart:1190-1295` (replace _showAddActivityDialog)
- Modify: `lib/screens/stopwatch_screen.dart:405-514` (replace _showAddActivityDialog)
- Modify: `lib/l10n/app_en.arb` (add new keys)
- Modify: `lib/l10n/app_fr.arb` (add new keys)
- Regenerate: `lib/l10n/generated/*`

**Interfaces:**
- Consumes: `CustomActivity`, `CustomField`, `CustomFieldType` from Task 2
- Produces: fully-configured `CustomActivity` objects saved via `StorageService.instance.addCustomActivity()`

- [ ] **Step 1: Add ARB keys for custom activity builder**

In `lib/l10n/app_en.arb`:

```json
"customActivityTitle": "Create Activity",
"customActivityName": "Activity name",
"customActivityNameHint": "e.g. Worship, Fasting Prayer",
"customActivityIcon": "Icon",
"customActivityTemplates": "Quick templates",
"customActivityTemplateSimple": "Simple",
"customActivityTemplateTimed": "Timed",
"customActivityTemplateCounted": "Counted",
"customActivityTemplateFull": "Full",
"customActivityAddField": "Add field",
"customActivityFieldLabel": "Field label",
"customActivityFieldType": "Type",
"customActivityCountsForProgress": "Counts for daily progress",
"customFieldTypeText": "Text",
"customFieldTypeNumber": "Number",
"customFieldTypeDuration": "Duration",
"customFieldTypeYesNo": "Yes/No",
"customFieldTypeNotes": "Notes",
"customActivityMaxFields": "Maximum 8 fields",
```

In `lib/l10n/app_fr.arb`, add the French equivalents:

```json
"customActivityTitle": "Créer une activité",
"customActivityName": "Nom de l'activité",
"customActivityNameHint": "ex. Louange, Prière de jeûne",
"customActivityIcon": "Icône",
"customActivityTemplates": "Modèles rapides",
"customActivityTemplateSimple": "Simple",
"customActivityTemplateTimed": "Minuté",
"customActivityTemplateCounted": "Compté",
"customActivityTemplateFull": "Complet",
"customActivityAddField": "Ajouter un champ",
"customActivityFieldLabel": "Libellé du champ",
"customActivityFieldType": "Type",
"customActivityCountsForProgress": "Compte pour la progression quotidienne",
"customFieldTypeText": "Texte",
"customFieldTypeNumber": "Nombre",
"customFieldTypeDuration": "Durée",
"customFieldTypeYesNo": "Oui/Non",
"customFieldTypeNotes": "Notes",
"customActivityMaxFields": "Maximum 8 champs",
```

- [ ] **Step 2: Regenerate l10n**

Run: `flutter gen-l10n`

- [ ] **Step 3: Replace _showAddActivityDialog in log_screen.dart**

Replace the `_showAddActivityDialog` method (lines 1190-1295) with the enhanced version. The dialog is a `showModalBottomSheet` with a `StatefulBuilder` inside:

```dart
void _showAddActivityDialog() {
  String name = '';
  String icon = '\u2728';
  final fields = <CustomField>[];
  bool countsForProgress = true;
  final t = S.of(context);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.isDark(context) ? AppTheme.bg1 : AppTheme.lightBg1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(t.customActivityTitle,
                  style: AppTheme.display(18, color: AppTheme.accentGold(ctx))),
              const SizedBox(height: 16),

              // Name + Icon row
              Row(
                children: [
                  Expanded(
                    child: GoldField(
                      label: t.customActivityName,
                      hint: t.customActivityNameHint,
                      value: name,
                      onChanged: (v) => setModalState(() => name = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      final emojis = ['\u2728', '\uD83D\uDE4F', '\uD83C\uDFB5', '\uD83D\uDCAA', '\u2764\uFE0F',
                        '\uD83D\uDD25', '\u2B50', '\uD83C\uDF1F', '\uD83D\uDC51', '\uD83C\uDF3F',
                        '\uD83D\uDCA1', '\uD83C\uDFAF', '\u270D\uFE0F', '\uD83D\uDCD6'];
                      final picked = await showDialog<String>(
                        context: ctx,
                        builder: (_) => AlertDialog(
                          title: Text(t.customActivityIcon),
                          content: Wrap(
                            spacing: 12, runSpacing: 12,
                            children: emojis.map((e) => GestureDetector(
                              onTap: () => Navigator.pop(ctx, e),
                              child: Text(e, style: const TextStyle(fontSize: 28)),
                            )).toList(),
                          ),
                        ),
                      );
                      if (picked != null) setModalState(() => icon = picked);
                    },
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.accentGold(ctx).withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text(icon, style: const TextStyle(fontSize: 28))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick templates
              Text(t.customActivityTemplates,
                  style: AppTheme.label(12, color: AppTheme.textColor(ctx).withValues(alpha: 0.6))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _templateChip(t.customActivityTemplateSimple, [], fields, setModalState),
                  _templateChip(t.customActivityTemplateTimed, [
                    CustomField(label: 'Duration', type: CustomFieldType.duration),
                    CustomField(label: 'Notes', type: CustomFieldType.notes),
                  ], fields, setModalState),
                  _templateChip(t.customActivityTemplateCounted, [
                    CustomField(label: 'Count', type: CustomFieldType.number),
                    CustomField(label: 'Notes', type: CustomFieldType.notes),
                  ], fields, setModalState),
                  _templateChip(t.customActivityTemplateFull, [
                    CustomField(label: 'Duration', type: CustomFieldType.duration),
                    CustomField(label: 'Count', type: CustomFieldType.number),
                    CustomField(label: 'Person', type: CustomFieldType.text),
                    CustomField(label: 'Notes', type: CustomFieldType.notes),
                  ], fields, setModalState),
                ],
              ),
              const SizedBox(height: 16),

              // Custom fields list
              ...fields.asMap().entries.map((entry) {
                final i = entry.key;
                final f = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: t.customActivityFieldLabel,
                            isDense: true,
                          ),
                          controller: TextEditingController(text: f.label),
                          onChanged: (v) => f.label = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<CustomFieldType>(
                          value: f.type,
                          isDense: true,
                          decoration: const InputDecoration(isDense: true),
                          items: CustomFieldType.values.map((t) =>
                            DropdownMenuItem(value: t, child: Text(_fieldTypeName(t, ctx)))).toList(),
                          onChanged: (v) => setModalState(() => f.type = v!),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setModalState(() => fields.removeAt(i)),
                      ),
                    ],
                  ),
                );
              }),

              // Add field button
              if (fields.length < 8)
                TextButton.icon(
                  onPressed: () => setModalState(() =>
                      fields.add(CustomField(label: '', type: CustomFieldType.text))),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(t.customActivityAddField),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(t.customActivityMaxFields,
                      style: AppTheme.serif(11, color: AppTheme.rust)),
                ),
              const SizedBox(height: 8),

              // Counts for progress toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(t.customActivityCountsForProgress,
                      style: AppTheme.serif(14, color: AppTheme.textColor(ctx)))),
                  Switch.adaptive(
                    value: countsForProgress,
                    activeTrackColor: AppTheme.accentGold(ctx),
                    onChanged: (v) => setModalState(() => countsForProgress = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGold(ctx),
                    foregroundColor: AppTheme.bg0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: name.trim().isEmpty ? null : () {
                    // Remove fields with empty labels
                    fields.removeWhere((f) => f.label.trim().isEmpty);
                    final activity = CustomActivity(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name.trim(),
                      icon: icon,
                      fields: fields,
                      countsForCompleteness: countsForProgress,
                    );
                    StorageService.instance.addCustomActivity(activity);
                    setState(() => _customActivities.add(activity));
                    Navigator.pop(ctx);
                  },
                  child: Text(t.save),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _templateChip(String label, List<CustomField> template,
    List<CustomField> target, StateSetter setModalState) {
  return ActionChip(
    label: Text(label, style: const TextStyle(fontSize: 12)),
    onPressed: () => setModalState(() {
      target.clear();
      target.addAll(template.map((f) => CustomField(label: f.label, type: f.type)));
    }),
  );
}

String _fieldTypeName(CustomFieldType type, BuildContext ctx) {
  final t = S.of(ctx);
  switch (type) {
    case CustomFieldType.text: return t.customFieldTypeText;
    case CustomFieldType.number: return t.customFieldTypeNumber;
    case CustomFieldType.duration: return t.customFieldTypeDuration;
    case CustomFieldType.yesNo: return t.customFieldTypeYesNo;
    case CustomFieldType.notes: return t.customFieldTypeNotes;
  }
}
```

- [ ] **Step 4: Replace _showAddActivityDialog in stopwatch_screen.dart**

Apply the same enhanced dialog to `stopwatch_screen.dart` (lines 405-514). The code is identical except the `setState` callback updates `_customActivities` in the stopwatch screen's state.

- [ ] **Step 5: Verify with flutter analyze**

Run: `flutter analyze`
Expected: no new errors

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/ lib/screens/log_screen.dart lib/screens/stopwatch_screen.dart
git commit -m "feat: enhanced custom activity builder with templates and configurable fields"
```

---

### Task 6: Custom Activity Rendering in LogScreen + Report Integration

**Files:**
- Modify: `lib/screens/log_screen.dart:1065-1092` (replace Other section custom activity rendering)
- Modify: `lib/services/report_service.dart:457` (add custom activities to reports)
- Modify: `lib/services/timer_service.dart:394-407` (write to customActivityData instead of `other`)

**Interfaces:**
- Consumes: `CustomActivity`, `CustomField`, `CustomFieldType` from Task 2; `DailyLog.customActivityData` from Task 2
- Produces: SectionCard per custom activity in LogScreen; custom activity lines in reports; stopwatch duration writes to `customActivityData`

- [ ] **Step 1: Render custom activities as SectionCards in LogScreen**

In `lib/screens/log_screen.dart`, find the "Other" section (around line 1065-1092) where custom activities are rendered as quick toggle buttons. After the existing "Other" SectionCard, add a loop that renders each custom activity as its own SectionCard:

```dart
// Custom activity section cards
..._customActivities.map((activity) {
  final actData = _log.customActivityData[activity.id] ?? {};
  final isDone = actData['done'] == true;
  final fieldValues = Map<String, dynamic>.from(actData['fields'] as Map? ?? {});

  return SectionCard(
    icon: activity.icon,
    title: activity.name,
    initiallyExpanded: isDone || fieldValues.values.any((v) => v.toString().isNotEmpty),
    trailing: Switch.adaptive(
      value: isDone,
      activeTrackColor: AppTheme.accentGold(context),
      onChanged: (v) {
        setState(() {
          final data = Map<String, dynamic>.from(
              _log.customActivityData[activity.id] ?? {});
          data['done'] = v;
          data['countsForCompleteness'] = activity.countsForCompleteness;
          if (!data.containsKey('fields')) data['fields'] = {};
          _log.customActivityData[activity.id] = Map<String, dynamic>.from(data);
          _persist();
        });
      },
    ),
    children: [
      ...activity.fields.map((field) {
        switch (field.type) {
          case CustomFieldType.text:
            return GoldField(
              label: field.label,
              value: fieldValues[field.label]?.toString() ?? '',
              onChanged: (v) => _updateCustomField(activity.id, field.label, v),
            );
          case CustomFieldType.number:
            return GoldField(
              label: field.label,
              value: fieldValues[field.label]?.toString() ?? '',
              keyboardType: TextInputType.number,
              onChanged: (v) => _updateCustomField(activity.id, field.label, v),
            );
          case CustomFieldType.duration:
            return GoldField(
              label: field.label,
              hint: t.durationHint,
              value: fieldValues[field.label]?.toString() ?? '',
              icon: Icons.access_time,
              onChanged: (v) => _updateCustomField(activity.id, field.label, v),
            );
          case CustomFieldType.yesNo:
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(field.label, style: AppTheme.serif(14, color: AppTheme.textColor(context))),
                  Switch.adaptive(
                    value: fieldValues[field.label] == true || fieldValues[field.label] == 'true',
                    activeTrackColor: AppTheme.accentGold(context),
                    onChanged: (v) => _updateCustomField(activity.id, field.label, v),
                  ),
                ],
              ),
            );
          case CustomFieldType.notes:
            return GoldField(
              label: field.label,
              value: fieldValues[field.label]?.toString() ?? '',
              maxLines: 3,
              onChanged: (v) => _updateCustomField(activity.id, field.label, v),
            );
        }
      }),
      // Time-conscious: add duration field if activity doesn't have one
      if (_timeConscious && !activity.fields.any((f) => f.type == CustomFieldType.duration))
        GoldField(
          label: t.durationLabel,
          hint: t.durationHint,
          value: fieldValues['_duration']?.toString() ?? '',
          icon: Icons.access_time,
          onChanged: (v) => _updateCustomField(activity.id, '_duration', v),
        ),
    ],
  ).animate().fadeIn(delay: 350.ms);
}),
```

Add the helper method `_updateCustomField`:

```dart
void _updateCustomField(String activityId, String fieldLabel, dynamic value) {
  setState(() {
    final data = Map<String, dynamic>.from(
        _log.customActivityData[activityId] ?? {});
    final fields = Map<String, dynamic>.from(data['fields'] as Map? ?? {});
    fields[fieldLabel] = value;
    data['fields'] = fields;
    _log.customActivityData[activityId] = Map<String, dynamic>.from(data);
    _persist();
  });
}
```

- [ ] **Step 2: Update timer_service to write custom activity duration to customActivityData**

In `lib/services/timer_service.dart`, modify the custom activity branch in `_writeToDailyLog` (lines 394-407). Replace:

```dart
    } else {
      // Custom activity — write to "other" field with duration
      final name = session.fields['_customName'] ?? '';
      final notes = session.fields.entries
          .where((e) => !e.key.startsWith('_') && e.value.isNotEmpty)
          .map((e) => '${e.key}: ${e.value}')
          .join('; ');
      final parts = <String>[
        if (name.isNotEmpty) name,
        if (notes.isNotEmpty) notes,
        durationStr,
      ];
      log.other = _appendText(log.other, parts.join(' — '));
    }
```

With:

```dart
    } else {
      // Custom activity — write to customActivityData
      final customId = session.key.customId!;
      final data = Map<String, dynamic>.from(
          log.customActivityData[customId] ?? {});
      data['done'] = true;
      final fields = Map<String, dynamic>.from(data['fields'] as Map? ?? {});

      // Find the first duration-type field in this custom activity, or use '_duration'
      String durationKey = '_duration';
      final activities = await StorageService.instance.getCustomActivities();
      final activity = activities.where((a) => a.id == customId).firstOrNull;
      if (activity != null) {
        final durField = activity.fields.where((f) => f.type == CustomFieldType.duration).firstOrNull;
        if (durField != null) durationKey = durField.label;
        data['countsForCompleteness'] = activity.countsForCompleteness;
      }

      final existing = fields[durationKey]?.toString() ?? '';
      fields[durationKey] = _accumulateDuration(existing, durationStr);

      // Merge extra pre-start fields
      for (final entry in session.fields.entries) {
        if (!entry.key.startsWith('_') && entry.value.isNotEmpty) {
          fields[entry.key] = entry.value;
        }
      }

      data['fields'] = fields;
      log.customActivityData[customId] = Map<String, dynamic>.from(data);
    }
```

Note: This requires importing `custom_activity.dart` in timer_service.dart if not already imported.

- [ ] **Step 3: Add custom activities to report output**

In `lib/services/report_service.dart`, after the `if (log.other.isNotEmpty)` line (around line 457), add custom activity reporting:

```dart
      // Custom activities
      for (final entry in log.customActivityData.entries) {
        final actData = entry.value;
        if (actData['done'] != true) continue;
        final fields = actData['fields'] as Map<String, dynamic>? ?? {};
        if (fields.isEmpty && actData['done'] == true) {
          // Simple activity, just mark as done
          final actName = entry.key; // We'll resolve the name below
          buf.writeln('\uD83D\uDCCC $actName: \u2713');
        } else {
          final parts = fields.entries
              .where((e) => !e.key.startsWith('_') && e.value.toString().isNotEmpty)
              .map((e) => '${e.key}: ${e.value}')
              .join(', ');
          buf.writeln('\uD83D\uDCCC ${parts.isNotEmpty ? parts : "\u2713"}');
        }
      }
```

To show the activity name instead of its ID, load the custom activity list once at the start of the report method and look up names:

```dart
    final customActivities = await StorageService.instance.getCustomActivities();
    final customNames = {for (final a in customActivities) a.id: '${a.icon} ${a.name}'};
```

Then use `customNames[entry.key] ?? entry.key` as the activity label.

- [ ] **Step 4: Include custom activity durations in total time aggregation**

In the `_totalConsecratedMinutes` method (from Task 4), add custom activity duration parsing:

```dart
      // Custom activity durations
      for (final actData in log.customActivityData.values) {
        final fields = actData['fields'] as Map<String, dynamic>? ?? {};
        for (final v in fields.values) {
          if (v is String) total += _parseDurationMinutes(v);
        }
      }
```

Wait — this would double-count non-duration fields that happen to look like durations. Instead, only parse fields we know are duration type. Since we don't have the field type info in the log data, parse any field named "Duration" or the `_duration` key:

```dart
      for (final actData in log.customActivityData.values) {
        final fields = actData['fields'] as Map<String, dynamic>? ?? {};
        for (final entry in fields.entries) {
          // Only count duration-like fields
          if (entry.key == '_duration' ||
              entry.key.toLowerCase().contains('duration') ||
              entry.key.toLowerCase().contains('time')) {
            total += _parseDurationMinutes(entry.value.toString());
          }
        }
      }
```

- [ ] **Step 5: Verify with flutter analyze**

Run: `flutter analyze`
Expected: no new errors

- [ ] **Step 6: Commit**

```bash
git add lib/screens/log_screen.dart lib/services/timer_service.dart lib/services/report_service.dart
git commit -m "feat: custom activities render as SectionCards, integrate into reports and stopwatch"
```

---

### Task 7: Notification Action Buttons Fix + Cancel + Smart Stop

**Files:**
- Modify: `lib/services/notification_service.dart:778-850, 405-421`
- Modify: `lib/services/timer_service.dart:86-95`
- Modify: `lib/screens/stopwatch_screen.dart:263-291`
- Modify: `lib/screens/home_shell.dart:56-60`
- Modify: `lib/models/activity_timer.dart` (add `activityLabel` helper)

**Interfaces:**
- Consumes: `TimerService` methods (pause, stop), `NotificationService.showStopwatchNotification`
- Produces: visible Pause/Resume + Stop + Cancel notification actions; `cancelTimer()` method; smart Stop → navigate for Bible Reading

- [ ] **Step 1: Fix notification importance and add all action buttons**

In `lib/services/notification_service.dart`, modify `showStopwatchNotification` (lines 778-850):

Change the actions list to include Resume and Cancel:

```dart
    final actions = <AndroidNotificationAction>[
      if (!isPaused)
        const AndroidNotificationAction(
          'timer_pause',
          '\u23F8 Pause',
          showsUserInterface: false,
          cancelNotification: false,
        )
      else
        const AndroidNotificationAction(
          'timer_resume',
          '\u25B6 Resume',
          showsUserInterface: false,
          cancelNotification: false,
        ),
      AndroidNotificationAction(
        'timer_stop',
        '\u23F9 Stop',
        showsUserInterface: activityLabel.contains('Bible') || activityLabel.contains('Lecture'),
        cancelNotification: true,
      ),
      const AndroidNotificationAction(
        'timer_cancel',
        '\u2715 Cancel',
        showsUserInterface: true,
        cancelNotification: false,
      ),
    ];
```

Change the channel importance from `Importance.low` to `Importance.defaultImportance`:

```dart
    final channel = AndroidNotificationDetails(
      'daily_account_stopwatch',
      'Activity Timer',
      channelDescription: 'Shows while a spiritual activity timer is running',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: false,
      enableVibration: false,
      ongoing: !isPaused,
      autoCancel: false,
      showWhen: useChronometer,
      usesChronometer: useChronometer,
      when: whenMs,
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
      actions: actions,
      styleInformation: BigTextStyleInformation(
        status,
        contentTitle: '$activityIcon $activityLabel',
      ),
    );
```

Update the body text to include elapsed time when running:

```dart
    final status = isPaused
        ? (pausedLabel ?? '\u23F8 Paused \u2014 $elapsed')
        : '\u23F1 In progress \u2014 $elapsed';
```

- [ ] **Step 2: Handle timer_resume and timer_cancel in notification response**

In `_onNotificationResponse` (lines 405-421), add the new action cases:

```dart
  void _onNotificationResponse(NotificationResponse response) {
    switch (response.actionId) {
      case 'snooze_15':
        _scheduleSnooze();
        return;
      case 'timer_pause':
      case 'timer_resume':
      case 'timer_stop':
      case 'timer_cancel':
        onTimerAction?.call(response.actionId!);
        return;
    }
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      onNotificationTap?.call(payload);
    }
  }
```

- [ ] **Step 3: Add cancelTimer() and handle new actions in TimerService**

In `lib/services/timer_service.dart`, add a `cancelTimer` method and update `_handleNotifAction`:

```dart
  void _handleNotifAction(String action) {
    final running = activeKey;
    if (running == null) return;
    switch (action) {
      case 'timer_pause':
      case 'timer_resume':
        pause(running);
      case 'timer_stop':
        stop(running);
      case 'timer_cancel':
        _requestCancel(running);
    }
  }

  /// Cancel the active timer. If elapsed >= 10s, notifies UI to show
  /// confirmation dialog. If < 10s, cancels immediately.
  void _requestCancel(TimerKey key) {
    final session = _sessions[key];
    if (session == null) return;
    if (session.currentElapsed.inSeconds < 10) {
      cancelTimer(key);
    } else {
      // Open the app and let the UI handle the confirmation
      // The notification already has showsUserInterface: true for cancel
      _pendingCancelKey = key;
      notifyListeners();
    }
  }

  /// Key awaiting cancel confirmation from UI.
  TimerKey? _pendingCancelKey;
  TimerKey? get pendingCancelKey => _pendingCancelKey;

  /// Clear the pending cancel (user chose "Keep timing").
  void clearPendingCancel() {
    _pendingCancelKey = null;
    notifyListeners();
  }

  /// Cancel a timer without saving its duration to the log.
  void cancelTimer(TimerKey key) {
    final session = _sessions[key];
    if (session == null) return;
    _sessions.remove(key);
    _pendingCancelKey = null;
    NotificationService.instance.cancelStopwatchNotification();
    _stopForegroundService();
    _hideOverlay();
    _persist();
    notifyListeners();
  }
```

- [ ] **Step 4: Handle smart Stop for Bible Reading in HomeShell**

In `lib/screens/home_shell.dart`, update the `onNotificationTap` handler (line 56-60):

```dart
    NotificationService.instance.onNotificationTap = (payload) {
      if (payload == 'navigate_report' && mounted) {
        setState(() => _tab = 2);
      } else if (payload == 'stopwatch_bible' && mounted) {
        // Navigate to log tab (Bible section)
        setState(() => _tab = 1);
      }
    };
```

In `TimerService.stop()`, when the activity is Bible Reading, set the notification tap payload. Find the `stop` method and after stopping, if the activity is `ActivityType.bibleReading`, call:

```dart
    if (key.isBuiltIn && key.builtIn == ActivityType.bibleReading) {
      NotificationService.instance.onNotificationTap?.call('stopwatch_bible');
    }
```

- [ ] **Step 5: Add Cancel button to stopwatch_screen UI**

In `lib/screens/stopwatch_screen.dart`, update the control buttons (lines 263-291) to add a Cancel button:

For the running state:
```dart
if (isRunning) ...[
  _tileButton(Icons.close_rounded, Colors.grey, () => _cancelTimer(key)),
  const SizedBox(width: 8),
  _tileButton(Icons.pause_rounded, AppTheme.goldSoft, () {
    ts.pause(key);
  }),
  const SizedBox(width: 8),
  _tileButton(Icons.stop_rounded, AppTheme.rust, () => _stopTimer(key)),
],
if (isPaused) ...[
  _tileButton(Icons.close_rounded, Colors.grey, () => _cancelTimer(key)),
  const SizedBox(width: 8),
  _tileButton(Icons.play_arrow_rounded, AppTheme.green, () {
    ts.start(key);
  }),
  const SizedBox(width: 8),
  _tileButton(Icons.stop_rounded, AppTheme.rust, () => _stopTimer(key)),
],
```

Add the `_cancelTimer` method:

```dart
void _cancelTimer(TimerKey key) {
  final ts = TimerService.instance;
  final session = ts.sessions[key];
  if (session == null) return;

  if (session.currentElapsed.inSeconds < 10) {
    ts.cancelTimer(key);
    return;
  }

  final elapsed = session.formattedDuration;
  final name = key.isBuiltIn ? key.builtIn!.shortCode : (session.fields['_customName'] ?? 'Activity');
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel timer?'),
      content: Text('Discard $elapsed of $name?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Keep timing'),
        ),
        TextButton(
          onPressed: () {
            ts.cancelTimer(key);
            Navigator.pop(ctx);
          },
          child: Text('Discard', style: TextStyle(color: AppTheme.rust)),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 6: Handle pending cancel confirmation from notification**

In the stopwatch screen, listen for `pendingCancelKey` changes from TimerService and show the confirmation dialog:

In `initState` or the listener callback:

```dart
void _onTimerChanged() {
  setState(() {});
  final ts = TimerService.instance;
  if (ts.pendingCancelKey != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cancelTimer(ts.pendingCancelKey!);
      ts.clearPendingCancel();
    });
  }
}
```

- [ ] **Step 7: Verify with flutter analyze**

Run: `flutter analyze`
Expected: no new errors

- [ ] **Step 8: Build release APK to verify everything compiles**

Run: `flutter build apk --release`
Expected: BUILD SUCCESSFUL

- [ ] **Step 9: Commit**

```bash
git add lib/services/notification_service.dart lib/services/timer_service.dart lib/screens/stopwatch_screen.dart lib/screens/home_shell.dart
git commit -m "feat: visible notification actions (Pause/Resume/Stop/Cancel) with smart Bible Reading stop"
```

---
