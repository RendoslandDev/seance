import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models.dart';

/// Loads the bundled, public-domain hymn library from assets.
///
/// This is the always-available, offline-safe source (the asset bundle is
/// present even in tests). Live metadata enrichment from Hymnary.org is a
/// possible future addition; lyrics stay bundled for licensing safety.
class HymnService {
  static const String _asset = 'assets/data/hymns.json';

  Future<List<Hymn>> loadBundledHymns() async {
    final raw = await rootBundle.loadString(_asset);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = (data['hymns'] as List?) ?? const [];
    return list
        .map((e) => Hymn.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
