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
  /// **'Number of Contacts'**
  String get evangelismContactsLabel;

  /// No description provided for @evangelismContactsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2'**
  String get evangelismContactsHint;

  /// No description provided for @evangelismOutcomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Outcome / Response'**
  String get evangelismOutcomeLabel;

  /// No description provided for @evangelismOutcomeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. One received the gospel'**
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
  /// **'On Sunday at the scheduled time, the app will remind you to send your weekly report to your disciple maker.'**
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
