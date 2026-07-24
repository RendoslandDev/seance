import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';
import 'session_card.dart';

class Timeline extends StatelessWidget {
  const Timeline({
    super.key,
    required this.day,
    required this.onToggle,
    this.onReflect,
    this.padding = const EdgeInsets.fromLTRB(8, 4, 24, 40),
    this.shrinkWrap = false,
    this.physics,
  });

  final DaySchedule day;
  final void Function(Session) onToggle;
  final void Function(Session)? onReflect;
  final EdgeInsets padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics ?? const BouncingScrollPhysics(),
      children: [
        for (final part in day.parts) ...[
          _SectionHeader(label: part.label, range: part.range),
          for (final s in part.sessions)
            SessionCard(
              session: s,
              onToggle: () => onToggle(s),
              onReflect: onReflect == null ? null : () => onReflect!(s),
            ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.range});

  final String label;
  final String range;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label, style: AppType.sectionLabel),
          const Spacer(),
          Text(range, style: AppType.sectionRange),
        ],
      ),
    );
  }
}
