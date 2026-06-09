# Phase 1: Production-Ready Daily Account — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform Daily Account into a polished, bilingual (FR/EN), production-ready app with complete CMFI disciplines, onboarding, local backup, and professional UX — zero backend, zero cost.

**Architecture:** Offline-first Flutter app with SQLite + SharedPreferences. Adding Flutter i18n (ARB files + gen-l10n), 4 new CMFI disciplines to the data model, database migration v1→v2, onboarding flow, collapsible log sections, local JSON backup/restore, and full French translation.

**Tech Stack:** Flutter/Dart, sqflite, SharedPreferences, flutter_localizations, intl, file_picker, path_provider, share_plus, flutter_animate, google_fonts

---

## Task 1: Add New Dependencies & Configure i18n

**Files:**
- Modify: `pubspec.yaml`
- Create: `l10n.yaml`

- [ ] **Step 1: Update pubspec.yaml dependencies**

Add to `dependencies` section after `intl: ^0.19.0`:

```yaml
  flutter_localizations:
    sdk: flutter
  path_provider: ^2.1.4
  file_picker: ^8.1.6
  share_plus: ^9.0.0
```

- [ ] **Step 2: Add l10n configuration to pubspec.yaml**

Add at the top level (after `flutter:` section):

```yaml
# Already present:
# flutter:
#   uses-material-design: true

# No changes to flutter section needed - l10n.yaml handles config
```

- [ ] **Step 3: Create l10n.yaml**

Create `l10n.yaml` in project root:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: S
synthetic-package: true
nullable-getter: false
```

- [ ] **Step 4: Run flutter pub get**

```bash
cd "c:/Users/goodn/Developement/Flutter projects/daily_account"
flutter pub get
```

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock l10n.yaml
git commit -m "chore: add i18n, file_picker, path_provider, share_plus dependencies"
```

---

## Task 2: Create English ARB File (All App Strings)

**Files:**
- Create: `lib/l10n/app_en.arb`

- [ ] **Step 1: Create lib/l10n directory**

```bash
mkdir -p "c:/Users/goodn/Developement/Flutter projects/daily_account/lib/l10n"
```

- [ ] **Step 2: Create app_en.arb with all extractable strings**

Create `lib/l10n/app_en.arb`:

