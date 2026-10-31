import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

class VideoCategory {
  final String id;
  final String label;
  const VideoCategory(this.id, this.label);
}

class VideoChannel {
  final String id;
  final String name;
  final String category;
  const VideoChannel(this.id, this.name, this.category);
}

class Video {
  final String id;
  final String title;
  final String channel;
  final String category;
  final DateTime published;
  final String description;

  const Video({
    required this.id,
    required this.title,
    required this.channel,
    required this.category,
    required this.published,
    this.description = '',
  });

  String get thumbnail => 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
  Uri get watchUrl => Uri.https('www.youtube.com', '/watch', {'v': id});

  factory Video.fromJson(Map<String, dynamic> j) => Video(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    channel: j['channel'] as String? ?? '',
    category: j['category'] as String? ?? '',
    published:
        DateTime.tryParse(j['published'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    description: j['description'] as String? ?? '',
  );
}

class VideoFeed {
  final DateTime updatedAt;
  final List<VideoCategory> categories;
  final List<VideoChannel> channels;
  final List<Video> videos;

  const VideoFeed({
    required this.updatedAt,
    required this.categories,
    required this.channels,
    required this.videos,
  });

  factory VideoFeed.fromJson(Map<String, dynamic> j) => VideoFeed(
    updatedAt:
        DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
    categories: [
      for (final c in (j['categories'] as List? ?? const []))
        VideoCategory(c['id'] as String, c['label'] as String),
    ],
    channels: [
      for (final c in (j['channels'] as List? ?? const []))
        VideoChannel(
          c['id'] as String,
          c['name'] as String,
          c['category'] as String,
        ),
    ],
    videos: [
      for (final v in (j['videos'] as List? ?? const []))
        Video.fromJson(v as Map<String, dynamic>),
    ],
  );
}

/// Latest Bible teaching, study and debate videos from the channels listed in
/// `functions/channels.json`.
///
/// - Native apps read each channel's public YouTube RSS feed directly.
/// - Browsers can't (YouTube sends no CORS headers), so the web app reads the
///   same feed from the `videos` Cloud Function at [_feedUrl].
/// - A snapshot bundled with the app is the offline fallback.
class VideoService {
  /// Tests turn the network off so nothing is left pending.
  static bool networkEnabled = true;

  static const _feedUrl = String.fromEnvironment(
    'VIDEO_FEED_URL',
    defaultValue: 'api/videos',
  );

  Future<VideoFeed> loadSnapshot() async {
    final raw = await rootBundle.loadString('assets/data/videos_snapshot.json');
    return VideoFeed.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// The live feed, or throws if it can't be reached.
  Future<VideoFeed> fetchLive(VideoFeed snapshot) async {
    if (!networkEnabled) throw StateError('network disabled');
    if (kIsWeb) {
      final res = await http
          .get(Uri.base.resolve(_feedUrl))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      return VideoFeed.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    final results = await Future.wait(
      snapshot.channels.map(
        (c) => _fetchChannel(c).catchError((_) => <Video>[]),
      ),
    );
    final videos = results.expand((v) => v).toList()
      ..sort((a, b) => b.published.compareTo(a.published));
    if (videos.isEmpty) throw Exception('no videos');
    return VideoFeed(
      updatedAt: DateTime.now(),
      categories: snapshot.categories,
      channels: snapshot.channels,
      videos: videos,
    );
  }

  Future<List<Video>> _fetchChannel(VideoChannel c) async {
    final res = await http
        .get(
          Uri.https('www.youtube.com', '/feeds/videos.xml', {
            'channel_id': c.id,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return const [];
    return parseFeed(res.body, c);
  }

  /// Parses a YouTube channel RSS feed (mirrors functions/feed.js).
  static List<Video> parseFeed(String xml, VideoChannel c) {
    String tag(String s, String name) {
      final m = RegExp('<$name[^>]*>([\\s\\S]*?)</$name>').firstMatch(s);
      return m == null ? '' : _decode(m.group(1)!.trim());
    }

    final out = <Video>[];
    for (final entry in xml.split('<entry>').skip(1)) {
      final id = tag(entry, 'yt:videoId');
      if (id.isEmpty ||
          RegExp(r'<link[^>]+href="[^"]*/shorts/').hasMatch(entry)) {
        continue;
      }
      var description = tag(entry, 'media:description');
      if (description.length > 280) {
        description = '${description.substring(0, 277).trimRight()}…';
      }
      out.add(
        Video(
          id: id,
          title: tag(entry, 'title'),
          channel: c.name,
          category: c.category,
          published:
              DateTime.tryParse(tag(entry, 'published')) ??
              DateTime.fromMillisecondsSinceEpoch(0),
          description: description,
        ),
      );
    }
    return out;
  }

  static String _decode(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');
}
