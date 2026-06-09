# Phase 1: Production-Ready Daily Account — Design Spec

## Goal

Transform Daily Account from a functional prototype into a polished, bilingual (French/English) production app that CMFI believers in Cameroon can use daily for spiritual accountability. Zero backend, zero cost, offline-first.

## Scope

### 1. Internationalization (French + English)

**Why:** CMFI is headquartered in Cameroon (bilingual country). Most CMFI members in Cameroon speak French as primary language. English is secondary. The app must launch with both.

**Approach:** Flutter's built-in `intl` + ARB files. Language toggle in Settings. Persist choice in SharedPreferences. Default to device locale (French if `fr`, English otherwise).

**What gets translated:**
- All UI labels, hints, placeholders, button text
- Notification messages
- Report template text
- Onboarding screens
- Error messages and toasts

**What stays untranslated:**
- User-entered data (their own notes, names, references)
- Scripture references (user types these)

### 2. Complete CMFI Disciplines

**Current:** Bible, Literature, DDEG, Prayer Alone, Prayer Others, Evangelism, Other

**Missing disciplines to add:**
- **Fasting** — type (full/partial/Daniel), duration, prayer focus during fast
- **Giving & Tithes** — amount (optional), type (tithe/offering/seed), purpose/occasion
- **Church Attendance** — service type (Sunday service/midweek/cell group/special), notes
- **Discipleship** — who you are discipling (names), what you covered, duration

**"Other" field** — Rename to "Other Activities" and keep as free-form for anything not covered.

**Model changes:** Add 10 new fields to DailyLog. Update completeness calculation to weight 11 sections instead of 7.

**Database migration:** ALTER TABLE to add new columns with empty string defaults. Existing data preserved.

### 3. Onboarding Flow

**First launch only** (tracked via SharedPreferences `onboarding_complete` flag).

3-4 swipeable pages:
1. **Welcome** — App name, cross icon, "Track your daily walk with God" in user's language
2. **How it works** — Brief explanation: log daily, send weekly, stay accountable
3. **Your Profile** — Name + disciple maker contact (inline, not redirecting to settings)
4. **Language** — French/English selector

After completion, navigates to HomeShell. Settings can change everything later.

### 4. UI/UX Polish

**Empty states:**
- Report screen with 0 days logged: show encouraging message instead of zeroes
- First day with no entries: show gentle prompt in each section

**Validation:**
- Email format validation (basic regex)
- WhatsApp number validation (must be digits, 10-15 chars)
- Bible chapters field: numeric keyboard
- Evangelism contacts field: numeric keyboard

**Toast/feedback improvements:**
- Show confirmation when reminders are scheduled
- Show error if email/WhatsApp launch fails
- Gentle vibration on "Mark Complete"

**Scroll preservation:**
- LogScreen maintains scroll position when switching tabs

**Log screen improvements:**
- Section collapse/expand (sections start collapsed if empty, expanded if has data)
- Swipe between days (left/right gesture on log screen)

**Report improvements:**
- Add weekly summary stats at bottom of report text
- Show "No report to send" state when 0 days logged
- Confirmation dialog before sending

### 5. Local Backup & Restore

**Export:** Serialize all logs + settings to a single JSON file. Save to device Downloads folder via file picker. Named `daily_account_backup_YYYY-MM-DD.json`.

**Import:** Pick JSON file, validate structure, merge or replace (user chooses). Shows preview of what will be imported (X days of logs, settings).

**Dependencies:** `file_picker` package for file selection, `path_provider` for Downloads directory.

### 6. Production Metadata

- Package name: keep `com.example.daily_account` for now (change before Play Store)
- App label: "Daily Account" (already set)
- Version: bump to 1.1.0
- Min SDK: 21 (already set)
- Proper signing config (user provides keystore)
- ProGuard/R8 rules if needed
- Remove debug banner (already done)

## Architecture Changes

### New Files
```
lib/
  l10n/
    app_en.arb                    English strings
    app_fr.arb                    French strings
    l10n.dart                     Generated localization delegate
  screens/
    onboarding_screen.dart        First-launch walkthrough
  services/
    backup_service.dart           JSON export/import
```

### Modified Files
```
lib/
  models/daily_log.dart           Add fasting, giving, church, discipleship fields
  services/storage_service.dart   Database migration v2, new columns
  services/report_service.dart    Updated report template with new disciplines
  services/notification_service.dart  Localized notification text
  screens/home_shell.dart         Language-aware, swipe gestures
  screens/log_screen.dart         New sections, collapsible, validation
  screens/report_screen.dart      Empty states, confirmation dialog
  screens/settings_screen.dart    Language toggle, backup/restore, validation
  widgets/common_widgets.dart     Minor: collapsible SectionCard
  theme/app_theme.dart            No changes needed
  main.dart                       Add localization delegates, onboarding routing
pubspec.yaml                      Add dependencies, l10n config
```

### Database Migration Strategy
- Current version: 1
- New version: 2
- Migration: ALTER TABLE logs ADD COLUMN for each new field
- All new columns default to empty string
- Existing data fully preserved
- completeness getter updated to count 11 sections

## Dependencies to Add
- `file_picker: ^8.0.0` — for backup file selection
- `path_provider: ^2.1.0` — for Downloads directory
- `flutter_localizations` (SDK) — for i18n support
- `share_plus: ^9.0.0` — for sharing backup files

## What This Does NOT Include (Phase 2+)
- No backend/auth/cloud sync
- No charts/graphs/analytics
- No calendar view
- No PDF report generation
- No AI reflection
- No push notifications via server
- No multi-device sync