```json
{
  "@@locale": "en",
  "appTitle": "Daily Account",
  "tagline": "WALK WITH GOD · CMFI DISCIPLINE",
  "walkWithGod": "WALK WITH GOD",
  "cmfiDiscipline": "CMFI DISCIPLINE",
  "splashVerse": "\"Give an account of thy stewardship.\"\n— Luke 16:2",

  "tabLog": "Log",
  "tabReport": "Report",
  "tabSettings": "Settings",

  "completedLabel": "Completed",
  "markComplete": "Mark Day Complete",
  "markedComplete": "Completed",

  "sectionBible": "Bible Reading",
  "bibleRefLabel": "Passage / Reference",
  "bibleRefHint": "e.g. John 3; Romans 8",
  "bibleChaptersLabel": "Number of Chapters",
  "bibleChaptersHint": "e.g. 3",

  "sectionLiterature": "Christian Literature",
  "bookTitleLabel": "Book Title",
  "bookTitleHint": "e.g. The Normal Christian Life",
  "amountLabel": "Amount",
  "amountHint": "e.g. 15",
  "unitLabel": "UNIT",
  "unitPages": "Pages",
  "unitChapters": "Chapters",
  "unitBooks": "Books",
  "addAnotherBook": "Add another book",
  "remove": "Remove",

  "sectionDDEG": "Daily Dynamic Encounter with God",
  "ddegScriptureLabel": "Scripture Meditated On",
  "ddegScriptureHint": "e.g. Psalm 23:1",
  "ddegTimeLabel": "Time Spent",
  "ddegTimeHint": "e.g. 30 minutes",
  "ddegNotesLabel": "What God Spoke to You",
  "ddegNotesHint": "Write what the Lord revealed or impressed...",

  "sectionPrayerAlone": "Prayer — Alone with God",
  "durationLabel": "Duration",
  "durationHint": "e.g. 45 minutes",
  "prayerAloneNotesLabel": "How was your prayer time?",
  "prayerAloneNotesHint": "Burdens, intercessions, breakthroughs...",

  "sectionPrayerOthers": "Prayer with Others",
  "prayerOthersContextLabel": "Context (Who / Where)",
  "prayerOthersContextHint": "e.g. Cell group, prayer meeting",

  "sectionEvangelism": "Evangelism",
  "evangelismContactsLabel": "Number of Contacts",
  "evangelismContactsHint": "e.g. 2",
  "evangelismOutcomeLabel": "Outcome / Response",
  "evangelismOutcomeHint": "e.g. One received the gospel",
  "evangelismNotesLabel": "Notes / Follow-up",
  "evangelismNotesHint": "Names, conversations, next steps...",

  "sectionFasting": "Fasting",
  "fastingTypeLabel": "Type of Fast",
  "fastingTypeHint": "e.g. Full fast, partial, Daniel fast",
  "fastingDurationLabel": "Duration",
  "fastingDurationHint": "e.g. 6am – 6pm",
  "fastingPrayerFocusLabel": "Prayer Focus During Fast",
  "fastingPrayerFocusHint": "What you are seeking God for...",

  "sectionGiving": "Giving & Tithes",
  "givingTypeLabel": "Type",
  "givingTypeHint": "e.g. Tithe, offering, seed, missions",
  "givingAmountLabel": "Amount (optional)",
  "givingAmountHint": "e.g. 5000 FCFA",
  "givingPurposeLabel": "Purpose / Occasion",
  "givingPurposeHint": "e.g. Sunday offering, missions fund",

  "sectionChurch": "Church & Fellowship",
  "churchTypeLabel": "Service / Meeting",
  "churchTypeHint": "e.g. Sunday service, midweek, cell group",
  "churchNotesLabel": "Notes",
  "churchNotesHint": "Key lessons, word received...",

  "sectionDiscipleship": "Discipleship",
  "discipleshipWhoLabel": "Who Are You Discipling?",
  "discipleshipWhoHint": "Name(s) of disciples",
  "discipleshipTopicLabel": "What Did You Cover?",
  "discipleshipTopicHint": "e.g. Prayer life, consecration",
  "discipleshipDurationLabel": "Duration",
  "discipleshipDurationHint": "e.g. 1 hour",

  "sectionOther": "Other Activities",
  "otherLabel": "Other Spiritual Activities",
  "otherHint": "Fellowship, service, outreach, conferences...",

  "reportTitle": "Weekly Account",
  "reportSubtitle": "Your walk with God, this week",
  "streakDays": "{count} day{count, plural, =1{} other{s}}",
  "@streakDays": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "streakLabel": "Faithfulness streak",
  "daysLogged": "Days Logged",
  "bibleChapters": "Bible Chapters",
  "booksRead": "Books Read",
  "soulsReached": "Souls Reached",
  "sundayBanner": "It's Sunday — time to send your account to your disciple maker.",
  "previewLabel": "PREVIEW",
  "sendEmail": "Send via Email",
  "sendWhatsApp": "WhatsApp",
  "copyReport": "Copy",
  "reportCopied": "Report copied to clipboard.",
  "noReportYet": "No entries this week yet.\nStart logging your walk with God!",
  "confirmSendTitle": "Send Report?",
  "confirmSendBody": "Send your weekly account to your disciple maker?",
  "cancel": "Cancel",
  "send": "Send",

  "settingsTitle": "Settings",
  "profileSection": "Your Profile",
  "yourNameLabel": "Your Name",
  "yourNameHint": "e.g. Emmanuel",
  "discipleMakerSection": "Disciple Maker",
  "emailLabel": "Email Address",
  "emailHint": "disciplemaker@example.com",
  "whatsappLabel": "WhatsApp Number (intl, no +)",
  "whatsappHint": "e.g. 237670000000",
  "remindersSection": "Reminders",
  "dailyReminder": "Daily log reminder",
  "sundayReminder": "Sunday send reminder",
  "saveReminders": "Save & Schedule Reminders",
  "remindersSaved": "Reminders scheduled!",
  "languageSection": "Language",
  "languageEnglish": "English",
  "languageFrench": "Français",
  "howItWorksTitle": "How it works",
  "howItWorks": "1. Log your walk with God each day\n2. Mark each day complete ✅\n3. Get a gentle reminder daily, and a special one each Sunday\n4. Tap Send to email or WhatsApp the full week to your disciple maker\n5. Everything is stored privately on your device",

  "backupSection": "Backup & Restore",
  "exportData": "Export Data",
  "importData": "Import Data",
  "exportSuccess": "Backup saved successfully!",
  "importSuccess": "Data imported successfully!",
  "importFailed": "Import failed. Invalid file format.",
  "importMerge": "Merge with existing data",
  "importReplace": "Replace all data",
  "importPreview": "{count} days of logs found",
  "@importPreview": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },

  "onboardingWelcome": "Welcome to\nDaily Account",
  "onboardingWelcomeSub": "Track your daily walk with God.\nStay accountable. Grow in faith.",
  "onboardingHow": "How It Works",
  "onboardingHowStep1": "Log your spiritual disciplines each day",
  "onboardingHowStep2": "Track Bible reading, prayer, fasting, evangelism, and more",
  "onboardingHowStep3": "Send your weekly account to your disciple maker every Sunday",
  "onboardingProfile": "Your Profile",
  "onboardingProfileSub": "Tell us a little about you",
  "onboardingLanguage": "Choose Your Language",
  "onboardingStart": "Begin Your Journey",
  "next": "Next",
  "skip": "Skip",
  "back": "Back",

  "notifDailyTitle": "Daily Account",
  "notifDailyBody": "Have you recorded your walk with God today? Tap to log it.",
  "notifSundayTitle": "Sunday — Send Your Account",
  "notifSundayBody": "Send this week's account to your disciple maker. Tap to review & send.",

  "reportHeader": "DAILY ACCOUNT — {name}",
  "@reportHeader": {
    "placeholders": { "name": { "type": "String" } }
  },
  "reportWeekOf": "Week of {start} – {end}",
  "@reportWeekOf": {
    "placeholders": {
      "start": { "type": "String" },
      "end": { "type": "String" }
    }
  },
  "reportNoEntry": "No entry recorded.",
  "reportBible": "Bible: {ref} ({chapters} ch.)",
  "@reportBible": {
    "placeholders": {
      "ref": { "type": "String" },
      "chapters": { "type": "String" }
    }
  },
  "reportLiterature": "Literature: \"{title}\" — {amount} {unit}",
  "@reportLiterature": {
    "placeholders": {
      "title": { "type": "String" },
      "amount": { "type": "String" },
      "unit": { "type": "String" }
    }
  },
  "reportDDEG": "DDEG — Encounter with God:",
  "reportDDEGScripture": "   Scripture: {scripture}",
  "@reportDDEGScripture": {
    "placeholders": { "scripture": { "type": "String" } }
  },
  "reportDDEGTime": "   Time: {time}",
  "@reportDDEGTime": {
    "placeholders": { "time": { "type": "String" } }
  },
  "reportDDEGMeditation": "   Meditation: {notes}",
  "@reportDDEGMeditation": {
    "placeholders": { "notes": { "type": "String" } }
  },
  "reportPrayerAlone": "Prayer (Alone): {duration} — {notes}",
  "@reportPrayerAlone": {
    "placeholders": {
      "duration": { "type": "String" },
      "notes": { "type": "String" }
    }
  },
  "reportPrayerOthers": "Prayer (with others): {duration} — {context}",
  "@reportPrayerOthers": {
    "placeholders": {
      "duration": { "type": "String" },
      "context": { "type": "String" }
    }
  },
  "reportEvangelism": "Evangelism: {contacts} contact(s). {outcome}. {notes}",
  "@reportEvangelism": {
    "placeholders": {
      "contacts": { "type": "String" },
      "outcome": { "type": "String" },
      "notes": { "type": "String" }
    }
  },
  "reportFasting": "Fasting: {type} ({duration}) — {focus}",
  "@reportFasting": {
    "placeholders": {
      "type": { "type": "String" },
      "duration": { "type": "String" },
      "focus": { "type": "String" }
    }
  },
  "reportGiving": "Giving: {type} — {purpose}",
  "@reportGiving": {
    "placeholders": {
      "type": { "type": "String" },
      "purpose": { "type": "String" }
    }
  },
  "reportChurch": "Church: {type} — {notes}",
  "@reportChurch": {
    "placeholders": {
      "type": { "type": "String" },
      "notes": { "type": "String" }
    }
  },
  "reportDiscipleship": "Discipleship: {who} — {topic} ({duration})",
  "@reportDiscipleship": {
    "placeholders": {
      "who": { "type": "String" },
      "topic": { "type": "String" },
      "duration": { "type": "String" }
    }
  },
  "reportOther": "Other: {other}",
  "@reportOther": {
    "placeholders": { "other": { "type": "String" } }
  },
  "reportFooter": "Sent with love · Daily Account",
  "reportEmailSubject": "Weekly Spiritual Account — {name} ({date})",
  "@reportEmailSubject": {
    "placeholders": {
      "name": { "type": "String" },
      "date": { "type": "String" }
    }
  },
  "emailError": "Could not open email app.",
  "whatsappError": "Could not open WhatsApp.",
  "invalidEmail": "Please enter a valid email address.",
  "invalidWhatsapp": "Please enter a valid phone number (digits only, 10-15 chars)."
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/app_en.arb
git commit -m "feat: add complete English ARB strings for i18n"
```

