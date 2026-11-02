import 'package:flutter_test/flutter_test.dart';
import 'package:seance/models.dart';
import 'package:seance/widgets/bible.dart' show timeAgo;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Bible kjv;
  setUpAll(() async => kjv = await BibleService().load(BibleTranslation.kjv));

  test('the whole KJV is bundled', () {
    expect(kjv.books, hasLength(66));
    expect(kjv.books.first.name, 'Genesis');
    expect(kjv.books.last.name, 'Revelation');
    final verses = kjv.books
        .expand((b) => b.chapters)
        .fold<int>(0, (n, c) => n + c.length);
    expect(verses, 31102);
    final john = kjv.books.firstWhere((b) => b.name == 'John');
    expect(john.chapters[2][15], startsWith('For God so loved the world'));
    // Translator markers are stripped.
    expect(kjv.books.first.chapters[0][1], isNot(contains('[')));
  });

  test('references resolve to book, chapter and verse', () {
    String show(String q) {
      final r = BibleService.parseReference(kjv, q);
      return r == null
          ? 'none'
          : '${kjv.books[r.book].name} ${r.chapter}:${r.verse}';
    }

    expect(show('John 3:16'), 'John 3:16');
    expect(show('ps 23'), 'Psalms 23:1');
    expect(show('1 cor 13'), '1 Corinthians 13:1');
    expect(show('Genesis 51'), 'none');
    expect(show('grace'), 'none');
  });

  test('phrase search finds verses', () {
    final hits = BibleService.search(kjv, 'the lord is my shepherd');
    expect(hits, isNotEmpty);
    expect(kjv.books[hits.first.book].name, 'Psalms');
    expect(hits.first.chapter, 23);
  });

  test('YouTube feed entries parse and shorts are skipped', () {
    const xml = '''
<feed><entry><yt:videoId>abc123</yt:videoId><title>Romans &amp; Grace</title>
<link rel="alternate" href="https://www.youtube.com/watch?v=abc123"/>
<published>2026-10-30T10:00:00+00:00</published>
<media:group><media:description>An overview.</media:description></media:group></entry>
<entry><yt:videoId>short1</yt:videoId><title>Clip</title>
<link rel="alternate" href="https://www.youtube.com/shorts/short1"/>
<published>2026-10-30T11:00:00+00:00</published></entry></feed>''';
    final videos = VideoService.parseFeed(
      xml,
      const VideoChannel('UC1', 'BibleProject', 'teaching'),
    );
    expect(videos, hasLength(1));
    expect(videos.single.title, 'Romans & Grace');
    expect(videos.single.channel, 'BibleProject');
    expect(videos.single.published.day, 30);
  });

  test('the bundled video snapshot is real and categorised', () async {
    final feed = await VideoService().loadSnapshot();
    expect(feed.channels.length, greaterThanOrEqualTo(8));
    expect(feed.videos.length, greaterThan(20));
    final cats = feed.categories.map((c) => c.id).toSet();
    expect(feed.videos.every((v) => cats.contains(v.category)), isTrue);
  });

  test('video ages read naturally, including premieres', () {
    final now = DateTime.utc(2026, 10, 31, 8);
    expect(timeAgo(DateTime.utc(2026, 10, 31, 6), now), '2 h ago');
    expect(timeAgo(DateTime.utc(2026, 10, 28, 8), now), '3 d ago');
    expect(timeAgo(DateTime.utc(2026, 10, 31, 12, 30), now), 'premieres in 4 h');
  });
}
