import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

class HymnScreen extends StatelessWidget {
  const HymnScreen({super.key, required this.hymn, required this.state});

  final Hymn hymn;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bg0,
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final saved = state.isHymnSaved(hymn);
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Header(hymn: hymn, saved: saved, state: state),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: _MetaRow(hymn: hymn),
                ),
              ),
              SliverList.builder(
                itemCount: hymn.verses.length,
                itemBuilder: (context, i) => _Verse(
                  number: i + 1,
                  text: hymn.verses[i],
                  refrain: hymn.refrain,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 56),
                  child: Text(
                    '${hymn.source} · ${hymn.author}'
                    '${hymn.year != null ? ' · ${hymn.year}' : ''}',
                    style: AppType.badge,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.hymn, required this.saved, required this.state});

  final Hymn hymn;
  final bool saved;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Palette.glow, Palette.bg1, Palette.bg0],
              ),
            ),
          ),
          Positioned(
            right: -24,
            top: 40,
            child: Icon(
              Icons.music_note,
              size: 220,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _RoundButton(
                    icon: saved ? Icons.bookmark : Icons.bookmark_border,
                    onTap: () => state.toggleHymnSaved(hymn),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TraditionBadge(hymn.tradition),
                const SizedBox(height: 12),
                Text(
                  hymn.title,
                  style: const TextStyle(
                    fontFamily: AppType.serif,
                    fontSize: 34,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.04,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hymn.author,
                  style: AppType.cardBody.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TraditionBadge extends StatelessWidget {
  const _TraditionBadge(this.tradition);
  final HymnTradition tradition;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        tradition.label.toUpperCase(),
        style: AppType.badge.copyWith(
          color: Colors.white.withValues(alpha: 0.95),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.hymn});
  final Hymn hymn;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      if (hymn.tune != null) 'Tune · ${hymn.tune}',
      if (hymn.meter != null) 'Meter · ${hymn.meter}',
      if (hymn.scripture != null) hymn.scripture!,
      if (hymn.hymnalRef != null) hymn.hymnalRef!,
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Palette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.border),
            ),
            child: Text(
              c,
              style: TextStyle(
                fontFamily: AppType.sans,
                fontSize: 12.5,
                color: Palette.textMid,
                letterSpacing: 0.2,
              ),
            ),
          ),
      ],
    );
  }
}

class _Verse extends StatelessWidget {
  const _Verse({required this.number, required this.text, this.refrain});

  final int number;
  final String text;
  final String? refrain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontFamily: AppType.serif,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Palette.textLow,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontFamily: AppType.sans,
                    fontSize: 17,
                    height: 1.6,
                    color: Palette.textHi,
                  ),
                ),
              ),
            ],
          ),
          if (refrain != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 12, 0, 4),
              child: Text(
                refrain!,
                style: TextStyle(
                  fontFamily: AppType.sans,
                  fontSize: 16,
                  height: 1.55,
                  fontStyle: FontStyle.italic,
                  color: Palette.textMid,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.32),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
