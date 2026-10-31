import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models.dart';

/// Loads the bundled, public-domain hymn books from assets.
///
/// These are the always-available, offline-safe sources (the asset bundle is
/// present even in tests).
class HymnService {
  static const String _asset = 'assets/data/hymns.json';
  static const String _wesleyAsset = 'assets/data/wesley_1876.json';

  /// The curated "Hymns of the World" selection.
  Future<List<Hymn>> loadBundledHymns() async {
    final raw = await rootBundle.loadString(_asset);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = (data['hymns'] as List?) ?? const [];
    return list
        .map((e) => Hymn.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// John Wesley's complete "Collection of Hymns for the Use of the People
  /// Called Methodists" (1876 edition, 1,026 hymns), in book order.
  /// Built by `tool/build_wesley_hymns.py`.
  Future<({List<HymnSection> sections, List<Hymn> hymns})> loadWesley() async {
    final raw = await rootBundle.loadString(_wesleyAsset);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final sections = ((data['sections'] as List?) ?? const [])
        .map((e) => HymnSection.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final hymns = ((data['hymns'] as List?) ?? const [])
        .map((e) {
          final j = e as Map<String, dynamic>;
          final number = (j['number'] as num).toInt();
          return Hymn(
            title: j['firstLine'] as String? ?? 'Hymn $number',
            firstLine: j['firstLine'] as String? ?? '',
            author: 'Wesley’s Collection',
            year: 1876,
            tradition: HymnTradition.methodist,
            meter: j['meter'] as String?,
            scripture: j['note'] as String?,
            hymnalRef: 'No. $number',
            source: 'Public domain',
            number: number,
            book: HymnBook.wesley,
            verses: ((j['verses'] as List?) ?? const [])
                .map((v) => v.toString())
                .toList(growable: false),
          );
        })
        .toList(growable: false);
    return (sections: sections, hymns: hymns);
  }
}
