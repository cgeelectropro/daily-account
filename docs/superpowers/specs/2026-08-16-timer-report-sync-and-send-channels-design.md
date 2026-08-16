# Timer/Report Sync, Proclamation Topics, and Send-Channel Configuration — Design

Date: 2026-08-16
Status: Approved, ready for implementation planning

## Background

Testing surfaced a batch of interconnected bugs and gaps in Daily Account:

1. Timer-logged activity results are inconsistently reflected in the weekly report.
2. Some timer activities accumulate correctly; Proclamation overwrites instead.
3. Fasting is exposed as a stopwatch tile even though it already has a proper
   multi-day tracker elsewhere in the app — the two are disconnected.
4. Only Bible/DDEG/Prayer support multiple sessions per day; other timed
   disciplines are single accumulated scalar strings.
5. Proclamation has no "topic" concept — it's a hardcoded declaration with a
   tap counter, and the count never resets across midnight on the Android
   home-screen widget.
6. The "time-conscious mode" duration field on Giving & Tithes is unwanted.
7. Auto-send is WhatsApp-only; the user wants an option to auto-send via
   Gmail (or both), gated on a valid configured email address.
8. Settings screen should already reflect the configurable report cadence
   (recently added via `ReportCadenceService`) — needs an audit for any
   leftover hardcoded "Sunday" strings.

Investigation (see prior conversation) confirmed root causes for each and
ruled out some suspected bugs (e.g. Bible duration is *not* silently
dropped — it feeds the aggregate total but is invisible per-day and in
completeness/consistency scoring, which is what created the "not counted"
impression).

## Goals

- Every timed activity's result reliably appears in the report, per-day
  and in aggregate.
- Timer sessions always accumulate (never silently overwrite) within a day.
- Proclamation supports user-defined topics, matched/reused per day, with a
  fixed midnight reset for the home-screen widget.
- Fasting is removed from the stopwatch grid; the existing multi-day
  tracker is the single source of truth.
- Evangelism and Church gain structured multi-session tracking, matching
  the existing Bible/DDEG/Prayer pattern.
- Giving/Tithe duration field is removed from UI and report.
- Auto-send supports WhatsApp, Gmail (silent, via Gmail API), or both,
  gated on valid configuration, with a generalized offline retry queue.
- Settings UI has no stale hardcoded "Sunday" cadence references.
- Any other functional/UX defect spotted during implementation gets fixed
  in the same pass.

## Non-goals

- No migration to a Supabase/backend architecture (explicitly deferred by
  the user as a separate future initiative).
- No SMTP/app-password email flow — superseded by the Gmail API approach
  since Google Sign-In infrastructure already exists in-app.
- No changes to `_openCustomCounterModal` (user-defined custom activities)
  — left as-is for this batch.
- No native Android widget configuration activity (long-press to
  configure) — topic entry happens in-app via a quick picker reached from
  the widget's existing deep link.

## Design

### 1. Data model

New shared session model for activities gaining structured tracking:

```dart
class TimedSession {
  DateTime start;
  DateTime end;
  int durationSeconds;
  String? topic; // proclamation only
}
```

- **Proclamation**: new `List<ProclamationSession>` (topic, count, duration)
  replaces active use of `proclamationCount`/`proclamationDuration`
  scalars. Legacy scalar fields remain in the model (read-only, for
  historical rows) but are no longer written to to by new saves.
- **Evangelism, Church**: gain `List<TimedSession> evangelismSessions` /
  `churchSessions`. Legacy scalar duration fields remain for historical
  rows; report/aggregation prefers the session list when non-empty, falls
  back to the scalar otherwise.
- **Giving/Tithe**: `givingDuration` removed from UI and from report
  aggregation. The DB column and model field remain unused (no migration)
  for backward compatibility, consistent with existing project convention
  for deprecated fields.
- **Fasting**: `ActivityType.fasting` removed from the Stopwatch grid
  rendering only (enum case and `fastingDuration` field remain, to avoid
  breaking historical data). The existing `FastingPeriod` multi-day
  tracker in the Log screen becomes the sole fasting mechanism.
- **Bible reading**: no model change. Fix is report-layer only (below).

**Topic matching rule** (Proclamation): when a session is about to be
recorded, compare the given topic (case-insensitive, trimmed) against
today's existing `ProclamationSession` topics. On match, increment that
session's count/duration. Otherwise append a new session. Applies
identically whether the session originates from the in-app timer or the
widget-triggered quick picker.

### 2. Report generation

- Bible per-day report line gains duration: reference + chapters + time
  (e.g. "Genesis 1-3 (3 chapters, 25 min)"). Aggregate total already
  correctly includes `bibleDuration` — unchanged.
