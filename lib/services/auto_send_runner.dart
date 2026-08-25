import 'dart:developer' as dev;
import 'dart:io';

import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/generated/app_localizations_en.dart';
import '../l10n/generated/app_localizations_fr.dart';
import 'cloud_sync_service.dart';
import 'report_cadence_service.dart';
import 'report_service.dart';
import 'storage_service.dart';

/// Runs the auto-send check and the pending-report retry — extracted from
/// `HomeShell` so the exact same logic (and the same queue/retry contract)
/// can run from the background service isolate, not just while the app is
/// open in the foreground. Free of `BuildContext` so it works in both.
///
/// Failures always fall back to `StorageService.queuePendingReport` /
/// `markPendingChannelSent`, so a run that hits no connectivity or a
/// Gmail API error never drops the report — it waits for the next call
/// (background tick or app foreground) to retry.
class AutoSendRunner {
  AutoSendRunner._();

  static Future<S> _localizations() async {
    final lang = await StorageService.instance.getSetting('reportLanguage', fallback: '');
    if (lang == 'fr') return SFr();
    return SEn();
  }

  static Future<bool> _hasConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String _subject(S l, String name) => '📖 ${l.reportEmailSubject(
        name.isEmpty ? "Disciple" : name,
        DateFormat('MMM d, y', l.localeName).format(DateTime.now()),
      )}';

  /// Retry whichever channels of a previously-queued report haven't
  /// succeeded yet. Safe to call even when there's nothing queued.
  static Future<void> trySendPending() async {
    final s = StorageService.instance;
    final pending = await s.getPendingReport();
    if (pending == null) return;
    if (!await _hasConnectivity()) return; // still offline, try next time

    final channels = List<String>.from(pending['channels'] as List? ?? []);
    final sentChannels = List<String>.from(pending['sentChannels'] as List? ?? []);
    final compactReport = pending['compactReport'] as String;
    final fullReport = pending['fullReport'] as String;
    final name = await s.getSetting('myName');
    final l = await _localizations();
    final subject = _subject(l, name);

    for (final channel in channels) {
      if (sentChannels.contains(channel)) continue;
      bool ok = false;
      if (channel == 'whatsapp') {
        final whatsapp = pending['whatsapp'] as String? ?? '';
        if (whatsapp.isNotEmpty) {
          ok = await ReportService.instance.sendByWhatsApp(whatsapp, compactReport);
        }
      } else if (channel == 'email') {
        final email = pending['email'] as String? ?? '';
        if (email.isNotEmpty) {
          ok = await CloudSyncService.instance.sendEmailSilently(
            toEmail: email,
            subject: subject,
            body: fullReport,
          );
        }
      }
      if (ok) {
        await s.markPendingChannelSent(channel);
        final periodKey = await ReportCadenceService.instance.currentPeriodKey();
        await s.setSetting('lastAutoSend', periodKey);
      }
    }
  }

  /// On the configured report day, past the scheduled time, if auto-send is
  /// enabled and hasn't already run this period: build the report and send
  /// it via the configured channel(s). Anything that fails (offline, Gmail
  /// API error, missing token) is queued via `queuePendingReport` for the
  /// next `trySendPending()` call rather than silently dropped.
  static Future<void> checkAutoSend([DateTime? now_]) async {
    final now = now_ ?? DateTime.now();
    try {
      if (!await ReportCadenceService.instance.isReportDay(now)) return;

      final s = StorageService.instance;
      final autoEnabled = (await s.getSetting('autoSendEnabled', fallback: 'false')) == 'true';
      if (!autoEnabled) return;

      final channelSetting = await s.getSetting('autoSendChannel', fallback: 'whatsapp');
      final channels = channelSetting == 'both' ? ['whatsapp', 'email'] : [channelSetting];

      final whatsapp = await s.getSetting('discipleWhatsApp');
      if (channels.contains('whatsapp') && whatsapp.isEmpty) return;

      final cadence = await ReportCadenceService.instance.getCadence();
      final periodKey = await ReportCadenceService.instance.currentPeriodKey(now);
      final alreadySent = await s.getSetting('lastAutoSend', fallback: '');
      if (alreadySent == periodKey) return;

      final pending = await s.getPendingReport();
      if (pending != null) {
        final pendingChannels = List<String>.from(pending['channels'] as List? ?? []);
        if (pendingChannels.isEmpty) {
          await s.clearPendingReport();
        } else {
          return;
        }
      }

      final ash = int.tryParse(await s.getSetting('autoSendHour', fallback: '19')) ?? 19;
      final asm = int.tryParse(await s.getSetting('autoSendMin', fallback: '0')) ?? 0;
      if (now.hour < ash || (now.hour == ash && now.minute < asm)) return;

      final name = await s.getSetting('myName');
      final l = await _localizations();
      final String fullReport;
      final String compactReport;
      if (cadence == ReportCadence.monthly) {
        final monthly = await ReportService.instance.buildMonthlyReport(name, l, now.year, now.month);
        fullReport = monthly;
        compactReport = monthly;
      } else {
        fullReport = await ReportService.instance.buildFullReport(name, l);
        compactReport = await ReportService.instance.buildCompactReport(name, l);
      }

      final subject = _subject(l, name);
      final email = await s.getSetting('discipleEmail');

      if (!await _hasConnectivity()) {
        await s.queuePendingReport(
          fullReport: fullReport,
          compactReport: compactReport,
          channels: channels,
          whatsapp: whatsapp,
          email: email,
        );
        return;
      }

      final sentChannels = <String>[];
      for (final channel in channels) {
        bool ok = false;
        if (channel == 'whatsapp') {
          ok = await ReportService.instance.sendByWhatsApp(whatsapp, fullReport);
        } else if (channel == 'email' && email.isNotEmpty) {
          ok = await CloudSyncService.instance.sendEmailSilently(
            toEmail: email,
            subject: subject,
            body: fullReport,
          );
        }
        if (ok) sentChannels.add(channel);
      }

      if (sentChannels.isNotEmpty) {
        await s.setSetting('lastAutoSend', periodKey);
        final String archiveStart;
        final String archiveEnd;
        if (cadence == ReportCadence.monthly) {
          final firstOfMonth = DateTime(now.year, now.month, 1);
          final lastOfMonth = DateTime(now.year, now.month + 1, 0);
          archiveStart = ReportService.instance.keyFor(firstOfMonth);
          archiveEnd = ReportService.instance.keyFor(lastOfMonth);
        } else {
          final endWeekday = await ReportCadenceService.instance.getWeeklyDay();
          final dates = ReportService.instance.weekDates(now, endWeekday);
          archiveStart = ReportService.instance.keyFor(dates.first);
          archiveEnd = ReportService.instance.keyFor(dates.last);
        }
        await s.saveReport(
          weekStart: archiveStart,
          weekEnd: archiveEnd,
          fullReport: fullReport,
          compactReport: compactReport,
          sentVia: sentChannels.join(' + '),
        );
      }

      final failedChannels = channels.where((c) => !sentChannels.contains(c)).toList();
      if (failedChannels.isNotEmpty) {
        await s.queuePendingReport(
          fullReport: fullReport,
          compactReport: compactReport,
          channels: failedChannels,
          whatsapp: whatsapp,
          email: email,
        );
      }
    } catch (e, st) {
      // Never let a background tick crash the service — whatever wasn't
      // sent stays queued (or simply gets retried next tick) rather than
      // taking down the guardian isolate.
      dev.log('AutoSendRunner.checkAutoSend failed: $e', name: 'AutoSendRunner');
      dev.log('$st', name: 'AutoSendRunner');
    }
  }
}
