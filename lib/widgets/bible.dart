import 'package:flutter/material.dart';

import '../models.dart';
import '../screens/video_screen.dart';
import '../theme.dart';
import 'reading.dart';

// ----------------------------------------------------------------------------
// Bible = Read (bundled KJV / WEB) + Watch (live teaching & debate videos)
// ----------------------------------------------------------------------------

class BibleView extends StatefulWidget {
  const BibleView({super.key, required this.state});

  final AppState state;

  @override
  State<BibleView> createState() => _BibleViewState();
}

class _BibleViewState extends State<BibleView> {
  int _segment = 0; // 0 = Read, 1 = Watch

  @override
  void initState() {
    super.initState();
    // Loading notifies listeners, which mustn't happen mid-build.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.state.loadBible(),
    );
  }

  void _select(int v) {
    setState(() => _segment = v);
    if (v == 1) widget.state.loadVideos();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BigTitle('Bible'),
              const SizedBox(height: 14),
              Segmented(
                labels: const ['Read', 'Watch'],
                value: _segment,
                onChanged: _select,
              ),
            ],
          ),
        ),
        Expanded(
          child: _segment == 0
              ? BibleReader(state: widget.state)
              : VideoList(state: widget.state),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Read
// ----------------------------------------------------------------------------

class BibleReader extends StatefulWidget {
  const BibleReader({super.key, required this.state});

  final AppState state;

  @override
  State<BibleReader> createState() => _BibleReaderState();
}

class _BibleReaderState extends State<BibleReader> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<VerseRef>? _results; // non-null while showing search results
  String _resultsFor = '';

  AppState get _state => widget.state;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _submit(String q) {
    final bible = _state.bible;
    if (bible == null) return;
    final ref = BibleService.parseReference(bible, q);
    if (ref != null) {
      _open(
        ref.book,
        ref.chapter,
        verse: q.contains(RegExp(r'[:.]\s*\d')) ? ref.verse : null,
      );
      return;
    }
    setState(() {
      _results = BibleService.search(bible, q);
      _resultsFor = q.trim();
    });
  }

  void _open(int book, int chapter, {int? verse}) {
    _state.openChapter(book, chapter, verse: verse);
    setState(() => _results = null);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _results = null);
  }

  void _step(int delta) {
    _state.stepChapter(delta);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final bible = _state.bible;
    if (bible == null) {
      return Center(
        child: _state.bibleLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: Palette.textLow,
                ),
              )
            : Text('The Bible could not be opened.', style: AppType.cardBody),
      );
    }

    final book = _state.currentBook!;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _PickerButton(
                  label: '${book.name} ${_state.bibleChapter}',
                  onTap: () => _showBookPicker(context),
                ),
              ),
              const SizedBox(width: 8),
              for (final t in BibleTranslation.values)
                FilterPill(
                  label: t.abbreviation,
                  selected: _state.translation == t,
                  onTap: () => _state.setTranslation(t),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onSubmitted: _submit,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Palette.textHi, fontSize: 15),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 19, color: Palette.textLow),
              suffixIcon: _results == null
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close, size: 18, color: Palette.textLow),
                      onPressed: _clearSearch,
                    ),
              hintText: 'Search words, or go to “John 3:16”',
              hintStyle: TextStyle(color: Palette.textLow, fontSize: 14),
              filled: true,
              fillColor: Palette.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Palette.borderStrong),
              ),
            ),
          ),
        ],
      ),
    );

    if (_results != null) {
      final results = _results!;
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(6, 0, 24, 40),
        physics: const BouncingScrollPhysics(),
        itemCount: results.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) return header;
          if (i == 1) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                results.isEmpty
                    ? 'No verses contain “$_resultsFor”.'
                    : '${results.length}${results.length >= 300 ? '+' : ''} '
                          'verses contain “$_resultsFor” · '
                          '${_state.translation.abbreviation}',
                style: AppType.badge,
              ),
            );
          }
          final r = results[i - 2];
          final b = bible.books[r.book];
          return _SearchHit(
            reference: '${b.name} ${r.chapter}:${r.verse}',
            text: r.text,
            query: _resultsFor,
            onTap: () => _open(r.book, r.chapter, verse: r.verse),
          );
        },
      );
    }

    final verses = _state.currentChapter;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(6, 0, 24, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        header,
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 18),
          child: Text(
            '${book.name} ${_state.bibleChapter}',
            style: AppType.display.copyWith(fontSize: 34),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SelectableText.rich(
            TextSpan(
              children: [
                for (var v = 0; v < verses.length; v++)
                  if (verses[v].isNotEmpty) ...[
                    TextSpan(
                      text: '${v + 1} ',
                      style: TextStyle(
                        fontFamily: AppType.sans,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Palette.textLow,
                      ),
                    ),
                    TextSpan(
                      text: '${verses[v]}  ',
                      style: TextStyle(
                        backgroundColor: _state.highlightVerse == v + 1
                            ? Palette.surfaceStrong
                            : null,
                      ),
                    ),
                  ],
              ],
            ),
            style: const TextStyle(
              fontFamily: AppType.serif,
              fontSize: 19,
              height: 1.75,
              color: Palette.textHi,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            if (_state.hasPreviousChapter)
              TextButton.icon(
                onPressed: () => _step(-1),
                icon: const Icon(Icons.chevron_left, size: 20),
                label: const Text('Previous'),
                style: TextButton.styleFrom(foregroundColor: Palette.textMid),
              ),
            const Spacer(),
            if (_state.hasNextChapter)
              TextButton.icon(
                onPressed: () => _step(1),
                icon: const Text('Next'),
                label: const Icon(Icons.chevron_right, size: 20),
                style: TextButton.styleFrom(foregroundColor: Palette.textHi),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '${_state.translation.title} · Public domain',
            style: AppType.badge,
          ),
        ),
      ],
    );
  }

  Future<void> _showBookPicker(BuildContext context) async {
    final bible = _state.bible!;
    final picked = await showModalBottomSheet<(int, int)>(
      context: context,
      backgroundColor: Palette.bg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => _BookPicker(bible: bible, current: _state.bibleBook),
    );
    if (picked != null) _open(picked.$1, picked.$2);
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.border),
          ),
          child: Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 17, color: Palette.textMid),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppType.sans,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Palette.textHi,
                  ),
                ),
              ),
              Icon(Icons.expand_more, size: 20, color: Palette.textLow),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two steps: pick a book (Old / New Testament), then a chapter.
