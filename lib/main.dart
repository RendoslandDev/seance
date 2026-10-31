import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth.dart';
import 'models.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'services/progress_store.dart';
import 'services/widget_service.dart';
import 'theme.dart';
import 'widgets/account.dart';
import 'widgets/hero_card.dart';
import 'widgets/journal.dart';
import 'widgets/side_nav.dart';
import 'widgets/tab_views.dart';
import 'widgets/timeline.dart';
import 'widgets/top_bar.dart';
import 'widgets/weeks_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  // Accounts + live sync (no-op when this build carries no Firebase config).
  await AuthController.initFirebase();
  // Wire up the home-screen widget bridge + weekly-reading notifications.
  await WidgetService.init();
  await NotificationService.init();
  runApp(const SeanceApp());
}

class SeanceApp extends StatelessWidget {
  const SeanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'séance',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: Palette.bg0,
        textTheme: base.textTheme.apply(
          fontFamily: AppType.sans,
          bodyColor: Palette.textHi,
          displayColor: Palette.textHi,
        ),
        splashFactory: InkRipple.splashFactory,
        highlightColor: Colors.white.withValues(alpha: 0.02),
        splashColor: Colors.white.withValues(alpha: 0.03),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Palette.textHi,
        ),
        colorScheme: base.colorScheme.copyWith(
          surface: Palette.bg0,
          primary: Palette.textHi,
        ),
      ),
      home: const SeanceRoot(),
    );
  }
}

/// Owns long-lived state and gates the app behind sign-in.
class SeanceRoot extends StatefulWidget {
  const SeanceRoot({super.key});

  @override
  State<SeanceRoot> createState() => _SeanceRootState();
}

class _SeanceRootState extends State<SeanceRoot> {
  final AuthController _auth = AuthController();
  final AppState _state = AppState();

  String? _attachedUid;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_syncStore);
    _auth.restore();
  }

  /// Point [_state] at the signed-in member's data whenever the member changes.
  void _syncStore() {
    final user = _auth.user;
    if (user?.uid == _attachedUid) return;
    _attachedUid = user?.uid;
    if (user == null) {
      _state.detach();
    } else if (user.isGuest || !AuthController.cloudEnabled) {
      _state.attach(LocalProgressStore());
    } else {
      _state.attach(CloudProgressStore(user.uid));
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_syncStore);
    _auth.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _auth,
      builder: (context, _) {
        final Widget child;
        if (_auth.loading) {
          child = const _Splash();
        } else if (!_auth.signedIn) {
          child = LoginScreen(key: const ValueKey('login'), auth: _auth);
        } else {
          child = HomeScreen(
            key: const ValueKey('home'),
            state: _state,
            auth: _auth,
          );
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: child,
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bg0,
      body: Center(child: Text('séance', style: AppType.logo)),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state, required this.auth});

  final AppState state;
  final AuthController auth;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppState get _state => widget.state;

  @override
  void initState() {
    super.initState();
    // Pull real-world readings once; silently keeps the template on failure.
    // Refresh the widget + reminder once live content arrives.
    _state.loadReadings().then((_) => _syncWeeklyReading());
    // Load the bundled hymn library (offline-safe asset).
    _state.loadHymns();
    // Publish an immediate value (seed/offline) and arm the weekly reminder.
    _syncWeeklyReading();
    NotificationService.requestPermissions();
  }

  /// Push the current week's reading to the home-screen widget and (re)schedule
  /// the Monday-morning reminder for it.
  void _syncWeeklyReading() {
    final reading = _state.weeklyReading;
    WidgetService.pushWeeklyReading(reading);
    NotificationService.scheduleWeeklyReading(reading);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    final part = h < 12 ? 'morning' : (h < 18 ? 'afternoon' : 'evening');
    final user = widget.auth.user;
    final first = user?.firstName;
    final name = first == null ? '' : ', $first';
    return "Let's begin your $part$name";
  }

  void _toggle(Session s) {
    if (_state.toggle(s)) return;
    final d = _state.day;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.bg1,
          content: Text(
            'This practice opens on ${d.weekday} ${d.dayNumber}.',
            style: const TextStyle(color: Palette.textHi),
          ),
        ),
      );
  }

  void _begin() {
    final w = _state.activeWeek;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.bg1,
          content: Text(
            'Beginning Week ${w.number} · ${w.title}',
            style: const TextStyle(color: Palette.textHi),
          ),
        ),
      );
  }

  void _reflect(Session s) => showJournalComposer(
    context,
    _state,
    sessionTitle: s.title,
    dayNumber: _state.day.dayNumber,
  );

  Widget _tab(int index) => TabView(
    index: index,
    state: _state,
    user: widget.auth.user,
    onSignOut: widget.auth.signOut,
    onDeleteAccount: () => deleteAccountFlow(context, widget.auth, _state),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bg0,
      body: Stack(
        children: [
          const Positioned.fill(child: _Backdrop()),
          SafeArea(
            child: AnimatedBuilder(
              animation: _state,
              builder: (context, _) {
                return LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 900;
                    return wide ? _buildWide() : _buildNarrow();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Wide (tablet / desktop) ----------------

  Widget _buildWide() {
    final showHero = _state.nav == 0;
    return Column(
      children: [
        SizedBox(
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Row(
                  children: [
                    const SeanceLogo(),
                    const Spacer(),
                    WeeksButton(onTap: () => showWeeksPanel(context, _state)),
                  ],
                ),
              ),
              DateStrip(
                days: _state.days,
                selected: _state.selectedDay,
                onSelect: _state.selectDay,
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 30, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SideNav(index: _state.nav, onSelect: _state.selectNav),
                const SizedBox(width: 18),
                Expanded(
                  flex: 5,
                  child: _state.nav == 0
                      ? Timeline(
                          day: _state.day,
                          onToggle: _toggle,
                          onReflect: _reflect,
                        )
                      : _tab(_state.nav),
                ),
                if (showHero) ...[
                  const SizedBox(width: 26),
                  Expanded(
                    flex: 4,
                    child: HeroCard(
                      week: _state.activeWeek,
                      greeting: _greeting,
                      onBegin: _begin,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- Narrow (phone) ----------------

  Widget _buildNarrow() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Row(
            children: [
              const SeanceLogo(),
              const Spacer(),
              WeeksButton(onTap: () => showWeeksPanel(context, _state)),
            ],
          ),
        ),
        if (_state.nav == 0)
          SizedBox(
            height: 56,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: DateStrip(
                  days: _state.days,
                  selected: _state.selectedDay,
                  onSelect: _state.selectDay,
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Expanded(child: _narrowBody()),
        BottomNav(index: _state.nav, onSelect: _state.selectNav),
      ],
    );
  }

  Widget _narrowBody() {
    if (_state.nav != 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _tab(_state.nav),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        SizedBox(
          height: 440,
          child: HeroCard(
            week: _state.activeWeek,
            greeting: _greeting,
            onBegin: _begin,
            titleSize: 46,
          ),
        ),
        const SizedBox(height: 24),
        Timeline(
          day: _state.day,
          onToggle: _toggle,
          onReflect: _reflect,
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        ),
      ],
    );
  }
}

/// Soft warm vignette behind everything.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Palette.bg1, Palette.bg0],
              ),
            ),
          ),
        ),
        Positioned(
          top: -260,
          left: 0,
          right: 0,
          child: Container(
            height: 620,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 0.9,
                colors: [Palette.glow, Color(0x00000000)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
