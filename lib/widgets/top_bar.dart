import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';

class SeanceLogo extends StatelessWidget {
  const SeanceLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Text('séance', style: AppType.logo);
  }
}

class WeeksButton extends StatelessWidget {
  const WeeksButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Palette.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 14, color: Palette.textMid),
              const SizedBox(width: 9),
              Text(
                'WEEKS',
                style: TextStyle(
                  fontFamily: AppType.sans,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Palette.textHi,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DateStrip extends StatelessWidget {
  const DateStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.onSelect,
  });

  final List<DaySchedule> days;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < days.length; i++)
          _DateChip(
            day: days[i],
            selected: i == selected,
            onTap: () => onSelect(i),
          ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final DaySchedule day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showDot = day.hasActivity && !selected;
    final label = (selected && day.isToday) ? 'TODAY' : '${day.dayNumber}';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 20 : 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selected ? Palette.surfaceStrong : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppType.sans,
                fontSize: selected && day.isToday ? 13 : 17,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: selected && day.isToday ? 1.4 : 0,
                color: selected
                    ? Palette.textHi
                    : (day.isToday ? Palette.textMid : Palette.textLow),
              ),
            ),
            if (showDot)
              Positioned(
                top: -7,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Palette.textHi,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
