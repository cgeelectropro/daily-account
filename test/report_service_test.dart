import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_account/l10n/generated/app_localizations_en.dart';
import 'package:daily_account/models/daily_log.dart';
import 'package:daily_account/services/report_service.dart';
import 'package:daily_account/services/storage_service.dart';

void main() {
  // Convenience accessor — avoids repeating ReportService.instance throughout.
  final svc = ReportService.instance;

  // ═══════════════════════════════════════════════════════════
  //  weekDates
  // ═══════════════════════════════════════════════════════════

  group('weekDates', () {
    test('always returns exactly 7 elements', () {
      // Arbitrary mid-week date.
      final result = svc.weekDates(DateTime(2025, 6, 18)); // Wednesday
      expect(result.length, 7);
    });

    test('first element is always a Monday (weekday == 1)', () {
      // Test a spread of different starting weekdays.
      final dates = [
        DateTime(2025, 6, 16), // Monday
        DateTime(2025, 6, 18), // Wednesday
        DateTime(2025, 6, 20), // Friday
        DateTime(2025, 6, 22), // Sunday
      ];
      for (final d in dates) {
        final result = svc.weekDates(d);
        expect(result.first.weekday, 1,
            reason: 'First element for $d should be Monday');
      }
    });

    test('last element is always a Sunday (weekday == 7)', () {
      final dates = [
        DateTime(2025, 6, 16), // Monday
        DateTime(2025, 6, 18), // Wednesday
        DateTime(2025, 6, 22), // Sunday
      ];
      for (final d in dates) {
        final result = svc.weekDates(d);
        expect(result.last.weekday, 7,
            reason: 'Last element for $d should be Sunday');
      }
    });

    test('a Monday returns itself as the first element', () {
      final monday = DateTime(2025, 6, 16); // known Monday
      final result = svc.weekDates(monday);
      expect(result.first.year, 2025);
      expect(result.first.month, 6);
      expect(result.first.day, 16);
    });

    test('a Monday returns the following Sunday as the last element', () {
      final monday = DateTime(2025, 6, 16);
      final result = svc.weekDates(monday);
      expect(result.last.year, 2025);
      expect(result.last.month, 6);
      expect(result.last.day, 22);
    });

    test('a Wednesday returns the correct Monday', () {
      final wednesday = DateTime(2025, 6, 18);
      final result = svc.weekDates(wednesday);
      // The Monday of that week is June 16.
      expect(result.first.day, 16);
      expect(result.first.month, 6);
    });

    test('a Sunday returns the Monday of the same week, not the next', () {
      // June 22 2025 is a Sunday — its week started on Monday June 16.
      final sunday = DateTime(2025, 6, 22);
      final result = svc.weekDates(sunday);
      expect(result.first.day, 16);
      expect(result.first.month, 6);
      expect(result.last.day, 22);
    });

    test('days are consecutive with no gaps', () {
      final result = svc.weekDates(DateTime(2025, 6, 18));
      for (int i = 1; i < result.length; i++) {
        final diff = result[i].difference(result[i - 1]).inDays;
        expect(diff, 1,
            reason: 'Element $i should be exactly 1 day after element ${i - 1}');
      }
    });

    test('crossing a month boundary — ref = March 2 2025 (Sunday)', () {
      // March 2 2025 is a Sunday. Week starts Mon Feb 24.
      final march2 = DateTime(2025, 3, 2);
      final result = svc.weekDates(march2);
      expect(result.first.month, 2);
      expect(result.first.day, 24);
      expect(result.last.month, 3);
      expect(result.last.day, 2);
    });

    test('crossing a month boundary — ref = March 5 2025 (Wednesday)', () {
      // Week of March 5 2025 (Wed): Mon Mar 3 – Sun Mar 9.
      final result = svc.weekDates(DateTime(2025, 3, 5));
      expect(result.first.month, 3);
      expect(result.first.day, 3);
      expect(result.last.month, 3);
      expect(result.last.day, 9);
    });

    test('crossing a year boundary — ref = January 2 2025 (Thursday)', () {
      // Jan 2 2025 is a Thursday. Week starts Mon Dec 30 2024.
      final jan2 = DateTime(2025, 1, 2);
      final result = svc.weekDates(jan2);
      expect(result.first.year, 2024);
      expect(result.first.month, 12);
      expect(result.first.day, 30);
      expect(result.last.year, 2025);
      expect(result.last.month, 1);
      expect(result.last.day, 5);
    });

    test('crossing a year boundary — ref = January 1 2025 (Wednesday)', () {
      // Jan 1 2025 is a Wednesday. Week starts Mon Dec 30 2024.
      final jan1 = DateTime(2025, 1, 1);
      final result = svc.weekDates(jan1);
      expect(result.first.year, 2024);
      expect(result.first.month, 12);
      expect(result.first.day, 30);
    });

    test('defaults to the current week when no argument given', () {
      // The result must still be 7 consecutive days starting on a Monday.
      final result = svc.weekDates();
      expect(result.length, 7);
      expect(result.first.weekday, 1);
      expect(result.last.weekday, 7);
    });
  });

  group('weekDates with endWeekday', () {
    final rs = ReportService.instance;

    test('defaults to Sunday-ending (Monday->Sunday) when endWeekday omitted', () {
      final ref = DateTime(2026, 8, 12); // a Wednesday
      final dates = rs.weekDates(ref);
      expect(dates.first.weekday, DateTime.monday);
      expect(dates.last.weekday, DateTime.sunday);
      expect(dates.length, 7);
    });

    test('Sunday-ending explicit matches default (regression guard)', () {
      final ref = DateTime(2026, 8, 12);
      final withDefault = rs.weekDates(ref);
      final withExplicit = rs.weekDates(ref, DateTime.sunday);
      expect(withExplicit, withDefault);
    });

    test('Friday-ending produces a Saturday->Friday window', () {
      final ref = DateTime(2026, 8, 12); // a Wednesday
      final dates = rs.weekDates(ref, DateTime.friday);
      expect(dates.first.weekday, DateTime.saturday);
      expect(dates.last.weekday, DateTime.friday);
      expect(dates.length, 7);
    });

    test('window always contains the reference date', () {
      final ref = DateTime(2026, 8, 12);
      for (int endDay = 1; endDay <= 7; endDay++) {
        final dates = rs.weekDates(ref, endDay);
        final containsRef = dates.any((d) =>
            d.year == ref.year && d.month == ref.month && d.day == ref.day);
        expect(containsRef, true, reason: 'endWeekday=$endDay should contain $ref');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  keyFor
  // ═══════════════════════════════════════════════════════════

  group('keyFor', () {
    test('formats a standard date as yyyy-MM-dd', () {
      expect(svc.keyFor(DateTime(2025, 6, 18)), '2025-06-18');
    });

    test('zero-pads single-digit month', () {
      expect(svc.keyFor(DateTime(2025, 3, 15)), '2025-03-15');
    });

    test('zero-pads single-digit day', () {
      expect(svc.keyFor(DateTime(2025, 11, 5)), '2025-11-05');
    });

    test('zero-pads both single-digit month and day', () {
      expect(svc.keyFor(DateTime(2025, 1, 1)), '2025-01-01');
    });

    test('handles December 31', () {
      expect(svc.keyFor(DateTime(2024, 12, 31)), '2024-12-31');
    });

    test('handles year 2000', () {
      expect(svc.keyFor(DateTime(2000, 6, 1)), '2000-06-01');
    });

    test('result for weekDates first/last matches expected keys', () {
      // Monday and Sunday of the week containing June 18 2025.
      final dates = svc.weekDates(DateTime(2025, 6, 18));
      expect(svc.keyFor(dates.first), '2025-06-16');
      expect(svc.keyFor(dates.last), '2025-06-22');
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  WeekStats
  // ═══════════════════════════════════════════════════════════

  group('WeekStats', () {
    test('constructor assigns all five positional fields', () {
      final stats = WeekStats(5, 12, 3, 7, 90);
      expect(stats.daysLogged, 5);
      expect(stats.totalBibleChapters, 12);
      expect(stats.totalEvangelismContacts, 3);
      expect(stats.litItems, 7);
      expect(stats.totalPrayerMinutes, 90);
    });

    test('zero values are preserved', () {
      final stats = WeekStats(0, 0, 0, 0, 0);
      expect(stats.daysLogged, 0);
      expect(stats.totalBibleChapters, 0);
      expect(stats.totalEvangelismContacts, 0);
      expect(stats.litItems, 0);
      expect(stats.totalPrayerMinutes, 0);
    });

    test('large values are preserved', () {
      final stats = WeekStats(7, 150, 50, 20, 600);
      expect(stats.daysLogged, 7);
      expect(stats.totalBibleChapters, 150);
      expect(stats.totalEvangelismContacts, 50);
      expect(stats.litItems, 20);
      expect(stats.totalPrayerMinutes, 600);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  MonthStats
  // ═══════════════════════════════════════════════════════════

  group('MonthStats', () {
    test('named constructor assigns all fields', () {
      final stats = MonthStats(
        daysLogged: 20,
        totalDays: 31,
        totalBibleChapters: 45,
        totalEvangelismContacts: 8,
        litItems: 12,
        weeksReported: 4,
        avgCompletion: 0.75,
      );
      expect(stats.daysLogged, 20);
      expect(stats.totalDays, 31);
      expect(stats.totalBibleChapters, 45);
      expect(stats.totalEvangelismContacts, 8);
      expect(stats.litItems, 12);
      expect(stats.weeksReported, 4);
      expect(stats.avgCompletion, 0.75);
    });

    test('zero/empty values are preserved', () {
      final stats = MonthStats(
        daysLogged: 0,
        totalDays: 28,
        totalBibleChapters: 0,
        totalEvangelismContacts: 0,
        litItems: 0,
        weeksReported: 0,
        avgCompletion: 0.0,
      );
      expect(stats.daysLogged, 0);
      expect(stats.avgCompletion, 0.0);
    });

    test('avgCompletion accepts 1.0 (full completion)', () {
      final stats = MonthStats(
        daysLogged: 30,
        totalDays: 30,
        totalBibleChapters: 60,
        totalEvangelismContacts: 15,
        litItems: 30,
        weeksReported: 5,
        avgCompletion: 1.0,
      );
      expect(stats.avgCompletion, 1.0);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  TrendData
  // ═══════════════════════════════════════════════════════════

  group('TrendData', () {
    test('constructor assigns required fields', () {
      final trend = TrendData(
        currentConsistency: 0.8,
        lastMonthConsistency: 0.6,
        disciplineRates: {'Bible': 1.0, 'Prayer (alone)': 0.7},
        hasData: true,
      );
      expect(trend.currentConsistency, 0.8);
      expect(trend.lastMonthConsistency, 0.6);
      expect(trend.disciplineRates['Bible'], 1.0);
      expect(trend.disciplineRates['Prayer (alone)'], 0.7);
      expect(trend.hasData, true);
    });

    test('optional fields default to null when omitted', () {
      final trend = TrendData(
        currentConsistency: 0.5,
        lastMonthConsistency: 0.5,
        disciplineRates: {},
        hasData: false,
      );
      expect(trend.bestDiscipline, isNull);
      expect(trend.weakDiscipline, isNull);
    });

    test('optional fields are stored when provided', () {
      final trend = TrendData(
        currentConsistency: 0.9,
        lastMonthConsistency: 0.7,
        disciplineRates: {},
        bestDiscipline: 'Bible',
        weakDiscipline: 'Fasting',
        hasData: true,
      );
      expect(trend.bestDiscipline, 'Bible');
      expect(trend.weakDiscipline, 'Fasting');
    });

    test('change getter returns positive value when current > last (improvement)', () {
      final trend = TrendData(
        currentConsistency: 0.8,
        lastMonthConsistency: 0.5,
        disciplineRates: {},
        hasData: true,
      );
      expect(trend.change, closeTo(0.3, 1e-9));
    });

    test('change getter returns negative value when current < last (decline)', () {
      final trend = TrendData(
        currentConsistency: 0.4,
        lastMonthConsistency: 0.7,
        disciplineRates: {},
        hasData: true,
      );
      expect(trend.change, closeTo(-0.3, 1e-9));
    });

    test('change getter returns zero when current == last', () {
      final trend = TrendData(
        currentConsistency: 0.65,
        lastMonthConsistency: 0.65,
        disciplineRates: {},
        hasData: true,
      );
      expect(trend.change, closeTo(0.0, 1e-9));
    });

    test('change getter is exactly currentConsistency - lastMonthConsistency', () {
      const current = 0.333;
      const last = 0.111;
      final trend = TrendData(
        currentConsistency: current,
        lastMonthConsistency: last,
        disciplineRates: {},
        hasData: true,
      );
      expect(trend.change, closeTo(current - last, 1e-9));
    });

    test('change is 1.0 when going from 0 to perfect consistency', () {
      final trend = TrendData(
        currentConsistency: 1.0,
        lastMonthConsistency: 0.0,
        disciplineRates: {},
        hasData: true,
      );
      expect(trend.change, closeTo(1.0, 1e-9));
    });

    test('change is -1.0 when dropping from perfect to zero consistency', () {
      final trend = TrendData(
        currentConsistency: 0.0,
        lastMonthConsistency: 1.0,
        disciplineRates: {},
        hasData: true,
      );
      expect(trend.change, closeTo(-1.0, 1e-9));
    });

    test('hasData false preserved', () {
      final trend = TrendData(
        currentConsistency: 0,
        lastMonthConsistency: 0,
        disciplineRates: {},
        hasData: false,
      );
      expect(trend.hasData, false);
    });

    test('disciplineRates map is stored by reference', () {
      final rates = <String, double>{'Evangelism': 0.5};
      final trend = TrendData(
        currentConsistency: 0.5,
        lastMonthConsistency: 0.5,
        disciplineRates: rates,
        hasData: true,
      );
      expect(trend.disciplineRates, same(rates));
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  computeTrend / _disciplineChecks — session-awareness (Task 7.5)
  // ═══════════════════════════════════════════════════════════

  group('computeTrend — _disciplineChecks session-awareness', () {
    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() async {
      final db = await StorageService.instance.database;
      await db.delete('logs');
    });

    // Fixed Wednesday so weekDates() resolves to a known Monday->Sunday window
    // (default weekly cadence day is Sunday).
    final ref = DateTime(2026, 8, 12);
    final monday = svc.weekDates(ref).first; // 2026-08-10

    test('registers Evangelism as done for a session-only day (no legacy scalar)', () async {
      final start = DateTime(2026, 8, 10, 9, 0);
      final log = DailyLog(
        dateKey: svc.keyFor(monday),
        evangelismSessions: [
          TimedSession(start: start, end: start.add(const Duration(minutes: 20)), durationSeconds: 20 * 60),
        ],
      );
      expect(log.evangelismContacts, isEmpty);
      await StorageService.instance.saveLog(log);

      final trend = await svc.computeTrend(ref);

      expect(trend.disciplineRates['Evangelism'], 1.0);
    });

    test('registers Church as done for a session-only day (no legacy scalar)', () async {
      final start = DateTime(2026, 8, 10, 10, 0);
      final log = DailyLog(
        dateKey: svc.keyFor(monday),
        churchSessions: [
          TimedSession(start: start, end: start.add(const Duration(minutes: 90)), durationSeconds: 90 * 60),
        ],
      );
      expect(log.churchType, isEmpty);
      await StorageService.instance.saveLog(log);

      final trend = await svc.computeTrend(ref);

      expect(trend.disciplineRates['Church'], 1.0);
    });

    test('registers Proclamation as done for a session-only day (no legacy scalar)', () async {
      final log = DailyLog(
        dateKey: svc.keyFor(monday),
        proclamationSessions: [
          ProclamationSession(topic: 'Salvation', count: 3, duration: '15min'),
        ],
      );
      expect(log.proclamationCount, isEmpty);
      await StorageService.instance.saveLog(log);

      final trend = await svc.computeTrend(ref);

      expect(trend.disciplineRates['Proclamation'], 1.0);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  buildFullReport — per-day report text (Task 7)
  // ═══════════════════════════════════════════════════════════

  group('buildFullReport — per-day report text', () {
    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await initializeDateFormatting();
    });
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // Tests share one in-memory database via the StorageService singleton.
    // Clear the logs table between tests so each test's weekly window only
    // ever contains what it seeded itself.
    tearDown(() async {
      final db = await StorageService.instance.database;
      await db.delete('logs');
    });

    final l = SEn();
    // A fixed Wednesday so weekDates() resolves to a known Monday->Sunday window.
    final ref = DateTime(2026, 8, 12);
    final monday = svc.weekDates(ref).first; // 2026-08-10

    test('shows Bible duration per-day when bibleDuration is present', () async {
      final log = DailyLog(
        dateKey: svc.keyFor(monday),
        bibleReference: 'John 3',
        bibleChapters: '1',
        bibleDuration: '25min',
      );
      await StorageService.instance.saveLog(log);

      final report = await svc.buildFullReport('Disciple', l, ref);

      expect(report, contains('25min'));
      expect(report, contains('John 3'));
    });

    test('falls back to plain Bible line (no duration) when bibleDuration is empty', () async {
      final log = DailyLog(
        dateKey: svc.keyFor(monday),
        bibleReference: 'John 3',
        bibleChapters: '1',
      );
      await StorageService.instance.saveLog(log);

      final report = await svc.buildFullReport('Disciple', l, ref);

      expect(report, contains(l.reportBible('John 3', '1')));
    });

    test('shows session-aware evangelism line when evangelismSessions exist', () async {
      final start = DateTime(2026, 8, 10, 9, 0);
      final log = DailyLog(
        dateKey: svc.keyFor(monday),
        // completeness (and thus hasContent in the report) doesn't currently
        // account for evangelismSessions on its own, so seed a minor legacy
        // field to make this day register as having content.
        discipleshipWho: 'Test Person',
        evangelismSessions: [
          TimedSession(start: start, end: start.add(const Duration(minutes: 20)), durationSeconds: 20 * 60),
          TimedSession(start: start, end: start.add(const Duration(minutes: 10)), durationSeconds: 10 * 60),
        ],
      );
      await StorageService.instance.saveLog(log);

      final report = await svc.buildFullReport('Disciple', l, ref);

      // 2 sessions, 30 minutes total — the session-aware line, not the
      // legacy contacts-based line (which requires evangelismContacts).
      expect(report, contains(l.reportEvangelismSessions('2', '30min')));
      expect(report, isNot(contains('contact(s)')));
    });

    test('falls back to legacy contacts-based evangelism line when no sessions exist', () async {
      final log = DailyLog(
        dateKey: svc.keyFor(monday),
        evangelismContacts: '3',
        evangelismOutcome: 'Good talk',
        evangelismNotes: 'Follow up next week',
      );
      await StorageService.instance.saveLog(log);

      final report = await svc.buildFullReport('Disciple', l, ref);

      expect(report, contains(l.reportEvangelism('3', 'Good talk', 'Follow up next week')));
    });

    test('shows session-aware church line when churchSessions exist', () async {
      final start = DateTime(2026, 8, 10, 10, 0);
      final log = DailyLog(
        dateKey: svc.keyFor(monday),
        // completeness doesn't account for churchSessions on its own, so
        // seed a minor legacy field to make this day register as having content.
        discipleshipWho: 'Test Person',
        churchSessions: [
          TimedSession(start: start, end: start.add(const Duration(minutes: 90)), durationSeconds: 90 * 60),
        ],
      );
      await StorageService.instance.saveLog(log);

      final report = await svc.buildFullReport('Disciple', l, ref);

      expect(report, contains(l.reportChurchSessions('1', '1h 30min')));
    });

    test('falls back to legacy type/notes-based church line when no sessions exist', () async {
      final log = DailyLog(
        dateKey: svc.keyFor(monday),
        churchType: 'Sunday service',
        churchNotes: 'Great sermon',
      );
      await StorageService.instance.saveLog(log);

      final report = await svc.buildFullReport('Disciple', l, ref);

      expect(report, contains(l.reportChurch('Sunday service', 'Great sermon')));
    });

    test('lists each proclamation topic separately with count and duration', () async {
      final log = DailyLog(
        dateKey: svc.keyFor(monday),
        // completeness doesn't account for proclamationSessions on its own, so
        // seed a minor legacy field to make this day register as having content.
        discipleshipWho: 'Test Person',
        proclamationSessions: [
          ProclamationSession(topic: 'Salvation', count: 3, duration: '15min'),
          ProclamationSession(topic: 'Grace', count: 2, duration: '10min'),
        ],
      );
      await StorageService.instance.saveLog(log);

      final report = await svc.buildFullReport('Disciple', l, ref);

      expect(report, contains('Salvation (3x, 15min)'));
      expect(report, contains('Grace (2x, 10min)'));
    });

    test('renders legacy proclamationCount/Duration via the auto-migrated session on read', () async {
      // DailyLog.fromMap migrates legacy proclamationCount/proclamationDuration
      // into a single synthetic ProclamationSession (empty topic) whenever no
      // proclamationSessions were persisted — so after a save/load round-trip
      // through StorageService, the session-aware line renders using the
      // sectionProclamation label as the topic fallback.
      final log = DailyLog(
        dateKey: svc.keyFor(monday),
        proclamationCount: '5',
        proclamationDuration: '20min',
      );
      await StorageService.instance.saveLog(log);

      final report = await svc.buildFullReport('Disciple', l, ref);

      expect(report, contains('${l.sectionProclamation} (5x, 20min)'));
    });

    test('buildCompactReport — session-only day (no legacy scalars) registers as having content', () async {
      // A day logged purely through the Stopwatch/timer flow: evangelismSessions,
      // churchSessions, and proclamationSessions are populated but the legacy
      // scalar fields (evangelismContacts, churchType, proclamationCount) are
      // untouched. Before the completeness/discipline-check fix, this day would
      // have completeness == 0 and be skipped from the compact report entirely
      // as "No entry recorded" (❌).
      final start = DateTime(2026, 8, 10, 9, 0);
      final log = DailyLog(
        dateKey: svc.keyFor(monday),
        evangelismSessions: [
          TimedSession(start: start, end: start.add(const Duration(minutes: 20)), durationSeconds: 20 * 60),
        ],
        churchSessions: [
          TimedSession(start: start, end: start.add(const Duration(minutes: 90)), durationSeconds: 90 * 60),
        ],
        proclamationSessions: [
          ProclamationSession(topic: 'Salvation', count: 3, duration: '15min'),
        ],
      );
      expect(log.evangelismContacts, isEmpty);
      expect(log.churchType, isEmpty);
      expect(log.proclamationCount, isEmpty);
      expect(log.completeness, greaterThan(0.0));

      await StorageService.instance.saveLog(log);

      final report = await svc.buildCompactReport('Disciple', l, ref);

      // Compact per-day summary emoji tags should reflect the session data —
      // these only ever get added inside the "day has content" branch, so
      // their presence proves the day was NOT skipped as "No entry recorded".
      // Evangelism count falls back to session count (1); proclamation falls
      // back to totalProclamationCount (3).
      expect(report, contains('📢1'));
      expect(report, contains('⛪'));
      expect(report, contains('📣3'));
    });
  });
}