- Evangelism/Church per-day lines render session-aware when sessions
  exist (e.g. "Evangelism: 2 sessions, 45 min total"), falling back to
  the legacy scalar-only rendering for historical logs without sessions.
- Proclamation per-day line lists each topic with count + duration (e.g.
  "Proclaimed: Healing (3x, 12min), Salvation (1x, 5min)").
- `givingDuration` removed from `ReportService._totalConsecratedMinutes`
  and from any report text.
- Extract a single shared helper (e.g. `TimeTotals.consecratedMinutes`)
  used by both `ReportService` and `ReflectionService`, replacing their
  currently-duplicated/divergent total-time computations.

### 3. Timer engine

- Proclamation moves onto `TimerService`, replacing the bespoke
  `_openProclamationCounter` (raw `dart:core Stopwatch`, bypasses
  foreground-service/overlay/notification support, and currently
  overwrites duration on save instead of accumulating).
- Starting a Proclamation timer first prompts for a topic via a quick
  picker: chips for today's existing topics + a free-text field for a new
  one. On stop, the topic-matching rule above applies.
- The same quick-picker screen is the destination for the Android
  widget's "+" tap (existing deep link `dailyaccount://open/proclamation`
  is reused, no new deep link needed).
- Fasting tile removed from the Stopwatch grid.
- `TimerService._writeToDailyLog` gains a session-append branch for
  Evangelism and Church (mirroring the existing Bible/DDEG/Prayer
  pattern) instead of scalar accumulation.

### 4. Settings — send channel configuration

- New setting `autoSendChannel`: `whatsapp` | `email` | `both`. Settings
  UI adds a segmented picker beside the existing Auto-Send toggle.
- Email option (and "both") is selectable only when: `discipleEmail` is
  present and passes a basic email regex, AND Google Sign-In is connected
  with the `gmail.send` scope granted. Otherwise those options are
  visibly disabled with an inline explanation.
- Google Sign-In (`cloud_sync_service.dart`) extends its requested scopes
  to include `https://www.googleapis.com/auth/gmail.send` alongside the
  existing `drive.appdata` scope. `google-services.json` is now in place
  under `android/app/`, registered against `com.jilengineering.dailyaccount`
  with both release and debug SHA-1 fingerprints — this was the blocker
  for Google Sign-In entirely (`DEVELOPER_ERROR` / 12500) and is now
  resolved.
- New `GmailApiService` (or extension of `CloudSyncService`) sends fully
  silently via the Gmail API (no `mailto:` client hand-off) using the
  authenticated user's OAuth token.
- `_checkAutoSend()` in `home_shell.dart` branches per configured
  channel, invoking `sendByWhatsApp` and/or the new silent Gmail send.
- Offline queue (`StorageService.queuePendingReport`) generalized from
  WhatsApp-only to a `channels` list; `_trySendPending()` retries each
  pending channel independently on every connectivity/resume check, with
  no time-based expiry — queued reports send whenever connectivity
  returns, regardless of how long the device stayed offline. The queue
  entry clears only once every requested channel has succeeded.
- Audit `settings_screen.dart` / `home_shell.dart` for any remaining
  hardcoded "Sunday" strings left over from the cadence refactor and
  correct them to reflect the configured cadence.

### 5. Home-screen widget (Proclamation)

- Add `proclamation_date_key` alongside the existing `proclamation_count`
  in the widget's SharedPreferences. Native display logic in
  `WidgetHelper` treats the count as 0 whenever the stored date key isn't
  today's date, closing the gap where a stale count could persist across
  midnight if the app isn't foregrounded.
- Add a `widgetTitle` setting, editable in a new "Home Widget" section of
  in-app Settings, pushed to widget SharedPreferences on save and read by
  `WidgetHelper` in place of the hardcoded Android string resource.

## Testing

- Unit tests for: `TimedSession` accumulation/topic-matching logic,
  `TimeTotals` shared helper (both report and reflection call sites),
  the generalized offline queue (multi-channel partial success).
- Manual verification on-device: Proclamation topic entry from both the
  in-app timer and the widget tap; midnight rollover behavior for the
  widget counter; auto-send with WhatsApp-only, Email-only, and Both,
  including one offline-then-reconnect scenario per channel.
- `flutter analyze` clean; existing test suite (`activity_timer_test.dart`,
  `report_cadence_service_test.dart`) still passes.

## Open items resolved during setup

- Google Sign-In was failing app-wide (`ApiException: 12500`) due to a
  missing `google-services.json` and no registered OAuth client for the
  app's package/signing certificates. Resolved: a Firebase project
  ("cmfi-daily-account") now has Android OAuth clients registered for
  both release and debug SHA-1 fingerprints, `google-services.json` is in
  place at `android/app/`, and the `gmail.send` scope has been added to
  the OAuth consent screen's Data Access configuration.
