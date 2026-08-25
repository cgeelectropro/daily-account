import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/saved_report.dart';
import '../services/report_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Shows all archived reports with view, resend, and delete actions.
class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  List<SavedReport> _reports = [];
  bool _loading = true;
  String _email = '';
  String _whatsapp = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _reports = await StorageService.instance.getAllReports();
    _email = await StorageService.instance.getSetting('discipleEmail');
    _whatsapp = await StorageService.instance.getSetting('discipleWhatsApp');
    if (mounted) setState(() => _loading = false);
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: AppTheme.serif(14, color: AppTheme.textColor(context))),
        backgroundColor: AppTheme.surfaceColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.accentGold(context)),
        ),
      ));

  Future<void> _viewReport(SavedReport report) async {
    final accent = AppTheme.accentGold(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.faintColor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${report.weekStart} \u2013 ${report.weekEnd}',
                style: AppTheme.display(18, color: accent),
              ),
              if (report.sentVia.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${S.of(context).sentVia(report.sentVia)} \u2022 ${_formatDate(report.sentAt)}',
                  style: AppTheme.serif(12, color: AppTheme.mutedColor(context)),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: Text(
                    report.fullReport,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      height: 1.6,
                      color: AppTheme.mutedColor(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _actionButton('\uD83D\uDCCB Copy', () {
                      Clipboard.setData(ClipboardData(text: report.fullReport));
                      Navigator.pop(ctx);
                      _toast('\uD83D\uDCCB ${S.of(context).reportCopied}');
                    }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionButton('\uD83D\uDCE4 Share', () {
                      Navigator.pop(ctx);
                      ReportService.instance.shareReport(report.fullReport);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_email.isNotEmpty)
                    Expanded(
                      child: _actionButton('\uD83D\uDCE7 Email', () async {
                        Navigator.pop(ctx);
                        final l = S.of(context);
                        final name = await StorageService.instance.getSetting('myName');
                        await ReportService.instance.sendByEmail(_email, name, report.fullReport, l);
                      }),
                    ),
                  if (_email.isNotEmpty && _whatsapp.isNotEmpty)
                    const SizedBox(width: 10),
                  if (_whatsapp.isNotEmpty)
                    Expanded(
                      child: _actionButton('\uD83D\uDCAC WhatsApp', () async {
                        Navigator.pop(ctx);
                        await ReportService.instance.sendByWhatsApp(_whatsapp, report.compactReport);
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String text, VoidCallback onTap) {
    final accent = AppTheme.accentGold(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.center,
        child: Text(text, style: AppTheme.display(14, color: accent)),
      ),
    );
  }

  Future<void> _deleteReport(SavedReport report) async {
    final l = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text(l.deleteReport, style: AppTheme.display(18, color: AppTheme.rust)),
        content: Text(
          '${report.weekStart} \u2013 ${report.weekEnd}',
          style: AppTheme.serif(14, color: AppTheme.textColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel, style: TextStyle(color: AppTheme.mutedColor(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.deleteReport, style: const TextStyle(color: AppTheme.rust)),
          ),
        ],
      ),
    );
    if (confirmed == true && report.id != null) {
      await StorageService.instance.deleteReport(report.id!);
      _toast(l.reportDeleted);
      setState(() => _loading = true);
      _load();
    }
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return isoDate;
    return DateFormat('MMM d, y \u2022 HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final accent = AppTheme.accentGold(context);

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: accent),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(l.reportHistory, style: AppTheme.display(20, color: accent)),
          centerTitle: true,
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: accent))
            : _reports.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        l.reportHistoryEmpty,
                        textAlign: TextAlign.center,
                        style: AppTheme.serif(15, color: AppTheme.mutedColor(context)),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    itemCount: _reports.length,
                    itemBuilder: (_, i) => _buildReportCard(_reports[i], l, accent),
                  ),
      ),
    );
  }

  Widget _buildReportCard(SavedReport report, S l, Color accent) {
    final hasSent = report.sentVia.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                hasSent ? '\u2705' : '\uD83D\uDCC4',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${report.weekStart} \u2013 ${report.weekEnd}',
                      style: AppTheme.display(15, color: accent),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasSent
                          ? '${l.sentVia(report.sentVia)} \u2022 ${_formatDate(report.sentAt)}'
                          : l.notSentYet,
                      style: AppTheme.serif(12,
                          color: hasSent
                              ? AppTheme.green
                              : AppTheme.mutedColor(context)),
                    ),
                  ],
                ),
              ),
              // Delete button
              GestureDetector(
                onTap: () => _deleteReport(report),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.delete_outline, color: AppTheme.rust, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _viewReport(report),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(l.viewReport, style: AppTheme.display(13, color: AppTheme.bg0)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: report.fullReport));
                    _toast('\uD83D\uDCCB ${l.reportCopied}');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: Text(l.copyReport, style: AppTheme.display(13, color: accent)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