class _BookPicker extends StatefulWidget {
  const _BookPicker({required this.bible, required this.current});
  final Bible bible;
  final int current;

  @override
  State<_BookPicker> createState() => _BookPickerState();
}

class _BookPickerState extends State<_BookPicker> {
  int? _book;

  @override
  Widget build(BuildContext context) {
    final books = widget.bible.books;
    final height = MediaQuery.of(context).size.height * 0.8;
    Widget grid(List<Widget> children, double minWidth) => LayoutBuilder(
      builder: (context, c) {
        final cols = (c.maxWidth / minWidth).floor().clamp(2, 10);
        final w = (c.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final child in children) SizedBox(width: w, child: child),
          ],
        );
      },
    );

    Widget tile(String label, bool selected, VoidCallback onTap) => Material(
      color: selected ? Palette.surfaceStrong : Palette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppType.sans,
              fontSize: 14,
              color: selected ? Palette.textHi : Palette.textMid,
            ),
          ),
        ),
      ),
    );

    final List<Widget> body;
    if (_book == null) {
      body = [
        for (final nt in [false, true]) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
            child: Text(
              nt ? 'NEW TESTAMENT' : 'OLD TESTAMENT',
              style: AppType.badge,
            ),
          ),
          grid([
            for (var i = 0; i < books.length; i++)
              if (books[i].isNewTestament == nt)
                tile(
                  books[i].name,
                  i == widget.current,
                  () => setState(() => _book = i),
                ),
          ], 130),
        ],
      ];
    } else {
      final b = books[_book!];
      body = [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: Palette.textMid),
              onPressed: () => setState(() => _book = null),
            ),
            Text(
              b.name,
              style: const TextStyle(
                fontFamily: AppType.serif,
                fontSize: 22,
                color: Palette.textHi,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        grid([
          for (var c = 1; c <= b.chapters.length; c++)
            tile('$c', false, () => Navigator.of(context).pop((_book!, c))),
        ], 56),
      ];
    }

    return SafeArea(
      child: SizedBox(
        height: height,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            Text(
              _book == null ? 'Books' : 'Chapter',
              style: const TextStyle(
                fontFamily: AppType.serif,
                fontSize: 26,
                fontWeight: FontWeight.w500,
                color: Palette.textHi,
              ),
            ),
            ...body,
          ],
        ),
      ),
    );
  }
}

