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
  String get delete => 'Delete';

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
  String get autoBackupInfo =>
      'Your data is automatically backed up every 6 hours and synced to Google Drive.';

  @override
  String get restoreAutoBackup => 'Restore from Auto-Backup';

  @override
  String autoBackupFound(String date) {
    return 'Auto-backup found from $date. Restore it?';
  }

  @override
  String get noAutoBackup => 'No auto-backup found.';

  @override
  String get restoreButton => 'Restore';

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
  String get reportSummaryHeader => 'WEEKLY SUMMARY';

  @override
  String reportSummaryActiveDays(int count) {
    return 'Active days: $count/7';
  }

  @override
  String reportSummaryBibleChapters(int count) {
    return 'Bible chapters: $count';
  }

  @override
  String reportSummaryEvangelism(int count) {
    return 'Evangelism contacts: $count';
  }

  @override
  String reportSummaryCompletion(int pct) {
    return 'Avg. completion: $pct%';
  }

  @override
  String get addEmailInSettings =>
      'Add your disciple maker\'s email in Settings first.';

  @override
  String get addWhatsAppInSettings =>
      'Add your disciple maker\'s WhatsApp number in Settings first.';

  @override
  String get emailError => 'Could not open email app.';

  @override
  String get whatsappError => 'Could not open WhatsApp.';

  @override
  String get invalidEmail => 'Please enter a valid email address.';

  @override
  String get invalidWhatsapp =>
      'Please enter a valid phone number (digits only, 10-15 chars).';

  @override
  String get themeSection => 'Appearance';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get notificationsSection => 'Notifications';

  @override
  String get notificationsEnabled => 'Enable Notifications';

  @override
  String get notificationsDisabledMsg => 'Notifications disabled';

  @override
  String get notificationsEnabledMsg => 'Notifications enabled';

  @override
  String get autoSendSection => 'Auto-Send Report';

  @override
  String get autoSendEnabled => 'Auto-open report on Sunday';

  @override
  String get autoSendTime => 'Send reminder time';

  @override
  String get autoSendDescription =>
      'On Sunday at the scheduled time, the app will automatically open WhatsApp to send your weekly report to your disciple maker.';

  @override
  String get aboutSection => 'About';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutDescription =>
      'Daily Account is a spiritual accountability tool for CMFI believers. Track your daily walk with God, and send weekly reports to your disciple maker.';

  @override
  String get madeWithLove => 'Made with love for CMFI Cameroon';

  @override
  String get dangerZone => 'Danger Zone';

  @override
  String get resetAllData => 'Reset All Data';

  @override
  String get resetConfirmTitle => 'Reset Everything?';

  @override
  String get resetConfirmBody =>
      'This will permanently delete all your logs, settings, and preferences. This action cannot be undone.';

  @override
  String get resetConfirmButton => 'Delete Everything';

  @override
  String get resetSuccess => 'All data has been reset.';

  @override
  String get thisWeek => 'This Week';

  @override
  String get today => 'Today';

  @override
  String weekOf(String date) {
    return 'Week of $date';
  }

  @override
  String get monthlyReport => 'Monthly';

  @override
  String get weeklyReport => 'Weekly';

  @override
  String monthOf(String month) {
    return 'Month of $month';
  }

  @override
  String get monthlySummaryHeader => 'MONTHLY SUMMARY';

  @override
  String monthlySummaryActiveDays(int count, int total) {
    return 'Active days: $count/$total';
  }

  @override
  String monthlySummaryWeeks(int count) {
    return 'Weeks reported: $count';
  }

  @override
  String get noReportForWeek =>
      'No entries for this week.\nNavigate to the Log tab and select a past date to enter data.';

  @override
  String get reportHistory => 'Report History';

  @override
  String get reportHistoryEmpty =>
      'No reports generated yet.\nYour reports will appear here after you view them.';

  @override
  String get reportHistorySection => 'Report Archive';

  @override
  String sentVia(String channel) {
    return 'Sent via $channel';
  }

  @override
  String get notSentYet => 'Not sent yet';

  @override
  String get resend => 'Resend';

  @override
  String get viewReport => 'View Report';

  @override
  String get deleteReport => 'Delete';

  @override
  String get reportSaved => 'Report saved to archive.';

  @override
  String get reportDeleted => 'Report deleted.';

  @override
  String get copyFromYesterday => 'Copy from yesterday';

  @override
  String get copiedFromYesterday => 'Copied yesterday\'s entries!';

  @override
  String get nothingToCopy => 'No entries from yesterday to copy.';

  @override
  String get securitySection => 'Security';

  @override
  String get appLockEnabled => 'App Lock';

  @override
  String get useBiometrics => 'Use Fingerprint / Face ID';

  @override
  String get changePin => 'Change PIN';

  @override
  String get setPinTitle => 'Set App PIN';

  @override
  String get setPinBody => 'Choose a 4-digit PIN to lock your app.';

  @override
  String get confirmPinTitle => 'Confirm PIN';

  @override
  String get confirmPinBody => 'Re-enter your PIN to confirm.';

  @override
  String get pinMismatch => 'PINs don\'t match. Try again.';

  @override
  String get pinSet => 'App PIN set successfully!';

  @override
  String get pinRemoved => 'App lock disabled.';

  @override
  String get enterPin => 'Enter your PIN';

  @override
  String get wrongPin => 'Wrong PIN';

  @override
  String get useBiometricsPrompt => 'Unlock Daily Account';

  @override
  String get saveAsPdf => 'Save as PDF';

  @override
  String get sharePdf => 'Share PDF';

  @override
  String get shareReport => 'Share';

  @override
  String get tabStopwatch => 'Timer';

  @override
  String get stopwatchTitle => 'Activity Timer';

  @override
  String get stopwatchSubtitle =>
      'Track your spiritual disciplines in real time';

  @override
  String get todayTotal => 'Today\'s total';

  @override
  String get timerStopped => 'Timer stopped — duration saved!';

  @override
  String get timerAlreadyRunning =>
      'Another timer is running. It will be paused.';

  @override
  String get stopwatchFillFields =>
      'Fill in details before starting (optional)';

  @override
  String get startTimer => 'Start Timer';

  @override
  String get addActivity => 'Add Activity';

  @override
  String get activityName => 'Activity name';

  @override
  String get activityNameHint => 'e.g. Worship, Meditation';

  @override
  String get activityIcon => 'Emoji icon';

  @override
  String get activityCreated => 'Activity added!';

  @override
  String get activityDeleted => 'Activity removed.';

  @override
  String get deleteActivityConfirm => 'Remove this activity?';

  @override
  String get customFieldLabel => 'Notes field label (optional)';

  @override
  String get customFieldHint => 'e.g. What did you learn?';

  @override
  String get ddegShort => 'DDEG';

  @override
  String get bibleStartRef => 'Starting reference';

  @override
  String get bibleStartHint => 'e.g. John 1';

  @override
  String get bibleEndRef => 'Ending reference (after reading)';

  @override
  String get bibleEndHint => 'e.g. John 3';

  @override
  String bibleChaptersRead(int count) {
    return '$count chapter(s) read';
  }

  @override
  String get enterEndReference => 'Where did you finish reading?';

  @override
  String timerStoppedDuration(String duration) {
    return 'Duration: $duration';
  }

  @override
  String get done => 'Done';

  @override
  String get sectionProclamation => 'Proclamation';

  @override
  String get proclamationCountLabel => 'Number of Proclamations';

  @override
  String get proclamationCountHint => 'e.g. 50';

  @override
  String get proclamationDurationLabel => 'Duration (optional)';

  @override
  String get proclamationDurationHint => 'e.g. 10 minutes';

  @override
  String get proclamationCounter => 'Proclamation Counter';

  @override
  String get proclamationSubtitle => 'Proclaim: Jesus Christ is the Lord!';

  @override
  String get proclamationTap => 'Tap to proclaim';

  @override
  String get proclamationSave => 'Save & Close';

  @override
  String reportProclamation(String count, String duration) {
    return 'Proclamation: $count times ($duration)';
  }

  @override
  String get followUpReminders => 'Follow-up reminders';

  @override
  String get followUpDescription =>
      'After the main reminder, follow-up alerts fire every 30 minutes to make sure you don\'t forget.';

  @override
  String followUpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '3 follow-ups (+30, +60, +90 min)',
      two: '2 follow-ups (+30, +60 min)',
      one: '1 follow-up (+30 min)',
      zero: 'No follow-ups',
    );
    return '$_temp0';
  }

  @override
  String get notificationIntensity => 'Notification Intensity';

  @override
  String get intensityAggressive => 'Aggressive (alarm-style)';

  @override
  String get intensityAggressiveDesc =>
      'Full-screen alerts, sound, vibration, LED — like an alarm clock';

  @override
  String get sundayFollowUps => 'Sunday follow-ups';

  @override
  String sundayFollowUpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count follow-ups',
      two: '2 follow-ups (+30, +60 min)',
      one: '1 follow-up (+30 min)',
      zero: 'No follow-ups',
    );
    return '$_temp0';
  }

  @override
  String get tabPrayer => 'Prayer';

  @override
  String get prayerRequestsTitle => 'Prayer Requests';

  @override
  String get prayerRequestsSubtitle => 'Bring your burdens before the Lord';

  @override
  String get prayerActive => 'Active';

  @override
  String get prayerAnswered => 'Answered';

  @override
  String get prayerEmptyActive =>
      'No prayer requests yet.\nTap + to add your first request.';

  @override
  String prayerAnsweredSection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count answered prayers',
      one: '1 answered prayer',
    );
    return '$_temp0';
  }

  @override
  String get prayerAddTitle => 'New Prayer Request';

  @override
  String get prayerTitleLabel => 'Prayer request';

  @override
  String get prayerTitleHint => 'e.g. Healing for my brother';

  @override
  String get prayerDescLabel => 'Details (optional)';

  @override
  String get prayerDescHint => 'More context about this request...';

  @override
  String get prayerAddButton => 'Add Prayer Request';

  @override
  String get prayerCatPersonal => 'Personal';

  @override
  String get prayerCatFamily => 'Family';

  @override
  String get prayerCatChurch => 'Church';

  @override
  String get prayerCatNation => 'Nation';

  @override
  String get prayerCatHealth => 'Health';

  @override
  String get prayerMarkAnswered => 'Prayer Answered!';

  @override
  String get prayerAnswerNote => 'How did God answer?';

  @override
  String get prayerAnswerHint => 'Describe how this prayer was answered...';

  @override
  String get prayerConfirmAnswered => 'Mark as Answered';

  @override
  String get weeklyChart => 'WEEKLY PROGRESS';

  @override
  String get chartCompletion => 'Completion %';

  @override
  String get quickLogTitle => 'Quick Log';

  @override
  String get quickLogSubtitle => 'Tap each discipline you practiced today';

  @override
  String get quickLogSaved => 'Quick log saved!';

  @override
  String get quickLogButton => 'Quick Log';

  @override
  String get badgeStreakWeek => '7-Day Warrior';

  @override
  String get badgeStreakMonth => '30-Day Champion';

  @override
  String get badgeBibleMarathon => 'Bible Marathon';

  @override
  String get badgePrayerWarrior => 'Prayer Warrior';

  @override
  String get badgeEvangelismFire => 'Soul Winner';

  @override
  String get badgePerfectWeek => 'Perfect Week';

  @override
  String get badgesTitle => 'ACHIEVEMENTS';

  @override
  String get badgesEmpty => 'Keep going! Badges will appear as you grow.';

  @override
  String get snoozeLabel => 'Snooze 15 min';

  @override
  String get testNotification => 'Test Notification';

  @override
  String get testNotificationSuccess =>
      'Notification sent! If you don\'t see it, check your system notification settings.';

  @override
  String get testNotificationFailed =>
      'Notification failed. Please enable notifications in your device settings.';

  @override
  String pendingNotifications(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications scheduled',
      one: '1 notification scheduled',
      zero: 'No scheduled notifications',
    );
    return '$_temp0';
  }

  @override
  String get missingDisciplinesTitle => 'Missing Disciplines';

  @override
  String get missingDisciplinesSubtitle => 'Tap to complete these today';

  @override
  String get disciplineDone => 'Done';

  @override
  String get disciplineMissing => 'Missing';

  @override
  String get allDisciplinesDone => 'All disciplines completed! Great job!';

  @override
  String get pendingReportBanner => 'Report pending — will send when online';

  @override
  String get pendingReportRetry => 'Retry now';

  @override
  String get pendingReportSent => 'Pending report sent!';

  @override
  String get offlineStatus => 'Offline';

  @override
  String get midWeekNudgeTitle => 'Mid-Week Check-in';

  @override
  String midWeekNudgeBody(int done, int total) {
    return 'You\'ve completed $done/$total disciplines this week. Keep going!';
  }

  @override
  String trendUp(int percent) {
    return 'up $percent%';
  }

  @override
  String trendDown(int percent) {
    return 'down $percent%';
  }

  @override
  String get trendSteady => 'steady';

  @override
  String get trendVsLastMonth => 'vs last month';

  @override
  String get trendTitle => 'TRENDS';

  @override
  String get trendConsistency => 'Consistency';

  @override
  String get trendBestDiscipline => 'Strongest';

  @override
  String get trendWeakDiscipline => 'Needs attention';

  @override
  String get trendNoData => 'Not enough data for trends yet';

  @override
  String get reflectionTitle => 'Daily Reflection';

  @override
  String get reflectionEmpty =>
      'Complete some disciplines to receive a reflection';

  @override
  String reflectionGreatDay(int count) {
    return 'Wonderful day of faithfulness! You covered $count disciplines — your commitment is bearing fruit.';
  }

  @override
  String reflectionGoodDay(int count) {
    return 'Good effort today with $count disciplines. Keep building consistency!';
  }

  @override
  String reflectionStartDay(int count) {
    return 'You\'ve started with $count discipline. Every step counts — keep pressing forward!';
  }

  @override
  String get reflectionPrayerFocus =>
      'Your prayer life is strong today. Let it fuel your other disciplines.';

  @override
  String get reflectionBibleFocus =>
      'Great Bible engagement today. Let the Word guide your day.';

  @override
  String get reflectionEvangelismFocus =>
      'Active in evangelism today — souls are being reached!';

  @override
  String get reflectionBalanced =>
      'A beautifully balanced day across your disciplines.';

  @override
  String reflectionStreakEncouragement(int days) {
    return 'You\'re on a $days-day streak! Don\'t break it!';
  }

  @override
  String get evangelismFollowUp => 'Follow-up';

  @override
  String get evangelismNewBelievers => 'New believers';

  @override
  String get evangelismNewBelieversHint =>
      'Number of people who accepted Christ';

  @override
  String get evangelismBeingDiscipled => 'Being discipled';

  @override
  String get evangelismBeingDiscipledHint => 'Number now in discipleship';

  @override
  String get evangelismFollowUpNotes => 'Follow-up notes';

  @override
  String get evangelismFollowUpHint => 'Names, next steps, needs...';

  @override
  String get textSizeLabel => 'Text size';

  @override
  String get textSizeSmall => 'A';

  @override
  String get textSizeLarge => 'A+';

  @override
  String get textSizePreview => 'Preview text';

  @override
  String get disciplineReminders => 'Discipline reminders';

  @override
  String get disciplineRemindersDesc => 'Set a time for each discipline';

  @override
  String get disciplineReminderOff => 'Off';

  @override
  String get disciplineReminderSet => 'Set';

  @override
  String get weeklyGoals => 'Weekly Goals';

  @override
  String get weeklyGoalsDesc => 'Set targets for the week';

  @override
  String get dailyGoals => 'Daily Goals';

  @override
  String get dailyGoalsDesc => 'Set targets for each day';

  @override
  String get goalFrequency => 'Frequency';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get enterGoalValue => 'Enter value';

  @override
  String get goalBibleChapters => 'Bible chapters';

  @override
  String get goalPrayerMinutes => 'Prayer (minutes)';

  @override
  String get goalEvangelismContacts => 'Evangelism contacts';

  @override
  String get goalLiteratureItems => 'Literature items';

  @override
  String goalProgress(String current, String target) {
    return '$current/$target';
  }

  @override
  String get goalReached => 'Goal reached!';

  @override
  String get setGoals => 'Set goals';

  @override
  String get saveGoals => 'Save';

  @override
  String get voiceNote => 'Voice note';

  @override
  String get voiceNoteRecord => 'Tap to record';

  @override
  String get voiceNoteRecording => 'Recording...';

  @override
  String get voiceNotePlay => 'Play';

  @override
  String get voiceNoteDelete => 'Delete recording';

  @override
  String get voiceNoteDeleteConfirm => 'Delete this voice note?';

  @override
  String get voiceNoteSaved => 'Voice note saved';

  @override
  String get fastingPeriod => 'Fasting period';

  @override
  String get fastingStartDate => 'Start date';

  @override
  String get fastingEndDate => 'End date';

  @override
  String get fastingTypeComplete => 'Complete fast';

  @override
  String get fastingTypePartial => 'Partial fast';

  @override
  String get fastingTypeEsther => 'Esther fast';

  @override
  String fastingDaysRemaining(int days) {
    return '$days days remaining';
  }

  @override
  String fastingDayOf(int current, int total) {
    return 'Day $current of $total';
  }

  @override
  String get fastingActive => 'Active fast';

  @override
  String get fastingCompleted => 'Fast completed!';

  @override
  String get fastingNone => 'No active fast';

  @override
  String get startFast => 'Start a fast';

  @override
  String get endFast => 'End fast';

  @override
  String get certificateTitle => 'Certificate of Faithfulness';

  @override
  String get certificateSubtitle => 'Monthly Spiritual Achievement';

  @override
  String certificateBody(String name, String month, int percent) {
    return 'This certifies that $name demonstrated faithful spiritual discipline during $month, achieving $percent% overall consistency across all disciplines.';
  }

  @override
  String get certificateGenerate => 'Generate certificate';

  @override
  String get certificateShare => 'Share certificate';

  @override
  String get certificateNoData =>
      'Need at least 80% consistency to earn a certificate';

  @override
  String get autoFillBanner => 'Auto-filled from your recent patterns';

  @override
  String get autoFillUndo => 'Undo';

  @override
  String get reportLanguageSection => 'Report Language';

  @override
  String get reportLanguageDesc =>
      'Choose the language for sent reports and PDF documents';

  @override
  String get reportLanguageSameAsApp => 'Same as app';

  @override
  String get saturdaySummaryTitle => 'Your week so far';

  @override
  String saturdaySummaryBody(int days, int chapters, int contacts) {
    return '$days/7 days logged, $chapters chapters read, $contacts contacts evangelized. Finish strong tomorrow!';
  }
}
