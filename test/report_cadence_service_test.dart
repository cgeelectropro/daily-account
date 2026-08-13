import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/services/report_cadence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final svc = ReportCadenceService.instance;

  group('resolveMonthlyDay', () {
    test('exact day within range returns that day', () {
      expect(svc.resolveMonthlyDay(2026, 3, '15'), 15);
    });

    test('day beyond month length clamps to last day (31 in Feb)', () {
      expect(svc.resolveMonthlyDay(2026, 2, '31'), 28); // 2026 is not a leap year
    });

    test('day beyond month length clamps to last day (31 in April, 30 days)', () {
      expect(svc.resolveMonthlyDay(2026, 4, '31'), 30);
    });

    test('"last" resolves to last day of a 31-day month', () {
      expect(svc.resolveMonthlyDay(2026, 1, 'last'), 31);
    });

    test('"last" resolves to last day of February in a non-leap year', () {
      expect(svc.resolveMonthlyDay(2026, 2, 'last'), 28);
    });

    test('"last" resolves to last day of February in a leap year', () {
      expect(svc.resolveMonthlyDay(2028, 2, 'last'), 29);
    });

    test('day 1 returns 1 in every month', () {
      expect(svc.resolveMonthlyDay(2026, 2, '1'), 1);
    });
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('cadence get/set', () {
    test('defaults to weekly', () async {
      expect(await svc.getCadence(), ReportCadence.weekly);
    });

    test('set then get round-trips monthly', () async {
      await svc.setCadence(ReportCadence.monthly);
      expect(await svc.getCadence(), ReportCadence.monthly);
    });

    test('set then get round-trips weekly', () async {
      await svc.setCadence(ReportCadence.monthly);
      await svc.setCadence(ReportCadence.weekly);
      expect(await svc.getCadence(), ReportCadence.weekly);
    });
  });

  group('weekly day get/set', () {
    test('defaults to 7 (Sunday)', () async {
      expect(await svc.getWeeklyDay(), 7);
    });

    test('set then get round-trips', () async {
      await svc.setWeeklyDay(5); // Friday
      expect(await svc.getWeeklyDay(), 5);
    });
  });

  group('monthly day get/set', () {
    test('defaults to "last"', () async {
      expect(await svc.getMonthlyDay(), 'last');
    });

    test('set then get round-trips a specific day', () async {
      await svc.setMonthlyDay('25');
      expect(await svc.getMonthlyDay(), '25');
    });
  });

  group('isReportDay', () {
    test('weekly mode: true only on the configured weekday', () async {
      await svc.setCadence(ReportCadence.weekly);
      await svc.setWeeklyDay(DateTime.friday);
      final friday = DateTime(2026, 8, 14); // a Friday
      final saturday = DateTime(2026, 8, 15);
      expect(await svc.isReportDay(friday), true);
      expect(await svc.isReportDay(saturday), false);
    });

    test('monthly mode with specific day: true only on that day', () async {
      await svc.setCadence(ReportCadence.monthly);
      await svc.setMonthlyDay('25');
      expect(await svc.isReportDay(DateTime(2026, 8, 25)), true);
      expect(await svc.isReportDay(DateTime(2026, 8, 24)), false);
    });

    test('monthly mode with "last": true only on the month\'s last day', () async {
      await svc.setCadence(ReportCadence.monthly);
      await svc.setMonthlyDay('last');
      expect(await svc.isReportDay(DateTime(2026, 2, 28)), true); // Feb 2026, 28 days
      expect(await svc.isReportDay(DateTime(2026, 2, 27)), false);
    });
  });
}