class _SearchHit extends StatelessWidget {
  const _SearchHit({
    required this.reference,
    required this.text,
    required this.query,
    required this.onTap,
  });

  final String reference;
  final String text;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Emphasise the matched phrase.
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final spans = <TextSpan>[];
    var i = 0;
    while (true) {
      final j = lower.indexOf(q, i);
      if (j < 0 || q.isEmpty) {
        spans.add(TextSpan(text: text.substring(i)));
        break;
      }
      spans.add(TextSpan(text: text.substring(i, j)));
      spans.add(
        TextSpan(
          text: text.substring(j, j + q.length),
          style: const TextStyle(
            color: Palette.textHi,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      i = j + q.length;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reference.toUpperCase(), style: AppType.badge),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(children: spans),
                  style: TextStyle(
                    fontFamily: AppType.serif,
                    fontSize: 16,
                    height: 1.5,
                    color: Palette.textMid,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Watch
// ----------------------------------------------------------------------------

String timeAgo(DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.isNegative) {
    // Scheduled premieres appear in channel feeds ahead of time.
    final ahead = t.difference(now);
    if (ahead.inHours < 1) return 'premieres in ${ahead.inMinutes + 1} min';
    if (ahead.inDays < 1) return 'premieres in ${ahead.inHours} h';
    return 'premieres in ${ahead.inDays} d';
  }
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 7) return '${d.inDays} d ago';
  if (d.inDays < 60) return '${d.inDays ~/ 7} wk ago';
  return '${d.inDays ~/ 30} mo ago';
}

class VideoList extends StatelessWidget {
  const VideoList({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final feed = state.videoFeed;
    final videos = state.visibleVideos;
    final now = DateTime.now();

    final String status;
    if (feed == null) {
      status = 'Gathering videos…';
    } else if (state.videosLive) {
      status = 'Live · updated ${timeAgo(feed.updatedAt, now)}';
    } else if (state.videosLoading) {
      status = 'Refreshing…';
    } else {
      status =
          'Offline · showing videos saved '
          '${timeAgo(feed.updatedAt, now)}';
    }

    return RefreshIndicator(
      color: Palette.textHi,
      backgroundColor: Palette.bg1,
      onRefresh: () => state.loadVideos(force: true),
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 760 ? 2 : 1;
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(6, 0, 24, 0),
                sliver: SliverList.list(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'Teaching, Bible study and debates from '
                        '${feed?.channels.length ?? 'trusted'} channels.',
                        style: AppType.cardBody,
                      ),
                    ),
                    // All categories stay visible; they wrap on phones.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Wrap(
                        runSpacing: 8,
                        children: [
                          FilterPill(
                            label: 'All',
                            selected: state.videoCategory == null,
                            onTap: () => state.setVideoCategory(null),
                          ),
                          for (final cat in feed?.categories ?? const [])
                            FilterPill(
                              label: cat.label,
                              selected: state.videoCategory == cat.id,
                              onTap: () => state.setVideoCategory(cat.id),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 14),
                      child: Row(
                        children: [
                          if (state.videosLive)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF8FD19E),
                                shape: BoxShape.circle,
                              ),
                            ),
                          Flexible(child: Text(status, style: AppType.badge)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(10, 0, 24, 40),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 16,
                    mainAxisExtent:
                        (c.maxWidth - 34 - (cols - 1) * 16) / cols * 9 / 16 +
                        92,
                  ),
                  itemCount: videos.length,
                  itemBuilder: (context, i) =>
                      VideoCard(video: videos[i], now: now),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.video, required this.now});

  final Video video;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => VideoScreen(video: video)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    video.thumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: Palette.glow),
                    loadingBuilder: (context, child, p) =>
                        p == null ? child : Container(color: Palette.glow),
                  ),
                  Center(
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppType.sans,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: Palette.textHi,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${video.channel.toUpperCase()} · '
            '${timeAgo(video.published, now).toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.badge,
          ),
        ],
      ),
    );
  }
}
