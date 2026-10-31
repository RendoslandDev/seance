import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models.dart';

/// Pulls real-world reading material from the open Wikipedia REST API.
/// No key required, HTTPS only. Returns an empty list on any problem so
/// callers can fall back to the bundled template.
class ContentService {
  /// Allows tests to disable live network so nothing real is left pending
  /// between cases. Production leaves this enabled.
  static bool networkEnabled = true;

  static const List<String> _pool = [
    'Meditation',
    'Mindfulness',
    'Equanimity',
    'Gratitude',
    'Breathwork',
    'Stoicism',
    'Sleep',
    'Compassion',
    'Contemplation',
    'Solitude',
    'Silence',
    'Patience',
    'Humility',
    'Forgiveness',
    'Lectio Divina',
    'Prayer',
    'Sabbath',
    'Walking meditation',
    'Yoga nidra',
    'Metta',
    'Wabi-sabi',
    'Hesychasm',
    'Christian meditation',
    'Desert Fathers',
    'Ikigai',
    'Flow (psychology)',
    'Self-compassion',
    'Relaxation technique',
    'Psalms',
    'Spiritual direction',
  ];

  static const int _perDay = 8;

  /// Today's topics: a window over [_pool] that advances every day, so the
  /// library refreshes daily and every reader sees the same set on a given day.
  static List<String> topicsFor(DateTime day) {
    final epochDay =
        DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    final start = (epochDay * 3) % _pool.length;
    return [
      for (var i = 0; i < _perDay; i++) _pool[(start + i) % _pool.length],
    ];
  }

  Future<List<Reading>> fetchReadings(DateTime day) async {
    if (!networkEnabled) return const <Reading>[];
    final topics = topicsFor(day);
    final uri = Uri.https('en.wikipedia.org', '/w/api.php', {
      'format': 'json',
      'formatversion': '2',
      'action': 'query',
      'prop': 'extracts|pageimages',
      'explaintext': '1',
      'exintro': '1',
      'exlimit': 'max',
      'piprop': 'thumbnail',
      'pithumbsize': '800',
      'redirects': '1',
      'titles': topics.join('|'),
      'origin': '*',
    });

    // Browsers set their own User-Agent; a custom header would also force a
    // CORS preflight, so only native builds identify themselves.
    final res = await http
        .get(uri, headers: kIsWeb ? null : {'User-Agent': 'seance-app/1.0'})
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final pages = (data['query']?['pages'] as List?) ?? const [];

    // Keep the original topic ordering for a deliberate feel.
    final byTitle = <String, Reading>{};
    for (final page in pages) {
      final m = page as Map<String, dynamic>;
      final extract = (m['extract'] as String?)?.trim() ?? '';
      if (extract.length < 80) continue;
      final title = (m['title'] as String?) ?? 'Reading';
      final image = m['thumbnail']?['source'] as String?;
      byTitle[title] = Reading(
        title: title,
        author: 'Wikipedia',
        body: extract,
        minutes: _minutes(extract),
        image: image,
        remote: image != null,
      );
    }

    final ordered = <Reading>[];
    for (final t in topics) {
      final r = byTitle.remove(t);
      if (r != null) ordered.add(r);
    }
    ordered.addAll(byTitle.values); // any redirects we didn't match by name
    return ordered;
  }

  int _minutes(String text) {
    final words = text.split(RegExp(r'\s+')).length;
    return (words / 180).ceil().clamp(1, 20);
  }
}
