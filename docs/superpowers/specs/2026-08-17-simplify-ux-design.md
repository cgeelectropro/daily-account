# Simplifying Daily Account's UX — Design

**Date:** 2026-08-17
**Status:** Draft for review

## Problem

Daily Account has grown from the 7-section app described in CLAUDE.md into
an app with 12 discipline sections on the Log screen and 14 settings
sections, plus goals, fasting periods, custom activities, reading plans,
cloud sync, and multiple report channels. Existing users absorbed this
gradually as features shipped one at a time. New users instead land on the
full surface area on day one, with:

- A single long scroll of 12 discipline `SectionCard`s on the Log screen,
  most `initiallyExpanded: true`.
- A single long scroll of 14 ungrouped `SectionCard`s on the Settings
  screen, most `initiallyExpanded: true`.
- No in-app guidance beyond a one-time 4-page onboarding flow
  (Welcome → How It Works → Profile → Language) that describes the app in
  the abstract but never points at the real UI.

The goal is not to remove features — it's to change what's *visible by
default* and to teach discovery in place, so a first-time user isn't
staring at the same density as a long-time member, while nothing is
actually taken away from anyone.

## Non-goals

- No new state-management architecture. This stays within the existing
  singleton-service pattern.
- No parallel "simple mode" screen/UI to maintain — one Log screen, one
  Settings screen, adjusted defaults and grouping.
- No change to data models, storage schema, or report generation.
- No forced flow — every collapse/hide is reversible by the user in one tap.

## Design

### 1. Settings: grouped, collapsed categories

Today `SettingsScreen` renders 14 `SectionCard`s flat, top to bottom:
Profile, Goals, Reading Plan, Disciple Maker, Widget Title, Theme,
Time-Conscious, Security, Notifications, Auto-Send, Language, Cloud
Backup, Backup, Report History — plus three non-collapsible `Container`
blocks at the very bottom (How It Works, About, Danger Zone) that add to
the visible scroll unconditionally.

Introduce one level of grouping via a new lightweight `SettingsGroup`
widget (header text + list of existing `SectionCard`s, no new visual
chrome beyond a label and spacing — the `SectionCard`s underneath are
unchanged). Groups, in display order:

- **Profile & Contacts** — Profile, Disciple Maker (expanded by default;
  this is what every user configures first)
- **Reminders & Delivery** — Notifications, Auto-Send, Time-Conscious
  (collapsed by default)
- **Personalize** — Theme, Widget Title, Language (collapsed by default)
- **Growth Tools** — Goals, Reading Plan (collapsed by default)
- **Advanced** — Security, Cloud Backup, Backup, Report History
  (collapsed by default)

This is a reorganization of existing `SectionCard`s, not new settings
logic — `initiallyExpanded` flips to `false` for everything except
Profile/Disciple Maker. A user who wants everything open still gets there
in one tap per group; nothing requires more taps than today to reach if
they already know where it is, and it requires far fewer if they don't.

The How It Works / About / Danger Zone blocks at the bottom are left
exactly as they are — per explicit decision, decluttering effort here
stays focused on the Notifications section (1a below) and the grouping
above, not on restructuring every corner of the screen.

A settings screen this size also benefits from search, but a search
affordance is deferred — see Future Work. Grouping alone addresses the
"scattered settings" complaint directly; search is additive polish, not
required to hit the goal.

### 1a. Notifications section → its own sub-screen

The Notifications `SectionCard` is the single largest contributor to
clutter: inline sound picker, a full diagnostics/health-check panel (with
a "tap to see pending notifications" dialog), daily/Sunday time pickers,
follow-up count sliders, a report cadence picker, a Save button, and 11
per-discipline reminder rows — all rendered at once whenever
notifications are enabled.

Split this into two layers:

- **Stays inline** in the Reminders & Delivery group: the on/off switch,
  the daily reminder time, and the report-day reminder time — the three
  things nearly every user sets once and rarely revisits.
- **Moves to a new `NotificationSettingsScreen`** (pushed via a
  "Notification settings →" row in the inline card, mirroring how
  `ReportHistoryScreen` is already reached from a button inside its
  section): notification sound picker, the diagnostics/health-check
  panel, follow-up count sliders, report cadence picker, and the
  per-discipline reminder list.

This is a pure move, not a rewrite — the extracted widgets/logic
(`_followUpSlider`, `_cadencePicker`, `_diagRow`,
`_disciplineReminderRow`, the sound-picker list, the diagnostics
container) transplant into the new screen's state largely unchanged,
since they already only depend on state (`_dailyFollowUps`,
`_selectedSound`, `_disciplineTimes`, etc.) and `StorageService`/
`NotificationService` calls that don't care which screen invokes them.

### 2. Log screen: core vs. more disciplines

Today `LogScreen` renders 12 discipline `SectionCard`s flat: Bible,
Literature, DDEG, Prayer Alone, Prayer Others, Evangelism, Fasting,
Giving, Church, Discipleship, Proclamation, Custom Activities.

Split into two visual bands, still one scroll, no navigation change:

