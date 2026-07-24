import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';

const List<double> _grayscale = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

class HeroCard extends StatefulWidget {
  const HeroCard({
    super.key,
    required this.week,
    required this.greeting,
    required this.onBegin,
    this.titleSize = 58,
  });

  final WeekInfo week;
  final String greeting;
  final VoidCallback onBegin;
  final double titleSize;

  @override
  State<HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<HeroCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final w = widget.week;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onBegin,
      child: AnimatedScale(
        scale: _pressed ? 0.99 : 1.0,
        duration: const Duration(milliseconds: 160),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photograph
              ColorFiltered(
                colorFilter: const ColorFilter.matrix(_grayscale),
                child: Image.asset(
                  w.image,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, _, _) => Container(color: Palette.glow),
                ),
              ),
              // Legibility scrims
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33000000),
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0xCC000000),
                    ],
                    stops: [0.0, 0.22, 0.5, 1.0],
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.greeting,
                      style: TextStyle(
                        fontFamily: AppType.sans,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.92),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Pill(text: 'WELCOME • 2 MIN'),
                    const Spacer(),
                    Text(
                      'WEEK ${w.number}',
                      style: TextStyle(
                        fontFamily: AppType.sans,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      w.title,
                      style: AppType.display.copyWith(fontSize: widget.titleSize),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppType.sans,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.95),
          letterSpacing: 1.3,
        ),
      ),
    );
  }
}
