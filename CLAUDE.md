# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Daily Account is a Flutter spiritual accountability app for the CMFI discipleship tradition. It tracks daily disciplines (Bible reading, Christian literature, DDEG, prayer, evangelism) and generates weekly reports to send to a disciple maker via email, WhatsApp, or clipboard. All data is stored locally (SQLite + SharedPreferences) — fully offline-first.

## Build & Run Commands

```bash
flutter pub get                      # Install dependencies
flutter run                          # Debug on connected device/emulator
flutter run --release                # Release mode on device
flutter build apk --release          # Build release APK
flutter analyze                      # Run static analysis (flutter_lints)
```

No test suite exists yet. The project uses `flutter_lints` for static analysis.

## Architecture

Singleton service-based architecture with no external state management (no Provider/Riverpod/BLoC). Screens are StatefulWidgets that call services directly.

### Data Flow

`Models` -> `Services` -> `Screens`

- **Models** ([daily_log.dart](lib/models/daily_log.dart)): `DailyLog` (date-keyed, serializable via `toMap()`/`fromMap()`) with nested `LiteratureEntry` list. The `completeness` getter calculates a 0.0–1.0 progress across 7 sections.
- **Services** (all singletons with `static final instance = Service._()`):
  - [storage_service.dart](lib/services/storage_service.dart): SQLite CRUD for logs + SharedPreferences for settings (disciple maker name/contact, reminder prefs)
  - [report_service.dart](lib/services/report_service.dart): Builds weekly text reports, computes stats/streak, launches email/WhatsApp via `url_launcher`
  - [notification_service.dart](lib/services/notification_service.dart): Schedules daily reminders + Sunday send reminders via `flutter_local_notifications` (hardcoded Africa/Lagos timezone)
- **Screens**: `HomeShell` (nav + week strip) -> `LogScreen` (daily entry with auto-save on every change), `ReportScreen` (stats dashboard + send), `SettingsScreen` (profile/contacts/reminders)
- **Widgets** ([common_widgets.dart](lib/widgets/common_widgets.dart)): Shared UI components — `SectionCard`, `GoldField`, `ProgressRing`, `StatTile`

### Key Patterns

- **Auto-persistence**: `LogScreen` calls `_persist()` on every field change — no explicit save button
- **Date-keyed storage**: All logs indexed by `'yyyy-MM-dd'` string keys
- **ValueKey rebuilds**: `HomeShell` uses `ValueKey(_reportKey)` to force `ReportScreen` rebuild when log data changes
- **Callback communication**: `LogScreen.onChanged()` notifies parent to refresh week completion indicators

## Android Build Notes

- `android/app/build.gradle.kts` uses Kotlin DSL
- Core library desugaring is enabled (required by `flutter_local_notifications`)
- Min SDK follows `flutter.minSdkVersion`; README recommends 21+
- AndroidManifest needs notification permissions/receivers (see README for `AndroidManifest_ADDITIONS.xml`)

## Theme

Espresso + gold-leaf palette. Typography: Cormorant Garamond + Lora via `google_fonts`. Subtle entrance animations via `flutter_animate`. Theme defined in [app_theme.dart](lib/theme/app_theme.dart).