---

## Task 3: Create French ARB File

**Files:**
- Create: `lib/l10n/app_fr.arb`

- [ ] **Step 1: Create app_fr.arb with all French translations**

Create `lib/l10n/app_fr.arb` with translations of every key from `app_en.arb`. Same structure, `"@@locale": "fr"`, all values in French. Key translations:

- "Daily Account" → "Compte Journalier"
- "Walk with God" → "MARCHER AVEC DIEU"
- "CMFI Discipline" → "DISCIPLINE CMFI"
- "Bible Reading" → "Lecture de la Bible"
- "Christian Literature" → "Littérature Chrétienne"
- "Daily Dynamic Encounter with God" → "Rencontre Dynamique Quotidienne avec Dieu"
- "Prayer — Alone with God" → "Prière — Seul avec Dieu"
- "Prayer with Others" → "Prière avec les Autres"
- "Evangelism" → "Évangélisation"
- "Fasting" → "Jeûne"
- "Giving & Tithes" → "Dons et Dîmes"
- "Church & Fellowship" → "Église et Communion"
- "Discipleship" → "Discipulat"
- "Other Activities" → "Autres Activités"
- "Disciple Maker" → "Faiseur de Disciples"
- "Weekly Account" → "Compte Hebdomadaire"
- "Faithfulness streak" → "Série de fidélité"
- "Settings" → "Paramètres"
- "Reminders" → "Rappels"

