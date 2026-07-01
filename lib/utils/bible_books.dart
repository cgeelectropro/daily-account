/// Bible books with their chapter counts, in canonical order.
/// Used to calculate the number of chapters read between a start and end reference.
class BibleBook {
  final String nameEn;
  final String nameFr;
  final int chapters;
  final int order; // canonical order (0-indexed)

  const BibleBook(this.nameEn, this.nameFr, this.chapters, this.order);
}

class BibleBooks {
  BibleBooks._();

  static const List<BibleBook> all = [
    // Old Testament
    BibleBook('Genesis', 'Genèse', 50, 0),
    BibleBook('Exodus', 'Exode', 40, 1),
    BibleBook('Leviticus', 'Lévitique', 27, 2),
    BibleBook('Numbers', 'Nombres', 36, 3),
    BibleBook('Deuteronomy', 'Deutéronome', 34, 4),
    BibleBook('Joshua', 'Josué', 24, 5),
    BibleBook('Judges', 'Juges', 21, 6),
    BibleBook('Ruth', 'Ruth', 4, 7),
    BibleBook('1 Samuel', '1 Samuel', 31, 8),
    BibleBook('2 Samuel', '2 Samuel', 24, 9),
    BibleBook('1 Kings', '1 Rois', 22, 10),
    BibleBook('2 Kings', '2 Rois', 25, 11),
    BibleBook('1 Chronicles', '1 Chroniques', 29, 12),
    BibleBook('2 Chronicles', '2 Chroniques', 36, 13),
    BibleBook('Ezra', 'Esdras', 10, 14),
    BibleBook('Nehemiah', 'Néhémie', 13, 15),
    BibleBook('Esther', 'Esther', 10, 16),
    BibleBook('Job', 'Job', 42, 17),
    BibleBook('Psalms', 'Psaumes', 150, 18),
    BibleBook('Proverbs', 'Proverbes', 31, 19),
    BibleBook('Ecclesiastes', 'Ecclésiaste', 12, 20),
    BibleBook('Song of Solomon', 'Cantique des Cantiques', 8, 21),
    BibleBook('Isaiah', 'Ésaïe', 66, 22),
    BibleBook('Jeremiah', 'Jérémie', 52, 23),
    BibleBook('Lamentations', 'Lamentations', 5, 24),
    BibleBook('Ezekiel', 'Ézéchiel', 48, 25),
    BibleBook('Daniel', 'Daniel', 12, 26),
    BibleBook('Hosea', 'Osée', 14, 27),
    BibleBook('Joel', 'Joël', 3, 28),
    BibleBook('Amos', 'Amos', 9, 29),
    BibleBook('Obadiah', 'Abdias', 1, 30),
    BibleBook('Jonah', 'Jonas', 4, 31),
    BibleBook('Micah', 'Michée', 7, 32),
    BibleBook('Nahum', 'Nahum', 3, 33),
    BibleBook('Habakkuk', 'Habakuk', 3, 34),
    BibleBook('Zephaniah', 'Sophonie', 3, 35),
    BibleBook('Haggai', 'Aggée', 2, 36),
    BibleBook('Zechariah', 'Zacharie', 14, 37),
    BibleBook('Malachi', 'Malachie', 4, 38),
    // New Testament
    BibleBook('Matthew', 'Matthieu', 28, 39),
    BibleBook('Mark', 'Marc', 16, 40),
    BibleBook('Luke', 'Luc', 24, 41),
    BibleBook('John', 'Jean', 21, 42),
    BibleBook('Acts', 'Actes', 28, 43),
    BibleBook('Romans', 'Romains', 16, 44),
    BibleBook('1 Corinthians', '1 Corinthiens', 16, 45),
    BibleBook('2 Corinthians', '2 Corinthiens', 13, 46),
    BibleBook('Galatians', 'Galates', 6, 47),
    BibleBook('Ephesians', 'Éphésiens', 6, 48),
    BibleBook('Philippians', 'Philippiens', 4, 49),
    BibleBook('Colossians', 'Colossiens', 4, 50),
    BibleBook('1 Thessalonians', '1 Thessaloniciens', 5, 51),
    BibleBook('2 Thessalonians', '2 Thessaloniciens', 3, 52),
    BibleBook('1 Timothy', '1 Timothée', 6, 53),
    BibleBook('2 Timothy', '2 Timothée', 4, 54),
    BibleBook('Titus', 'Tite', 3, 55),
    BibleBook('Philemon', 'Philémon', 1, 56),
    BibleBook('Hebrews', 'Hébreux', 13, 57),
    BibleBook('James', 'Jacques', 5, 58),
    BibleBook('1 Peter', '1 Pierre', 5, 59),
    BibleBook('2 Peter', '2 Pierre', 3, 60),
    BibleBook('1 John', '1 Jean', 5, 61),
    BibleBook('2 John', '2 Jean', 1, 62),
    BibleBook('3 John', '3 Jean', 1, 63),
    BibleBook('Jude', 'Jude', 1, 64),
    BibleBook('Revelation', 'Apocalypse', 22, 65),
  ];

