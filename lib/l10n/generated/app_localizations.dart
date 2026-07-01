import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Account'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'WALK WITH GOD · CMFI DISCIPLINE'**
  String get tagline;

  /// No description provided for @walkWithGod.
  ///
  /// In en, this message translates to:
  /// **'WALK WITH GOD'**
  String get walkWithGod;

  /// No description provided for @cmfiDiscipline.
  ///
  /// In en, this message translates to:
  /// **'CMFI DISCIPLINE'**
  String get cmfiDiscipline;

  /// No description provided for @splashVerse.
  ///
  /// In en, this message translates to:
  /// **'\"Give an account of thy stewardship.\"\n— Luke 16:2'**
  String get splashVerse;

  /// No description provided for @tabLog.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get tabLog;

  /// No description provided for @tabReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get tabReport;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @markComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark Day Complete'**
  String get markComplete;

  /// No description provided for @markedComplete.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get markedComplete;

  /// No description provided for @sectionBible.
  ///
  /// In en, this message translates to:
  /// **'Bible Reading'**
  String get sectionBible;

  /// No description provided for @bibleRefLabel.
  ///
  /// In en, this message translates to:
  /// **'Passage / Reference'**
  String get bibleRefLabel;

  /// No description provided for @bibleRefHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. John 3; Romans 8'**
  String get bibleRefHint;

  /// No description provided for @bibleChaptersLabel.
  ///
  /// In en, this message translates to:
  /// **'Number of Chapters'**
  String get bibleChaptersLabel;

  /// No description provided for @bibleChaptersHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 3'**
  String get bibleChaptersHint;

  /// No description provided for @bibleSessionFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get bibleSessionFrom;

  /// No description provided for @bibleSessionTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get bibleSessionTo;

  /// No description provided for @bibleSessionBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get bibleSessionBook;

  /// No description provided for @bibleSessionChapter.
  ///
  /// In en, this message translates to:
  /// **'Ch.'**
  String get bibleSessionChapter;

  /// No description provided for @bibleSessionChaptersResult.
  ///
  /// In en, this message translates to:
  /// **'= {count} chapter(s)'**
  String bibleSessionChaptersResult(int count);

  /// No description provided for @addReadingSession.
  ///
  /// In en, this message translates to:
  /// **'Add reading session'**
  String get addReadingSession;

  /// No description provided for @removeSession.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeSession;

  /// No description provided for @durationCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get durationCustom;

  /// No description provided for @sectionLiterature.
  ///
  /// In en, this message translates to:
  /// **'Christian Literature'**
  String get sectionLiterature;

  /// No description provided for @bookTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Book Title'**
  String get bookTitleLabel;

  /// No description provided for @bookTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. The Normal Christian Life'**
  String get bookTitleHint;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// No description provided for @amountHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 15'**
  String get amountHint;

  /// No description provided for @unitLabel.
  ///
  /// In en, this message translates to:
  /// **'UNIT'**
  String get unitLabel;

  /// No description provided for @unitPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get unitPages;

  /// No description provided for @unitChapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get unitChapters;

  /// No description provided for @unitBooks.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get unitBooks;

  /// No description provided for @addAnotherBook.
  ///
  /// In en, this message translates to:
  /// **'Add another book'**
  String get addAnotherBook;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @sectionDDEG.
  ///
  /// In en, this message translates to:
  /// **'Daily Dynamic Encounter with God'**
  String get sectionDDEG;

  /// No description provided for @ddegScriptureLabel.
  ///
  /// In en, this message translates to:
  /// **'Scripture Meditated On'**
  String get ddegScriptureLabel;

  /// No description provided for @ddegScriptureHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Psalm 23:1'**
  String get ddegScriptureHint;

  /// No description provided for @ddegTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time Spent'**
  String get ddegTimeLabel;

  /// No description provided for @ddegTimeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 30 minutes'**
  String get ddegTimeHint;

  /// No description provided for @ddegNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'What God Spoke to You'**
  String get ddegNotesLabel;

  /// No description provided for @ddegNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Write what the Lord revealed or impressed...'**
  String get ddegNotesHint;

  /// No description provided for @sectionPrayerAlone.
  ///
  /// In en, this message translates to:
  /// **'Prayer — Alone with God'**
  String get sectionPrayerAlone;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationLabel;

  /// No description provided for @durationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 45 minutes'**
  String get durationHint;

  /// No description provided for @prayerAloneNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'How was your prayer time?'**
  String get prayerAloneNotesLabel;

  /// No description provided for @prayerAloneNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Burdens, intercessions, breakthroughs...'**
  String get prayerAloneNotesHint;

  /// No description provided for @sectionPrayerOthers.
  ///
  /// In en, this message translates to:
  /// **'Prayer with Others'**
  String get sectionPrayerOthers;

  /// No description provided for @prayerOthersContextLabel.
  ///
  /// In en, this message translates to:
  /// **'Context (Who / Where)'**
  String get prayerOthersContextLabel;

  /// No description provided for @prayerOthersContextHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Cell group, prayer meeting'**
  String get prayerOthersContextHint;

  /// No description provided for @sectionEvangelism.
  ///
  /// In en, this message translates to:
  /// **'Evangelism'**
  String get sectionEvangelism;

  /// No description provided for @evangelismContactsLabel.
  ///
  /// In en, this message translates to:
  /// **'Gospel tracts distributed'**
  String get evangelismContactsLabel;

  /// No description provided for @evangelismContactsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 5'**
  String get evangelismContactsHint;

  /// No description provided for @evangelismOutcomeLabel.
  ///
  /// In en, this message translates to:
  /// **'People reached by the gospel'**
  String get evangelismOutcomeLabel;

  /// No description provided for @evangelismOutcomeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 3'**
  String get evangelismOutcomeHint;

  /// No description provided for @evangelismNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes / Follow-up'**
  String get evangelismNotesLabel;

  /// No description provided for @evangelismNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Names, conversations, next steps...'**
  String get evangelismNotesHint;

  /// No description provided for @sectionFasting.
  ///
  /// In en, this message translates to:
  /// **'Fasting'**
  String get sectionFasting;

  /// No description provided for @fastingTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type of Fast'**
  String get fastingTypeLabel;

  /// No description provided for @fastingTypeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Full fast, partial, Daniel fast'**
  String get fastingTypeHint;

  /// No description provided for @fastingDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get fastingDurationLabel;

  /// No description provided for @fastingDurationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 6am – 6pm'**
  String get fastingDurationHint;

  /// No description provided for @fastingPrayerFocusLabel.
  ///
  /// In en, this message translates to:
  /// **'Prayer Focus During Fast'**
  String get fastingPrayerFocusLabel;

  /// No description provided for @fastingPrayerFocusHint.
  ///
  /// In en, this message translates to:
  /// **'What you are seeking God for...'**
  String get fastingPrayerFocusHint;

  /// No description provided for @sectionGiving.
  ///
  /// In en, this message translates to:
  /// **'Giving & Tithes'**
  String get sectionGiving;

  /// No description provided for @givingTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get givingTypeLabel;

  /// No description provided for @givingTypeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Tithe, offering, seed, missions'**
  String get givingTypeHint;

  /// No description provided for @givingAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount (optional)'**
  String get givingAmountLabel;

  /// No description provided for @givingAmountHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 5000 FCFA'**
  String get givingAmountHint;

  /// No description provided for @givingPurposeLabel.
  ///
  /// In en, this message translates to:
  /// **'Purpose / Occasion'**
  String get givingPurposeLabel;

  /// No description provided for @givingPurposeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sunday offering, missions fund'**
  String get givingPurposeHint;

  /// No description provided for @sectionChurch.
  ///
  /// In en, this message translates to:
  /// **'Church & Fellowship'**
  String get sectionChurch;

  /// No description provided for @churchTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Service / Meeting'**
  String get churchTypeLabel;

  /// No description provided for @churchTypeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sunday service, midweek, cell group'**
  String get churchTypeHint;

  /// No description provided for @churchNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get churchNotesLabel;

  /// No description provided for @churchNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Key lessons, word received...'**
  String get churchNotesHint;

  /// No description provided for @sectionDiscipleship.
  ///
  /// In en, this message translates to:
  /// **'Discipleship'**
  String get sectionDiscipleship;

  /// No description provided for @discipleshipWhoLabel.
  ///
  /// In en, this message translates to:
  /// **'Who Are You Discipling?'**
  String get discipleshipWhoLabel;

  /// No description provided for @discipleshipWhoHint.
  ///
  /// In en, this message translates to:
  /// **'Name(s) of disciples'**
  String get discipleshipWhoHint;

  /// No description provided for @discipleshipTopicLabel.
  ///
  /// In en, this message translates to:
  /// **'What Did You Cover?'**
  String get discipleshipTopicLabel;

  /// No description provided for @discipleshipTopicHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Prayer life, consecration'**
  String get discipleshipTopicHint;

  /// No description provided for @discipleshipDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get discipleshipDurationLabel;

  /// No description provided for @discipleshipDurationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1 hour'**
  String get discipleshipDurationHint;

  /// No description provided for @sectionOther.
  ///
  /// In en, this message translates to:
  /// **'Other Activities'**
  String get sectionOther;

  /// No description provided for @otherLabel.
  ///
  /// In en, this message translates to:
  /// **'Other Spiritual Activities'**
  String get otherLabel;

  /// No description provided for @otherHint.
  ///
  /// In en, this message translates to:
  /// **'Fellowship, service, outreach, conferences...'**
  String get otherHint;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly Account'**
  String get reportTitle;

  /// No description provided for @reportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your walk with God, this week'**
  String get reportSubtitle;

  /// No description provided for @streakDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String streakDays(int count);

  /// No description provided for @streakLabel.
  ///
  /// In en, this message translates to:
  /// **'Faithfulness streak'**
  String get streakLabel;

  /// No description provided for @daysLogged.
  ///
  /// In en, this message translates to:
  /// **'Days Logged'**
  String get daysLogged;

  /// No description provided for @bibleChapters.
  ///
  /// In en, this message translates to:
  /// **'Bible Chapters'**
  String get bibleChapters;

  /// No description provided for @booksRead.
  ///
  /// In en, this message translates to:
  /// **'Books Read'**
  String get booksRead;

  /// No description provided for @soulsReached.
  ///
  /// In en, this message translates to:
  /// **'Souls Reached'**
  String get soulsReached;

  /// No description provided for @sundayBanner.
  ///
  /// In en, this message translates to:
  /// **'It\'s Sunday — time to send your account to your disciple maker.'**
  String get sundayBanner;

  /// No description provided for @previewLabel.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW'**
  String get previewLabel;

  /// No description provided for @sendEmail.
  ///
  /// In en, this message translates to:
  /// **'Send via Email'**
  String get sendEmail;

  /// No description provided for @sendWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get sendWhatsApp;

  /// No description provided for @copyReport.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyReport;

  /// No description provided for @reportCopied.
  ///
  /// In en, this message translates to:
  /// **'Report copied to clipboard.'**
  String get reportCopied;

  /// No description provided for @noReportYet.
  ///
  /// In en, this message translates to:
  /// **'No entries this week yet.\nStart logging your walk with God!'**
  String get noReportYet;

  /// No description provided for @confirmSendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Report?'**
  String get confirmSendTitle;

  /// No description provided for @confirmSendBody.
  ///
  /// In en, this message translates to:
  /// **'Send your weekly account to your disciple maker?'**
  String get confirmSendBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @profileSection.
  ///
  /// In en, this message translates to:
  /// **'Your Profile'**
  String get profileSection;

  /// No description provided for @yourNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get yourNameLabel;

  /// No description provided for @yourNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Emmanuel'**
  String get yourNameHint;

  /// No description provided for @discipleMakerSection.
  ///
  /// In en, this message translates to:
  /// **'Disciple Maker'**
  String get discipleMakerSection;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'disciplemaker@example.com'**
  String get emailHint;

  /// No description provided for @whatsappLabel.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Number (intl, no +)'**
  String get whatsappLabel;

  /// No description provided for @whatsappHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 237670000000'**
  String get whatsappHint;

  /// No description provided for @remindersSection.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersSection;

  /// No description provided for @dailyReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily log reminder'**
  String get dailyReminder;

  /// No description provided for @sundayReminder.
  ///
  /// In en, this message translates to:
  /// **'Sunday send reminder'**
  String get sundayReminder;

  /// No description provided for @saveReminders.
  ///
  /// In en, this message translates to:
  /// **'Save & Schedule Reminders'**
  String get saveReminders;

  /// No description provided for @remindersSaved.
  ///
  /// In en, this message translates to:
  /// **'Reminders scheduled!'**
  String get remindersSaved;

  /// No description provided for @languageSection.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSection;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @howItWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get howItWorksTitle;

  /// No description provided for @howItWorks.
  ///
  /// In en, this message translates to:
  /// **'1. Log your walk with God each day\n2. Mark each day complete ✅\n3. Get a gentle reminder daily, and a special one each Sunday\n4. Tap Send to email or WhatsApp the full week to your disciple maker\n5. Everything is stored privately on your device'**
  String get howItWorks;

  /// No description provided for @backupSection.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupSection;

  /// No description provided for @autoBackupInfo.
  ///
  /// In en, this message translates to:
  /// **'Your data is automatically backed up every 6 hours and synced to Google Drive.'**
  String get autoBackupInfo;

  /// No description provided for @restoreAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from Auto-Backup'**
  String get restoreAutoBackup;

  /// No description provided for @autoBackupFound.
  ///
  /// In en, this message translates to:
  /// **'Auto-backup found from {date}. Restore it?'**
  String autoBackupFound(String date);

  /// No description provided for @noAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'No auto-backup found.'**
  String get noAutoBackup;

  /// No description provided for @restoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreButton;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportData;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get importData;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup saved successfully!'**
  String get exportSuccess;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data imported successfully!'**
  String get importSuccess;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed. Invalid file format.'**
  String get importFailed;

  /// No description provided for @importMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge with existing data'**
  String get importMerge;

  /// No description provided for @importReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace all data'**
  String get importReplace;

  /// No description provided for @importPreview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day of logs found} other{{count} days of logs found}}'**
  String importPreview(int count);

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to\nDaily Account'**
  String get onboardingWelcome;

  /// No description provided for @onboardingWelcomeSub.
  ///
  /// In en, this message translates to:
  /// **'Track your daily walk with God.\nStay accountable. Grow in faith.'**
  String get onboardingWelcomeSub;

  /// No description provided for @onboardingHow.
  ///
  /// In en, this message translates to:
  /// **'How It Works'**
  String get onboardingHow;

  /// No description provided for @onboardingHowStep1.
  ///
  /// In en, this message translates to:
  /// **'Log your spiritual disciplines each day'**
  String get onboardingHowStep1;

  /// No description provided for @onboardingHowStep2.
  ///
  /// In en, this message translates to:
  /// **'Track Bible reading, prayer, fasting, evangelism, and more'**
  String get onboardingHowStep2;

  /// No description provided for @onboardingHowStep3.
  ///
  /// In en, this message translates to:
  /// **'Send your weekly account to your disciple maker every Sunday'**
  String get onboardingHowStep3;

  /// No description provided for @onboardingProfile.
  ///
  /// In en, this message translates to:
  /// **'Your Profile'**
  String get onboardingProfile;

  /// No description provided for @onboardingProfileSub.
  ///
  /// In en, this message translates to:
  /// **'Tell us a little about you'**
  String get onboardingProfileSub;

  /// No description provided for @onboardingLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Language'**
  String get onboardingLanguage;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Begin Your Journey'**
  String get onboardingStart;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @notifDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Account'**
  String get notifDailyTitle;

  /// No description provided for @notifDailyBody.
  ///
  /// In en, this message translates to:
  /// **'Have you recorded your walk with God today? Tap to log it.'**
  String get notifDailyBody;

  /// No description provided for @notifSundayTitle.
  ///
  /// In en, this message translates to:
  /// **'Sunday — Send Your Account'**
  String get notifSundayTitle;

  /// No description provided for @notifSundayBody.
  ///
  /// In en, this message translates to:
  /// **'Send this week\'s account to your disciple maker. Tap to review & send.'**
  String get notifSundayBody;

  /// No description provided for @reportHeader.
  ///
  /// In en, this message translates to:
  /// **'DAILY ACCOUNT — {name}'**
  String reportHeader(String name);

  /// No description provided for @reportWeekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {start} – {end}'**
  String reportWeekOf(String start, String end);

  /// No description provided for @reportNoEntry.
  ///
  /// In en, this message translates to:
  /// **'No entry recorded.'**
  String get reportNoEntry;

  /// No description provided for @reportBible.
  ///
  /// In en, this message translates to:
  /// **'Bible: {ref} ({chapters} ch.)'**
  String reportBible(String ref, String chapters);

  /// No description provided for @reportLiterature.
  ///
  /// In en, this message translates to:
  /// **'Literature: \"{title}\" — {amount} {unit}'**
  String reportLiterature(String title, String amount, String unit);

  /// No description provided for @reportDDEG.
  ///
  /// In en, this message translates to:
  /// **'DDEG — Encounter with God:'**
  String get reportDDEG;

  /// No description provided for @reportDDEGScripture.
  ///
  /// In en, this message translates to:
  /// **'   Scripture: {scripture}'**
  String reportDDEGScripture(String scripture);

  /// No description provided for @reportDDEGTime.
  ///
  /// In en, this message translates to:
  /// **'   Time: {time}'**
  String reportDDEGTime(String time);

  /// No description provided for @reportDDEGMeditation.
  ///
  /// In en, this message translates to:
  /// **'   Meditation: {notes}'**
  String reportDDEGMeditation(String notes);

  /// No description provided for @reportPrayerAlone.
  ///
  /// In en, this message translates to:
  /// **'Prayer (Alone): {duration} — {notes}'**
  String reportPrayerAlone(String duration, String notes);

  /// No description provided for @reportPrayerOthers.
  ///
  /// In en, this message translates to:
  /// **'Prayer (with others): {duration} — {context}'**
  String reportPrayerOthers(String duration, String context);

  /// No description provided for @reportEvangelism.
  ///
  /// In en, this message translates to:
  /// **'Evangelism: {contacts} contact(s). {outcome}. {notes}'**
  String reportEvangelism(String contacts, String outcome, String notes);

  /// No description provided for @reportFasting.
  ///
  /// In en, this message translates to:
  /// **'Fasting: {type} ({duration}) — {focus}'**
  String reportFasting(String type, String duration, String focus);

  /// No description provided for @reportGiving.
  ///
  /// In en, this message translates to:
  /// **'Giving: {type} — {purpose}'**
  String reportGiving(String type, String purpose);

  /// No description provided for @reportChurch.
  ///
  /// In en, this message translates to:
  /// **'Church: {type} — {notes}'**
  String reportChurch(String type, String notes);

  /// No description provided for @reportDiscipleship.
  ///
  /// In en, this message translates to:
  /// **'Discipleship: {who} — {topic} ({duration})'**
  String reportDiscipleship(String who, String topic, String duration);

  /// No description provided for @reportOther.
  ///
  /// In en, this message translates to:
  /// **'Other: {other}'**
  String reportOther(String other);

  /// No description provided for @reportFooter.
  ///
  /// In en, this message translates to:
  /// **'Sent with love · Daily Account'**
  String get reportFooter;

  /// No description provided for @reportEmailSubject.
  ///
  /// In en, this message translates to:
  /// **'Weekly Spiritual Account — {name} ({date})'**
  String reportEmailSubject(String name, String date);

  /// No description provided for @reportSummaryHeader.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY SUMMARY'**
  String get reportSummaryHeader;

  /// No description provided for @reportSummaryActiveDays.
  ///
  /// In en, this message translates to:
  /// **'Active days: {count}/7'**
  String reportSummaryActiveDays(int count);

  /// No description provided for @reportSummaryBibleChapters.
  ///
  /// In en, this message translates to:
  /// **'Bible chapters: {count}'**
  String reportSummaryBibleChapters(int count);

  /// No description provided for @reportSummaryEvangelism.
  ///
  /// In en, this message translates to:
  /// **'Evangelism contacts: {count}'**
  String reportSummaryEvangelism(int count);

  /// No description provided for @reportSummaryCompletion.
  ///
  /// In en, this message translates to:
  /// **'Avg. completion: {pct}%'**
  String reportSummaryCompletion(int pct);

  /// No description provided for @addEmailInSettings.
  ///
  /// In en, this message translates to:
  /// **'Add your disciple maker\'s email in Settings first.'**
  String get addEmailInSettings;

  /// No description provided for @addWhatsAppInSettings.
  ///
  /// In en, this message translates to:
  /// **'Add your disciple maker\'s WhatsApp number in Settings first.'**
  String get addWhatsAppInSettings;

  /// No description provided for @emailError.
  ///
  /// In en, this message translates to:
  /// **'Could not open email app.'**
  String get emailError;

  /// No description provided for @whatsappError.
  ///
  /// In en, this message translates to:
  /// **'Could not open WhatsApp.'**
  String get whatsappError;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get invalidEmail;

  /// No description provided for @invalidWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number (digits only, 10-15 chars).'**
  String get invalidWhatsapp;

  /// No description provided for @themeSection.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get themeSection;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @notificationsSection.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsSection;

  /// No description provided for @notificationsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get notificationsEnabled;

  /// No description provided for @notificationsDisabledMsg.
  ///
  /// In en, this message translates to:
  /// **'Notifications disabled'**
  String get notificationsDisabledMsg;

  /// No description provided for @notificationsEnabledMsg.
  ///
  /// In en, this message translates to:
  /// **'Notifications enabled'**
  String get notificationsEnabledMsg;

  /// No description provided for @autoSendSection.
  ///
  /// In en, this message translates to:
  /// **'Auto-Send Report'**
  String get autoSendSection;

  /// No description provided for @autoSendEnabled.
  ///
  /// In en, this message translates to:
  /// **'Auto-open report on Sunday'**
  String get autoSendEnabled;

  /// No description provided for @autoSendTime.
  ///
  /// In en, this message translates to:
  /// **'Send reminder time'**
  String get autoSendTime;

  /// No description provided for @autoSendDescription.
  ///
  /// In en, this message translates to:
  /// **'On Sunday at the scheduled time, the app will automatically open WhatsApp to send your weekly report to your disciple maker.'**
  String get autoSendDescription;

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSection;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersion(String version);

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Daily Account is a spiritual accountability tool for CMFI believers. Track your daily walk with God, and send weekly reports to your disciple maker.'**
  String get aboutDescription;

  /// No description provided for @madeWithLove.
  ///
  /// In en, this message translates to:
  /// **'Made with love for CMFI Cameroon'**
  String get madeWithLove;

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// No description provided for @resetAllData.
  ///
  /// In en, this message translates to:
  /// **'Reset All Data'**
  String get resetAllData;

  /// No description provided for @resetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Everything?'**
  String get resetConfirmTitle;

  /// No description provided for @resetConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all your logs, settings, and preferences. This action cannot be undone.'**
  String get resetConfirmBody;

  /// No description provided for @resetConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Delete Everything'**
  String get resetConfirmButton;

  /// No description provided for @resetSuccess.
  ///
  /// In en, this message translates to:
  /// **'All data has been reset.'**
  String get resetSuccess;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @weekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String weekOf(String date);

  /// No description provided for @monthlyReport.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthlyReport;

  /// No description provided for @weeklyReport.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weeklyReport;

  /// No description provided for @monthOf.
  ///
  /// In en, this message translates to:
  /// **'Month of {month}'**
  String monthOf(String month);

  /// No description provided for @monthlySummaryHeader.
  ///
  /// In en, this message translates to:
  /// **'MONTHLY SUMMARY'**
  String get monthlySummaryHeader;

  /// No description provided for @monthlySummaryActiveDays.
  ///
  /// In en, this message translates to:
  /// **'Active days: {count}/{total}'**
  String monthlySummaryActiveDays(int count, int total);

  /// No description provided for @monthlySummaryWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks reported: {count}'**
  String monthlySummaryWeeks(int count);

  /// No description provided for @noReportForWeek.
  ///
  /// In en, this message translates to:
  /// **'No entries for this week.\nNavigate to the Log tab and select a past date to enter data.'**
  String get noReportForWeek;

  /// No description provided for @reportHistory.
  ///
  /// In en, this message translates to:
  /// **'Report History'**
  String get reportHistory;

  /// No description provided for @reportHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reports generated yet.\nYour reports will appear here after you view them.'**
  String get reportHistoryEmpty;

  /// No description provided for @reportHistorySection.
  ///
  /// In en, this message translates to:
  /// **'Report Archive'**
  String get reportHistorySection;

  /// No description provided for @sentVia.
  ///
  /// In en, this message translates to:
  /// **'Sent via {channel}'**
  String sentVia(String channel);

  /// No description provided for @notSentYet.
  ///
  /// In en, this message translates to:
  /// **'Not sent yet'**
  String get notSentYet;

  /// No description provided for @resend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get resend;

  /// No description provided for @viewReport.
  ///
  /// In en, this message translates to:
  /// **'View Report'**
  String get viewReport;

  /// No description provided for @deleteReport.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteReport;

  /// No description provided for @reportSaved.
  ///
  /// In en, this message translates to:
  /// **'Report saved to archive.'**
  String get reportSaved;

  /// No description provided for @reportDeleted.
  ///
  /// In en, this message translates to:
  /// **'Report deleted.'**
  String get reportDeleted;

  /// No description provided for @copyFromYesterday.
  ///
  /// In en, this message translates to:
  /// **'Copy from yesterday'**
  String get copyFromYesterday;

  /// No description provided for @copiedFromYesterday.
  ///
  /// In en, this message translates to:
  /// **'Copied yesterday\'s entries!'**
  String get copiedFromYesterday;

  /// No description provided for @nothingToCopy.
  ///
  /// In en, this message translates to:
  /// **'No entries from yesterday to copy.'**
  String get nothingToCopy;

  /// No description provided for @securitySection.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securitySection;

  /// No description provided for @appLockEnabled.
  ///
  /// In en, this message translates to:
  /// **'App Lock'**
  String get appLockEnabled;

  /// No description provided for @useBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Use Fingerprint / Face ID'**
  String get useBiometrics;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// No description provided for @setPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Set App PIN'**
  String get setPinTitle;

  /// No description provided for @setPinBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a 4-digit PIN to lock your app.'**
  String get setPinBody;

  /// No description provided for @confirmPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get confirmPinTitle;

  /// No description provided for @confirmPinBody.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your PIN to confirm.'**
  String get confirmPinBody;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs don\'t match. Try again.'**
  String get pinMismatch;

  /// No description provided for @pinSet.
  ///
  /// In en, this message translates to:
  /// **'App PIN set successfully!'**
  String get pinSet;

  /// No description provided for @pinRemoved.
  ///
  /// In en, this message translates to:
  /// **'App lock disabled.'**
  String get pinRemoved;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get enterPin;

  /// No description provided for @wrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get wrongPin;

  /// No description provided for @useBiometricsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Unlock Daily Account'**
  String get useBiometricsPrompt;

  /// No description provided for @saveAsPdf.
  ///
  /// In en, this message translates to:
  /// **'Save as PDF'**
  String get saveAsPdf;

  /// No description provided for @sharePdf.
  ///
  /// In en, this message translates to:
  /// **'Share PDF'**
  String get sharePdf;

  /// No description provided for @shareReport.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareReport;

  /// No description provided for @tabStopwatch.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get tabStopwatch;

  /// No description provided for @stopwatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity Timer'**
  String get stopwatchTitle;

  /// No description provided for @stopwatchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track your spiritual disciplines in real time'**
  String get stopwatchSubtitle;

  /// No description provided for @todayTotal.
  ///
  /// In en, this message translates to:
  /// **'Today\'s total'**
  String get todayTotal;

  /// No description provided for @timerStopped.
  ///
  /// In en, this message translates to:
  /// **'Timer stopped — duration saved!'**
  String get timerStopped;

  /// No description provided for @timerAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'Another timer is running. It will be paused.'**
  String get timerAlreadyRunning;

  /// No description provided for @stopwatchFillFields.
  ///
  /// In en, this message translates to:
  /// **'Fill in details before starting (optional)'**
  String get stopwatchFillFields;

  /// No description provided for @startTimer.
  ///
  /// In en, this message translates to:
  /// **'Start Timer'**
  String get startTimer;

  /// No description provided for @addActivity.
  ///
  /// In en, this message translates to:
  /// **'Add Activity'**
  String get addActivity;

  /// No description provided for @activityName.
  ///
  /// In en, this message translates to:
  /// **'Activity name'**
  String get activityName;

  /// No description provided for @activityNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Worship, Meditation'**
  String get activityNameHint;

  /// No description provided for @activityIcon.
  ///
  /// In en, this message translates to:
  /// **'Emoji icon'**
  String get activityIcon;

  /// No description provided for @activityCreated.
  ///
  /// In en, this message translates to:
  /// **'Activity added!'**
  String get activityCreated;

  /// No description provided for @activityDeleted.
  ///
  /// In en, this message translates to:
  /// **'Activity removed.'**
  String get activityDeleted;

  /// No description provided for @deleteActivityConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this activity?'**
  String get deleteActivityConfirm;

  /// No description provided for @customFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes field label (optional)'**
  String get customFieldLabel;

  /// No description provided for @customFieldHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. What did you learn?'**
  String get customFieldHint;

  /// No description provided for @ddegShort.
  ///
  /// In en, this message translates to:
  /// **'DDEG'**
  String get ddegShort;

  /// No description provided for @bibleStartRef.
  ///
  /// In en, this message translates to:
  /// **'Starting reference'**
  String get bibleStartRef;

  /// No description provided for @bibleStartHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. John 1'**
  String get bibleStartHint;

  /// No description provided for @bibleEndRef.
  ///
  /// In en, this message translates to:
  /// **'Ending reference (after reading)'**
  String get bibleEndRef;

  /// No description provided for @bibleEndHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. John 3'**
  String get bibleEndHint;

  /// No description provided for @bibleChaptersRead.
  ///
  /// In en, this message translates to:
  /// **'{count} chapter(s) read'**
  String bibleChaptersRead(int count);

  /// No description provided for @enterEndReference.
  ///
  /// In en, this message translates to:
  /// **'Where did you finish reading?'**
  String get enterEndReference;

  /// No description provided for @timerStoppedDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration: {duration}'**
  String timerStoppedDuration(String duration);

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @sectionProclamation.
  ///
  /// In en, this message translates to:
  /// **'Proclamation'**
  String get sectionProclamation;

  /// No description provided for @proclamationCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Number of Proclamations'**
  String get proclamationCountLabel;

  /// No description provided for @proclamationCountHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 50'**
  String get proclamationCountHint;

  /// No description provided for @proclamationDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration (optional)'**
  String get proclamationDurationLabel;

  /// No description provided for @proclamationDurationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 10 minutes'**
  String get proclamationDurationHint;

  /// No description provided for @proclamationCounter.
  ///
  /// In en, this message translates to:
  /// **'Proclamation Counter'**
  String get proclamationCounter;

  /// No description provided for @proclamationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Proclaim: Jesus Christ is the Lord!'**
  String get proclamationSubtitle;

  /// No description provided for @proclamationTap.
  ///
  /// In en, this message translates to:
  /// **'Tap to proclaim'**
  String get proclamationTap;

  /// No description provided for @proclamationSave.
  ///
  /// In en, this message translates to:
  /// **'Save & Close'**
  String get proclamationSave;

  /// No description provided for @reportProclamation.
  ///
  /// In en, this message translates to:
  /// **'Proclamation: {count} times ({duration})'**
  String reportProclamation(String count, String duration);

  /// No description provided for @followUpReminders.
  ///
  /// In en, this message translates to:
  /// **'Follow-up reminders'**
  String get followUpReminders;

  /// No description provided for @followUpDescription.
  ///
  /// In en, this message translates to:
  /// **'After the main reminder, follow-up alerts fire every 30 minutes to make sure you don\'t forget.'**
  String get followUpDescription;

  /// No description provided for @followUpCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No follow-ups} =1{1 follow-up (+30 min)} =2{2 follow-ups (+30, +60 min)} other{3 follow-ups (+30, +60, +90 min)}}'**
  String followUpCount(int count);

  /// No description provided for @notificationIntensity.
  ///
  /// In en, this message translates to:
  /// **'Notification Intensity'**
  String get notificationIntensity;

  /// No description provided for @intensityAggressive.
  ///
  /// In en, this message translates to:
  /// **'Aggressive (alarm-style)'**
  String get intensityAggressive;

  /// No description provided for @intensityAggressiveDesc.
  ///
  /// In en, this message translates to:
  /// **'Full-screen alerts, sound, vibration, LED — like an alarm clock'**
  String get intensityAggressiveDesc;

  /// No description provided for @sundayFollowUps.
  ///
  /// In en, this message translates to:
  /// **'Sunday follow-ups'**
  String get sundayFollowUps;

  /// No description provided for @sundayFollowUpCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No follow-ups} =1{1 follow-up (+30 min)} =2{2 follow-ups (+30, +60 min)} other{{count} follow-ups}}'**
  String sundayFollowUpCount(int count);

  /// No description provided for @tabPrayer.
  ///
  /// In en, this message translates to:
  /// **'Prayer'**
  String get tabPrayer;

  /// No description provided for @prayerRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Prayer Requests'**
  String get prayerRequestsTitle;

  /// No description provided for @prayerRequestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bring your burdens before the Lord'**
  String get prayerRequestsSubtitle;

  /// No description provided for @prayerActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get prayerActive;

  /// No description provided for @prayerAnswered.
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get prayerAnswered;

  /// No description provided for @prayerEmptyActive.
  ///
  /// In en, this message translates to:
  /// **'No prayer requests yet.\nTap + to add your first request.'**
  String get prayerEmptyActive;

  /// No description provided for @prayerAnsweredSection.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 answered prayer} other{{count} answered prayers}}'**
  String prayerAnsweredSection(int count);

  /// No description provided for @prayerAddTitle.
  ///
  /// In en, this message translates to:
  /// **'New Prayer Request'**
  String get prayerAddTitle;

  /// No description provided for @prayerTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Prayer request'**
  String get prayerTitleLabel;

  /// No description provided for @prayerTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Healing for my brother'**
  String get prayerTitleHint;

  /// No description provided for @prayerDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get prayerDescLabel;

  /// No description provided for @prayerDescHint.
  ///
  /// In en, this message translates to:
  /// **'More context about this request...'**
  String get prayerDescHint;

  /// No description provided for @prayerAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Prayer Request'**
  String get prayerAddButton;

  /// No description provided for @prayerCatPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get prayerCatPersonal;

  /// No description provided for @prayerCatFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get prayerCatFamily;

  /// No description provided for @prayerCatChurch.
  ///
  /// In en, this message translates to:
  /// **'Church'**
  String get prayerCatChurch;

  /// No description provided for @prayerCatNation.
  ///
  /// In en, this message translates to:
  /// **'Nation'**
  String get prayerCatNation;

  /// No description provided for @prayerCatHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get prayerCatHealth;

  /// No description provided for @prayerMarkAnswered.
  ///
  /// In en, this message translates to:
  /// **'Prayer Answered!'**
  String get prayerMarkAnswered;

  /// No description provided for @prayerAnswerNote.
  ///
  /// In en, this message translates to:
  /// **'How did God answer?'**
  String get prayerAnswerNote;

  /// No description provided for @prayerAnswerHint.
  ///
  /// In en, this message translates to:
  /// **'Describe how this prayer was answered...'**
  String get prayerAnswerHint;

  /// No description provided for @prayerConfirmAnswered.
  ///
  /// In en, this message translates to:
  /// **'Mark as Answered'**
  String get prayerConfirmAnswered;

  /// No description provided for @weeklyChart.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY PROGRESS'**
  String get weeklyChart;

  /// No description provided for @chartCompletion.
  ///
  /// In en, this message translates to:
  /// **'Completion %'**
  String get chartCompletion;

  /// No description provided for @quickLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Log'**
  String get quickLogTitle;

  /// No description provided for @quickLogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap each discipline you practiced today'**
  String get quickLogSubtitle;

  /// No description provided for @quickLogSaved.
  ///
  /// In en, this message translates to:
  /// **'Quick log saved!'**
  String get quickLogSaved;

  /// No description provided for @quickLogButton.
  ///
  /// In en, this message translates to:
  /// **'Quick Log'**
  String get quickLogButton;

  /// No description provided for @badgeStreakWeek.
  ///
  /// In en, this message translates to:
  /// **'7-Day Warrior'**
  String get badgeStreakWeek;

  /// No description provided for @badgeStreakMonth.
  ///
  /// In en, this message translates to:
  /// **'30-Day Champion'**
  String get badgeStreakMonth;

  /// No description provided for @badgeBibleMarathon.
  ///
  /// In en, this message translates to:
  /// **'Bible Marathon'**
  String get badgeBibleMarathon;

  /// No description provided for @badgePrayerWarrior.
  ///
  /// In en, this message translates to:
  /// **'Prayer Warrior'**
  String get badgePrayerWarrior;

  /// No description provided for @badgeEvangelismFire.
  ///
  /// In en, this message translates to:
  /// **'Soul Winner'**
  String get badgeEvangelismFire;

  /// No description provided for @badgePerfectWeek.
  ///
  /// In en, this message translates to:
  /// **'Perfect Week'**
  String get badgePerfectWeek;

  /// No description provided for @badgesTitle.
  ///
  /// In en, this message translates to:
  /// **'ACHIEVEMENTS'**
  String get badgesTitle;

  /// No description provided for @badgesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Keep going! Badges will appear as you grow.'**
  String get badgesEmpty;

  /// No description provided for @snoozeLabel.
  ///
  /// In en, this message translates to:
  /// **'Snooze 15 min'**
  String get snoozeLabel;

  /// No description provided for @testNotification.
  ///
  /// In en, this message translates to:
  /// **'Test Notification'**
  String get testNotification;

  /// No description provided for @testNotificationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Notification sent! If you don\'t see it, check your system notification settings.'**
  String get testNotificationSuccess;

  /// No description provided for @testNotificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Notification failed. Please enable notifications in your device settings.'**
  String get testNotificationFailed;

  /// No description provided for @pendingNotifications.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No scheduled notifications} =1{1 notification scheduled} other{{count} notifications scheduled}}'**
  String pendingNotifications(int count);

  /// No description provided for @missingDisciplinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Missing Disciplines'**
  String get missingDisciplinesTitle;

  /// No description provided for @missingDisciplinesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to complete these today'**
  String get missingDisciplinesSubtitle;

  /// No description provided for @disciplineDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get disciplineDone;

  /// No description provided for @disciplineMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get disciplineMissing;

  /// No description provided for @allDisciplinesDone.
  ///
  /// In en, this message translates to:
  /// **'All disciplines completed! Great job!'**
  String get allDisciplinesDone;

  /// No description provided for @pendingReportBanner.
  ///
  /// In en, this message translates to:
  /// **'Report pending — will send when online'**
  String get pendingReportBanner;

  /// No description provided for @pendingReportRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry now'**
  String get pendingReportRetry;

  /// No description provided for @pendingReportSent.
  ///
  /// In en, this message translates to:
  /// **'Pending report sent!'**
  String get pendingReportSent;

  /// No description provided for @offlineStatus.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineStatus;

  /// No description provided for @midWeekNudgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Mid-Week Check-in'**
  String get midWeekNudgeTitle;

  /// No description provided for @midWeekNudgeBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ve completed {done}/{total} disciplines this week. Keep going!'**
  String midWeekNudgeBody(int done, int total);

  /// No description provided for @trendUp.
  ///
  /// In en, this message translates to:
  /// **'up {percent}%'**
  String trendUp(int percent);

  /// No description provided for @trendDown.
  ///
  /// In en, this message translates to:
  /// **'down {percent}%'**
  String trendDown(int percent);

  /// No description provided for @trendSteady.
  ///
  /// In en, this message translates to:
  /// **'steady'**
  String get trendSteady;

  /// No description provided for @trendVsLastMonth.
  ///
  /// In en, this message translates to:
  /// **'vs last month'**
  String get trendVsLastMonth;

  /// No description provided for @trendTitle.
  ///
  /// In en, this message translates to:
  /// **'TRENDS'**
  String get trendTitle;

  /// No description provided for @trendConsistency.
  ///
  /// In en, this message translates to:
  /// **'Consistency'**
  String get trendConsistency;

  /// No description provided for @trendBestDiscipline.
  ///
  /// In en, this message translates to:
  /// **'Strongest'**
  String get trendBestDiscipline;

  /// No description provided for @trendWeakDiscipline.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get trendWeakDiscipline;

  /// No description provided for @trendNoData.
  ///
  /// In en, this message translates to:
  /// **'Not enough data for trends yet'**
  String get trendNoData;

  /// No description provided for @reflectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Reflection'**
  String get reflectionTitle;

  /// No description provided for @reflectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Complete some disciplines to receive a reflection'**
  String get reflectionEmpty;

  /// No description provided for @reflectionGreatDay.
  ///
  /// In en, this message translates to:
  /// **'Wonderful day of faithfulness! You covered {count} disciplines — your commitment is bearing fruit.'**
  String reflectionGreatDay(int count);

  /// No description provided for @reflectionGoodDay.
  ///
  /// In en, this message translates to:
  /// **'Good effort today with {count} disciplines. Keep building consistency!'**
  String reflectionGoodDay(int count);

  /// No description provided for @reflectionStartDay.
  ///
  /// In en, this message translates to:
  /// **'You\'ve started with {count} discipline. Every step counts — keep pressing forward!'**
  String reflectionStartDay(int count);

  /// No description provided for @reflectionPrayerFocus.
  ///
  /// In en, this message translates to:
  /// **'Your prayer life is strong today. Let it fuel your other disciplines.'**
  String get reflectionPrayerFocus;

  /// No description provided for @reflectionBibleFocus.
  ///
  /// In en, this message translates to:
  /// **'Great Bible engagement today. Let the Word guide your day.'**
  String get reflectionBibleFocus;

  /// No description provided for @reflectionEvangelismFocus.
  ///
  /// In en, this message translates to:
  /// **'Active in evangelism today — souls are being reached!'**
  String get reflectionEvangelismFocus;

  /// No description provided for @reflectionBalanced.
  ///
  /// In en, this message translates to:
  /// **'A beautifully balanced day across your disciplines.'**
  String get reflectionBalanced;

  /// No description provided for @reflectionStreakEncouragement.
  ///
  /// In en, this message translates to:
  /// **'You\'re on a {days}-day streak! Don\'t break it!'**
  String reflectionStreakEncouragement(int days);

  /// No description provided for @evangelismFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get evangelismFollowUp;

  /// No description provided for @evangelismNewBelievers.
  ///
  /// In en, this message translates to:
  /// **'Those who accepted Jesus'**
  String get evangelismNewBelievers;

  /// No description provided for @evangelismNewBelieversHint.
  ///
  /// In en, this message translates to:
  /// **'Number who accepted Christ in their hearts'**
  String get evangelismNewBelieversHint;

  /// No description provided for @evangelismBeingDiscipled.
  ///
  /// In en, this message translates to:
  /// **'Being discipled'**
  String get evangelismBeingDiscipled;

  /// No description provided for @evangelismBeingDiscipledHint.
  ///
  /// In en, this message translates to:
  /// **'Number now in discipleship'**
  String get evangelismBeingDiscipledHint;

  /// No description provided for @evangelismFollowUpNotes.
  ///
  /// In en, this message translates to:
  /// **'Follow-up notes'**
  String get evangelismFollowUpNotes;

  /// No description provided for @evangelismFollowUpHint.
  ///
  /// In en, this message translates to:
  /// **'Names, next steps, needs...'**
  String get evangelismFollowUpHint;

  /// No description provided for @textSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSizeLabel;

  /// No description provided for @textSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'A'**
  String get textSizeSmall;

  /// No description provided for @textSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'A+'**
  String get textSizeLarge;

  /// No description provided for @textSizePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview text'**
  String get textSizePreview;

  /// No description provided for @disciplineReminders.
  ///
  /// In en, this message translates to:
  /// **'Discipline reminders'**
  String get disciplineReminders;

  /// No description provided for @disciplineRemindersDesc.
  ///
  /// In en, this message translates to:
  /// **'Set a time for each discipline'**
  String get disciplineRemindersDesc;

  /// No description provided for @disciplineReminderOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get disciplineReminderOff;

  /// No description provided for @disciplineReminderSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get disciplineReminderSet;

  /// No description provided for @weeklyGoals.
  ///
  /// In en, this message translates to:
  /// **'Weekly Goals'**
  String get weeklyGoals;

  /// No description provided for @weeklyGoalsDesc.
  ///
  /// In en, this message translates to:
  /// **'Set targets for the week'**
  String get weeklyGoalsDesc;

  /// No description provided for @dailyGoals.
  ///
  /// In en, this message translates to:
  /// **'Daily Goals'**
  String get dailyGoals;

  /// No description provided for @dailyGoalsDesc.
  ///
  /// In en, this message translates to:
  /// **'Set targets for each day'**
  String get dailyGoalsDesc;

  /// No description provided for @goalFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get goalFrequency;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @enterGoalValue.
  ///
  /// In en, this message translates to:
  /// **'Enter value'**
  String get enterGoalValue;

  /// No description provided for @goalBibleChapters.
  ///
  /// In en, this message translates to:
  /// **'Bible chapters'**
  String get goalBibleChapters;

  /// No description provided for @goalPrayerMinutes.
  ///
  /// In en, this message translates to:
  /// **'Prayer (minutes)'**
  String get goalPrayerMinutes;

  /// No description provided for @goalEvangelismContacts.
  ///
  /// In en, this message translates to:
  /// **'Evangelism contacts'**
  String get goalEvangelismContacts;

  /// No description provided for @goalLiteratureItems.
  ///
  /// In en, this message translates to:
  /// **'Literature items'**
  String get goalLiteratureItems;

  /// No description provided for @goalProgress.
  ///
  /// In en, this message translates to:
  /// **'{current}/{target}'**
  String goalProgress(String current, String target);

  /// No description provided for @goalReached.
  ///
  /// In en, this message translates to:
  /// **'Goal reached!'**
  String get goalReached;

  /// No description provided for @setGoals.
  ///
  /// In en, this message translates to:
  /// **'Set goals'**
  String get setGoals;

  /// No description provided for @saveGoals.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveGoals;

  /// No description provided for @weeklyChallenge.
  ///
  /// In en, this message translates to:
  /// **'This Week\'s Challenge'**
  String get weeklyChallenge;

  /// No description provided for @challengeWeakDiscipline.
  ///
  /// In en, this message translates to:
  /// **'Focus on {discipline} — your weakest area this week'**
  String challengeWeakDiscipline(String discipline);

  /// No description provided for @challengePrayerDaily.
  ///
  /// In en, this message translates to:
  /// **'Pray every day this week — even 5 minutes counts'**
  String get challengePrayerDaily;

  /// No description provided for @challengeBibleDaily.
  ///
  /// In en, this message translates to:
  /// **'Read at least 1 Bible chapter every day'**
  String get challengeBibleDaily;

  /// No description provided for @challengeEvangelism.
  ///
  /// In en, this message translates to:
  /// **'Share the gospel with 3 people this week'**
  String get challengeEvangelism;

  /// No description provided for @challengeStreak7.
  ///
  /// In en, this message translates to:
  /// **'Keep logging daily to reach a 7-day streak!'**
  String get challengeStreak7;

  /// No description provided for @challengeStreak30.
  ///
  /// In en, this message translates to:
  /// **'You\'re on fire! Push for a 30-day streak!'**
  String get challengeStreak30;

  /// No description provided for @challengePerfectWeek.
  ///
  /// In en, this message translates to:
  /// **'Almost there — log every day for a perfect week!'**
  String get challengePerfectWeek;

  /// No description provided for @milestoneStreak7.
  ///
  /// In en, this message translates to:
  /// **'7-Day Streak!'**
  String get milestoneStreak7;

  /// No description provided for @milestoneStreak7Body.
  ///
  /// In en, this message translates to:
  /// **'A full week of faithfulness. Keep going!'**
  String get milestoneStreak7Body;

  /// No description provided for @milestoneStreak30.
  ///
  /// In en, this message translates to:
  /// **'30-Day Streak!'**
  String get milestoneStreak30;

  /// No description provided for @milestoneStreak30Body.
  ///
  /// In en, this message translates to:
  /// **'A month of daily discipline. You are building something lasting.'**
  String get milestoneStreak30Body;

  /// No description provided for @milestoneStreak100.
  ///
  /// In en, this message translates to:
  /// **'100-Day Streak!'**
  String get milestoneStreak100;

  /// No description provided for @milestoneStreak100Body.
  ///
  /// In en, this message translates to:
  /// **'100 days of walking with God. What a testimony!'**
  String get milestoneStreak100Body;

  /// No description provided for @milestonePerfectWeek.
  ///
  /// In en, this message translates to:
  /// **'Perfect Week!'**
  String get milestonePerfectWeek;

  /// No description provided for @milestonePerfectWeekBody.
  ///
  /// In en, this message translates to:
  /// **'Every day accounted for. Well done, faithful servant.'**
  String get milestonePerfectWeekBody;

  /// No description provided for @milestoneBibleMarathon.
  ///
  /// In en, this message translates to:
  /// **'Bible Marathon!'**
  String get milestoneBibleMarathon;

  /// No description provided for @milestoneBibleMarathonBody.
  ///
  /// In en, this message translates to:
  /// **'20+ chapters this week. The Word is alive in you.'**
  String get milestoneBibleMarathonBody;

  /// No description provided for @milestoneShare.
  ///
  /// In en, this message translates to:
  /// **'Share Achievement'**
  String get milestoneShare;

  /// No description provided for @voiceNote.
  ///
  /// In en, this message translates to:
  /// **'Voice note'**
  String get voiceNote;

  /// No description provided for @voiceNoteRecord.
  ///
  /// In en, this message translates to:
  /// **'Tap to record'**
  String get voiceNoteRecord;

  /// No description provided for @voiceNoteRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get voiceNoteRecording;

  /// No description provided for @voiceNotePlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get voiceNotePlay;

  /// No description provided for @voiceNoteDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete recording'**
  String get voiceNoteDelete;

  /// No description provided for @voiceNoteDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this voice note?'**
  String get voiceNoteDeleteConfirm;

  /// No description provided for @voiceNoteSaved.
  ///
  /// In en, this message translates to:
  /// **'Voice note saved'**
  String get voiceNoteSaved;

  /// No description provided for @fastingPeriod.
  ///
  /// In en, this message translates to:
  /// **'Fasting period'**
  String get fastingPeriod;

  /// No description provided for @fastingStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get fastingStartDate;

  /// No description provided for @fastingEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get fastingEndDate;

  /// No description provided for @fastingTypeComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete fast'**
  String get fastingTypeComplete;

  /// No description provided for @fastingTypePartial.
  ///
  /// In en, this message translates to:
  /// **'Partial fast'**
  String get fastingTypePartial;

  /// No description provided for @fastingTypeEsther.
  ///
  /// In en, this message translates to:
  /// **'Esther fast'**
  String get fastingTypeEsther;

  /// No description provided for @fastingDaysRemaining.
  ///
  /// In en, this message translates to:
  /// **'{days} days remaining'**
  String fastingDaysRemaining(int days);

  /// No description provided for @fastingDayOf.
  ///
  /// In en, this message translates to:
  /// **'Day {current} of {total}'**
  String fastingDayOf(int current, int total);

  /// No description provided for @fastingActive.
  ///
  /// In en, this message translates to:
  /// **'Active fast'**
  String get fastingActive;

  /// No description provided for @fastingCompleted.
  ///
  /// In en, this message translates to:
  /// **'Fast completed!'**
  String get fastingCompleted;

  /// No description provided for @fastingNone.
  ///
  /// In en, this message translates to:
  /// **'No active fast'**
  String get fastingNone;

  /// No description provided for @startFast.
  ///
  /// In en, this message translates to:
  /// **'Start a fast'**
  String get startFast;

  /// No description provided for @endFast.
  ///
  /// In en, this message translates to:
  /// **'End fast'**
  String get endFast;

  /// No description provided for @certificateTitle.
  ///
  /// In en, this message translates to:
  /// **'Certificate of Faithfulness'**
  String get certificateTitle;

  /// No description provided for @certificateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly Spiritual Achievement'**
  String get certificateSubtitle;

  /// No description provided for @certificateBody.
  ///
  /// In en, this message translates to:
  /// **'This certifies that {name} demonstrated faithful spiritual discipline during {month}, achieving {percent}% overall consistency across all disciplines.'**
  String certificateBody(String name, String month, int percent);

  /// No description provided for @certificateGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate certificate'**
  String get certificateGenerate;

  /// No description provided for @certificateShare.
  ///
  /// In en, this message translates to:
  /// **'Share certificate'**
  String get certificateShare;

  /// No description provided for @certificateNoData.
  ///
  /// In en, this message translates to:
  /// **'Need at least 80% consistency to earn a certificate'**
  String get certificateNoData;

  /// No description provided for @autoFillBanner.
  ///
  /// In en, this message translates to:
  /// **'Auto-filled from your recent patterns'**
  String get autoFillBanner;

  /// No description provided for @autoFillUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get autoFillUndo;

  /// No description provided for @reportLanguageSection.
  ///
  /// In en, this message translates to:
  /// **'Report Language'**
  String get reportLanguageSection;

  /// No description provided for @reportLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose the language for sent reports and PDF documents'**
  String get reportLanguageDesc;

  /// No description provided for @reportLanguageSameAsApp.
  ///
  /// In en, this message translates to:
  /// **'Same as app'**
  String get reportLanguageSameAsApp;

  /// No description provided for @saturdaySummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your week so far'**
  String get saturdaySummaryTitle;

  /// No description provided for @saturdaySummaryBody.
  ///
  /// In en, this message translates to:
  /// **'{days}/7 days logged, {chapters} chapters read, {contacts} contacts evangelized. Finish strong tomorrow!'**
  String saturdaySummaryBody(int days, int chapters, int contacts);

  /// No description provided for @cloudBackupSection.
  ///
  /// In en, this message translates to:
  /// **'Cloud Backup'**
  String get cloudBackupSection;

  /// No description provided for @cloudBackupDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Google account to back up all your data to Google Drive. Restore it on any device.'**
  String get cloudBackupDescription;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String signedInAs(String email);

  /// No description provided for @lastCloudBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {date}'**
  String lastCloudBackup(String date);

  /// No description provided for @backupToDrive.
  ///
  /// In en, this message translates to:
  /// **'Back up to Google Drive'**
  String get backupToDrive;

  /// No description provided for @restoreFromDrive.
  ///
  /// In en, this message translates to:
  /// **'Restore from Google Drive'**
  String get restoreFromDrive;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @cloudBackupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backed up to Google Drive!'**
  String get cloudBackupSuccess;

  /// No description provided for @cloudBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup failed. Check your connection.'**
  String get cloudBackupFailed;

  /// No description provided for @cloudRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data restored from Google Drive!'**
  String get cloudRestoreSuccess;

  /// No description provided for @cloudRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed. Check your connection.'**
  String get cloudRestoreFailed;

  /// No description provided for @cloudRestoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from Cloud?'**
  String get cloudRestoreConfirmTitle;

  /// No description provided for @cloudRestoreConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will replace all local data with the cloud backup. Are you sure?'**
  String get cloudRestoreConfirmBody;

  /// No description provided for @cloudNoBackupFound.
  ///
  /// In en, this message translates to:
  /// **'No backup found on your Google Drive.'**
  String get cloudNoBackupFound;

  /// No description provided for @cloudSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Please try again.'**
  String get cloudSignInFailed;

  /// No description provided for @timeConsciousLabel.
  ///
  /// In en, this message translates to:
  /// **'Time-conscious mode'**
  String get timeConsciousLabel;

  /// No description provided for @timeConsciousDescription.
  ///
  /// In en, this message translates to:
  /// **'Track how much time you consecrate to each spiritual activity'**
  String get timeConsciousDescription;

  /// No description provided for @totalTimeConsecrated.
  ///
  /// In en, this message translates to:
  /// **'Total time consecrated: {time}'**
  String totalTimeConsecrated(String time);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @customActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Activity'**
  String get customActivityTitle;

  /// No description provided for @customActivityName.
  ///
  /// In en, this message translates to:
  /// **'Activity name'**
  String get customActivityName;

  /// No description provided for @customActivityNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Worship, Fasting Prayer'**
  String get customActivityNameHint;

  /// No description provided for @customActivityIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get customActivityIcon;

  /// No description provided for @customActivityTemplates.
  ///
  /// In en, this message translates to:
  /// **'Quick templates'**
  String get customActivityTemplates;

  /// No description provided for @customActivityTemplateSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get customActivityTemplateSimple;

  /// No description provided for @customActivityTemplateTimed.
  ///
  /// In en, this message translates to:
  /// **'Timed'**
  String get customActivityTemplateTimed;

  /// No description provided for @customActivityTemplateCounted.
  ///
  /// In en, this message translates to:
  /// **'Counted'**
  String get customActivityTemplateCounted;

  /// No description provided for @customActivityTemplateFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get customActivityTemplateFull;

  /// No description provided for @customActivityAddField.
  ///
  /// In en, this message translates to:
  /// **'Add field'**
  String get customActivityAddField;

  /// No description provided for @customActivityFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Field label'**
  String get customActivityFieldLabel;

  /// No description provided for @customActivityFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get customActivityFieldType;

  /// No description provided for @customActivityCountsForProgress.
  ///
  /// In en, this message translates to:
  /// **'Counts for daily progress'**
  String get customActivityCountsForProgress;

  /// No description provided for @customFieldTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get customFieldTypeText;

  /// No description provided for @customFieldTypeNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get customFieldTypeNumber;

  /// No description provided for @customFieldTypeDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get customFieldTypeDuration;

  /// No description provided for @customFieldTypeYesNo.
  ///
  /// In en, this message translates to:
  /// **'Yes/No'**
  String get customFieldTypeYesNo;

  /// No description provided for @customFieldTypeNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get customFieldTypeNotes;

  /// No description provided for @customActivityMaxFields.
  ///
  /// In en, this message translates to:
  /// **'Maximum 8 fields'**
  String get customActivityMaxFields;

  /// No description provided for @cancelTimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel timer?'**
  String get cancelTimerTitle;

  /// No description provided for @cancelTimerContent.
  ///
  /// In en, this message translates to:
  /// **'Discard {elapsed} of {name}?'**
  String cancelTimerContent(String elapsed, String name);

  /// No description provided for @cancelTimerKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep timing'**
  String get cancelTimerKeep;

  /// No description provided for @cancelTimerDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get cancelTimerDiscard;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'fr':
      return SFr();
  }

  throw FlutterError(
      'S.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