All report strings, onboarding, notifications, backup messages — everything translated.

- [ ] **Step 2: Commit**

```bash
git add lib/l10n/app_fr.arb
git commit -m "feat: add complete French ARB translations"
```

---

## Task 4: Update DailyLog Model with New CMFI Disciplines

**Files:**
- Modify: `lib/models/daily_log.dart`

- [ ] **Step 1: Add new fields to DailyLog class**

Add after `String other` (line 31):

```dart
  // ── Fasting ──
  final String fastingType;
  final String fastingDuration;
  final String fastingPrayerFocus;
  // ── Giving & Tithes ──
  final String givingType;
  final String givingAmount;
  final String givingPurpose;
  // ── Church & Fellowship ──
  final String churchType;
  final String churchNotes;
  // ── Discipleship ──
  final String discipleshipWho;
  final String discipleshipTopic;
  final String discipleshipDuration;
```

- [ ] **Step 2: Update constructor**

Add all new fields with `this.fastingType = ''` defaults in the constructor.

- [ ] **Step 3: Update completeness getter**

Change from 7 sections to 11:

```dart
double get completeness {
  var filled = 0;
  if (bibleReference.isNotEmpty || bibleChapters.isNotEmpty) filled++;
  if (literature.any((e) => e.title.isNotEmpty)) filled++;
  if (ddegScripture.isNotEmpty || ddegNotes.isNotEmpty) filled++;
  if (prayerAloneDuration.isNotEmpty) filled++;
  if (prayerOthersDuration.isNotEmpty) filled++;
  if (evangelismContacts.isNotEmpty) filled++;
  if (fastingType.isNotEmpty || fastingDuration.isNotEmpty) filled++;
  if (givingType.isNotEmpty) filled++;
  if (churchType.isNotEmpty) filled++;
  if (discipleshipWho.isNotEmpty) filled++;
  if (other.isNotEmpty) filled++;
  return filled / 11;
}
```

