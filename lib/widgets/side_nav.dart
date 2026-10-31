import 'package:flutter/material.dart';
import '../theme.dart';

const List<IconData> kNavIcons = [
  Icons.home_filled,
  Icons.auto_stories_outlined,
  Icons.menu_book_outlined,
  Icons.self_improvement_outlined,
  Icons.bookmark_border,
  Icons.edit_note,
  Icons.person_outline,
];

const List<String> kNavLabels = [
  'Today',
  'Library',
  'Bible',
  'Journey',
  'Saved',
  'Journal',
  'Profile',
];

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Palette.surfaceStrong : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? Palette.textHi : Palette.textLow,
          ),
        ),
      ),
    );
  }
}

/// Vertical rail for wide layouts.
class SideNav extends StatelessWidget {
  const SideNav({super.key, required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < kNavIcons.length; i++) ...[
            _NavButton(
              icon: kNavIcons[i],
              label: kNavLabels[i],
              selected: index == i,
              onTap: () => onSelect(i),
            ),
            if (i != kNavIcons.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

/// Horizontal bar for phone layouts.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
        left: 12,
        right: 12,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Palette.border)),
        color: Palette.bg0.withValues(alpha: 0.6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < kNavIcons.length; i++)
            _NavButton(
              icon: kNavIcons[i],
              label: kNavLabels[i],
              selected: index == i,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}
