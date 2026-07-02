import 'dart:convert';

import '../data/reading_plans.dart';
import '../models/daily_log.dart';
import '../utils/bible_books.dart';
import 'storage_service.dart';

/// Manages the user's active Bible reading plan — load, activate, pause, reset,
/// progress tracking, and auto-detection of completion from daily log sessions.
class ReadingPlanService {
  static final ReadingPlanService instance = ReadingPlanService._();
  ReadingPlanService._();

  static const _kActivePlanKey = 'activePlan';

  ActivePlan? _activePlan;

  /// The currently active plan, or null if no plan is active.
  ActivePlan? get activePlan => _activePlan;

  // ── Persistence ─────────────────────────────────────────────────────────────

  /// Loads the active plan from SharedPreferences. Call once at app startup.
  Future<void> load() async {
    final raw = await StorageService.instance.getSetting(_kActivePlanKey);
    if (raw.isEmpty) {
      _activePlan = null;
      return;
    }
    try {
      _activePlan = ActivePlan.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      _activePlan = null;
    }
  }

  Future<void> _save() async {
    final value = _activePlan != null ? jsonEncode(_activePlan!.toJson()) : '';
    await StorageService.instance.setSetting(_kActivePlanKey, value);
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  /// Activates the plan identified by [planId], starting from Day 1 today.
  /// Replaces any previously active plan.
  Future<void> activate(String planId) async {
    final plan = ReadingPlans.getById(planId);
    if (plan == null) return;
    _activePlan = ActivePlan(
      planId: planId,
      totalDays: plan.readings.length,
      startedAt: DateTime.now(),
      currentDay: 1,
      completedDays: {},
    );
    await _save();
  }

  /// Pauses (clears) the active plan. The user can re-activate later.
  Future<void> pause() async {
    _activePlan = null;
    await _save();
  }

  /// Resets the current plan back to Day 1, preserving the same planId.
  Future<void> reset() async {
    if (_activePlan == null) return;
    _activePlan = ActivePlan(
      planId: _activePlan!.planId,
      totalDays: _activePlan!.totalDays,
      startedAt: DateTime.now(),
      currentDay: 1,
      completedDays: {},
    );
    await _save();
  }

  // ── Reading Access ───────────────────────────────────────────────────────────

  /// Returns today's scheduled reading (the current day's entry), or null if
  /// no plan is active or the plan is complete.
  PlanReading? todayReading() {
    if (_activePlan == null || _activePlan!.isComplete) return null;
    final plan = ReadingPlans.getById(_activePlan!.planId);
    if (plan == null) return null;
    final day = _activePlan!.currentDay;
    // readings list is 0-indexed; dayNumber is 1-indexed
    final idx = plan.readings.indexWhere((r) => r.dayNumber == day);
    if (idx < 0) return null;
    return plan.readings[idx];
  }

  // ── Progress ─────────────────────────────────────────────────────────────────

  /// Marks [dayNumber] as completed and advances [currentDay] to the next
  /// uncompleted day. Saves immediately.
  Future<void> markComplete(int dayNumber) async {
    if (_activePlan == null) return;

    // Add to completed set
    final updated = Set<int>.from(_activePlan!.completedDays)..add(dayNumber);

    // Advance currentDay past any already-completed days
    int next = _activePlan!.currentDay;
    // Bump at least once if we just completed the current day
    if (next == dayNumber) next++;
    while (updated.contains(next) && next <= _activePlan!.totalDays) {
      next++;
    }
    // Cap at totalDays + 1 to signal completion without going out of bounds
    if (next > _activePlan!.totalDays) next = _activePlan!.totalDays + 1;

    _activePlan = ActivePlan(
      planId: _activePlan!.planId,
      totalDays: _activePlan!.totalDays,
      startedAt: _activePlan!.startedAt,
      currentDay: next,
      completedDays: updated,
    );
    await _save();
  }

  // ── Completion Detection ─────────────────────────────────────────────────────

  /// Returns true when the plan's current reading is already covered by the
  /// user's Bible sessions in [log].
  ///
  /// A session "covers" the plan reading when:
  ///   - The session's book range starts at or before the plan's start book+chapter
  ///   - The session's book range ends at or after the plan's end book+chapter
  ///
  /// This is a fuzzy superset check: a session that spans a larger range than
  /// the day's assignment still counts as done.
  bool isReadingDoneToday(DailyLog log) {
    final reading = todayReading();
    if (reading == null) return false;

    final planStartBook = BibleBooks.findBook(reading.startBook);
    if (planStartBook == null) return false;

    final planEndBookName =
        reading.endBook.isEmpty ? reading.startBook : reading.endBook;
    final planEndBook = BibleBooks.findBook(planEndBookName);
    if (planEndBook == null) return false;

    final planEndChapter =
        reading.endChapter < 1 ? reading.startChapter : reading.endChapter;

    // Encode plan boundaries as comparable integers: (bookOrder * 1500 + chapter)
    final planStartOrd = planStartBook.order * 1500 + reading.startChapter;
    final planEndOrd = planEndBook.order * 1500 + planEndChapter;

    for (final session in log.bibleSessions) {
      if (session.isEmpty) continue;

      final sessStartBook = BibleBooks.findBook(session.startBook);
      if (sessStartBook == null) continue;

      final sessEndBookName =
          session.endBook.isEmpty ? session.startBook : session.endBook;
      final sessEndBook = BibleBooks.findBook(sessEndBookName);
      if (sessEndBook == null) continue;

      final sessEndChapter =
          session.endChapter < 1 ? session.startChapter : session.endChapter;

      final sessStartOrd = sessStartBook.order * 1500 + session.startChapter;
      final sessEndOrd = sessEndBook.order * 1500 + sessEndChapter;

      // Session covers the plan range when it starts <= plan start AND ends >= plan end
      if (sessStartOrd <= planStartOrd && sessEndOrd >= planEndOrd) {
        return true;
      }
    }
    return false;
  }

  /// If today's plan reading is covered by the user's sessions, auto-mark it
  /// complete. No-op if already marked or not covered.
  Future<void> autoDetectCompletion(DailyLog log) async {
    if (_activePlan == null) return;
    final reading = todayReading();
    if (reading == null) return;
    if (_activePlan!.completedDays.contains(reading.dayNumber)) return;
    if (isReadingDoneToday(log)) {
      await markComplete(reading.dayNumber);
    }
  }
}