- [ ] **Step 4: Update toMap()**

Add all new fields to the map serialization.

- [ ] **Step 5: Update fromMap()**

Add all new fields to the factory constructor with `m['fieldName'] ?? ''` fallbacks.

- [ ] **Step 6: Commit**

```bash
git add lib/models/daily_log.dart
git commit -m "feat: add fasting, giving, church, discipleship to DailyLog model"
```

---

## Task 5: Database Migration v1 → v2

**Files:**
- Modify: `lib/services/storage_service.dart`

- [ ] **Step 1: Update database version and add migration**

Change `_init()` method:

```dart
Future<Database> _init() async {
  final dbPath = await getDatabasesPath();
  return openDatabase(
    join(dbPath, 'daily_account.db'),
    version: 2,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE logs (
          dateKey TEXT PRIMARY KEY,
          bibleReference TEXT,
          bibleChapters TEXT,
          literature TEXT,
          ddegScripture TEXT,
          ddegTime TEXT,
          ddegNotes TEXT,
          prayerAloneDuration TEXT,
          prayerAloneNotes TEXT,
          prayerOthersDuration TEXT,
          prayerOthersContext TEXT,
          evangelismContacts TEXT,
          evangelismOutcome TEXT,
          evangelismNotes TEXT,
          other TEXT,
          aiReflection TEXT,
          completed INTEGER,
          fastingType TEXT DEFAULT '',
          fastingDuration TEXT DEFAULT '',
          fastingPrayerFocus TEXT DEFAULT '',
          givingType TEXT DEFAULT '',
          givingAmount TEXT DEFAULT '',
          givingPurpose TEXT DEFAULT '',
          churchType TEXT DEFAULT '',
          churchNotes TEXT DEFAULT '',
          discipleshipWho TEXT DEFAULT '',
          discipleshipTopic TEXT DEFAULT '',
          discipleshipDuration TEXT DEFAULT ''
        )
      ''');
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        final newCols = [
          'fastingType', 'fastingDuration', 'fastingPrayerFocus',
          'givingType', 'givingAmount', 'givingPurpose',
          'churchType', 'churchNotes',
          'discipleshipWho', 'discipleshipTopic', 'discipleshipDuration',
        ];
        for (final col in newCols) {
          await db.execute("ALTER TABLE logs ADD COLUMN $col TEXT DEFAULT ''");
        }
      }
    },
  );
}
```

- [ ] **Step 2: Update saveLog to include new fields**

Ensure `log.toMap()` already includes all new fields (handled by Task 4).

- [ ] **Step 3: Commit**

```bash
git add lib/services/storage_service.dart
git commit -m "feat: database migration v2 — add fasting, giving, church, discipleship columns"
```

---

## Task 6: Wire i18n into MaterialApp

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Run flutter gen-l10n to generate localization files**

```bash
cd "c:/Users/goodn/Developement/Flutter projects/daily_account"
flutter gen-l10n
```

- [ ] **Step 2: Update main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await NotificationService.instance.init();
  runApp(const DailyAccountApp());
}

class DailyAccountApp extends StatefulWidget {
  const DailyAccountApp({super.key});

  static void setLocale(BuildContext context, Locale locale) {
    context.findAncestorStateOfType<_DailyAccountAppState>()?.setLocale(locale);
  }

  @override
  State<DailyAccountApp> createState() => _DailyAccountAppState();
}