  /// Get list of book names for a given locale.
  static List<String> bookNames(String locale) {
    if (locale.startsWith('fr')) {
      return all.map((b) => b.nameFr).toList();
    }
    return all.map((b) => b.nameEn).toList();
  }

  /// Find a book by name (case-insensitive, partial match).
  static BibleBook? findBook(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.isEmpty) return null;

    // Try exact match first
    for (final b in all) {
      if (b.nameEn.toLowerCase() == lower || b.nameFr.toLowerCase() == lower) {
        return b;
      }
    }
    // Try prefix match
    for (final b in all) {
      if (b.nameEn.toLowerCase().startsWith(lower) ||
          b.nameFr.toLowerCase().startsWith(lower)) {
        return b;
      }
    }
    // Try contains match
    for (final b in all) {
      if (b.nameEn.toLowerCase().contains(lower) ||
          b.nameFr.toLowerCase().contains(lower)) {
        return b;
      }
    }
    return null;
  }

  /// Parse a reference string like "John 3" into (BibleBook, chapter).
  /// Returns null if parsing fails.
  static (BibleBook, int)? parseReference(String ref) {
    final trimmed = ref.trim();
    if (trimmed.isEmpty) return null;

    // Try to split into book name and chapter number
    // Handle cases like "1 John 3", "Genesis 1", "John 3", "Ps 23"
    final match = RegExp(r'^(.+?)\s+(\d+)$').firstMatch(trimmed);
    if (match != null) {
      final bookName = match.group(1)!;
      final chapter = int.tryParse(match.group(2)!);
      if (chapter == null || chapter < 1) return null;
      final book = findBook(bookName);
      if (book == null) return null;
      if (chapter > book.chapters) return null;
      return (book, chapter);
    }

    // If no chapter number, just the book name — assume chapter 1
    final book = findBook(trimmed);
    if (book != null) return (book, 1);

    return null;
  }

  /// Calculate the number of chapters read from start to end reference.
  /// Both references are inclusive.
  /// Returns null if references can't be parsed.
  static int? calculateChapters(String startRef, String endRef) {
    final start = parseReference(startRef);
    final end = parseReference(endRef);
    if (start == null || end == null) return null;

    final (startBook, startChapter) = start;
    final (endBook, endChapter) = end;

    if (startBook.order == endBook.order) {
      // Same book: simple subtraction
      if (endChapter < startChapter) return null; // invalid
      return endChapter - startChapter + 1;
    }

    if (endBook.order < startBook.order) {
      return null; // end is before start — invalid
    }

    // Different books: count remaining chapters in start book +
    // all chapters in books between + chapters in end book
    int total = startBook.chapters - startChapter + 1; // remaining in start book

    // Add all chapters in books between start and end
    for (final b in all) {
      if (b.order > startBook.order && b.order < endBook.order) {
        total += b.chapters;
      }
    }

    // Add chapters in end book
    total += endChapter;

    return total;
  }

  /// Build a readable reference string from book + chapter.
  static String formatReference(BibleBook book, int chapter, String locale) {
    final name = locale.startsWith('fr') ? book.nameFr : book.nameEn;
    return '$name $chapter';
  }
}
