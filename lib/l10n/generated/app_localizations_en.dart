// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Daily Account';

  @override
  String get tagline => 'WALK WITH GOD · CMFI DISCIPLINE';

  @override
  String get walkWithGod => 'WALK WITH GOD';

  @override
  String get cmfiDiscipline => 'CMFI DISCIPLINE';

  @override
  String get splashVerse =>
      '\"Give an account of thy stewardship.\"\n— Luke 16:2';

  @override
  String get tabLog => 'Log';

  @override
  String get tabReport => 'Report';

  @override
  String get tabSettings => 'Settings';

  @override
  String get markComplete => 'Mark Day Complete';

  @override
  String get markedComplete => 'Completed';

  @override
  String get sectionBible => 'Bible Reading';

  @override
  String get bibleRefLabel => 'Passage / Reference';

  @override
  String get bibleRefHint => 'e.g. John 3; Romans 8';

  @override
  String get bibleChaptersLabel => 'Number of Chapters';

  @override
  String get bibleChaptersHint => 'e.g. 3';

  @override
  String get sectionLiterature => 'Christian Literature';

  @override
  String get bookTitleLabel => 'Book Title';

  @override
  String get bookTitleHint => 'e.g. The Normal Christian Life';

  @override
  String get amountLabel => 'Amount';

  @override
  String get amountHint => 'e.g. 15';

  @override
  String get unitLabel => 'UNIT';

  @override
  String get unitPages => 'Pages';

  @override
  String get unitChapters => 'Chapters';

  @override
  String get unitBooks => 'Books';

  @override
  String get addAnotherBook => 'Add another book';

  @override
  String get remove => 'Remove';

  @override
  String get sectionDDEG => 'Daily Dynamic Encounter with God';

  @override
  String get ddegScriptureLabel => 'Scripture Meditated On';

  @override
  String get ddegScriptureHint => 'e.g. Psalm 23:1';

  @override
  String get ddegTimeLabel => 'Time Spent';

  @override
  String get ddegTimeHint => 'e.g. 30 minutes';

  @override
  String get ddegNotesLabel => 'What God Spoke to You';

  @override
  String get ddegNotesHint => 'Write what the Lord revealed or impressed...';

  @override
  String get sectionPrayerAlone => 'Prayer — Alone with God';

  @override
  String get durationLabel => 'Duration';

  @override
  String get durationHint => 'e.g. 45 minutes';

  @override
  String get prayerAloneNotesLabel => 'How was your prayer time?';

  @override
  String get prayerAloneNotesHint => 'Burdens, intercessions, breakthroughs...';

  @override
  String get sectionPrayerOthers => 'Prayer with Others';

  @override
  String get prayerOthersContextLabel => 'Context (Who / Where)';

  @override
  String get prayerOthersContextHint => 'e.g. Cell group, prayer meeting';

  @override
  String get sectionEvangelism => 'Evangelism';

  @override
  String get evangelismContactsLabel => 'Number of Contacts';

  @override
  String get evangelismContactsHint => 'e.g. 2';

  @override
  String get evangelismOutcomeLabel => 'Outcome / Response';

  @override
  String get evangelismOutcomeHint => 'e.g. One received the gospel';

  @override
  String get evangelismNotesLabel => 'Notes / Follow-up';

  @override
  String get evangelismNotesHint => 'Names, conversations, next steps...';

  @override
  String get sectionFasting => 'Fasting';

  @override
  String get fastingTypeLabel => 'Type of Fast';

  @override
  String get fastingTypeHint => 'e.g. Full fast, partial, Daniel fast';

  @override
  String get fastingDurationLabel => 'Duration';

  @override
  String get fastingDurationHint => 'e.g. 6am – 6pm';

  @override
  String get fastingPrayerFocusLabel => 'Prayer Focus During Fast';

  @override
  String get fastingPrayerFocusHint => 'What you are seeking God for...';

  @override
  String get sectionGiving => 'Giving & Tithes';

  @override
  String get givingTypeLabel => 'Type';

  @override
  String get givingTypeHint => 'e.g. Tithe, offering, seed, missions';

  @override
  String get givingAmountLabel => 'Amount (optional)';

  @override
  String get givingAmountHint => 'e.g. 5000 FCFA';

  @override
  String get givingPurposeLabel => 'Purpose / Occasion';

  @override
  String get givingPurposeHint => 'e.g. Sunday offering, missions fund';

  @override
  String get sectionChurch => 'Church & Fellowship';

  @override
  String get churchTypeLabel => 'Service / Meeting';

  @override
  String get churchTypeHint => 'e.g. Sunday service, midweek, cell group';

  @override
  String get churchNotesLabel => 'Notes';

  @override
  String get churchNotesHint => 'Key lessons, word received...';

  @override
  String get sectionDiscipleship => 'Discipleship';

  @override
  String get discipleshipWhoLabel => 'Who Are You Discipling?';

  @override
  String get discipleshipWhoHint => 'Name(s) of disciples';

  @override
  String get discipleshipTopicLabel => 'What Did You Cover?';

  @override
  String get discipleshipTopicHint => 'e.g. Prayer life, consecration';

  @override
  String get discipleshipDurationLabel => 'Duration';

  @override
  String get discipleshipDurationHint => 'e.g. 1 hour';

  @override
  String get sectionOther => 'Other Activities';

  @override
  String get otherLabel => 'Other Spiritual Activities';

  @override
  String get otherHint => 'Fellowship, service, outreach, conferences...';

  @override
  String get reportTitle => 'Weekly Account';

  @override
  String get reportSubtitle => 'Your walk with God, this week';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get streakLabel => 'Faithfulness streak';

  @override
  String get daysLogged => 'Days Logged';

  @override
  String get bibleChapters => 'Bible Chapters';

  @override
  String get booksRead => 'Books Read';

  @override
  String get soulsReached => 'Souls Reached';

  @override
  String get sundayBanner =>
      'It\'s Sunday — time to send your account to your disciple maker.';

  @override
  String get previewLabel => 'PREVIEW';

  @override
  String get sendEmail => 'Send via Email';

  @override
  String get sendWhatsApp => 'WhatsApp';

  @override
  String get copyReport => 'Copy';

  @override
  String get reportCopied => 'Report copied to clipboard.';

  @override
  String get noReportYet =>
      'No entries this week yet.\nStart logging your walk with God!';

  @override
  String get confirmSendTitle => 'Send Report?';

  @override
  String get confirmSendBody =>
      'Send your weekly account to your disciple maker?';

  @override
  String get cancel => 'Cancel';

  @override
  String get send => 'Send';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get profileSection => 'Your Profile';

  @override
  String get yourNameLabel => 'Your Name';

  @override
  String get yourNameHint => 'e.g. Emmanuel';

  @override
  String get discipleMakerSection => 'Disciple Maker';

  @override
  String get emailLabel => 'Email Address';

  @override
  String get emailHint => 'disciplemaker@example.com';

  @override
  String get whatsappLabel => 'WhatsApp Number (intl, no +)';

  @override
  String get whatsappHint => 'e.g. 237670000000';

  @override
  String get remindersSection => 'Reminders';

  @override
  String get dailyReminder => 'Daily log reminder';

  @override
  String get sundayReminder => 'Sunday send reminder';

  @override
  String get saveReminders => 'Save & Schedule Reminders';

  @override
  String get remindersSaved => 'Reminders scheduled!';

  @override
  String get languageSection => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'Français';

  @override
  String get howItWorksTitle => 'How it works';

  @override
  String get howItWorks =>
      '1. Log your walk with God each day\n2. Mark each day complete ✅\n3. Get a gentle reminder daily, and a special one each Sunday\n4. Tap Send to email or WhatsApp the full week to your disciple maker\n5. Everything is stored privately on your device';

  @override
  String get backupSection => 'Backup & Restore';

  @override
  String get exportData => 'Export Data';

  @override
  String get importData => 'Import Data';

  @override
  String get exportSuccess => 'Backup saved successfully!';

  @override
  String get importSuccess => 'Data imported successfully!';

  @override
  String get importFailed => 'Import failed. Invalid file format.';

  @override
  String get importMerge => 'Merge with existing data';

  @override
  String get importReplace => 'Replace all data';

  @override
  String importPreview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days of logs found',
      one: '1 day of logs found',
    );
    return '$_temp0';
  }

  @override
  String get onboardingWelcome => 'Welcome to\nDaily Account';

  @override
  String get onboardingWelcomeSub =>
      'Track your daily walk with God.\nStay accountable. Grow in faith.';

  @override
  String get onboardingHow => 'How It Works';

  @override
  String get onboardingHowStep1 => 'Log your spiritual disciplines each day';

  @override
  String get onboardingHowStep2 =>
      'Track Bible reading, prayer, fasting, evangelism, and more';

  @override
  String get onboardingHowStep3 =>
      'Send your weekly account to your disciple maker every Sunday';

  @override
  String get onboardingProfile => 'Your Profile';

  @override
  String get onboardingProfileSub => 'Tell us a little about you';

  @override
  String get onboardingLanguage => 'Choose Your Language';

  @override
  String get onboardingStart => 'Begin Your Journey';

  @override
  String get next => 'Next';

  @override
  String get skip => 'Skip';

  @override
  String get back => 'Back';

  @override
  String get notifDailyTitle => 'Daily Account';

  @override
  String get notifDailyBody =>
      'Have you recorded your walk with God today? Tap to log it.';

  @override
  String get notifSundayTitle => 'Sunday — Send Your Account';

  @override
  String get notifSundayBody =>
      'Send this week\'s account to your disciple maker. Tap to review & send.';

  @override
  String reportHeader(String name) {
    return 'DAILY ACCOUNT — $name';
  }

  @override
  String reportWeekOf(String start, String end) {
    return 'Week of $start – $end';
  }

  @override
  String get reportNoEntry => 'No entry recorded.';

  @override
  String reportBible(String ref, String chapters) {
    return 'Bible: $ref ($chapters ch.)';
  }

  @override
  String reportLiterature(String title, String amount, String unit) {
    return 'Literature: \"$title\" — $amount $unit';
  }

  @override
  String get reportDDEG => 'DDEG — Encounter with God:';

  @override
  String reportDDEGScripture(String scripture) {
    return '   Scripture: $scripture';
  }

  @override
  String reportDDEGTime(String time) {
    return '   Time: $time';
  }

  @override
  String reportDDEGMeditation(String notes) {
    return '   Meditation: $notes';
  }

  @override
  String reportPrayerAlone(String duration, String notes) {
    return 'Prayer (Alone): $duration — $notes';
  }

  @override
  String reportPrayerOthers(String duration, String context) {
    return 'Prayer (with others): $duration — $context';
  }

  @override
  String reportEvangelism(String contacts, String outcome, String notes) {
    return 'Evangelism: $contacts contact(s). $outcome. $notes';
  }

  @override
  String reportFasting(String type, String duration, String focus) {
    return 'Fasting: $type ($duration) — $focus';
  }

  @override
  String reportGiving(String type, String purpose) {
    return 'Giving: $type — $purpose';
  }

  @override
  String reportChurch(String type, String notes) {
    return 'Church: $type — $notes';
  }

  @override
  String reportDiscipleship(String who, String topic, String duration) {
    return 'Discipleship: $who — $topic ($duration)';
  }

  @override
  String reportOther(String other) {
    return 'Other: $other';
  }

  @override
  String get reportFooter => 'Sent with love · Daily Account';

  @override
  String reportEmailSubject(String name, String date) {
    return 'Weekly Spiritual Account — $name ($date)';
  }

  @override
  String get emailError => 'Could not open email app.';

  @override
  String get whatsappError => 'Could not open WhatsApp.';

  @override
  String get invalidEmail => 'Please enter a valid email address.';

  @override
  String get invalidWhatsapp =>
      'Please enter a valid phone number (digits only, 10-15 chars).';
}
