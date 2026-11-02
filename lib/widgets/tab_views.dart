import 'package:flutter/material.dart';

import '../auth.dart';
import '../models.dart';
import '../theme.dart';
import '../screens/legal_screen.dart';
import 'bible.dart';
import 'journal.dart';
import 'reading.dart';

const List<double> _grayscale = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Routes a nav index to its content panel. Index 0 (Today) is handled
/// separately by the home layout.
class TabView extends StatelessWidget {
  const TabView({
    super.key,
    required this.index,
    required this.state,
    required this.user,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final int index;
  final AppState state;
  final AppUser? user;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case 1:
        return LibraryView(state: state);
      case 2:
        return BibleView(state: state);
      case 3:
        return _JourneyView(state: state);
      case 4:
        return SavedList(state: state);
      case 5:
        return JournalView(state: state);
      case 6:
        return _ProfileView(
          state: state,
          user: user,
          onSignOut: onSignOut,
          onDeleteAccount: onDeleteAccount,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
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

class _JourneyView extends StatelessWidget {
  const _JourneyView({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: _SectionTitle('Your Journey'),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 22),
          child: Text(
            '${AppState.weeks.length} weeks toward a steadier center. '
            'A new week opens every seven days.',
            style: AppType.cardBody,
          ),
        ),
        for (final w in AppState.weeks) _weekTile(w),
      ],
    );
  }

  Widget _weekTile(WeekInfo w) {
    final locked = state.isLocked(w);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: w.number == state.activeWeek.number
            ? Palette.surfaceStrong
            : Palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: locked ? null : () => state.selectWeek(w),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix(_grayscale),
                    child: Image.asset(
                      w.image,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(width: 64, height: 64, color: Palette.glow),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WEEK ${w.number}',
                        style: AppType.badge.copyWith(
                          color: locked ? Palette.textLow : Palette.textMid,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        w.title,
                        style: TextStyle(
                          fontFamily: AppType.serif,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: locked ? Palette.textLow : Palette.textHi,
                        ),
                      ),
                    ],
                  ),
                ),
                if (locked)
                  Icon(Icons.lock_outline, size: 18, color: Palette.textLow),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({
    required this.state,
    required this.user,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final AppState state;
  final AppUser? user;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label) => Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppType.serif,
            fontSize: 44,
            fontWeight: FontWeight.w500,
            color: Palette.textHi,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: AppType.badge),
      ],
    );

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.surfaceStrong,
                border: Border.all(color: Palette.border),
              ),
              child: (user == null || user!.initials.isEmpty)
                  ? Icon(Icons.person_outline, size: 34, color: Palette.textMid)
                  : Text(
                      user!.initials,
                      style: const TextStyle(
                        fontFamily: AppType.serif,
                        fontSize: 32,
                        fontWeight: FontWeight.w500,
                        color: Palette.textHi,
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            _SectionTitle(user?.name ?? 'You'),
            const SizedBox(height: 8),
            Text(
              user?.subtitle ?? 'Week ${state.activeWeek.number}',
              style: AppType.cardBody,
            ),
            const SizedBox(height: 34),
            // Evenly spread, and never wider than the screen (small phones).
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Row(
                children: [
                  for (final (value, label) in [
                    ('${state.totalSessions}', 'SESSIONS'),
                    ('${state.activeDays}', 'DAYS'),
                    ('${state.streak}', 'STREAK'),
                    (
                      '${state.savedReadings.length + state.savedHymns.length}',
                      'SAVED',
                    ),
                  ])
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: stat(value, label),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 38),
            OutlinedButton(
              onPressed: onSignOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: Palette.textHi,
                side: BorderSide(color: Palette.borderStrong),
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('Sign out'),
            ),
            const SizedBox(height: 26),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              children: [
                TextButton(
                  onPressed: () => openLegal(context, LegalDoc.privacy),
                  style: TextButton.styleFrom(foregroundColor: Palette.textMid),
                  child: const Text('Privacy Policy'),
                ),
                TextButton(
                  onPressed: () => openLegal(context, LegalDoc.terms),
                  style: TextButton.styleFrom(foregroundColor: Palette.textMid),
                  child: const Text('Terms of Service'),
                ),
              ],
            ),
            TextButton(
              onPressed: onDeleteAccount,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE8A598),
              ),
              child: const Text('Delete account'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