class _DailyAccountAppState extends State<DailyAccountApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final lang = await StorageService.instance.getSetting('language', fallback: '');
    if (lang.isNotEmpty && mounted) {
      setState(() => _locale = Locale(lang));
    }
  }

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
    StorageService.instance.setSetting('language', locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Account',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData(),
      locale: _locale,
      supportedLocales: S.supportedLocales,
      localizationsDelegates: S.localizationsDelegates,
      home: const SplashScreen(),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire i18n with locale switching into MaterialApp"
```

---

## Task 7: Create Onboarding Screen

**Files:**
- Create: `lib/screens/onboarding_screen.dart`

- [ ] **Step 1: Create the onboarding screen**

A 4-page PageView: Welcome → How It Works → Profile (name + disciple maker) → Language selector. Saves settings to SharedPreferences. Sets `onboarding_complete` flag. Navigates to HomeShell on completion. Uses the app's gold/espresso theme with `flutter_animate` for page transitions.

Each page is a simple Column with the app's display/serif typography. Profile page has inline GoldField inputs. Language page has two large selectable cards (EN/FR).

"Next" / "Back" / "Skip" navigation. Final page shows "Begin Your Journey" button.

- [ ] **Step 2: Commit**

```bash
git add lib/screens/onboarding_screen.dart
git commit -m "feat: add 4-page onboarding flow with profile setup and language selection"
```

---

## Task 8: Update Splash Screen to Route Based on Onboarding State

**Files:**
- Modify: `lib/screens/splash_screen.dart`

- [ ] **Step 1: Check onboarding flag and route accordingly**

In `initState()`, change the navigation delay to:

```dart
Future.delayed(const Duration(milliseconds: 3200), () async {
  if (!mounted) return;
  final done = await StorageService.instance.getSetting('onboarding_complete');
  final destination = done == 'true' ? const HomeShell() : const OnboardingScreen();
  if (mounted) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionDuration: const Duration(milliseconds: 800),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
});
```

Add imports for `StorageService` and `OnboardingScreen`.

- [ ] **Step 2: Commit**

```bash
git add lib/screens/splash_screen.dart
git commit -m "feat: route splash to onboarding or home based on first-launch flag"
```

---

## Task 9: Update Log Screen with New Disciplines + Collapsible Sections

**Files:**
- Modify: `lib/screens/log_screen.dart`
- Modify: `lib/widgets/common_widgets.dart`

- [ ] **Step 1: Add collapsible behavior to SectionCard**

Update `SectionCard` in `common_widgets.dart` to accept `bool initiallyExpanded` and wrap children in an `AnimatedCrossFade` or expandable area. Tap the header to toggle. Sections with data start expanded; empty sections start collapsed.

```dart
class SectionCard extends StatefulWidget {
  final String icon;
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;
  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.initiallyExpanded = true,
  });

  @override
  State<SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<SectionCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.gold.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text(widget.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.title, style: AppTheme.display(18, color: AppTheme.gold)),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.clay,
                  size: 22,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 16),
            ...widget.children,
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add new discipline sections to LogScreen**

Add 4 new SectionCard widgets in `log_screen.dart` after the existing Evangelism section:

- **Fasting** (3 GoldFields: type, duration, prayer focus)
- **Giving & Tithes** (3 GoldFields: type, amount, purpose)
- **Church & Fellowship** (2 GoldFields: service type, notes)
- **Discipleship** (3 GoldFields: who, topic, duration)

Wire each to `_log` fields and `_persist()`.

- [ ] **Step 3: Replace all hardcoded strings with S.of(context) calls**

Replace every string literal in LogScreen with the corresponding localization key. Example:

```dart
// Before:
SectionCard(icon: '📖', title: 'Bible Reading', ...)
// After:
SectionCard(icon: '📖', title: S.of(context).sectionBible, ...)
```

- [ ] **Step 4: Set initiallyExpanded based on data**

```dart
SectionCard(
  icon: '📖',
  title: S.of(context).sectionBible,
  initiallyExpanded: _log.bibleReference.isNotEmpty || _log.bibleChapters.isNotEmpty,
  children: [...],
)
```

