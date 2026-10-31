import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// The public-domain translations bundled with the app.
enum BibleTranslation {
  kjv('KJV', 'King James Version'),
  web('WEB', 'World English Bible');

  const BibleTranslation(this.abbreviation, this.title);
  final String abbreviation;
  final String title;

  static BibleTranslation fromName(String? name) => values.firstWhere(
    (t) => t.name == name,
    orElse: () => BibleTranslation.kjv,
  );
}

class BibleBook {
  final String code;
  final String name;

  /// chapters[c][v] is the text of chapter c+1, verse v+1 ('' if the
  /// translation omits that verse).
  final List<List<String>> chapters;

  const BibleBook({
    required this.code,
    required this.name,
    required this.chapters,
  });

  bool get isNewTestament => BibleService.newTestament.contains(code);
}

class Bible {
  final BibleTranslation translation;
  final List<BibleBook> books;

  const Bible({required this.translation, required this.books});
}

/// A located verse, e.g. a search hit.
class VerseRef {
  final int book; // index into Bible.books
  final int chapter; // 1-based
  final int verse; // 1-based
  final String text;

  const VerseRef(this.book, this.chapter, this.verse, this.text);
}

/// Loads the bundled Bibles (built by `tool/build_bible.py` from eBible.org's
/// public-domain texts). Each is ~4 MB, so only the chosen one is loaded.
class BibleService {
  static const newTestament = {
    'MAT', 'MAR', 'LUK', 'JOH', 'ACT', 'ROM', '1CO', '2CO', 'GAL', 'EPH', //
    'PHI', 'COL', '1TH', '2TH', '1TI', '2TI', 'TIT', 'PHM', 'HEB', 'JAM', //
    '1PE', '2PE', '1JO', '2JO', '3JO', 'JUD', 'REV',
  };

  Future<Bible> load(BibleTranslation t) async {
    final raw = await rootBundle.loadString('assets/data/bible/${t.name}.json');
    final books = await compute(_parse, raw);
    return Bible(translation: t, books: books);
  }

  static List<BibleBook> _parse(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    return [
      for (final b in data['books'] as List)
        BibleBook(
          code: b['code'] as String,
          name: b['name'] as String,
          chapters: [
            for (final c in b['chapters'] as List) (c as List).cast<String>(),
          ],
        ),
    ];
  }

  /// Case-insensitive phrase search across the whole Bible.
  static List<VerseRef> search(Bible bible, String query, {int limit = 300}) {
    final q = query.trim().toLowerCase();
    if (q.length < 3) return const [];
    final out = <VerseRef>[];
    for (var b = 0; b < bible.books.length; b++) {
      final chapters = bible.books[b].chapters;
      for (var c = 0; c < chapters.length; c++) {
        final verses = chapters[c];
        for (var v = 0; v < verses.length; v++) {
          if (verses[v].toLowerCase().contains(q)) {
            out.add(VerseRef(b, c + 1, v + 1, verses[v]));
            if (out.length >= limit) return out;
          }
        }
      }
    }
    return out;
  }

  /// Parses references like "John 3:16", "1 cor 13", "ps 23" into a
  /// location. Matches book names by prefix, ignoring spaces and case.
  static VerseRef? parseReference(Bible bible, String input) {
    final m = RegExp(
      r'^\s*(\d?\s*[a-zA-Z][a-zA-Z .]*?)\s*(\d+)(?:\s*[:.]\s*(\d+))?\s*$',
    ).firstMatch(input);
    if (m == null) return null;
    String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s.]'), '');
    final name = norm(m.group(1)!);
    if (name.isEmpty) return null;
    final aliases = {
      'ps': 'psalms',
      'psalm': 'psalms',
      'song': 'songofsolomon',
    };
    final key = aliases[name] ?? name;
    final b = bible.books.indexWhere(
      (book) => norm(book.name).startsWith(key) || norm(book.code) == key,
    );
    if (b < 0) return null;
    final chapter = int.parse(m.group(2)!);
    if (chapter < 1 || chapter > bible.books[b].chapters.length) return null;
    final verse = int.tryParse(m.group(3) ?? '') ?? 1;
    return VerseRef(b, chapter, verse, '');
  }
}
