import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/services/report_service.dart';

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
}