- [ ] **Step 5: Commit**

```bash
git add lib/screens/log_screen.dart lib/widgets/common_widgets.dart
git commit -m "feat: add fasting, giving, church, discipleship sections + collapsible cards + i18n"
```

---

## Task 10: Update Report Service & Screen with New Disciplines + i18n

**Files:**
- Modify: `lib/services/report_service.dart`
- Modify: `lib/screens/report_screen.dart`

- [ ] **Step 1: Update buildWeeklyReport to accept localization and include new disciplines**

Change method signature to accept a `S` localization object (or pass pre-resolved strings). Add report sections for Fasting, Giving, Church, Discipleship using the localized report strings.

- [ ] **Step 2: Update ReportScreen with i18n, empty states, confirmation dialog**

Replace all hardcoded strings with `S.of(context)` calls. Add empty state when `_stats?.daysLogged == 0`:

```dart
if (_stats != null && _stats!.daysLogged == 0)
  Center(child: Text(S.of(context).noReportYet, textAlign: TextAlign.center, style: AppTheme.serif(15, color: AppTheme.sand)))
```

Add confirmation dialog before sending email/WhatsApp.

- [ ] **Step 3: Remove unused import in report_service.dart**

Remove `import '../models/daily_log.dart';` (line 3) which the analyzer flagged as unused.

- [ ] **Step 4: Commit**

```bash
git add lib/services/report_service.dart lib/screens/report_screen.dart
git commit -m "feat: update report with new disciplines, i18n, empty states, confirm dialog"
```

---

## Task 11: Update Home Shell & Settings with i18n + Language Toggle

**Files:**
- Modify: `lib/screens/home_shell.dart`
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Replace all hardcoded strings in HomeShell with S.of(context)**

- [ ] **Step 2: Add Language section to SettingsScreen**

Add a new SectionCard with two selectable cards (English / Français). On selection, call `DailyAccountApp.setLocale(context, Locale('fr'))` or `Locale('en')`.

- [ ] **Step 3: Add Backup & Restore section to SettingsScreen**

Two buttons: "Export Data" and "Import Data". Wire to BackupService (Task 12).

- [ ] **Step 4: Add validation to email and WhatsApp fields**

Email: basic format check on save. WhatsApp: digits only, 10-15 chars.

- [ ] **Step 5: Replace all hardcoded strings in SettingsScreen with S.of(context)**

- [ ] **Step 6: Commit**

```bash
git add lib/screens/home_shell.dart lib/screens/settings_screen.dart
git commit -m "feat: add language toggle, backup section, validation, i18n to settings & nav"
```

---

## Task 12: Create Backup Service (Export/Import)

**Files:**
- Create: `lib/services/backup_service.dart`

