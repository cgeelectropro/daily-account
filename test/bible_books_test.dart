import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/utils/bible_books.dart';

void main() {
  group('BibleBooks.all', () {
    test('contains 66 books', () {
      expect(BibleBooks.all.length, 66);
    });

    test('first book is Genesis', () {
      expect(BibleBooks.all.first.nameEn, 'Genesis');
      expect(BibleBooks.all.first.nameFr, 'Genèse');
      expect(BibleBooks.all.first.chapters, 50);
      expect(BibleBooks.all.first.order, 0);
    });

    test('last book is Revelation', () {
      expect(BibleBooks.all.last.nameEn, 'Revelation');
      expect(BibleBooks.all.last.nameFr, 'Apocalypse');
      expect(BibleBooks.all.last.chapters, 22);
      expect(BibleBooks.all.last.order, 65);
    });

    test('orders are sequential 0-65', () {
      for (int i = 0; i < BibleBooks.all.length; i++) {
        expect(BibleBooks.all[i].order, i);
      }
    });
  });

  group('BibleBooks.bookNames', () {
    test('returns English names for en locale', () {
      final names = BibleBooks.bookNames('en');
      expect(names.length, 66);
      expect(names.first, 'Genesis');
      expect(names.last, 'Revelation');
    });

    test('returns French names for fr locale', () {
      final names = BibleBooks.bookNames('fr');
      expect(names.length, 66);
      expect(names.first, 'Genèse');
      expect(names.last, 'Apocalypse');
    });

    test('returns French names for fr_FR locale', () {
      final names = BibleBooks.bookNames('fr_FR');
      expect(names.first, 'Genèse');
    });

    test('returns English names for unknown locale', () {
      final names = BibleBooks.bookNames('de');
      expect(names.first, 'Genesis');
    });
  });

  group('BibleBooks.findBook', () {
    test('finds by exact English name', () {
      final book = BibleBooks.findBook('Genesis');
      expect(book, isNotNull);
      expect(book!.nameEn, 'Genesis');
    });

    test('finds by exact French name', () {
      final book = BibleBooks.findBook('Genèse');
      expect(book, isNotNull);
      expect(book!.nameEn, 'Genesis');
    });

    test('case insensitive', () {
      expect(BibleBooks.findBook('genesis')?.nameEn, 'Genesis');
      expect(BibleBooks.findBook('GENESIS')?.nameEn, 'Genesis');
      expect(BibleBooks.findBook('GeNeSiS')?.nameEn, 'Genesis');
    });

    test('prefix match', () {
      expect(BibleBooks.findBook('Gen')?.nameEn, 'Genesis');
      expect(BibleBooks.findBook('Rev')?.nameEn, 'Revelation');
    });

    test('finds numbered books', () {
      expect(BibleBooks.findBook('1 Samuel')?.nameEn, '1 Samuel');
      expect(BibleBooks.findBook('2 Kings')?.nameEn, '2 Kings');
      expect(BibleBooks.findBook('1 Corinthians')?.nameEn, '1 Corinthians');
    });

    test('returns null for empty string', () {
      expect(BibleBooks.findBook(''), isNull);
    });

    test('returns null for nonsense', () {
      expect(BibleBooks.findBook('xyzzy'), isNull);
    });
  });

  group('BibleBooks.parseReference', () {
    test('parses "John 3"', () {
      final result = BibleBooks.parseReference('John 3');
      expect(result, isNotNull);
      expect(result!.$1.nameEn, 'John');
      expect(result.$2, 3);
    });

    test('parses "1 John 3"', () {
      final result = BibleBooks.parseReference('1 John 3');
      expect(result, isNotNull);
      expect(result!.$1.nameEn, '1 John');
      expect(result.$2, 3);
    });

    test('parses "Genesis 50" (last chapter)', () {
      final result = BibleBooks.parseReference('Genesis 50');
      expect(result, isNotNull);
      expect(result!.$2, 50);
    });

    test('returns null for chapter beyond max', () {
      final result = BibleBooks.parseReference('Genesis 51');
      expect(result, isNull);
    });

    test('returns null for chapter 0', () {
      final result = BibleBooks.parseReference('Genesis 0');
      expect(result, isNull);
    });

    test('handles book name only (assumes chapter 1)', () {
      final result = BibleBooks.parseReference('Genesis');
      expect(result, isNotNull);
      expect(result!.$1.nameEn, 'Genesis');
      expect(result.$2, 1);
    });

    test('returns null for empty string', () {
      expect(BibleBooks.parseReference(''), isNull);
    });

    test('returns null for unknown book', () {
      expect(BibleBooks.parseReference('Nonexistent 5'), isNull);
    });
  });

  group('BibleBooks.calculateChapters', () {
    test('same book, same chapter = 1', () {
      expect(BibleBooks.calculateChapters('John 3', 'John 3'), 1);
    });

    test('same book, range within', () {
      // John 1 to John 5 = 5 chapters
      expect(BibleBooks.calculateChapters('John 1', 'John 5'), 5);
    });

    test('same book, entire book', () {
      // Genesis 1 to Genesis 50 = 50 chapters
      expect(BibleBooks.calculateChapters('Genesis 1', 'Genesis 50'), 50);
    });

    test('across books — Genesis to Exodus', () {
      // Genesis 49 (chs 49-50 = 2) + Exodus 1 (ch 1 = 1) = 3
      expect(BibleBooks.calculateChapters('Genesis 49', 'Exodus 1'), 3);
    });

    test('across multiple books', () {
      // Obadiah (1ch) is between Amos and Jonah
      // Amos 9 (ch 9 = 1) + Obadiah all (1) + Jonah 1 (ch 1 = 1) = 3
      expect(BibleBooks.calculateChapters('Amos 9', 'Jonah 1'), 3);
    });

    test('entire Bible', () {
      // Genesis 1 to Revelation 22 = 1189 chapters total
      final total = BibleBooks.calculateChapters('Genesis 1', 'Revelation 22');
      expect(total, 1189);
    });

    test('returns null when end is before start', () {
      expect(BibleBooks.calculateChapters('John 5', 'John 3'), isNull);
    });

    test('returns null when end book is before start book', () {
      expect(BibleBooks.calculateChapters('Exodus 1', 'Genesis 1'), isNull);
    });

    test('returns null for invalid references', () {
      expect(BibleBooks.calculateChapters('', 'John 3'), isNull);
      expect(BibleBooks.calculateChapters('John 3', ''), isNull);
    });
  });

  group('BibleBooks.formatReference', () {
    test('formats English reference', () {
      final book = BibleBooks.all.first; // Genesis
      expect(BibleBooks.formatReference(book, 1, 'en'), 'Genesis 1');
    });

    test('formats French reference', () {
      final book = BibleBooks.all.first; // Genesis
      expect(BibleBooks.formatReference(book, 1, 'fr'), 'Genèse 1');
    });
  });
}
