import 'package:flutter/material.dart';

import '../models.dart';
import '../screens/hymn_screen.dart';
import '../screens/reader_screen.dart';
import '../theme.dart';

const List<double> kGrayscale = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Renders an asset image or a live network image, always desaturated,
/// with a graceful fallback so nothing ever shows as broken.
class GrayImage extends StatelessWidget {
  const GrayImage({
    super.key,
    required this.reading,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });

  final Reading reading;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
          width: width,
          height: height,
          color: Palette.glow,
          alignment: Alignment.center,
          child: Icon(Icons.spa_outlined, color: Palette.textLow, size: 22),
        );

    final path = reading.image;
    if (path == null) return fallback();

    final Widget img = reading.remote
        ? Image.network(
            path,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) => fallback(),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: width,
                height: height,
                color: Palette.glow,
              );
            },
          )
        : Image.asset(
            path,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) => fallback(),
          );

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(kGrayscale),
      child: img,
    );
  }
}

// ----------------------------------------------------------------------------
// Library = Readings + Hymns
// ----------------------------------------------------------------------------

class LibraryView extends StatefulWidget {
  const LibraryView({super.key, required this.state});

  final AppState state;

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  int _segment = 0; // 0 = Readings, 1 = Hymns

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
              const _BigTitle('Library'),
              const SizedBox(height: 14),
              _Segmented(
                labels: const ['Readings', 'Hymns'],
                value: _segment,
                onChanged: (v) => setState(() => _segment = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: _segment == 0
              ? ReadingList(state: widget.state)
              : HymnList(state: widget.state),
        ),
      ],
    );
  }
}

class _BigTitle extends StatelessWidget {
  const _BigTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppType.serif,
        fontSize: 34,
        fontWeight: FontWeight.w500,
        color: Palette.textHi,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.labels,
    required this.value,
    required this.onChanged,
  });

  final List<String> labels;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        value == i ? Palette.surfaceStrong : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontFamily: AppType.sans,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: value == i ? Palette.textHi : Palette.textLow,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Readings
// ----------------------------------------------------------------------------

class ReadingCard extends StatelessWidget {
  const ReadingCard({super.key, required this.reading, required this.state});

  final Reading reading;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final saved = state.isSaved(reading);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReaderScreen(reading: reading, state: state),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GrayImage(reading: reading, width: 76, height: 92),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        reading.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppType.serif,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Palette.textHi,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${reading.author.toUpperCase()} · ${reading.minutes} MIN READ',
                        style: AppType.badge,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => state.toggleSaved(reading),
                  icon: Icon(
                    saved ? Icons.bookmark : Icons.bookmark_border,
                    size: 20,
                    color: saved ? Palette.textHi : Palette.textLow,
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

class ReadingList extends StatelessWidget {
  const ReadingList({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: Palette.textHi,
      backgroundColor: Palette.bg1,
      onRefresh: () => state.loadReadings(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(6, 2, 24, 40),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    state.readingsOffline
                        ? 'Offline · showing the curated library'
                        : 'Fresh passages, gathered for you',
                    style: AppType.cardBody,
                  ),
                ),
                if (state.readingsLoading) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: Palette.textLow,
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final r in state.readings) ReadingCard(reading: r, state: state),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Hymns
// ----------------------------------------------------------------------------

class HymnCard extends StatelessWidget {
  const HymnCard({super.key, required this.hymn, required this.state});

  final Hymn hymn;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final saved = state.isHymnSaved(hymn);
    final meta =
        '${hymn.tradition.label.toUpperCase()} · ${hymn.verseCount} VERSES'
        '${hymn.hymnalRef != null ? ' · ${hymn.hymnalRef}' : ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => HymnScreen(hymn: hymn, state: state),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 76,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Palette.glow, Palette.bg1],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.music_note,
                      color: Palette.textLow, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hymn.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppType.serif,
                          fontSize: 19,
                          fontWeight: FontWeight.w500,
                          color: Palette.textHi,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(meta, style: AppType.badge),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => state.toggleHymnSaved(hymn),
                  icon: Icon(
                    saved ? Icons.bookmark : Icons.bookmark_border,
                    size: 20,
                    color: saved ? Palette.textHi : Palette.textLow,
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

class HymnList extends StatelessWidget {
  const HymnList({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final hymns = state.visibleHymns;
    return ListView(
      padding: const EdgeInsets.fromLTRB(6, 2, 24, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Text(
            'Hymns across the world — Wesley, Reformed, psalms and more.',
            style: AppType.cardBody,
          ),
        ),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 4, right: 4),
            children: [
              _FilterChip(
                label: 'All',
                selected: state.hymnFilter == null,
                onTap: () => state.setHymnFilter(null),
              ),
              for (final t in HymnTradition.values)
                _FilterChip(
                  label: t.label,
                  selected: state.hymnFilter == t,
                  onTap: () => state.setHymnFilter(t),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: TextField(
            onChanged: state.setHymnQuery,
            style: const TextStyle(color: Palette.textHi, fontSize: 15),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon:
                  Icon(Icons.search, size: 19, color: Palette.textLow),
              hintText: 'Search title, first line or author',
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
        ),
        const SizedBox(height: 16),
        if (state.hymnsLoading && hymns.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: Palette.textLow,
                ),
              ),
            ),
          )
        else if (hymns.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30, left: 4),
            child: Text('No hymns match your search.',
                style: AppType.cardBody),
          )
        else
          for (final h in hymns) HymnCard(hymn: h, state: state),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Palette.surfaceStrong : Palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Palette.borderStrong : Palette.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppType.sans,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Palette.textHi : Palette.textMid,
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Saved (readings + hymns)
// ----------------------------------------------------------------------------

class SavedList extends StatelessWidget {
  const SavedList({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final readings = state.savedReadings;
    final hymns = state.savedHymns;

    if (readings.isEmpty && hymns.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 34, color: Palette.textLow),
            const SizedBox(height: 22),
            const _BigTitle('Saved'),
            const SizedBox(height: 14),
            Text(
              'Bookmark a reading or hymn and it\nwill be waiting for you here.',
              textAlign: TextAlign.center,
              style: AppType.cardBody.copyWith(height: 1.5),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(6, 8, 24, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 18),
          child: _BigTitle('Saved'),
        ),
        if (readings.isNotEmpty) ...[
          const _GroupLabel('READINGS'),
          for (final r in readings) ReadingCard(reading: r, state: state),
          const SizedBox(height: 18),
        ],
        if (hymns.isNotEmpty) ...[
          const _GroupLabel('HYMNS'),
          for (final h in hymns) HymnCard(hymn: h, state: state),
        ],
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(text, style: AppType.badge),
    );
  }
}
