import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/models/daily_log.dart';

void main() {
  group('LiteratureEntry', () {
    test('default constructor', () {
      final entry = LiteratureEntry();
      expect(entry.title, '');
      expect(entry.amount, '');
      expect(entry.unit, 'pages');
    });

    test('named constructor', () {
      final entry = LiteratureEntry(title: 'Book', amount: '50', unit: 'chapters');
      expect(entry.title, 'Book');
      expect(entry.amount, '50');
      expect(entry.unit, 'chapters');
    });

    test('toMap / fromMap round-trip', () {
      final entry = LiteratureEntry(title: 'Test', amount: '10', unit: 'books');
      final map = entry.toMap();
      final restored = LiteratureEntry.fromMap(map);
      expect(restored.title, 'Test');
      expect(restored.amount, '10');
      expect(restored.unit, 'books');
    });

    test('fromMap handles missing keys', () {
      final entry = LiteratureEntry.fromMap({});
      expect(entry.title, '');
      expect(entry.amount, '');
      expect(entry.unit, 'pages');
    });
  });

  group('BibleReadingEntry', () {
    test('default constructor', () {
      final entry = BibleReadingEntry();
      expect(entry.startBook, '');
      expect(entry.startChapter, 0);
      expect(entry.endBook, '');
      expect(entry.endChapter, 0);
      expect(entry.chaptersRead, 0);
      expect(entry.isEmpty, true);
      expect(entry.isNotEmpty, false);
    });

    test('toMap / fromMap round-trip', () {
      final entry = BibleReadingEntry(
        startBook: 'Genesis',
        startChapter: 1,
        endBook: 'Genesis',
        endChapter: 3,
        chaptersRead: 3,
      );
      final map = entry.toMap();
      final restored = BibleReadingEntry.fromMap(map);
      expect(restored.startBook, 'Genesis');
      expect(restored.startChapter, 1);
      expect(restored.endBook, 'Genesis');
      expect(restored.endChapter, 3);
      expect(restored.chaptersRead, 3);
    });

    test('recalculate — same book', () {
      final entry = BibleReadingEntry(
        startBook: 'John',
        startChapter: 1,
        endBook: 'John',
        endChapter: 5,
      );
      entry.recalculate();
      expect(entry.chaptersRead, 5);
    });

    test('recalculate — cross-book', () {
      final entry = BibleReadingEntry(
        startBook: 'Genesis',
        startChapter: 49,
        endBook: 'Exodus',
        endChapter: 1,
      );
      entry.recalculate();
      expect(entry.chaptersRead, 3); // Gen 49, 50, Exo 1
    });

    test('recalculate — empty start book returns 0', () {
      final entry = BibleReadingEntry(startChapter: 1);
      entry.recalculate();
      expect(entry.chaptersRead, 0);
    });

    test('recalculate — start chapter < 1 returns 0', () {
      final entry = BibleReadingEntry(startBook: 'Genesis', startChapter: 0);
      entry.recalculate();
      expect(entry.chaptersRead, 0);
    });

    test('recalculate — end book empty defaults to start book', () {
      final entry = BibleReadingEntry(
        startBook: 'Genesis',
        startChapter: 1,
        endChapter: 5,
      );
      entry.recalculate();
      expect(entry.chaptersRead, 5);
    });

    test('recalculate — end chapter < 1 defaults to start chapter', () {
      final entry = BibleReadingEntry(
        startBook: 'Genesis',
        startChapter: 3,
      );
      entry.recalculate();
      expect(entry.chaptersRead, 1);
    });

    test('localizedDisplay — English', () {
      final entry = BibleReadingEntry(
        startBook: 'Genesis',
        startChapter: 1,
        endBook: 'Genesis',
        endChapter: 3,
      );
      final display = entry.localizedDisplay('en');
      expect(display, 'Genesis 1 \u2013 Genesis 3');
    });

    test('localizedDisplay — French', () {
      final entry = BibleReadingEntry(
        startBook: 'Genesis',
        startChapter: 1,
        endBook: 'Genesis',
        endChapter: 3,
      );
      final display = entry.localizedDisplay('fr');
      expect(display, 'Genèse 1 \u2013 Genèse 3');
    });

    test('localizedDisplay — single chapter', () {
      final entry = BibleReadingEntry(
        startBook: 'John',
        startChapter: 3,
        endBook: 'John',
        endChapter: 3,
      );
      expect(entry.localizedDisplay('en'), 'John 3');
    });

    test('localizedDisplay — empty returns empty string', () {
      final entry = BibleReadingEntry();
      expect(entry.localizedDisplay('en'), '');
    });

    test('isEmpty / isNotEmpty', () {
      expect(BibleReadingEntry().isEmpty, true);
      expect(BibleReadingEntry(startBook: 'Genesis').isNotEmpty, true);
    });
  });

  group('DailyLog', () {
    test('default constructor', () {
      final log = DailyLog(dateKey: '2025-01-01');
      expect(log.dateKey, '2025-01-01');
      expect(log.bibleReference, '');
      expect(log.bibleChapters, '');
      expect(log.bibleSessions, isEmpty);
      expect(log.literature.length, 1); // default empty entry
      expect(log.completed, false);
    });

    test('completeness — empty log is 0', () {
      final log = DailyLog(dateKey: '2025-01-01');
      expect(log.completeness, 0.0);
    });

    test('completeness — all 11 disciplines filled', () {
      final log = DailyLog(
        dateKey: '2025-01-01',
        bibleReference: 'John 3',
        literature: [LiteratureEntry(title: 'Book')],
        ddegScripture: 'Ps 23',
        prayerAloneDuration: '30 minutes',
        prayerOthersDuration: '15 minutes',
        evangelismContacts: '2',
        fastingType: 'Daniel fast',
        givingType: 'tithe',
        churchType: 'Sunday service',
        discipleshipWho: 'John',
        proclamationCount: '5',
      );
      expect(log.completeness, 1.0);
    });

    test('completeness — partial fill', () {
      final log = DailyLog(
        dateKey: '2025-01-01',
        bibleReference: 'John 3',
        prayerAloneDuration: '30 minutes',
      );
      // 2 out of 11
      expect(log.completeness, closeTo(2 / 11, 0.01));
    });

    test('completeness — bibleSessions counts for bible discipline', () {
      final log = DailyLog(
        dateKey: '2025-01-01',
        bibleSessions: [BibleReadingEntry(startBook: 'Genesis', startChapter: 1, endChapter: 3, chaptersRead: 3)],
      );
      // Bible = true (from sessions), rest empty
      expect(log.completeness, closeTo(1 / 11, 0.01));
    });

    test('totalSessionChapters', () {
      final log = DailyLog(
        dateKey: '2025-01-01',
        bibleSessions: [
          BibleReadingEntry(chaptersRead: 3),
          BibleReadingEntry(chaptersRead: 5),
        ],
      );
      expect(log.totalSessionChapters, 8);
    });

    test('totalBibleChapters — combines sessions and legacy', () {
      final log = DailyLog(
        dateKey: '2025-01-01',
        bibleChapters: '2',
        bibleSessions: [BibleReadingEntry(chaptersRead: 3)],
      );
      expect(log.totalBibleChapters, 5);
    });

    test('totalBibleChapters — non-numeric legacy ignored', () {
      final log = DailyLog(
        dateKey: '2025-01-01',
        bibleChapters: 'abc',
        bibleSessions: [BibleReadingEntry(chaptersRead: 3)],
      );
      expect(log.totalBibleChapters, 3);
    });

    test('combinedBibleReference — sessions only', () {
      final log = DailyLog(
        dateKey: '2025-01-01',
        bibleSessions: [
          BibleReadingEntry(startBook: 'Genesis', startChapter: 1, endBook: 'Genesis', endChapter: 3),
          BibleReadingEntry(startBook: 'John', startChapter: 1, endBook: 'John', endChapter: 1),
        ],
      );
      final ref = log.combinedBibleReference('en');
      expect(ref, contains('Genesis'));
      expect(ref, contains('John'));
      expect(ref, contains(';')); // separator
    });

    test('combinedBibleReference — falls back to legacy', () {
      final log = DailyLog(
        dateKey: '2025-01-01',
        bibleReference: 'Ps 23',
      );
      expect(log.combinedBibleReference('en'), 'Ps 23');
    });

    test('combinedBibleReference — empty', () {
      final log = DailyLog(dateKey: '2025-01-01');
      expect(log.combinedBibleReference('en'), '');
    });

    test('toMap / fromMap round-trip', () {
      final log = DailyLog(
        dateKey: '2025-01-15',
        bibleReference: 'John 3',
        bibleChapters: '5',
        bibleSessions: [
          BibleReadingEntry(startBook: 'Genesis', startChapter: 1, endBook: 'Genesis', endChapter: 3, chaptersRead: 3),
        ],
        literature: [LiteratureEntry(title: 'Book A', amount: '50', unit: 'pages')],
        ddegScripture: 'Ps 23',
        ddegTime: '30 minutes',
        ddegNotes: 'Meditated on peace',
        prayerAloneDuration: '45 minutes',
        prayerAloneNotes: 'Praise and worship',
        prayerOthersDuration: '20 minutes',
        prayerOthersContext: 'Cell group',
        evangelismContacts: '3',
        evangelismOutcome: 'Good conversation',
        evangelismNotes: 'At the market',
        evangelismNewBelievers: '1',
        evangelismBeingDiscipled: '2',
        evangelismFollowUpNotes: 'Called back',
        other: 'Visited hospital',
        fastingType: 'Daniel fast',
        fastingDuration: '12 hours',
        fastingPrayerFocus: 'Family',
        givingType: 'tithe',
        givingAmount: '50000',
        givingPurpose: 'Church building',
        churchType: 'Sunday service',
        churchNotes: 'Good message',
        discipleshipWho: 'Brother John',
        discipleshipTopic: 'Prayer life',
        discipleshipDuration: '1 hour',
        proclamationCount: '7',
        proclamationDuration: '30 minutes',
        voiceNotePath: '/path/to/voice.m4a',
        aiReflection: 'Keep growing!',
        completed: true,
      );

      final map = log.toMap();
      final restored = DailyLog.fromMap(map);

      expect(restored.dateKey, '2025-01-15');
      expect(restored.bibleReference, 'John 3');
      expect(restored.bibleChapters, '5');
      expect(restored.bibleSessions.length, 1);
      expect(restored.bibleSessions[0].startBook, 'Genesis');
      expect(restored.bibleSessions[0].chaptersRead, 3);
      expect(restored.literature.length, 1);
      expect(restored.literature[0].title, 'Book A');
      expect(restored.ddegScripture, 'Ps 23');
      expect(restored.ddegTime, '30 minutes');
      expect(restored.ddegNotes, 'Meditated on peace');
      expect(restored.prayerAloneDuration, '45 minutes');
      expect(restored.prayerAloneNotes, 'Praise and worship');
      expect(restored.prayerOthersDuration, '20 minutes');
      expect(restored.prayerOthersContext, 'Cell group');
      expect(restored.evangelismContacts, '3');
      expect(restored.evangelismOutcome, 'Good conversation');
      expect(restored.evangelismNotes, 'At the market');
      expect(restored.evangelismNewBelievers, '1');
      expect(restored.evangelismBeingDiscipled, '2');
      expect(restored.evangelismFollowUpNotes, 'Called back');
      expect(restored.other, 'Visited hospital');
      expect(restored.fastingType, 'Daniel fast');
      expect(restored.fastingDuration, '12 hours');
      expect(restored.fastingPrayerFocus, 'Family');
      expect(restored.givingType, 'tithe');
      expect(restored.givingAmount, '50000');
      expect(restored.givingPurpose, 'Church building');
      expect(restored.churchType, 'Sunday service');
      expect(restored.churchNotes, 'Good message');
      expect(restored.discipleshipWho, 'Brother John');
      expect(restored.discipleshipTopic, 'Prayer life');
      expect(restored.discipleshipDuration, '1 hour');
      expect(restored.proclamationCount, '7');
      expect(restored.proclamationDuration, '30 minutes');
      expect(restored.voiceNotePath, '/path/to/voice.m4a');
      expect(restored.aiReflection, 'Keep growing!');
      expect(restored.completed, true);
    });

    test('fromMap handles missing fields gracefully', () {
      final log = DailyLog.fromMap({'dateKey': '2025-01-01'});
      expect(log.dateKey, '2025-01-01');
      expect(log.bibleReference, '');
      expect(log.literature.length, 1);
      expect(log.bibleSessions, isEmpty);
      expect(log.completed, false);
    });

    test('fromMap handles corrupted literature JSON', () {
      final log = DailyLog.fromMap({
        'dateKey': '2025-01-01',
        'literature': 'not-valid-json',
      });
      // Should fall back to default
      expect(log.literature.length, 1);
      expect(log.literature[0].title, '');
    });

    test('fromMap handles corrupted bibleSessions JSON', () {
      final log = DailyLog.fromMap({
        'dateKey': '2025-01-01',
        'bibleSessions': 'not-valid-json',
      });
      expect(log.bibleSessions, isEmpty);
    });

    test('fromMap handles empty literature list in JSON', () {
      final log = DailyLog.fromMap({
        'dateKey': '2025-01-01',
        'literature': jsonEncode([]),
      });
      // Should add a default entry
      expect(log.literature.length, 1);
    });

    test('toMap encodes completed as int', () {
      final log = DailyLog(dateKey: '2025-01-01', completed: true);
      expect(log.toMap()['completed'], 1);

      final log2 = DailyLog(dateKey: '2025-01-01', completed: false);
      expect(log2.toMap()['completed'], 0);
    });

    test('toMap encodes literature as JSON string', () {
      final log = DailyLog(
        dateKey: '2025-01-01',
        literature: [LiteratureEntry(title: 'Test')],
      );
      final map = log.toMap();
      expect(map['literature'], isA<String>());
      final decoded = jsonDecode(map['literature']);
      expect(decoded, isA<List>());
      expect(decoded[0]['title'], 'Test');
    });

    test('toMap encodes bibleSessions as JSON string', () {
      final log = DailyLog(
        dateKey: '2025-01-01',
        bibleSessions: [BibleReadingEntry(startBook: 'Genesis', startChapter: 1)],
      );
      final map = log.toMap();
      expect(map['bibleSessions'], isA<String>());
      final decoded = jsonDecode(map['bibleSessions']);
      expect(decoded[0]['startBook'], 'Genesis');
    });
  });
}
