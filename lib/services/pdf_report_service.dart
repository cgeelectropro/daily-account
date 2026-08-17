import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/daily_log.dart';
import 'report_cadence_service.dart';
import 'report_service.dart';
import 'storage_service.dart';

/// Generates styled PDF reports for weekly / monthly accounts.
class PdfReportService {
  static final PdfReportService instance = PdfReportService._();
  PdfReportService._();

  // ── Brand colours (espresso + gold) ──────────────────────
  static const _bg = PdfColor.fromInt(0xFF0D0A05);
  static const _gold = PdfColor.fromInt(0xFFD4AF64);
  static const _goldDeep = PdfColor.fromInt(0xFFA07830);
  static const _sand = PdfColor.fromInt(0xFFA09070);
  static const _green = PdfColor.fromInt(0xFF6FBF73);
  static const _rust = PdfColor.fromInt(0xFFC97B5A);

  // ═════════════════════════════════════════════════════════
  //  PUBLIC API
  // ═════════════════════════════════════════════════════════

  /// Build + show print/share dialog for a weekly report.
  Future<void> printWeeklyReport(String name, DateTime ref, S l, [String locale = 'en']) async {
    final doc = await _buildWeeklyPdf(name, ref, l, locale);
    final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
    final dates = ReportService.instance.weekDates(ref, endWeekday);
    final fmtRange = DateFormat('MMM_d', locale);
    final fileName = 'DailyAccount_${fmtRange.format(dates.first)}-${fmtRange.format(dates.last)}.pdf';
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: fileName,
    );
  }

  /// Build + show print/share dialog for a monthly report.
  Future<void> printMonthlyReport(String name, int year, int month, S l, [String locale = 'en']) async {
    final doc = await _buildMonthlyPdf(name, year, month, l, locale);
    final fmtMonth = DateFormat('MMMM_yyyy', locale);
    final fileName = 'DailyAccount_${fmtMonth.format(DateTime(year, month, 1))}.pdf';
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: fileName,
    );
  }

  /// Share PDF bytes directly (for system share sheet).
  Future<void> shareWeeklyPdf(String name, DateTime ref, S l, [String locale = 'en']) async {
    final doc = await _buildWeeklyPdf(name, ref, l, locale);
    final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
    final dates = ReportService.instance.weekDates(ref, endWeekday);
    final fmtRange = DateFormat('MMM_d', locale);
    final fileName = 'DailyAccount_${fmtRange.format(dates.first)}-${fmtRange.format(dates.last)}.pdf';
    await Printing.sharePdf(bytes: await doc.save(), filename: fileName);
  }

  Future<void> shareMonthlyPdf(String name, int year, int month, S l, [String locale = 'en']) async {
    final doc = await _buildMonthlyPdf(name, year, month, l, locale);
    final fmtMonth = DateFormat('MMMM_yyyy', locale);
    final fileName = 'DailyAccount_${fmtMonth.format(DateTime(year, month, 1))}.pdf';
    await Printing.sharePdf(bytes: await doc.save(), filename: fileName);
  }

  // ═════════════════════════════════════════════════════════
  //  WEEKLY PDF
  // ═════════════════════════════════════════════════════════

  Future<pw.Document> _buildWeeklyPdf(String name, DateTime ref, S l, [String locale = 'en']) async {
    final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
    final dates = ReportService.instance.weekDates(ref, endWeekday);
    final stats = await ReportService.instance.computeWeekStats(ref);
    final fmtRange = DateFormat('MMM d, yyyy', locale);
    final fmtLong = DateFormat('EEEE, MMM d', locale);

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.loraRegular(),
        bold: await PdfGoogleFonts.loraBold(),
        italic: await PdfGoogleFonts.loraItalic(),
      ),
    );

    // Collect all day logs
    final dayLogs = <DailyLog?>[];
    for (final d in dates) {
      dayLogs.add(await StorageService.instance.getLog(ReportService.instance.keyFor(d)));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _header(
          name.isEmpty ? 'Disciple' : name,
          '${fmtRange.format(dates.first)} – ${fmtRange.format(dates.last)}',
          l,
        ),
        footer: (ctx) => _footer(ctx, l),
        build: (ctx) {
          final widgets = <pw.Widget>[];

          // Summary stats row
          widgets.add(_summaryRow(stats, l));
          widgets.add(pw.SizedBox(height: 16));

          // Day-by-day entries
          for (int i = 0; i < dates.length; i++) {
            widgets.add(_dayEntry(fmtLong.format(dates[i]), dayLogs[i], l, locale));
            if (i < dates.length - 1) widgets.add(pw.SizedBox(height: 8));
          }

          return widgets;
        },
      ),
    );

    return doc;
  }

  // ═════════════════════════════════════════════════════════
  //  MONTHLY PDF
  // ═════════════════════════════════════════════════════════

  Future<pw.Document> _buildMonthlyPdf(String name, int year, int month, S l, [String locale = 'en']) async {
    final monthStats = await ReportService.instance.computeMonthStats(year, month);
    final fmtMonth = DateFormat('MMMM yyyy', locale);
    final fmtLong = DateFormat('EEEE, MMM d', locale);
    final monthDate = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);

    // Collect all day logs for the month
    final dayDates = <DateTime>[];
    final dayLogs = <DailyLog?>[];
    for (int day = 1; day <= lastDay.day; day++) {
      final d = DateTime(year, month, day);
      if (d.isAfter(DateTime.now())) break;
      dayDates.add(d);
      dayLogs.add(await StorageService.instance.getLog(ReportService.instance.keyFor(d)));
    }

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.loraRegular(),
        bold: await PdfGoogleFonts.loraBold(),
        italic: await PdfGoogleFonts.loraItalic(),
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _header(
          name.isEmpty ? 'Disciple' : name,
          fmtMonth.format(monthDate),
          l,
        ),
        footer: (ctx) => _footer(ctx, l),
        build: (ctx) {
          final widgets = <pw.Widget>[];

          // Monthly summary at the top
          widgets.add(_monthlySummaryBlock(monthStats, l));
          widgets.add(pw.SizedBox(height: 16));

          // Full day-by-day entries — same format as weekly PDF
          for (int i = 0; i < dayDates.length; i++) {
            widgets.add(_dayEntry(fmtLong.format(dayDates[i]), dayLogs[i], l, locale));
            if (i < dayDates.length - 1) widgets.add(pw.SizedBox(height: 8));
          }

          return widgets;
        },
      ),
    );

    return doc;
  }

  // ═════════════════════════════════════════════════════════
  //  SHARED PDF COMPONENTS
  // ═════════════════════════════════════════════════════════

  pw.Widget _header(String name, String period, S l) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _gold, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                l.appTitle.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _gold,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                name,
                style: pw.TextStyle(
                  fontSize: 14,
                  color: _goldDeep,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
          pw.Text(
            period,
            style: const pw.TextStyle(fontSize: 11, color: _sand),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context ctx, S l) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _sand, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            l.reportFooter,
            style: const pw.TextStyle(fontSize: 8, color: _sand),
          ),
          pw.Text(
            l.pdfPageOf(ctx.pageNumber, ctx.pagesCount),
            style: const pw.TextStyle(fontSize: 8, color: _sand),
          ),
        ],
      ),
    );
  }

  pw.Widget _summaryRow(WeekStats stats, S l) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFAF6EF),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _gold, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _statCell('${stats.daysLogged}/7', l.daysLogged),
          _statCell('${stats.totalBibleChapters}', l.bibleChapters),
          _statCell('${stats.litItems}', l.booksRead),
          _statCell('${stats.totalEvangelismContacts}', l.soulsReached),
        ],
      ),
    );
  }

  pw.Widget _monthlySummaryBlock(MonthStats ms, S l) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFAF6EF),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _gold, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            l.monthlySummaryHeader,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _gold,
              letterSpacing: 1.5,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _statCell('${ms.daysLogged}/${ms.totalDays}', l.pdfActiveDays),
              _statCell('${ms.weeksReported}', l.pdfWeeksReported),
              _statCell('${ms.totalBibleChapters}', l.bibleChapters),
              _statCell('${ms.totalEvangelismContacts}', l.soulsReached),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _statCell('${ms.litItems}', l.booksRead),
              _statCell('${(ms.avgCompletion * 100).round()}%', l.pdfAvgCompletion),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _statCell(String value, String label) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: _goldDeep,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: _sand),
        ),
      ],
    );
  }

  pw.Widget _dayEntry(String dayLabel, DailyLog? log, S l, [String locale = 'en']) {
    final hasContent = log != null && log.completeness > 0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: hasContent ? _gold.shade(0.3) : _sand.shade(0.3),
          width: 0.5,
        ),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Day header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                dayLabel.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: hasContent ? _gold : _sand,
                  letterSpacing: 1,
                ),
              ),
              if (hasContent)
                _completionBadge(log.completeness),
            ],
          ),
          pw.SizedBox(height: 6),
          if (!hasContent)
            pw.Text(
              l.reportNoEntry,
              style: pw.TextStyle(
                fontSize: 10,
                color: _sand,
                fontStyle: pw.FontStyle.italic,
              ),
            )
          else
            ..._dayDetailRows(log, l, locale),
        ],
      ),
    );
  }

  pw.Widget _completionBadge(double completeness) {
    final pct = (completeness * 100).round();
    final color = pct >= 70 ? _green : (pct >= 40 ? _gold : _rust);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Text(
        '$pct%',
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  List<pw.Widget> _dayDetailRows(DailyLog log, S l, [String locale = 'en']) {
    final rows = <pw.Widget>[];

    final bibleRef = log.combinedBibleReference(locale);
    if (bibleRef.isNotEmpty || log.totalBibleChapters > 0) {
      rows.add(_detailRow(l.pdfBible, '${bibleRef.isNotEmpty ? bibleRef : log.bibleReference} (${log.totalBibleChapters} ${l.pdfChAbbr})'));
    }
    for (final lit in log.literature.where((e) => e.title.isNotEmpty)) {
      rows.add(_detailRow(l.pdfLiterature, '"${lit.title}" — ${lit.amount} ${lit.unit}'));
    }
    if (log.ddegScripture.isNotEmpty || log.ddegNotes.isNotEmpty) {
      final parts = <String>[];
      if (log.ddegScripture.isNotEmpty) parts.add(log.ddegScripture);
      if (log.ddegTime.isNotEmpty) parts.add(log.ddegTime);
      if (log.ddegNotes.isNotEmpty) parts.add(log.ddegNotes);
      rows.add(_detailRow(l.ddegShort, parts.join(' · ')));
    }
    if (log.prayerAloneSessions.any((s) => s.isNotEmpty)) {
      for (final s in log.prayerAloneSessions.where((s) => s.isNotEmpty)) {
        final label = s.title.isNotEmpty ? s.title : l.pdfPrayerAlone;
        final detail = '${s.duration}${s.notes.isNotEmpty ? " — ${s.notes}" : ""}';
        rows.add(_detailRow(label, detail));
      }
    } else if (log.prayerAloneDuration.isNotEmpty) {
      rows.add(_detailRow(l.pdfPrayerAlone, '${log.prayerAloneDuration}${log.prayerAloneNotes.isNotEmpty ? " — ${log.prayerAloneNotes}" : ""}'));
    }
    if (log.prayerOthersSessions.any((s) => s.isNotEmpty)) {
      for (final s in log.prayerOthersSessions.where((s) => s.isNotEmpty)) {
        final label = s.title.isNotEmpty ? s.title : l.pdfPrayerOthers;
        final peopleSuffix = s.peopleCount.isNotEmpty ? ' (${s.peopleCount})' : '';
        rows.add(_detailRow(label, '${s.duration}$peopleSuffix'));
      }
    } else if (log.prayerOthersDuration.isNotEmpty) {
      rows.add(_detailRow(l.pdfPrayerOthers, '${log.prayerOthersDuration}${log.prayerOthersContext.isNotEmpty ? " — ${log.prayerOthersContext}" : ""}'));
    }
    if (log.evangelismContacts.isNotEmpty || log.evangelismSessions.isNotEmpty) {
      if (log.evangelismSessions.isNotEmpty && log.evangelismContacts.isEmpty) {
        // Session-only day — mirror report_service.dart's session-aware
        // rendering ("N sessions, X min total") since there's no manual
        // contact count / outcome / notes to show for this day.
        final mins = log.totalEvangelismMinutes;
        final durationStr = mins >= 60 ? '${mins ~/ 60}h ${mins % 60}min' : '${mins}min';
        rows.add(_detailRow(l.pdfEvangelism, l.reportEvangelismSessions('${log.evangelismSessions.length}', durationStr)));
      } else {
        final parts = <String>[
          '${log.evangelismContacts} ${l.pdfContacts}',
          if (log.evangelismOutcome.isNotEmpty) log.evangelismOutcome,
          if (log.evangelismNotes.isNotEmpty) log.evangelismNotes,
        ];
        rows.add(_detailRow(l.pdfEvangelism, parts.join('. ')));
      }
      // Follow-up data
      if (log.evangelismNewBelievers.isNotEmpty) {
        rows.add(_detailRow('  ${l.pdfNewBelievers}', log.evangelismNewBelievers));
      }
      if (log.evangelismBeingDiscipled.isNotEmpty) {
        rows.add(_detailRow('  ${l.pdfBeingDiscipled}', log.evangelismBeingDiscipled));
      }
      if (log.evangelismFollowUpNotes.isNotEmpty) {
        rows.add(_detailRow('  ${l.evangelismFollowUp}', log.evangelismFollowUpNotes));
      }
    }
    if (log.fastingType.isNotEmpty || log.fastingDuration.isNotEmpty) {
      rows.add(_detailRow(l.sectionFasting, '${log.fastingType} (${log.fastingDuration})${log.fastingPrayerFocus.isNotEmpty ? " — ${log.fastingPrayerFocus}" : ""}'));
    }
    for (final g in log.giving.where((e) => e.isNotEmpty)) {
      final givingParts = <String>[
        g.type,
        if (g.amount.isNotEmpty) g.amount,
        if (g.purpose.isNotEmpty) g.purpose,
      ];
      rows.add(_detailRow(l.pdfGiving, givingParts.join(' — ')));
    }
    if (log.churchType.isNotEmpty || log.churchSessions.isNotEmpty) {
      if (log.churchSessions.isNotEmpty && log.churchType.isEmpty) {
        final mins = log.totalChurchMinutes;
        final durationStr = mins >= 60 ? '${mins ~/ 60}h ${mins % 60}min' : '${mins}min';
        rows.add(_detailRow(l.pdfChurch, l.reportChurchSessions('${log.churchSessions.length}', durationStr)));
      } else {
        rows.add(_detailRow(l.pdfChurch, '${log.churchType}${log.churchNotes.isNotEmpty ? " — ${log.churchNotes}" : ""}'));
      }
    }
    if (log.discipleshipWho.isNotEmpty) {
      rows.add(_detailRow(l.sectionDiscipleship, '${log.discipleshipWho}${log.discipleshipTopic.isNotEmpty ? " — ${log.discipleshipTopic}" : ""}${log.discipleshipDuration.isNotEmpty ? " (${log.discipleshipDuration})" : ""}'));
    }
    if (log.proclamationSessions.isNotEmpty) {
      final parts = log.proclamationSessions.map((s) {
        final label = s.topic.isNotEmpty ? s.topic : l.sectionProclamation;
        // A session can have a real duration but zero count (the user only
        // filled in the Duration field) — that's genuine data, not a
        // phantom entry, but showing "0x" would look broken. Omit the
        // count suffix entirely when count is 0.
        if (s.count == 0) {
          return '$label (${s.duration})';
        }
        final dur = s.duration.isNotEmpty ? s.duration : '-';
        return '$label (${s.count}x, $dur)';
      }).join(', ');
      rows.add(_detailRow(l.sectionProclamation, parts));
    } else if (log.proclamationCount.isNotEmpty) {
      rows.add(_detailRow(l.sectionProclamation, '${log.proclamationCount} ${l.pdfTimes}${log.proclamationDuration.isNotEmpty ? " (${log.proclamationDuration})" : ""}'));
    }
    if (log.other.isNotEmpty) {
      rows.add(_detailRow(l.pdfOther, log.other));
    }
    // Custom activities
    for (final entry in log.customActivityData.entries) {
      final actData = entry.value;
      if (actData['done'] != true) continue;
      final fields = actData['fields'] as Map<String, dynamic>? ?? {};
      final parts = fields.entries
          .where((e) => !e.key.startsWith('_') && e.value.toString().isNotEmpty)
          .map((e) => '${e.key}: ${e.value}')
          .join(', ');
      final label = entry.key;
      rows.add(_detailRow(label, parts.isNotEmpty ? parts : '\u2713'));
    }

    return rows;
  }

  // ═════════════════════════════════════════════════════════
  //  CERTIFICATE PDF
  // ═════════════════════════════════════════════════════════

  Future<void> shareCertificatePdf(String name, int year, int month, S l) async {
    final doc = await _buildCertificatePdf(name, year, month, l);
    final fmtMonth = DateFormat('MMMM_yyyy', l.localeName);
    final fileName = 'Certificate_${fmtMonth.format(DateTime(year, month, 1))}.pdf';
    await Printing.sharePdf(bytes: await doc.save(), filename: fileName);
  }

  Future<pw.Document> _buildCertificatePdf(String name, int year, int month, S l) async {
    final stats = await ReportService.instance.computeMonthStats(year, month);
    final fmtMonth = DateFormat('MMMM yyyy', l.localeName);
    final monthLabel = fmtMonth.format(DateTime(year, month, 1));
    final pct = stats.totalDays > 0 ? (stats.avgCompletion * 100).round() : 0;

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.loraRegular(),
        bold: await PdfGoogleFonts.loraBold(),
        italic: await PdfGoogleFonts.loraItalic(),
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        build: (ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _gold, width: 4),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _goldDeep, width: 1),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    '\u2720',
                    style: const pw.TextStyle(fontSize: 36, color: _gold),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    l.certificateTitle.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: _gold,
                      letterSpacing: 4,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    width: 200,
                    height: 2,
                    color: _gold,
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    l.pdfCertifiesThat,
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: _sand,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    name.isEmpty ? 'Disciple' : name,
                    style: pw.TextStyle(
                      fontSize: 30,
                      fontWeight: pw.FontWeight.bold,
                      color: _goldDeep,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    l.pdfFaithfulDiscipline,
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: _sand,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    monthLabel,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: _gold,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  // Achievement stats row
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFFAF6EF),
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: _gold, width: 0.5),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                      children: [
                        _statCell('$pct%', l.pdfConsistency),
                        _statCell('${stats.daysLogged}/${stats.totalDays}', l.pdfDaysActive),
                        _statCell('${stats.totalBibleChapters}', l.pdfChaptersRead),
                        _statCell('${stats.totalEvangelismContacts}', l.soulsReached),
                        _statCell('${stats.litItems}', l.booksRead),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        '"Be faithful unto death, and I will give you the crown of life." — Revelation 2:10',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: _sand,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Generated: ${DateFormat('MMMM d, yyyy', l.localeName).format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 8, color: _sand),
                      ),
                      pw.Text(
                        l.pdfCertificateFooter,
                        style: const pw.TextStyle(fontSize: 8, color: _sand),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return doc;
  }

  pw.Widget _detailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _goldDeep,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 9, color: _bg),
            ),
          ),
        ],
      ),
    );
  }
}
