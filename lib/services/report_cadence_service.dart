import 'storage_service.dart';

enum ReportCadence { weekly, monthly }

/// Owns the user's reporting cadence preference (weekly on a chosen weekday,
/// or monthly on a chosen day / the last day of the month) and the pure
/// date math needed to answer "is today the report day?".
class ReportCadenceService {
  static final instance = ReportCadenceService._();
  ReportCadenceService._();

  static const _cadenceKey = 'reportCadence';
  static const _weeklyDayKey = 'reportWeeklyDay';
  static const _monthlyDayKey = 'reportMonthlyDay';

  Future<ReportCadence> getCadence() async {
    final raw = await StorageService.instance.getSetting(_cadenceKey, fallback: 'weekly');
    return raw == 'monthly' ? ReportCadence.monthly : ReportCadence.weekly;
  }

  Future<void> setCadence(ReportCadence cadence) => StorageService.instance
      .setSetting(_cadenceKey, cadence == ReportCadence.monthly ? 'monthly' : 'weekly');

  /// 1-7, DateTime.weekday convention (1=Monday...7=Sunday). Default: 7 (Sunday).
  Future<int> getWeeklyDay() async {
    final raw = await StorageService.instance.getSetting(_weeklyDayKey, fallback: '7');
    final parsed = int.tryParse(raw) ?? 7;
    return (parsed >= 1 && parsed <= 7) ? parsed : 7;
  }

  Future<void> setWeeklyDay(int weekday) =>
      StorageService.instance.setSetting(_weeklyDayKey, '$weekday');

  /// "1".."31" or "last". Default: "last".
  Future<String> getMonthlyDay() =>
      StorageService.instance.getSetting(_monthlyDayKey, fallback: 'last');

  Future<void> setMonthlyDay(String day) =>
      StorageService.instance.setSetting(_monthlyDayKey, day);

  /// Resolves "last" or a numeric day string against [year]/[month],
  /// clamping to that month's actual last day if the configured day
  /// doesn't exist in it (e.g. "31" in February).
  int resolveMonthlyDay(int year, int month, String configuredDay) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    if (configuredDay == 'last') return lastDayOfMonth;
    final parsed = int.tryParse(configuredDay) ?? lastDayOfMonth;
    return parsed.clamp(1, lastDayOfMonth);
  }

  /// The dedup key identifying the current report period (used to detect
  /// "already auto-sent this period"). Weekly: the Monday-of-week date key
  /// (yyyy-MM-dd, unchanged format for backward compatibility). Monthly:
  /// a yyyy-MM key.
  Future<String> currentPeriodKey([DateTime? date]) async {
    final d = date ?? DateTime.now();
    final cadence = await getCadence();
    if (cadence == ReportCadence.monthly) {
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    }
    final monday = d.subtract(Duration(days: (d.weekday - 1) % 7));
    return '${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  /// True if [date] (default: today) is the configured report/send day.
  Future<bool> isReportDay([DateTime? date]) async {
    final d = date ?? DateTime.now();
    final cadence = await getCadence();
    if (cadence == ReportCadence.weekly) {
      final weeklyDay = await getWeeklyDay();
      return d.weekday == weeklyDay;
    }
    final monthlyDay = await getMonthlyDay();
    return d.day == resolveMonthlyDay(d.year, d.month, monthlyDay);
  }
}
