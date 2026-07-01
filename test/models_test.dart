import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/models/saved_report.dart';
import 'package:daily_account/models/prayer_request.dart';
import 'package:daily_account/models/fasting_period.dart';
import 'package:daily_account/models/custom_activity.dart';

void main() {
  group('SavedReport', () {
    test('toMap / fromMap round-trip', () {
      final report = SavedReport(
        id: 1,
        weekStart: '2025-01-06',
        weekEnd: '2025-01-12',
        fullReport: 'Full report text',
        compactReport: 'Compact report text',
        generatedAt: '2025-01-12T18:00:00',
        sentVia: 'whatsapp',
        sentAt: '2025-01-12T19:00:00',
      );
      final map = report.toMap();
      final restored = SavedReport.fromMap(map);
      expect(restored.id, 1);
      expect(restored.weekStart, '2025-01-06');
      expect(restored.weekEnd, '2025-01-12');
      expect(restored.fullReport, 'Full report text');
      expect(restored.compactReport, 'Compact report text');
      expect(restored.generatedAt, '2025-01-12T18:00:00');
      expect(restored.sentVia, 'whatsapp');
      expect(restored.sentAt, '2025-01-12T19:00:00');
    });

    test('toMap excludes null id', () {
      final report = SavedReport(
        weekStart: '2025-01-06',
        weekEnd: '2025-01-12',
        fullReport: '',
        compactReport: '',
        generatedAt: '',
      );
      final map = report.toMap();
      expect(map.containsKey('id'), false);
    });

    test('fromMap handles missing fields', () {
      final report = SavedReport.fromMap({});
      expect(report.id, isNull);
      expect(report.weekStart, '');
      expect(report.weekEnd, '');
      expect(report.sentVia, '');
    });
  });

  group('PrayerRequest', () {
    test('toMap / fromMap round-trip', () {
      final req = PrayerRequest(
        id: 5,
        title: 'Pray for healing',
        description: 'For brother James',
        category: 'church',
        createdAt: '2025-01-01T00:00:00',
        answeredAt: '2025-01-15T00:00:00',
        answerNote: 'Healed completely!',
        isAnswered: true,
      );
      final map = req.toMap();
      final restored = PrayerRequest.fromMap(map);
      expect(restored.id, 5);
      expect(restored.title, 'Pray for healing');
      expect(restored.description, 'For brother James');
      expect(restored.category, 'church');
      expect(restored.createdAt, '2025-01-01T00:00:00');
      expect(restored.answeredAt, '2025-01-15T00:00:00');
      expect(restored.answerNote, 'Healed completely!');
      expect(restored.isAnswered, true);
    });

    test('toMap encodes isAnswered as int', () {
      final req = PrayerRequest(title: 'Test', createdAt: '', isAnswered: true);
      expect(req.toMap()['isAnswered'], 1);
      final req2 = PrayerRequest(title: 'Test', createdAt: '', isAnswered: false);
      expect(req2.toMap()['isAnswered'], 0);
    });

    test('fromMap with unanswered request (empty answeredAt)', () {
      final req = PrayerRequest.fromMap({
        'title': 'Test',
        'createdAt': '2025-01-01',
        'answeredAt': '',
        'isAnswered': 0,
      });
      expect(req.answeredAt, isNull);
      expect(req.isAnswered, false);
    });

    test('fromMap with null answeredAt', () {
      final req = PrayerRequest.fromMap({
        'title': 'Test',
        'createdAt': '2025-01-01',
        'answeredAt': null,
        'isAnswered': 0,
      });
      expect(req.answeredAt, isNull);
    });

    test('toMap excludes null id', () {
      final req = PrayerRequest(title: 'Test', createdAt: '');
      expect(req.toMap().containsKey('id'), false);
    });

    test('default category is personal', () {
      final req = PrayerRequest(title: 'Test', createdAt: '');
      expect(req.category, 'personal');
    });
  });

  group('FastingPeriod', () {
    test('toMap / fromMap round-trip', () {
      final period = FastingPeriod(
        id: 1,
        startDate: '2025-01-10',
        endDate: '2025-01-13',
        type: FastType.partial,
        prayerFocus: 'Family',
        completed: false,
      );
      final map = period.toMap();
      final restored = FastingPeriod.fromMap(map);
      expect(restored.id, 1);
      expect(restored.startDate, '2025-01-10');
      expect(restored.endDate, '2025-01-13');
      expect(restored.type, FastType.partial);
      expect(restored.prayerFocus, 'Family');
      expect(restored.completed, false);
    });

    test('totalDays calculates inclusive range', () {
      final period = FastingPeriod(
        startDate: '2025-01-10',
        endDate: '2025-01-13',
        type: FastType.complete,
      );
      expect(period.totalDays, 4); // 10, 11, 12, 13
    });

    test('totalDays with same start and end = 1', () {
      final period = FastingPeriod(
        startDate: '2025-01-10',
        endDate: '2025-01-10',
        type: FastType.complete,
      );
      expect(period.totalDays, 1);
    });

    test('totalDays with invalid dates returns 1', () {
      final period = FastingPeriod(
        startDate: 'invalid',
        endDate: 'also-invalid',
        type: FastType.complete,
      );
      expect(period.totalDays, 1);
    });

    test('currentDay on start date = 1', () {
      final period = FastingPeriod(
        startDate: '2025-01-10',
        endDate: '2025-01-13',
        type: FastType.complete,
      );
      expect(period.currentDay(DateTime(2025, 1, 10)), 1);
    });

    test('currentDay on second day = 2', () {
      final period = FastingPeriod(
        startDate: '2025-01-10',
        endDate: '2025-01-13',
        type: FastType.complete,
      );
      expect(period.currentDay(DateTime(2025, 1, 11)), 2);
    });

    test('currentDay clamped to totalDays after end', () {
      final period = FastingPeriod(
        startDate: '2025-01-10',
        endDate: '2025-01-13',
        type: FastType.complete,
      );
      expect(period.currentDay(DateTime(2025, 1, 20)), 4);
    });

    test('currentDay clamped to 1 before start', () {
      final period = FastingPeriod(
        startDate: '2025-01-10',
        endDate: '2025-01-13',
        type: FastType.complete,
      );
      expect(period.currentDay(DateTime(2025, 1, 5)), 1);
    });

    test('typeLabel returns correct keys', () {
      expect(
        FastingPeriod(startDate: '', endDate: '', type: FastType.complete).typeLabel,
        'fastingTypeComplete',
      );
      expect(
        FastingPeriod(startDate: '', endDate: '', type: FastType.partial).typeLabel,
        'fastingTypePartial',
      );
      expect(
        FastingPeriod(startDate: '', endDate: '', type: FastType.esther).typeLabel,
        'fastingTypeEsther',
      );
    });

    test('fromMap with unknown type defaults to complete', () {
      final period = FastingPeriod.fromMap({
        'startDate': '2025-01-10',
        'endDate': '2025-01-13',
        'type': 'unknownType',
      });
      expect(period.type, FastType.complete);
    });

    test('toMap excludes null id', () {
      final period = FastingPeriod(
        startDate: '2025-01-10',
        endDate: '2025-01-13',
        type: FastType.complete,
      );
      expect(period.toMap().containsKey('id'), false);
    });

    test('toMap encodes completed as int', () {
      final period = FastingPeriod(
        startDate: '', endDate: '', type: FastType.complete, completed: true,
      );
      expect(period.toMap()['completed'], 1);
    });
  });

  group('CustomActivity', () {
    test('toMap / fromMap round-trip', () {
      final activity = CustomActivity(
        id: 'abc-123',
        name: 'Worship',
        icon: '🎵',
        fields: [
          CustomField(label: 'Song'),
          CustomField(label: 'Duration', type: CustomFieldType.duration),
        ],
      );
      final map = activity.toMap();
      final restored = CustomActivity.fromMap(map);
      expect(restored.id, 'abc-123');
      expect(restored.name, 'Worship');
      expect(restored.icon, '🎵');
      expect(restored.fields.map((f) => f.label).toList(), ['Song', 'Duration']);
      expect(restored.fields[1].type, CustomFieldType.duration);
    });

    test('default icon is sparkles', () {
      final activity = CustomActivity(id: '1', name: 'Test');
      expect(activity.icon, '\u2728');
    });

    test('default fields is empty', () {
      final activity = CustomActivity(id: '1', name: 'Test');
      expect(activity.fields, isEmpty);
    });

    test('fromMap with missing icon uses default', () {
      final activity = CustomActivity.fromMap({
        'id': '1',
        'name': 'Test',
      });
      expect(activity.icon, '\u2728');
    });

    test('fromMap with old fieldLabels format migrates to fields', () {
      final activity = CustomActivity.fromMap({
        'id': '1',
        'name': 'Test',
        'fieldLabels': ['Alpha', 'Beta'],
      });
      expect(activity.fields.map((f) => f.label).toList(), ['Alpha', 'Beta']);
    });

    test('fromMap with null fieldLabels returns empty fields', () {
      final activity = CustomActivity.fromMap({
        'id': '1',
        'name': 'Test',
        'fieldLabels': null,
      });
      expect(activity.fields, isEmpty);
    });
  });
}