- **Core** (always visible, `initiallyExpanded: true`): Bible,
  Literature, Prayer Alone, Evangelism — the four disciplines every CMFI
  member tracks daily and that already anchor the existing Quick Log
  sheet's most-used items.
- **More disciplines** (collapsed behind a single "More disciplines ▾"
  expander, itself a `SectionCard`-style toggle): DDEG, Prayer Others,
  Fasting, Giving, Church, Discipleship, Proclamation, Custom Activities.

This expander remembers its expanded/collapsed state per app session
(in-memory only — no new persisted setting) so a user who opens it once
doesn't have to re-open it every time they switch days within the same
session. If a discipline inside "More" already has data for the day
(e.g. imported from a widget toggle or auto-fill), the group defaults to
expanded for that day's view so nothing already filled in hides from the
user.

The existing Quick Log bottom sheet is untouched — it already covers all
11 disciplines with checkboxes and remains the fast path for catching up
on a busy day.

### 3. First-run guided walkthrough (coach marks)

New reusable widget, `CoachMark` / `CoachMarkSequence`, in
`lib/widgets/`: a spotlight overlay that highlights one target widget at
a time with a short caption and a "Next"/"Got it" control, using
`Overlay.of(context)` + `CompositedTransformTarget`/`GlobalKey` to locate
targets — no new package dependency.

Sequences, keyed by screen, shown automatically the first time that
screen is visited after onboarding:

- **Log screen** (3 steps): the Core section ("log the essentials
  here"), the "More disciplines" expander ("everything else lives
  here"), the Quick Log flash button ("busy day? tap here instead").
- **Report screen** (2 steps): the send button, the report history
  entry.
- **Settings screen** (3 steps): the new group headers ("tap a category
  to open it"), the disciple-maker contact field, the header `?` help
  icon ("stuck? tap here anytime").

State: one new `StorageService` setting per sequence,
e.g. `coachmark_log_shown`, `coachmark_report_shown`,
`coachmark_settings_shown` (string `'true'`/unset), checked in each
screen's `initState`/first frame the same way `onboarding_complete` is
checked today. A **"Replay tutorial"** action in the new Advanced
settings group clears all three flags so any user — including existing
members who want a refresher — can re-trigger every walkthrough on next
screen visit.

This is the piece that directly answers "a sort of way that leads you
into discovering the application... click here" — it points at the real,
live UI rather than describing it in an abstract onboarding slide.

### 4. Help & FAQ screen, reached from one global header icon

A new `HelpScreen` collects a usage guide and FAQ (what is DDEG, how
reports get sent, what Quick Log does, how reminders work, etc.) in one
scrollable place. The risk flagged during design was real: adding a help
screen to fix "too much stuff" can itself become one more thing to find
if it's positioned badly. The mitigation is placement, not content
scope — see below.

Placement: a small `?` icon in the header row, next to the existing
Prayer Requests button, present on every screen — not a Settings entry,
not a fifth bottom-nav tab. Two reasons this beats a Settings-screen
entry:

- **Settings means "change something."** Every visit to Settings to
  edit a reminder time or contact would otherwise scroll past a help
  entry first. A global header icon keeps Settings focused on
  configuration only.
- **Confusion happens on whatever screen the user is on.** Someone
  puzzled by "DDEG" on the Log screen shouldn't have to first navigate
  to Settings to ask; the icon is already there, in the same place,
  everywhere.

The header row already hosts the Prayer Requests button and (on the Log
tab) the Quick Log button — the `?` icon adds one more small icon to an
existing row, not a new UI region.

Per explicit decision, the existing "How It Works" card in Settings is
left as-is (see §1) — `HelpScreen` is additive, not a replacement for
it. It's still a net win for discoverability because it's the one place
that gathers FAQ-style content (discipline definitions, how auto-send
works, what Quick Log does) that today doesn't exist in the app at all,
reached from a spot that costs nothing extra to check.

### Data flow / error handling

No new persistence beyond three string flags in the existing
`SharedPreferences`-backed settings table (`StorageService.getSetting` /
`setSetting`, already used for `onboarding_complete`). No network calls,
no schema changes. If a coach mark's target widget isn't mounted yet
(e.g. rebuilt mid-sequence), the sequence should skip that step rather
than throw — mirrors the "never crash from X" defensive style already
used elsewhere in `HomeShell` (e.g. `_syncWidgetChangesToDb`).

### Testing

No test suite exists in this project today (per CLAUDE.md). Verification
will be manual: run the app, clear `onboarding_complete` and the three
coach-mark flags via a fresh install/emulator wipe, confirm each
walkthrough appears once, confirm "Replay tutorial" re-triggers them,
confirm Settings groups collapse/expand correctly, confirm Log screen's
Core/More split doesn't hide already-filled-in data, confirm the
Notifications sub-screen preserves every existing behavior (sound
preview, diagnostics fix button, per-discipline reminder bottom sheet,
follow-up sliders all still write the same `StorageService` keys), and
confirm the header `?` icon opens `HelpScreen` from every tab.

## Future work (explicitly deferred)

- Settings search bar.
- Any form of adaptive/usage-based unlocking (e.g. auto-revealing Growth
  Tools after N days of use) — starting with a static grouping first and
  observing whether that alone resolves the complaint.
