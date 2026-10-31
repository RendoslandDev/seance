import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';

const List<double> _grayscale = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

Future<void> showWeeksPanel(BuildContext context, AppState state) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Palette.bg1,
    isScrollControlled: true,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 16),
                child: Text(
                  'The Programme',
                  style: TextStyle(
                    fontFamily: AppType.serif,
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: Palette.textHi,
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: AppState.weeks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final w = AppState.weeks[i];
                    final active = w.number == state.activeWeek.number;
                    final locked = state.isLocked(w);
                    return _WeekRow(
                      week: w,
                      active: active,
                      locked: locked,
                      onTap: () {
                        if (!locked) {
                          state.selectWeek(w);
                          Navigator.of(ctx).pop();
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.week,
    required this.active,
    required this.locked,
    required this.onTap,
  });

  final WeekInfo week;
  final bool active;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Palette.surfaceStrong : Palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(_grayscale),
                  child: Image.asset(
                    week.image,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(width: 56, height: 56, color: Palette.glow),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEEK ${week.number}',
                      style: AppType.badge.copyWith(
                        color: locked ? Palette.textLow : Palette.textMid,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      week.title,
                      style: TextStyle(
                        fontFamily: AppType.serif,
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                        color: locked ? Palette.textLow : Palette.textHi,
                      ),
                    ),
                  ],
                ),
              ),
              if (locked)
                Icon(Icons.lock_outline, size: 18, color: Palette.textLow)
              else if (active)
                Icon(Icons.check_circle, size: 20, color: Palette.textHi),
            ],
          ),
        ),
      ),
    );
  }
}
