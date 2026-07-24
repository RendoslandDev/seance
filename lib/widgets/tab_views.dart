import 'package:flutter/material.dart';

import '../auth.dart';
import '../models.dart';
import '../theme.dart';
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
  });

  final int index;
  final AppState state;
  final AppUser? user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case 1:
        return LibraryView(state: state);
      case 2:
        return _JourneyView(state: state);
      case 3:
        return SavedList(state: state);
      case 4:
        return JournalView(state: state);
      case 5:
        return _ProfileView(state: state, user: user, onSignOut: onSignOut);
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
            'Eight weeks toward a steadier center.',
            style: AppType.cardBody,
          ),
        ),
        for (final w in AppState.weeks)
          Container(
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
                onTap: w.locked ? null : () => state.selectWeek(w),
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
                            errorBuilder: (_, _, _) => Container(
                              width: 64,
                              height: 64,
                              color: Palette.glow,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('WEEK ${w.number}',
                                style: AppType.badge.copyWith(
                                  color: w.locked
                                      ? Palette.textLow
                                      : Palette.textMid,
                                )),
                            const SizedBox(height: 4),
                            Text(
                              w.title,
                              style: TextStyle(
                                fontFamily: AppType.serif,
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color:
                                    w.locked ? Palette.textLow : Palette.textHi,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (w.locked)
                        Icon(Icons.lock_outline,
                            size: 18, color: Palette.textLow),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({
    required this.state,
    required this.user,
    required this.onSignOut,
  });

  final AppState state;
  final AppUser? user;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final sessionsDone =
        state.days.fold<int>(0, (sum, d) => sum + d.completed);
    final daysActive = state.days.where((d) => d.hasActivity).length;

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
              child: user == null
                  ? Icon(Icons.person_outline,
                      size: 34, color: Palette.textMid)
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                stat('$sessionsDone', 'SESSIONS'),
                const SizedBox(width: 40),
                stat('${state.savedReadings.length + state.savedHymns.length}',
                    'SAVED'),
                const SizedBox(width: 40),
                stat('$daysActive', 'DAYS'),
              ],
            ),
            const SizedBox(height: 38),
            OutlinedButton(
              onPressed: onSignOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: Palette.textHi,
                side: BorderSide(color: Palette.borderStrong),
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
