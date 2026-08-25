# Timer/Log/Report Field Parity — Design

Date: 2026-08-17
Status: Approved, ready for implementation planning

## Background

Production testing on the previous timer/report/send-channel batch surfaced
three further problems, all rooted in the same underlying issue: the
Stopwatch timer and the Log screen have never treated the same data as the
same data.

1. **Report visibility gap** (Bible reading, DDEG, Discipleship, Literature):
   the report's "does this day have content" check looks at a different
   field than the one the timer alone populates. A user who times Bible
   reading without typing a reference sees the duration in the Log screen
   but nothing in the report. Investigation found this is not "most
   activities" as first feared — Prayer (both), Fasting, Evangelism,
   Church, and Proclamation are correctly gated already; exactly four
   activities are affected, plus Literature has a second, worse bug where
   its title field is silently discarded by `TimerService._mergeLogField`
   even when the user does fill it in.
2. **Proclamation regressed from a counter to a timer.** The bug fix that
   stopped Proclamation's duration from being overwritten (instead of
   accumulated) also replaced its original tap-to-count interaction with
   the generic stopwatch UI. The counting interaction — the actual point
   of "Proclamation" as a discipline — was lost in that fix.
3. **Proclamation has no topic field in the Log screen's manual entry**,
   even though the Stopwatch timer flow (added in the same prior batch)
   asks for one. The two entry paths for the same discipline behave
   differently.

A deeper structural cause underlies all three: **Bible, DDEG, Prayer
(alone/with-others) each have a real structured session-list data model
(what the Log screen actually displays as cards), but the timer has only
ever written into old legacy scalar fields alongside that model.** A
timer-completed Bible reading does not create a `BibleReadingEntry` — it
sets `bibleReference`/`bibleChapters` strings that render only when the
session list is empty. Two parallel, half-connected data paths exist where
there should be one.

## Core principle

**The timer is not a separate input path that happens to feed the log — it
IS a way of filling in the log.** Whether a session's data comes from
typing directly into the Log screen or from running the Stopwatch timer,
it must land in the exact same underlying model (the same session list,
the same fields), be visible in the Log screen the moment it's saved, and
be counted by the report identically. There is no "timer data" and
"manual data" — there is only log data, entered by whichever method the
user chose. Every future check for "does this day have X" must be written
once, against the real model, and reused everywhere (report lines,
`completeness`, `_disciplineChecks`, PDF export, goals, report
intelligence) — not re-derived per consumer, which is what caused the
original report-visibility bug to slip through undetected in four
different files.

## Goals

- Every timer-completed session, for every activity, writes into the same
  structured model the Log screen displays and edits — never into a
  parallel legacy scalar.
- Every field visible in the Log screen for a given activity has a
  corresponding timer prompt, placed at Start if the value is genuinely
  knowable beforehand, or at Stop if only knowable after the activity —
  judged per field on its actual semantic content, not a blanket rule.
- Required fields (the entry is meaningless without them — e.g. Bible
  needs a reference, Discipleship needs a "who") block progress with an
  inline validation error; the action (Start or Save) stays tappable,
  the error appears under the empty field, nothing persists until fixed.
- Prayer Alone and Prayer with Others gain topic/burden-based multi-session
  support, matching Proclamation's existing case-insensitive
  merge-or-append-by-topic pattern exactly.
- Giving & Tithes becomes a list of entries per day (mirrors Literature's
  existing multi-book-entry pattern), so a tithe and a separate offering
  on the same day are two distinct, individually-editable entries.
- Every report surface (per-day text, weekly/monthly totals, PDF export,
  `completeness`, `_disciplineChecks`, goals, report intelligence) reflects
  the new session-based data correctly and consistently — built as shared
  logic from the start, not discovered gap-by-gap after the fact.
- Fasting's dead stopwatch pre-start-field code (unreachable since Fasting
  has no grid tile, by original design — fasting/tithes are correctly
  excluded from timing since they aren't bounded, moment-in-time
  activities) is removed.

## Non-goals

