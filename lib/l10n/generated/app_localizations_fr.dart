// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class SFr extends S {
  SFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Compte Journalier';

  @override
  String get tagline => 'MARCHER AVEC DIEU · DISCIPLINE CMFI';

  @override
  String get walkWithGod => 'MARCHER AVEC DIEU';

  @override
  String get cmfiDiscipline => 'DISCIPLINE CMFI';

  @override
  String get splashVerse =>
      '\"Rends compte de ton administration.\"\n— Luc 16:2';

  @override
  String get tabLog => 'Journal';

  @override
  String get tabReport => 'Rapport';

  @override
  String get tabSettings => 'Paramètres';

  @override
  String get markComplete => 'Marquer le Jour Complet';

  @override
  String get markedComplete => 'Complété';

  @override
  String get sectionBible => 'Lecture de la Bible';

  @override
  String get bibleRefLabel => 'Passage / Référence';

  @override
  String get bibleRefHint => 'ex. Jean 3 ; Romains 8';

  @override
  String get bibleChaptersLabel => 'Nombre de Chapitres';

  @override
  String get bibleChaptersHint => 'ex. 3';

  @override
  String get bibleSessionFrom => 'De';

  @override
  String get bibleSessionTo => 'À';

  @override
  String get bibleSessionBook => 'Livre';

  @override
  String get bibleSessionChapter => 'Ch.';

  @override
  String bibleSessionChaptersResult(int count) {
    return '= $count chapitre(s)';
  }

  @override
  String get addReadingSession => 'Ajouter une session de lecture';

  @override
  String get removeSession => 'Supprimer';

  @override
  String get durationCustom => 'Personnalisé';

  @override
  String get sectionLiterature => 'Littérature Chrétienne';

  @override
  String get bookTitleLabel => 'Titre du Livre';

  @override
  String get bookTitleHint => 'ex. La Vie Chrétienne Normale';

  @override
  String get amountLabel => 'Quantité';

  @override
  String get amountHint => 'ex. 15';

  @override
  String get unitLabel => 'UNITÉ';

  @override
  String get unitPages => 'Pages';

  @override
  String get unitChapters => 'Chapitres';

  @override
  String get unitBooks => 'Livres';

  @override
  String get addAnotherBook => 'Ajouter un autre livre';

  @override
  String get remove => 'Supprimer';

  @override
  String get sectionDDEG => 'Rencontre Dynamique Quotidienne avec Dieu';

  @override
  String get ddegScriptureLabel => 'Passage Médité';

  @override
  String get ddegScriptureHint => 'ex. Psaume 23:1';

  @override
  String get ddegTimeLabel => 'Temps Passé';

  @override
  String get ddegTimeHint => 'ex. 30 minutes';

  @override
  String get ddegNotesLabel => 'Ce que Dieu t’a dit';

  @override
  String get ddegNotesHint =>
      'Écris ce que le Seigneur t’a révélé ou inspiré...';

  @override
  String get sectionPrayerAlone => 'Prière — Seul avec Dieu';

  @override
  String get durationLabel => 'Durée';

  @override
  String get durationHint => 'ex. 30 minutes';

  @override
  String get prayerAloneNotesLabel =>
      'Comment s’est passé ton temps de prière ?';

  @override
  String get prayerAloneNotesHint => 'Fardeaux, intercessions, percées...';

  @override
  String get sectionPrayerOthers => 'Prière avec les Autres';

  @override
  String get prayerOthersContextLabel => 'Contexte (Qui / Où)';

  @override
  String get prayerOthersContextHint =>
      'ex. Groupe de cellule, réunion de prière';

  @override
  String get sectionEvangelism => 'Évangélisation';

  @override
  String get evangelismContactsLabel => 'Tracts d\'évangile distribués';

  @override
  String get evangelismContactsHint => 'ex. 5';

  @override
  String get evangelismOutcomeLabel => 'Personnes atteintes par l\'évangile';

  @override
  String get evangelismOutcomeHint => 'ex. 3';

  @override
  String get evangelismNotesLabel => 'Notes / Suivi';

  @override
  String get evangelismNotesHint => 'Noms, conversations, prochaines étapes...';

  @override
  String get sectionFasting => 'Jeûne';

  @override
  String get fastingTypeLabel => 'Type de Jeûne';

  @override
  String get fastingTypeHint => 'ex. Jeûne total, partiel, jeûne de Daniel';

  @override
  String get fastingDurationLabel => 'Durée';

  @override
  String get fastingDurationHint => 'ex. 6h – 18h';

  @override
  String get fastingPrayerFocusLabel => 'Sujet de Prière pendant le Jeûne';

  @override
  String get fastingPrayerFocusHint => 'Ce que tu recherches auprès de Dieu...';

  @override
  String get sectionGiving => 'Dons et Dîmes';

  @override
  String get givingTypeLabel => 'Type';

  @override
  String get givingTypeHint => 'ex. Dîme, offrande, semence, missions';

  @override
  String get givingAmountLabel => 'Montant (optionnel)';

  @override
  String get givingAmountHint => 'ex. 5000 FCFA';

  @override
  String get givingPurposeLabel => 'But / Occasion';

  @override
  String get givingPurposeHint => 'ex. Offrande du dimanche, fonds de missions';

  @override
  String get sectionChurch => 'Église et Communion';

  @override
  String get churchTypeLabel => 'Culte / Réunion';

  @override
  String get churchTypeHint =>
      'ex. Culte du dimanche, mi-semaine, groupe de cellule';

  @override
  String get churchNotesLabel => 'Notes';

  @override
  String get churchNotesHint => 'Leçons clés, parole reçue...';

  @override
  String get sectionDiscipleship => 'Discipulat';

  @override
  String get discipleshipWhoLabel => 'Qui disciples-tu ?';

  @override
  String get discipleshipWhoHint => 'Nom(s) des disciples';

  @override
  String get discipleshipTopicLabel => 'Qu’as-tu couvert ?';

  @override
  String get discipleshipTopicHint => 'ex. Vie de prière, consécration';

  @override
  String get discipleshipDurationLabel => 'Durée';

  @override
  String get discipleshipDurationHint => 'ex. 1 heure';

  @override
  String get sectionOther => 'Autres Activités';

  @override
  String get otherLabel => 'Autres Activités Spirituelles';

  @override
  String get otherHint =>
      'Communion fraternelle, service, rayonnement, conférences...';

  @override
  String get reportTitle => 'Compte Hebdomadaire';

  @override
  String get reportSubtitle => 'Ta marche avec Dieu, cette semaine';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count jour$_temp0';
  }

  @override
  String get streakLabel => 'Série de fidélité';

  @override
  String get daysLogged => 'Jours Enregistrés';

  @override
  String get bibleChapters => 'Chapitres Bibliques';

  @override
  String get booksRead => 'Livres Lus';

  @override
  String get soulsReached => 'Âmes Atteintes';

  @override
  String get sundayBanner =>
      'C’est dimanche — il est temps d’envoyer ton compte à ton faiseur de disciples.';

  @override
  String get previewLabel => 'APERÇU';

  @override
  String get sendEmail => 'Envoyer par Email';

  @override
  String get sendWhatsApp => 'WhatsApp';

  @override
  String get copyReport => 'Copier';

  @override
  String get reportCopied => 'Rapport copié dans le presse-papiers.';

  @override
  String get noReportYet =>
      'Aucune entrée cette semaine.\nCommence à enregistrer ta marche avec Dieu !';

  @override
  String get confirmSendTitle => 'Envoyer le Rapport ?';

  @override
  String get confirmSendBody =>
      'Envoyer ton compte hebdomadaire à ton faiseur de disciples ?';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get send => 'Envoyer';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get profileSection => 'Ton Profil';

  @override
  String get yourNameLabel => 'Ton Nom';

  @override
  String get yourNameHint => 'ex. Emmanuel';

  @override
  String get discipleMakerSection => 'Faiseur de Disciples';

  @override
  String get emailLabel => 'Adresse Email';

  @override
  String get emailHint => 'faiseur@example.com';

  @override
  String get whatsappLabel => 'Numéro WhatsApp (intl, sans +)';

  @override
  String get whatsappHint => 'ex. 237670000000';

  @override
  String get remindersSection => 'Rappels';

  @override
  String get dailyReminder => 'Rappel quotidien';

  @override
  String get sundayReminder => 'Rappel du dimanche';

  @override
  String get saveReminders => 'Sauvegarder et Programmer les Rappels';

  @override
  String get remindersSaved => 'Rappels programmés !';

  @override
  String get languageSection => 'Langue';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'Français';

  @override
  String get howItWorksTitle => 'Comment ça marche';

  @override
  String get howItWorks =>
      '1. Enregistre ta marche avec Dieu chaque jour\n2. Marque chaque jour comme complet ✅\n3. Reçois un rappel quotidien, et un spécial chaque dimanche\n4. Appuie sur Envoyer pour transmettre la semaine complète à ton faiseur de disciples par email ou WhatsApp\n5. Tout est stocké en privé sur ton appareil';

  @override
  String get backupSection => 'Sauvegarde et Restauration';

  @override
  String get autoBackupInfo =>
      'Vos données sont automatiquement sauvegardées toutes les 6 heures et synchronisées sur Google Drive.';

  @override
  String get restoreAutoBackup => 'Restaurer la sauvegarde auto';

  @override
  String autoBackupFound(String date) {
    return 'Sauvegarde automatique du $date trouvée. Restaurer ?';
  }

  @override
  String get noAutoBackup => 'Aucune sauvegarde automatique trouvée.';

  @override
  String get restoreButton => 'Restaurer';

  @override
  String get exportData => 'Exporter les Données';

  @override
  String get importData => 'Importer les Données';

  @override
  String get exportSuccess => 'Sauvegarde réussie !';

  @override
  String get importSuccess => 'Données importées avec succès !';

  @override
  String get importFailed =>
      'Échec de l’importation. Format de fichier invalide.';

  @override
  String get importMerge => 'Fusionner avec les données existantes';

  @override
  String get importReplace => 'Remplacer toutes les données';

  @override
  String importPreview(int count) {
    return '$count jours de données trouvés';
  }

  @override
  String get onboardingWelcome => 'Bienvenue sur\nCompte Journalier';

  @override
  String get onboardingWelcomeSub =>
      'Suis ta marche quotidienne avec Dieu.\nReste redevable. Grandis dans la foi.';

  @override
  String get onboardingHow => 'Comment Ça Marche';

  @override
  String get onboardingHowStep1 =>
      'Enregistre tes disciplines spirituelles chaque jour';

  @override
  String get onboardingHowStep2 =>
      'Suis la lecture biblique, la prière, le jeûne, l’évangélisation et plus encore';

  @override
  String get onboardingHowStep3 =>
      'Envoie ton compte hebdomadaire à ton faiseur de disciples chaque dimanche';

  @override
  String get onboardingProfile => 'Ton Profil';

  @override
  String get onboardingProfileSub => 'Parle-nous un peu de toi';

  @override
  String get onboardingLanguage => 'Choisis Ta Langue';

  @override
  String get onboardingStart => 'Commence Ton Parcours';

  @override
  String get next => 'Suivant';

  @override
  String get skip => 'Passer';

  @override
  String get back => 'Retour';

  @override
  String get notifDailyTitle => 'Compte Journalier';

  @override
  String get notifDailyBody =>
      'As-tu enregistré ta marche avec Dieu aujourd’hui ? Appuie pour le faire.';

  @override
  String get notifSundayTitle => 'Dimanche — Envoie Ton Compte';

  @override
  String get notifSundayBody =>
      'Envoie le compte de cette semaine à ton faiseur de disciples. Appuie pour revoir et envoyer.';

  @override
  String reportHeader(String name) {
    return 'COMPTE JOURNALIER — $name';
  }

  @override
  String reportWeekOf(String start, String end) {
    return 'Semaine du $start – $end';
  }

  @override
  String get reportNoEntry => 'Aucune entrée enregistrée.';

  @override
  String reportBible(String ref, String chapters) {
    return 'Bible : $ref ($chapters ch.)';
  }

  @override
  String reportLiterature(String title, String amount, String unit) {
    return 'Littérature : « $title » — $amount $unit';
  }

  @override
  String get reportDDEG => 'RDQ — Rencontre avec Dieu :';

  @override
  String reportDDEGScripture(String scripture) {
    return '   Passage : $scripture';
  }

  @override
  String reportDDEGTime(String time) {
    return '   Temps : $time';
  }

  @override
  String reportDDEGMeditation(String notes) {
    return '   Méditation : $notes';
  }

  @override
  String reportPrayerAlone(String duration, String notes) {
    return 'Prière (Seul) : $duration — $notes';
  }

  @override
  String reportPrayerOthers(String duration, String context) {
    return 'Prière (avec d’autres) : $duration — $context';
  }

  @override
  String reportEvangelism(String contacts, String outcome, String notes) {
    return 'Évangélisation : $contacts contact(s). $outcome. $notes';
  }

  @override
  String reportFasting(String type, String duration, String focus) {
    return 'Jeûne : $type ($duration) — $focus';
  }

  @override
  String reportGiving(String type, String purpose) {
    return 'Dons : $type — $purpose';
  }

  @override
  String reportChurch(String type, String notes) {
    return 'Église : $type — $notes';
  }

  @override
  String reportDiscipleship(String who, String topic, String duration) {
    return 'Discipulat : $who — $topic ($duration)';
  }

  @override
  String reportOther(String other) {
    return 'Autres : $other';
  }

  @override
  String get reportFooter => 'Envoyé avec amour · Compte Journalier';

  @override
  String reportEmailSubject(String name, String date) {
    return 'Compte Spirituel Hebdomadaire — $name ($date)';
  }

  @override
  String get reportSummaryHeader => 'RÉSUMÉ HEBDOMADAIRE';

  @override
  String reportSummaryActiveDays(int count) {
    return 'Jours actifs : $count/7';
  }

  @override
  String reportSummaryBibleChapters(int count) {
    return 'Chapitres de la Bible : $count';
  }

  @override
  String reportSummaryEvangelism(int count) {
    return 'Contacts d\'évangélisation : $count';
  }

  @override
  String reportSummaryCompletion(int pct) {
    return 'Complétion moyenne : $pct%';
  }

  @override
  String get addEmailInSettings =>
      'Ajoutez l\'email de votre faiseur de disciples dans les Paramètres.';

  @override
  String get addWhatsAppInSettings =>
      'Ajoutez le numéro WhatsApp de votre faiseur de disciples dans les Paramètres.';

  @override
  String get emailError => 'Impossible d’ouvrir l’application email.';

  @override
  String get whatsappError => 'Impossible d’ouvrir WhatsApp.';

  @override
  String get invalidEmail => 'Veuillez entrer une adresse email valide.';

  @override
  String get invalidWhatsapp =>
      'Veuillez entrer un numéro de téléphone valide (chiffres uniquement, 10-15 caractères).';

  @override
  String get themeSection => 'Apparence';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeLight => 'Clair';

  @override
  String get notificationsSection => 'Notifications';

  @override
  String get notificationsEnabled => 'Activer les notifications';

  @override
  String get notificationsDisabledMsg => 'Notifications désactivées';

  @override
  String get notificationsEnabledMsg => 'Notifications activées';

  @override
  String get autoSendSection => 'Envoi automatique';

  @override
  String get autoSendEnabled => 'Rappel d’envoi le dimanche';

  @override
  String get autoSendTime => 'Heure du rappel';

  @override
  String get autoSendDescription =>
      'Le dimanche à l’heure programmée, l’application ouvrira automatiquement WhatsApp pour envoyer ton compte à ton faiseur de disciples.';

  @override
  String get aboutSection => 'À propos';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutDescription =>
      'Compte Journalier est un outil de responsabilité spirituelle pour les croyants CMFI. Suivez votre marche quotidienne avec Dieu et envoyez des rapports hebdomadaires à votre faiseur de disciples.';

  @override
  String get madeWithLove => 'Fait avec amour pour CMFI Cameroun';

  @override
  String get dangerZone => 'Zone de danger';

  @override
  String get resetAllData => 'Réinitialiser toutes les données';

  @override
  String get resetConfirmTitle => 'Tout réinitialiser ?';

  @override
  String get resetConfirmBody =>
      'Cela supprimera définitivement tous vos journaux, paramètres et préférences. Cette action est irréversible.';

  @override
  String get resetConfirmButton => 'Tout supprimer';

  @override
  String get resetSuccess => 'Toutes les données ont été réinitialisées.';

  @override
  String get thisWeek => 'Cette Semaine';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String weekOf(String date) {
    return 'Semaine du $date';
  }

  @override
  String get monthlyReport => 'Mensuel';

  @override
  String get weeklyReport => 'Hebdomadaire';

  @override
  String monthOf(String month) {
    return 'Mois de $month';
  }

  @override
  String get monthlySummaryHeader => 'RÉSUMÉ MENSUEL';

  @override
  String monthlySummaryActiveDays(int count, int total) {
    return 'Jours actifs : $count/$total';
  }

  @override
  String monthlySummaryWeeks(int count) {
    return 'Semaines rapportées : $count';
  }

  @override
  String get noReportForWeek =>
      'Aucune entrée pour cette semaine.\nVa dans l\'onglet Journal et sélectionne une date passée pour saisir des données.';

  @override
  String get reportHistory => 'Historique des Rapports';

  @override
  String get reportHistoryEmpty =>
      'Aucun rapport généré pour le moment.\nTes rapports apparaîtront ici après les avoir consultés.';

  @override
  String get reportHistorySection => 'Archive des Rapports';

  @override
  String sentVia(String channel) {
    return 'Envoyé via $channel';
  }

  @override
  String get notSentYet => 'Pas encore envoyé';

  @override
  String get resend => 'Renvoyer';

  @override
  String get viewReport => 'Voir le Rapport';

  @override
  String get deleteReport => 'Supprimer';

  @override
  String get reportSaved => 'Rapport sauvegardé dans l\'archive.';

  @override
  String get reportDeleted => 'Rapport supprimé.';

  @override
  String get copyFromYesterday => 'Copier d\'hier';

  @override
  String get copiedFromYesterday => 'Entrées d\'hier copiées !';

  @override
  String get nothingToCopy => 'Aucune entrée d\'hier à copier.';

  @override
  String get securitySection => 'Sécurité';

  @override
  String get appLockEnabled => 'Verrouillage de l\'app';

  @override
  String get useBiometrics => 'Empreinte digitale / Face ID';

  @override
  String get changePin => 'Changer le PIN';

  @override
  String get setPinTitle => 'Définir un PIN';

  @override
  String get setPinBody =>
      'Choisissez un code PIN à 4 chiffres pour verrouiller l\'application.';

  @override
  String get confirmPinTitle => 'Confirmer le PIN';

  @override
  String get confirmPinBody => 'Ressaisissez votre PIN pour confirmer.';

  @override
  String get pinMismatch => 'Les PINs ne correspondent pas. Réessayez.';

  @override
  String get pinSet => 'PIN de l\'application défini avec succès !';

  @override
  String get pinRemoved => 'Verrouillage désactivé.';

  @override
  String get enterPin => 'Entrez votre PIN';

  @override
  String get wrongPin => 'PIN incorrect';

  @override
  String get useBiometricsPrompt => 'Déverrouiller Compte Journalier';

  @override
  String get saveAsPdf => 'Enregistrer en PDF';

  @override
  String get sharePdf => 'Partager le PDF';

  @override
  String get shareReport => 'Partager';

  @override
  String get tabStopwatch => 'Chrono';

  @override
  String get stopwatchTitle => 'Chronomètre';

  @override
  String get stopwatchSubtitle =>
      'Mesure tes disciplines spirituelles en temps réel';

  @override
  String get todayTotal => 'Total aujourd\'hui';

  @override
  String get timerStopped => 'Chrono arrêté — durée enregistrée !';

  @override
  String get timerAlreadyRunning =>
      'Un autre chrono est en cours. Il sera mis en pause.';

  @override
  String get stopwatchFillFields =>
      'Remplis les détails avant de démarrer (optionnel)';

  @override
  String get startTimer => 'Démarrer le chrono';

  @override
  String get addActivity => 'Ajouter une activité';

  @override
  String get activityName => 'Nom de l\'activité';

  @override
  String get activityNameHint => 'ex. Louange, Méditation';

  @override
  String get activityIcon => 'Icône emoji';

  @override
  String get activityCreated => 'Activité ajoutée !';

  @override
  String get activityDeleted => 'Activité supprimée.';

  @override
  String get deleteActivityConfirm => 'Supprimer cette activité ?';

  @override
  String get customFieldLabel => 'Libellé du champ notes (optionnel)';

  @override
  String get customFieldHint => 'ex. Qu\'as-tu appris ?';

  @override
  String get ddegShort => 'RDQD';

  @override
  String get bibleStartRef => 'Référence de début';

  @override
  String get bibleStartHint => 'ex. Jean 1';

  @override
  String get bibleEndRef => 'Référence de fin (après lecture)';

  @override
  String get bibleEndHint => 'ex. Jean 3';

  @override
  String bibleChaptersRead(int count) {
    return '$count chapitre(s) lu(s)';
  }

  @override
  String get enterEndReference => 'Où as-tu terminé ta lecture ?';

  @override
  String timerStoppedDuration(String duration) {
    return 'Durée : $duration';
  }

  @override
  String get done => 'Terminé';

  @override
  String get sectionProclamation => 'Proclamation';

  @override
  String get proclamationCountLabel => 'Nombre de proclamations';

  @override
  String get proclamationCountHint => 'ex. 50';

  @override
  String get proclamationDurationLabel => 'Durée (optionnel)';

  @override
  String get proclamationDurationHint => 'ex. 10 minutes';

  @override
  String get proclamationCounter => 'Compteur de Proclamation';

  @override
  String get proclamationSubtitle => 'Proclame : Jésus-Christ est Seigneur !';

  @override
  String get proclamationTap => 'Appuie pour proclamer';

  @override
  String get proclamationSave => 'Enregistrer et Fermer';

  @override
  String reportProclamation(String count, String duration) {
    return 'Proclamation : $count fois ($duration)';
  }

  @override
  String get followUpReminders => 'Rappels de suivi';

  @override
  String get followUpDescription =>
      'Après le rappel principal, des alertes de suivi sonnent toutes les 30 minutes pour ne rien oublier.';

  @override
  String followUpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '3 suivis (+30, +60, +90 min)',
      two: '2 suivis (+30, +60 min)',
      one: '1 suivi (+30 min)',
      zero: 'Aucun suivi',
    );
    return '$_temp0';
  }

  @override
  String get notificationIntensity => 'Intensité des notifications';

  @override
  String get intensityAggressive => 'Agressive (style alarme)';

  @override
  String get intensityAggressiveDesc =>
      'Alertes plein écran, son, vibration, LED — comme un réveil';

  @override
  String get sundayFollowUps => 'Suivis du dimanche';

  @override
  String sundayFollowUpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suivis',
      two: '2 suivis (+30, +60 min)',
      one: '1 suivi (+30 min)',
      zero: 'Aucun suivi',
    );
    return '$_temp0';
  }

  @override
  String get tabPrayer => 'Prières';

  @override
  String get prayerRequestsTitle => 'Sujets de Prière';

  @override
  String get prayerRequestsSubtitle => 'Dépose tes fardeaux devant le Seigneur';

  @override
  String get prayerActive => 'Actifs';

  @override
  String get prayerAnswered => 'Exaucés';

  @override
  String get prayerEmptyActive =>
      'Aucun sujet de prière.\nAppuie sur + pour ajouter ton premier sujet.';

  @override
  String prayerAnsweredSection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prières exaucées',
      one: '1 prière exaucée',
    );
    return '$_temp0';
  }

  @override
  String get prayerAddTitle => 'Nouveau Sujet de Prière';

  @override
  String get prayerTitleLabel => 'Sujet de prière';

  @override
  String get prayerTitleHint => 'ex. Guérison pour mon frère';

  @override
  String get prayerDescLabel => 'Détails (optionnel)';

  @override
  String get prayerDescHint => 'Plus de contexte sur ce sujet...';

  @override
  String get prayerAddButton => 'Ajouter le Sujet';

  @override
  String get prayerCatPersonal => 'Personnel';

  @override
  String get prayerCatFamily => 'Famille';

  @override
  String get prayerCatChurch => 'Église';

  @override
  String get prayerCatNation => 'Nation';

  @override
  String get prayerCatHealth => 'Santé';

  @override
  String get prayerMarkAnswered => 'Prière Exaucée !';

  @override
  String get prayerAnswerNote => 'Comment Dieu a-t-il répondu ?';

  @override
  String get prayerAnswerHint => 'Décris comment cette prière a été exaucée...';

  @override
  String get prayerConfirmAnswered => 'Marquer comme Exaucé';

  @override
  String get weeklyChart => 'PROGRESSION HEBDOMADAIRE';

  @override
  String get chartCompletion => 'Complétion %';

  @override
  String get quickLogTitle => 'Journal Rapide';

  @override
  String get quickLogSubtitle =>
      'Coche chaque discipline pratiquée aujourd\'hui';

  @override
  String get quickLogSaved => 'Journal rapide enregistré !';

  @override
  String get quickLogButton => 'Journal Rapide';

  @override
  String get badgeStreakWeek => 'Guerrier 7 Jours';

  @override
  String get badgeStreakMonth => 'Champion 30 Jours';

  @override
  String get badgeBibleMarathon => 'Marathon Biblique';

  @override
  String get badgePrayerWarrior => 'Guerrier de Prière';

  @override
  String get badgeEvangelismFire => 'Gagneur d\'Âmes';

  @override
  String get badgePerfectWeek => 'Semaine Parfaite';

  @override
  String get badgesTitle => 'ACCOMPLISSEMENTS';

  @override
  String get badgesEmpty =>
      'Continue ! Les badges apparaîtront au fur et à mesure.';

  @override
  String get snoozeLabel => 'Reporter 15 min';

  @override
  String get testNotification => 'Tester les Notifications';

  @override
  String get testNotificationSuccess =>
      'Notification envoyée ! Si vous ne la voyez pas, vérifiez les paramètres de notification.';

  @override
  String get testNotificationFailed =>
      'Notification échouée. Activez les notifications dans les paramètres de votre appareil.';

  @override
  String pendingNotifications(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications planifiées',
      one: '1 notification planifiée',
      zero: 'Aucune notification planifiée',
    );
    return '$_temp0';
  }

  @override
  String get missingDisciplinesTitle => 'Disciplines Manquantes';

  @override
  String get missingDisciplinesSubtitle =>
      'Appuyez pour les compléter aujourd\'hui';

  @override
  String get disciplineDone => 'Fait';

  @override
  String get disciplineMissing => 'Manquant';

  @override
  String get allDisciplinesDone =>
      'Toutes les disciplines complétées ! Excellent !';

  @override
  String get pendingReportBanner => 'Rapport en attente — sera envoyé en ligne';

  @override
  String get pendingReportRetry => 'Réessayer';

  @override
  String get pendingReportSent => 'Rapport en attente envoyé !';

  @override
  String get offlineStatus => 'Hors ligne';

  @override
  String get midWeekNudgeTitle => 'Bilan de mi-semaine';

  @override
  String midWeekNudgeBody(int done, int total) {
    return 'Vous avez complété $done/$total disciplines cette semaine. Continuez !';
  }

  @override
  String trendUp(int percent) {
    return 'en hausse de $percent%';
  }

  @override
  String trendDown(int percent) {
    return 'en baisse de $percent%';
  }

  @override
  String get trendSteady => 'stable';

  @override
  String get trendVsLastMonth => 'vs le mois dernier';

  @override
  String get trendTitle => 'TENDANCES';

  @override
  String get trendConsistency => 'Régularité';

  @override
  String get trendBestDiscipline => 'Point fort';

  @override
  String get trendWeakDiscipline => 'À améliorer';

  @override
  String get trendNoData => 'Pas assez de données pour les tendances';

  @override
  String get reflectionTitle => 'Réflexion Quotidienne';

  @override
  String get reflectionEmpty =>
      'Complétez des disciplines pour recevoir une réflexion';

  @override
  String reflectionGreatDay(int count) {
    return 'Magnifique journée de fidélité ! Vous avez couvert $count disciplines — votre engagement porte du fruit.';
  }

  @override
  String reflectionGoodDay(int count) {
    return 'Bon effort aujourd\'hui avec $count disciplines. Continuez à bâtir la régularité !';
  }

  @override
  String reflectionStartDay(int count) {
    return 'Vous avez commencé avec $count discipline. Chaque pas compte — continuez !';
  }

  @override
  String get reflectionPrayerFocus =>
      'Votre vie de prière est forte aujourd\'hui. Qu\'elle nourrisse vos autres disciplines.';

  @override
  String get reflectionBibleFocus =>
      'Excellent engagement biblique aujourd\'hui. Que la Parole guide votre journée.';

  @override
  String get reflectionEvangelismFocus =>
      'Actif en évangélisation aujourd\'hui — des âmes sont atteintes !';

  @override
  String get reflectionBalanced =>
      'Une journée magnifiquement équilibrée à travers vos disciplines.';

  @override
  String reflectionStreakEncouragement(int days) {
    return 'Vous êtes sur une série de $days jours ! Ne la brisez pas !';
  }

  @override
  String get evangelismFollowUp => 'Suivi';

  @override
  String get evangelismNewBelievers => 'Ceux qui ont accepté Jésus';

  @override
  String get evangelismNewBelieversHint =>
      'Nombre de personnes qui ont accepté Christ dans leur cœur';

  @override
  String get evangelismBeingDiscipled => 'En cours de formation';

  @override
  String get evangelismBeingDiscipledHint => 'Nombre en formation de disciple';

  @override
  String get evangelismFollowUpNotes => 'Notes de suivi';

  @override
  String get evangelismFollowUpHint => 'Noms, prochaines étapes, besoins...';

  @override
  String get textSizeLabel => 'Taille du texte';

  @override
  String get textSizeSmall => 'A';

  @override
  String get textSizeLarge => 'A+';

  @override
  String get textSizePreview => 'Aperçu du texte';

  @override
  String get disciplineReminders => 'Rappels par discipline';

  @override
  String get disciplineRemindersDesc =>
      'Définir une heure pour chaque discipline';

  @override
  String get disciplineReminderOff => 'Désactivé';

  @override
  String get disciplineReminderSet => 'Défini';

  @override
  String get weeklyGoals => 'Objectifs hebdomadaires';

  @override
  String get weeklyGoalsDesc => 'Définissez vos cibles pour la semaine';

  @override
  String get dailyGoals => 'Objectifs quotidiens';

  @override
  String get dailyGoalsDesc => 'Définissez vos cibles pour chaque jour';

  @override
  String get goalFrequency => 'Fréquence';

  @override
  String get daily => 'Quotidien';

  @override
  String get weekly => 'Hebdomadaire';

  @override
  String get enterGoalValue => 'Entrer la valeur';

  @override
  String get goalBibleChapters => 'Chapitres bibliques';

  @override
  String get goalPrayerMinutes => 'Prière (minutes)';

  @override
  String get goalEvangelismContacts => 'Contacts d\'évangélisation';

  @override
  String get goalLiteratureItems => 'Livres lus';

  @override
  String goalProgress(String current, String target) {
    return '$current/$target';
  }

  @override
  String get goalReached => 'Objectif atteint !';

  @override
  String get setGoals => 'Définir les objectifs';

  @override
  String get saveGoals => 'Enregistrer';

  @override
  String get weeklyChallenge => 'Défi de la semaine';

  @override
  String challengeWeakDiscipline(String discipline) {
    return 'Concentrez-vous sur $discipline — votre point faible cette semaine';
  }

  @override
  String get challengePrayerDaily =>
      'Priez chaque jour cette semaine — même 5 minutes comptent';

  @override
  String get challengeBibleDaily =>
      'Lisez au moins 1 chapitre biblique chaque jour';

  @override
  String get challengeEvangelism =>
      'Partagez l’évangile avec 3 personnes cette semaine';

  @override
  String get challengeStreak7 =>
      'Continuez à journaliser pour atteindre 7 jours consécutifs !';

  @override
  String get challengeStreak30 =>
      'Vous êtes en feu ! Visez 30 jours consécutifs !';

  @override
  String get challengePerfectWeek =>
      'Presque ! Journalisez chaque jour pour une semaine parfaite !';

  @override
  String get milestoneStreak7 => '7 jours consécutifs !';

  @override
  String get milestoneStreak7Body =>
      'Une semaine complète de fidélité. Continuez !';

  @override
  String get milestoneStreak30 => '30 jours consécutifs !';

  @override
  String get milestoneStreak30Body =>
      'Un mois de discipline quotidienne. Vous construisez quelque chose de durable.';

  @override
  String get milestoneStreak100 => '100 jours consécutifs !';

  @override
  String get milestoneStreak100Body =>
      '100 jours de marche avec Dieu. Quel témoignage !';

  @override
  String get milestonePerfectWeek => 'Semaine parfaite !';

  @override
  String get milestonePerfectWeekBody =>
      'Chaque jour comptabilisé. Bien fait, serviteur fidèle.';

  @override
  String get milestoneBibleMarathon => 'Marathon biblique !';

  @override
  String get milestoneBibleMarathonBody =>
      '20+ chapitres cette semaine. La Parole est vivante en vous.';

  @override
  String get milestoneShare => 'Partager la réussite';

  @override
  String get voiceNote => 'Note vocale';

  @override
  String get voiceNoteRecord => 'Appuyez pour enregistrer';

  @override
  String get voiceNoteRecording => 'Enregistrement...';

  @override
  String get voiceNotePlay => 'Écouter';

  @override
  String get voiceNoteDelete => 'Supprimer l\'enregistrement';

  @override
  String get voiceNoteDeleteConfirm => 'Supprimer cette note vocale ?';

  @override
  String get voiceNoteSaved => 'Note vocale enregistrée';

  @override
  String get fastingPeriod => 'Période de jeûne';

  @override
  String get fastingStartDate => 'Date de début';

  @override
  String get fastingEndDate => 'Date de fin';

  @override
  String get fastingTypeComplete => 'Jeûne complet';

  @override
  String get fastingTypePartial => 'Jeûne partiel';

  @override
  String get fastingTypeEsther => 'Jeûne d\'Esther';

  @override
  String fastingDaysRemaining(int days) {
    return '$days jours restants';
  }

  @override
  String fastingDayOf(int current, int total) {
    return 'Jour $current sur $total';
  }

  @override
  String get fastingActive => 'Jeûne actif';

  @override
  String get fastingCompleted => 'Jeûne terminé !';

  @override
  String get fastingNone => 'Pas de jeûne actif';

  @override
  String get startFast => 'Commencer un jeûne';

  @override
  String get endFast => 'Terminer le jeûne';

  @override
  String get certificateTitle => 'Certificat de fidélité';

  @override
  String get certificateSubtitle => 'Réalisation spirituelle mensuelle';

  @override
  String certificateBody(String name, String month, int percent) {
    return 'Ceci certifie que $name a fait preuve de discipline spirituelle fidèle au cours de $month, atteignant $percent% de cohérence globale.';
  }

  @override
  String get certificateGenerate => 'Générer le certificat';

  @override
  String get certificateShare => 'Partager le certificat';

  @override
  String get certificateNoData =>
      'Il faut au moins 80% de régularité pour obtenir un certificat';

  @override
  String get autoFillBanner =>
      'Rempli automatiquement selon vos habitudes récentes';

  @override
  String get autoFillUndo => 'Annuler';

  @override
  String get reportLanguageSection => 'Langue du rapport';

  @override
  String get reportLanguageDesc =>
      'Choisissez la langue des rapports envoyés et des documents PDF';

  @override
  String get reportLanguageSameAsApp => 'Identique à l\'application';

  @override
  String get saturdaySummaryTitle => 'Votre semaine jusqu\'ici';

  @override
  String saturdaySummaryBody(int days, int chapters, int contacts) {
    return '$days/7 jours enregistrés, $chapters chapitres lus, $contacts contacts évangélisés. Terminez en beauté demain !';
  }

  @override
  String get cloudBackupSection => 'Sauvegarde Cloud';

  @override
  String get cloudBackupDescription =>
      'Connectez-vous avec votre compte Google pour sauvegarder toutes vos données sur Google Drive. Restaurez-les sur n\'importe quel appareil.';

  @override
  String get signInWithGoogle => 'Se connecter avec Google';

  @override
  String signedInAs(String email) {
    return 'Connecté en tant que $email';
  }

  @override
  String lastCloudBackup(String date) {
    return 'Dernière sauvegarde : $date';
  }

  @override
  String get backupToDrive => 'Sauvegarder sur Google Drive';

  @override
  String get restoreFromDrive => 'Restaurer depuis Google Drive';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get cloudBackupSuccess => 'Sauvegardé sur Google Drive !';

  @override
  String get cloudBackupFailed =>
      'Échec de la sauvegarde cloud. Vérifiez votre connexion.';

  @override
  String get cloudRestoreSuccess => 'Données restaurées depuis Google Drive !';

  @override
  String get cloudRestoreFailed =>
      'Échec de la restauration. Vérifiez votre connexion.';

  @override
  String get cloudRestoreConfirmTitle => 'Restaurer depuis le cloud ?';

  @override
  String get cloudRestoreConfirmBody =>
      'Ceci remplacera toutes les données locales par la sauvegarde cloud. Êtes-vous sûr ?';

  @override
  String get cloudNoBackupFound =>
      'Aucune sauvegarde trouvée sur votre Google Drive.';

  @override
  String get cloudSignInFailed =>
      'Échec de la connexion Google. Veuillez réessayer.';

  @override
  String get timeConsciousLabel => 'Mode temps conscient';

  @override
  String get timeConsciousDescription =>
      'Suivre le temps que vous consacrez à chaque activité spirituelle';

  @override
  String totalTimeConsecrated(String time) {
    return 'Temps total consacré : $time';
  }

  @override
  String get save => 'Enregistrer';

  @override
  String get customActivityTitle => 'Créer une activité';

  @override
  String get customActivityName => 'Nom de l\'activité';

  @override
  String get customActivityNameHint => 'ex. Louange, Prière de jeûne';

  @override
  String get customActivityIcon => 'Icône';

  @override
  String get customActivityTemplates => 'Modèles rapides';

  @override
  String get customActivityTemplateSimple => 'Simple';

  @override
  String get customActivityTemplateTimed => 'Minuté';

  @override
  String get customActivityTemplateCounted => 'Compté';

  @override
  String get customActivityTemplateFull => 'Complet';

  @override
  String get customActivityAddField => 'Ajouter un champ';

  @override
  String get customActivityFieldLabel => 'Libellé du champ';

  @override
  String get customActivityFieldType => 'Type';

  @override
  String get customActivityCountsForProgress =>
      'Compte pour la progression quotidienne';

  @override
  String get customFieldTypeText => 'Texte';

  @override
  String get customFieldTypeNumber => 'Nombre';

  @override
  String get customFieldTypeDuration => 'Durée';

  @override
  String get customFieldTypeYesNo => 'Oui/Non';

  @override
  String get customFieldTypeNotes => 'Notes';

  @override
  String get customActivityMaxFields => 'Maximum 8 champs';

  @override
  String get cancelTimerTitle => 'Annuler le minuteur ?';

  @override
  String cancelTimerContent(String elapsed, String name) {
    return 'Abandonner $elapsed de $name ?';
  }

  @override
  String get cancelTimerKeep => 'Continuer';

  @override
  String get cancelTimerDiscard => 'Abandonner';
}
