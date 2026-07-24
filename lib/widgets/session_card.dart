import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';

const List<double> _grayscale = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Animated completion control — solid ring + check when done,
/// dotted ring when pending.
class StatusToggle extends StatelessWidget {
  const StatusToggle({super.key, required this.done, required this.onTap});

  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 30,
        height: 30,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: done
              ? Container(
                  key: const ValueKey('done'),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Palette.borderStrong, width: 1.3),
                  ),
                  child: Icon(Icons.check, size: 15, color: Palette.textHi),
                )
              : CustomPaint(
                  key: const ValueKey('pending'),
                  painter: _DottedRing(color: Palette.textLow),
                ),
        ),
      ),
    );
  }
}

class _DottedRing extends CustomPainter {
  _DottedRing({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1;
    const dots = 16;
    const dotR = 1.05;
    for (var i = 0; i < dots; i++) {
      final a = (i / dots) * 2 * math.pi;
      final p = Offset(
        center.dx + radius * math.cos(a),
        center.dy + radius * math.sin(a),
      );
      canvas.drawCircle(p, dotR, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedRing old) => old.color != color;
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.image});
  final String image;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_grayscale),
        child: Image.asset(
          image,
          width: 88,
          height: 66,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 88,
            height: 66,
            color: Palette.glow,
          ),
        ),
      ),
    );
  }
}

class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.onToggle,
    this.onReflect,
  });

  final Session session;
  final VoidCallback onToggle;

  /// When non-null, shows a Reflect action that writes a journal entry for
  /// this session. Has its own gesture so it never toggles completion.
  final VoidCallback? onReflect;

  @override
  Widget build(BuildContext context) {
    final badge = Text('${session.minutes} MIN', style: AppType.badge);

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 52, child: badge),
        Expanded(
          child: Text(
            session.title,
            style: AppType.cardTitle.copyWith(
              color: session.done ? Palette.textMid : Palette.textHi,
            ),
          ),
        ),
        if (onReflect != null) ...[
          GestureDetector(
            onTap: onReflect,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.edit_outlined, size: 19, color: Palette.textLow),
            ),
          ),
          const SizedBox(width: 6),
        ],
        StatusToggle(done: session.done, onTap: onToggle),
      ],
    );

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
          onTap: onToggle,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: session.expanded ? 18 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                if (session.expanded) ...[
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (session.image != null) ...[
                        _Thumb(image: session.image!),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            session.description!,
                            style: AppType.cardBody,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