- No change to which activities get a Stopwatch tile at all — Fasting and
  Giving remain untimed, as originally decided.
- No change to the multi-day `FastingPeriod` tracker.
- No backend/cloud changes — this is entirely local data-model and UI work.

## Design

### 1. Data model changes

**`PrayerSession`** (used by both `prayerAloneSessions` and
`prayerOthersSessions`) gains a `title` field (String), matching
`ProclamationSession`'s topic in shape and matching rules
(case-insensitive, trimmed, merge-or-append via the same
`findMatchingIndex`-style helper already built for Proclamation — this
helper is generalized/shared rather than duplicated a third time).

- **Prayer Alone**: `title` becomes the burden/subject a session is
  filed under (e.g. "Healing for Mom"). The existing free-text "how was
  your prayer time" field becomes `notes`, an optional per-session
  reflection captured at Stop (moved from its current, semantically
  wrong Start-time placement — you can't truthfully describe a prayer
  time before it happens).
- **Prayer with Others**: the existing single `context` field ("Who /
  Where") is replaced by `title` as the first, most prominent field in
  both the Start-time timer prompt and the Log screen card. A new
  optional `peopleCount` field (int) is added, shown after title.

**`DailyLog.giving`** changes from four flat scalar fields
(`givingType`/`givingAmount`/`givingPurpose`, no duration field per the
prior removal) to `List<GivingEntry>` — mirrors `List<LiteratureEntry>`
exactly, including the "+ Add another" UI affordance in the Log screen.
Each `GivingEntry` has `type` (required), `amount` (optional),
`purpose` (optional). The legacy scalar fields remain in the model,
unused going forward; on first load with an empty list and non-empty
legacy scalars, one `GivingEntry` is synthesized from them — this
migration is written idempotently from the start (the legacy scalars are
cleared on the object returned by `fromMap` once migrated, exactly
mirroring the fix already applied to `ProclamationSession`'s migration
after that bug was found in the previous batch).

**`BibleReadingEntry`, `DdegSession`** gain no new fields — the fix here
is entirely about the *write path* (below), not the shape.

**`LiteratureEntry`** gains no new fields — the fix is the write-path bug
where `_mergeLogField` currently discards `literatureTitle`/
`literatureAmount` as no-ops.

### 2. Timer write path — session-first, not scalar-first

`TimerService._writeToDailyLog` is restructured so that, for every
activity with a structured session-list model (Bible, DDEG, Prayer Alone,
Prayer with Others, Proclamation — already correct, Evangelism/Church —
already correct via `TimedSession`), stopping a timer **appends or merges
into that list**, never writes a legacy scalar. Legacy scalars are read
by `fromMap`'s one-time migration path only, never written by new
activity going forward, for any of these five.

Literature's fix is narrower: `_mergeLogField`'s `literatureTitle`/
`literatureAmount` cases stop being no-ops and correctly construct/update
a `LiteratureEntry` in `log.literature`.

### 3. Prompt placement per activity (Start vs. Stop, required vs. optional)

| Activity | Start prompt | Stop prompt |
|---|---|---|
| Bible reading | Starting book/chapter (**required**) | Ending book/chapter (**required**) → chapters auto-calculated |
| Literature | Book title (**required**) | Amount + unit (**required**) |
| DDEG | Scripture (**required**) | Reflection notes (optional) |
| Prayer Alone | Title/burden (**required**, pick-existing-or-new like Proclamation) | Reflection notes (optional) |
| Prayer with Others | Title/burden (**required**, same pattern) | People count (optional) |
| Evangelism | *(none — nothing is truly known beforehand)* | Contacts reached (**required**) + people reached (**required**, newly prompted) + notes (optional) |
| Church | Which service/meeting (**required**) | Notes (optional, newly prompted) |
| Discipleship | Who (**required**) + topic (optional) | *(none — duration is automatic)* |
| Proclamation | Topic (**required**, pick-existing-or-new) | *(none — count and duration are fully automatic from tapping)* |
| Fasting, Giving | *(not timed — no Stopwatch tile, unchanged)* | — |

Duration itself is always automatic (the timer's own elapsed time) for
every activity — never a manual prompt.

### 4. Required-field validation

Matches the existing pattern already in the app (e.g. Bible's stop
dialog): the action button (Start, or Save at Stop) stays tappable at all
times. Attempting to proceed with a required field empty shows an inline
error under that field and does not start the timer / does not persist
the session. This applies identically at Start and at Stop — validation
timing follows the same UX regardless of which end of the session it's
attached to.

### 5. Proclamation counter restoration

The Stopwatch's Proclamation tile returns to a tap-to-count interaction
(the original design, before the override-bug fix inadvertently replaced
it): after the topic prompt, a large tappable circle increments a count
on each tap; a background stopwatch starts automatically on the first tap
and requires no user management (no visible pause/resume — it just runs
until Save). Save writes the topic, final count, and elapsed duration into
the matching `ProclamationSession` (merged by topic, per existing rules).
No change to the topic-matching logic itself — only the interaction after
the topic is chosen.

### 6. Log screen manual-entry parity

Every activity gains manual-entry parity with its timer counterpart:
Proclamation's Log screen section gains a topic field (reusing the same
merge-by-topic write path the timer uses — a manual entry with a matching
topic to an existing session that day merges into it, exactly as a second
timer run would). Prayer Alone/with Others' Log screen cards gain the new
title (and, for with-others, people-count) fields, writing through the
same shared session-list helpers the timer uses — this is the direct
expression of the core principle: one write path per model, reached from
two UI entry points.

### 7. Reporting

Every report surface that currently understands Proclamation's
session-list format (per-day topic listing, `TimeTotals` minute-summing,
`completeness`, `_disciplineChecks`, PDF export, goals,
`report_intelligence_service.dart`) is extended with the identical
pattern for the newly-titled Prayer Alone/Prayer-with-Others sessions and
the new Giving entry list:

- **Per-day report line**: lists each title/entry with its count and
  summed duration (Prayer) or type/amount/purpose (Giving), falling back
  to the old undifferentiated line for historical data with no titles/
  list entries.
- **Weekly/monthly totals**: sum across all titled sessions, reusing
  `TimeTotals`'s existing session-vs-scalar-fallback pattern.
- **`completeness`/`_disciplineChecks`/PDF/goals/intelligence**: each
  extended with the shared "has session data OR has legacy scalar" check,
  written once as a reusable helper this time rather than four times
  independently — the exact gap that caused the final-review fix wave in
  the previous batch. A single audit pass across all consumers of each
  changed field happens as part of implementation, before considering any
  task in this area complete.

### 8. Fasting dead-code removal

`stopwatch_screen.dart`'s `_fieldsFor(ActivityType.fasting)` case and its
associated `fastingType`/`fastingPrayerFocus` prompt strings are removed,
since `_activityGrid` already excludes Fasting from the grid entirely and
no code path can reach this case. `ActivityType.fasting` itself remains
in the enum (existing data, other switches depend on it existing) — only
the unreachable prompt-field code is deleted.

## Testing

- Unit tests per activity: timer-completed session correctly appends/
  merges into the real structured list (not a scalar); required-field
  validation blocks Start/Save with an empty required field and allows it
  once filled; a second same-topic session (Prayer Alone/Prayer-with-
  Others/Proclamation) merges into the existing one rather than creating
  a duplicate.
- Report tests: per-day line correctly reflects multi-title Prayer
  sessions and multi-entry Giving; `completeness`/`_disciplineChecks`
  correctly register a day logged purely via a newly-titled session with
  no legacy scalar touched.
- Manual on-device verification: Log screen reflects a timer-completed
  session immediately (same session, not a duplicate or a legacy-scalar
  ghost); Proclamation's counter screen behaves as a tap-counter, not a
  generic stopwatch; Giving section shows multiple entries with a working
  "+ Add another."
- `flutter analyze` clean; full existing test suite green.
