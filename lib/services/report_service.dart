import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/generated/app_localizations.dart';
import 'storage_service.dart';

class WeekStats {
  int daysLogged;
  int totalBibleChapters;
  int totalEvangelismContacts;
  int litItems;
  WeekStats(this.daysLogged, this.totalBibleChapters, this.totalEvangelismContacts, this.litItems);
}

/// Builds the weekly report and dispatches it via email or WhatsApp.
class ReportService {
  static final ReportService instance = ReportService._();
  ReportService._();

  /// Monday→Sunday dates for the week containing [ref] (default today).
  List<DateTime> weekDates([DateTime? ref]) {
    final today = ref ?? DateTime.now();
    final monday = today.subtract(Duration(days: (today.weekday + 6) % 7));
    return List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));
  }

  String keyFor(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<WeekStats> computeWeekStats() async {
    final dates = weekDates();
    final logs = await StorageService.instance
        .getLogsBetween(keyFor(dates.first), keyFor(dates.last));
    int days = 0, chapters = 0, contacts = 0, lit = 0;
    for (final l in logs) {
      if (l.completed) days++;
      chapters += int.tryParse(l.bibleChapters) ?? 0;
      contacts += int.tryParse(l.evangelismContacts) ?? 0;
      lit += l.literature.where((e) => e.title.isNotEmpty).length;
    }
    return WeekStats(days, chapters, contacts, lit);
  }

  /// Current consecutive-day streak ending today.
  Future<int> computeStreak() async {
    int streak = 0;
    var day = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final log = await StorageService.instance.getLog(keyFor(day));
      if (log != null && log.completed) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        // allow today to be unlogged without breaking the streak
        if (i == 0) {
          day = day.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
    }
    return streak;
  }

  /// Build the weekly report using localized strings from [l].
  Future<String> buildWeeklyReport(String name, S l) async {
    final dates = weekDates();
    final fmtLong = DateFormat('EEEE, MMM d');
    final fmtRange = DateFormat('MMM d');
    final buf = StringBuffer();

    buf.writeln('✝️ ${l.reportHeader(name.isEmpty ? "Disciple" : name)}');
    buf.writeln(l.reportWeekOf(fmtRange.format(dates.first), fmtRange.format(dates.last)));
    buf.writeln('');

    int activeDays = 0;
    int totalChapters = 0;
    int totalContacts = 0;
    double totalCompletion = 0;

    for (final d in dates) {
      final log = await StorageService.instance.getLog(keyFor(d));
      buf.writeln('━━━━━━━━━━━━━━━━━━━━');
      buf.writeln('📅 ${fmtLong.format(d).toUpperCase()}');
      // Show data if the log has any content, even if not explicitly marked complete
      final hasContent = log != null && log.completeness > 0;
      if (log == null || !hasContent) {
        buf.writeln('   ⚠️  ${l.reportNoEntry}');
        buf.writeln('');
        continue;
      }
      activeDays++;
      totalChapters += int.tryParse(log.bibleChapters) ?? 0;
      totalContacts += int.tryParse(log.evangelismContacts) ?? 0;
      totalCompletion += log.completeness;

      if (log.bibleReference.isNotEmpty) {
        buf.writeln('📖 ${l.reportBible(log.bibleReference, log.bibleChapters.isNotEmpty ? log.bibleChapters : "0")}');
      }
      for (final lit in log.literature.where((e) => e.title.isNotEmpty)) {
        buf.writeln('📚 ${l.reportLiterature(lit.title, lit.amount, lit.unit)}');
      }
      if (log.ddegScripture.isNotEmpty || log.ddegNotes.isNotEmpty) {
        buf.writeln('🔥 ${l.reportDDEG}');
        if (log.ddegScripture.isNotEmpty) buf.writeln(l.reportDDEGScripture(log.ddegScripture));
        if (log.ddegTime.isNotEmpty) buf.writeln(l.reportDDEGTime(log.ddegTime));
        if (log.ddegNotes.isNotEmpty) buf.writeln(l.reportDDEGMeditation(log.ddegNotes));
      }
      if (log.prayerAloneDuration.isNotEmpty) {
        buf.writeln('🙏 ${l.reportPrayerAlone(log.prayerAloneDuration, log.prayerAloneNotes)}');
      }
      if (log.prayerOthersDuration.isNotEmpty) {
        buf.writeln('🤝 ${l.reportPrayerOthers(log.prayerOthersDuration, log.prayerOthersContext)}');
      }
      if (log.evangelismContacts.isNotEmpty) {
        buf.writeln('📢 ${l.reportEvangelism(log.evangelismContacts, log.evangelismOutcome, log.evangelismNotes)}');
      }
      if (log.fastingType.isNotEmpty || log.fastingDuration.isNotEmpty) {
        buf.writeln('🍽️ ${l.reportFasting(log.fastingType, log.fastingDuration, log.fastingPrayerFocus)}');
      }
      if (log.givingType.isNotEmpty) {
        buf.writeln('💰 ${l.reportGiving(log.givingType, log.givingPurpose)}');
      }
      if (log.churchType.isNotEmpty) {
        buf.writeln('⛪ ${l.reportChurch(log.churchType, log.churchNotes)}');
      }
      if (log.discipleshipWho.isNotEmpty) {
        buf.writeln('👥 ${l.reportDiscipleship(log.discipleshipWho, log.discipleshipTopic, log.discipleshipDuration)}');
      }
      if (log.other.isNotEmpty) buf.writeln('➕ ${l.reportOther(log.other)}');
      buf.writeln('');
    }

    // Weekly summary for the disciple maker
    buf.writeln('━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('📊 ${l.reportSummaryHeader}');
    buf.writeln(l.reportSummaryActiveDays(activeDays));
    buf.writeln(l.reportSummaryBibleChapters(totalChapters));
    buf.writeln(l.reportSummaryEvangelism(totalContacts));
    final avgPct = activeDays > 0 ? (totalCompletion / activeDays * 100).round() : 0;
    buf.writeln(l.reportSummaryCompletion(avgPct));
    buf.writeln('');
    buf.writeln('${l.reportFooter} 🕊️');
    return buf.toString();
  }

  /// Open the device email client pre-filled with the report.
  Future<bool> sendByEmail(String toEmail, String name, String body, S l) async {
    final subject = '📖 ${l.reportEmailSubject(
      name.isEmpty ? "Disciple" : name,
      DateFormat('MMM d, y').format(DateTime.now()),
    )}';
    final uri = Uri(
      scheme: 'mailto',
      path: toEmail,
      query: _encodeQuery({'subject': subject, 'body': body}),
    );
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Share the report via WhatsApp (reliable fallback).
  Future<bool> sendByWhatsApp(String phone, String body) async {
    // phone in international format without '+' e.g. 237xxxxxxxxx
    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(body)}');
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  String _encodeQuery(Map<String, String> params) => params.entries
      .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
}