- [ ] **Step 1: Create BackupService singleton**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'storage_service.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  Future<bool> exportData() async {
    final logs = await StorageService.instance.getAllLogs();
    final settings = <String, String>{};
    for (final key in ['myName', 'discipleEmail', 'discipleWhatsApp', 'language',
        'dailyHour', 'dailyMin', 'sundayHour', 'sundayMin']) {
      settings[key] = await StorageService.instance.getSetting(key);
    }
    final data = {
      'version': 2,
      'exportDate': DateTime.now().toIso8601String(),
      'settings': settings,
      'logs': logs.map((l) => l.toMap()).toList(),
    };
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getTemporaryDirectory();
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final file = File('${dir.path}/daily_account_backup_$date.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)], text: 'Daily Account Backup');
    return true;
  }

  Future<Map<String, dynamic>?> pickAndPreview() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;
    try {
      final file = File(result.files.single.path!);
      final json = await file.readAsString();
      final data = jsonDecode(json) as Map<String, dynamic>;
      if (!data.containsKey('logs')) return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<bool> importData(Map<String, dynamic> data, {bool merge = true}) async {
    try {
      final logs = (data['logs'] as List).cast<Map<String, dynamic>>();
      final storage = StorageService.instance;
      if (!merge) {
        // Clear existing logs — import replaces all
        final db = await storage.database;
        await db.delete('logs');
      }
      for (final logMap in logs) {
        final log = DailyLog.fromMap(logMap);
        await storage.saveLog(log);
      }
      // Import settings if present
      if (data['settings'] != null) {
        final settings = (data['settings'] as Map<String, dynamic>).cast<String, String>();
        for (final entry in settings.entries) {
          if (entry.value.isNotEmpty) {
            await storage.setSetting(entry.key, entry.value);
          }
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
```

Add `import '../models/daily_log.dart';` at top.

- [ ] **Step 2: Commit**

```bash
git add lib/services/backup_service.dart
git commit -m "feat: add BackupService for JSON export/import with share and file picker"
```

---

## Task 13: Update Notification Service with i18n

**Files:**
- Modify: `lib/services/notification_service.dart`

- [ ] **Step 1: Make notification text configurable**

Update `scheduleDailyReminder` and `scheduleSundayReminder` to accept title and body strings:

```dart
Future<void> scheduleDailyReminder(int hour, int minute, {String? title, String? body}) async {
  await _plugin.cancel(1);
  await _plugin.zonedSchedule(
    1,
    title ?? 'Daily Account',
    body ?? 'Have you recorded your walk with God today?',
    _nextInstanceOfTime(hour, minute),
    // ... rest unchanged
  );
}
```

Same pattern for `scheduleSundayReminder`. The SettingsScreen passes localized strings when scheduling.

- [ ] **Step 2: Commit**

```bash
git add lib/services/notification_service.dart
git commit -m "feat: make notification text configurable for i18n"
```

---

## Task 14: Final Integration, Version Bump & Cleanup

**Files:**
- Modify: `pubspec.yaml` (version bump)
- Modify: `lib/screens/splash_screen.dart` (i18n)
- All screens: final i18n pass

- [ ] **Step 1: Replace splash screen hardcoded text with S.of(context)**

The splash screen needs localized text. Since `S.of(context)` may not be available during splash (before MaterialApp is built), use a fallback: load language from SharedPreferences synchronously or use both languages on splash.

Better approach: keep the splash visual-only (cross animation) and move the text to appear after the localization context is available. The scripture verse and app name use AppTheme typography with no localization dependency — they are brand elements that stay in English. The tagline "WALK WITH GOD" / "CMFI DISCIPLINE" stays as-is on splash.

- [ ] **Step 2: Bump version in pubspec.yaml**

```yaml
version: 1.1.0+2
```

- [ ] **Step 3: Run flutter gen-l10n and verify**

```bash
flutter gen-l10n
flutter analyze
```

Fix any issues.

- [ ] **Step 4: Run the app on device and verify all flows**

```bash
flutter run
```

Test: onboarding → log all 11 disciplines → switch language → send report → export backup → import backup.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: phase 1 complete — bilingual, 11 CMFI disciplines, onboarding, backup"
```

---

## Task Summary

| Task | Description | Files |
|------|------------|-------|
| 1 | Dependencies & i18n config | pubspec.yaml, l10n.yaml |
| 2 | English ARB strings | lib/l10n/app_en.arb |
| 3 | French ARB strings | lib/l10n/app_fr.arb |
| 4 | DailyLog model — new disciplines | lib/models/daily_log.dart |
| 5 | Database migration v1→v2 | lib/services/storage_service.dart |
| 6 | Wire i18n into MaterialApp | lib/main.dart |
| 7 | Onboarding screen | lib/screens/onboarding_screen.dart |
| 8 | Splash routing (onboarding check) | lib/screens/splash_screen.dart |
| 9 | Log screen — new sections + collapsible + i18n | lib/screens/log_screen.dart, lib/widgets/common_widgets.dart |
| 10 | Report — new disciplines + i18n + UX | lib/services/report_service.dart, lib/screens/report_screen.dart |
| 11 | Settings + HomeShell — language, backup, validation, i18n | lib/screens/settings_screen.dart, lib/screens/home_shell.dart |
| 12 | Backup service | lib/services/backup_service.dart |
| 13 | Notification i18n | lib/services/notification_service.dart |
| 14 | Integration, version bump, final verification | All files |
