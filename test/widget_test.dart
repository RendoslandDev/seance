import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seance/main.dart';
import 'package:seance/services/content_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Keep tests deterministic + leak-free: no live network fetch.
    ContentService.networkEnabled = false;
    // Drop any asset future cached (possibly half-resolved) by a prior test.
    rootBundle.clear();
  });

  Future<void> bootLoggedOut(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SeanceApp());
    await tester.pumpAndSettle();
    // Warm the bundled-hymn asset cache in this test's real-async context so
    // the app's later (pump-driven) read resolves immediately.
    await tester.runAsync(
      () => rootBundle.loadString('assets/data/hymns.json'),
    );
  }

  Future<void> signIn(WidgetTester tester) async {
    await bootLoggedOut(tester);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts at the login gate with Google + social options',
      (tester) async {
    await bootLoggedOut(tester);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('or use a social handle'), findsOneWidget);
    expect(find.text('TODAY'), findsNothing);
  });

  testWidgets('signing in with Google reveals today', (tester) async {
    await signIn(tester);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Align'), findsOneWidget);
    expect(find.text('Finding your Center'), findsOneWidget);
  });

  testWidgets('a session card toggles after sign-in', (tester) async {
    await signIn(tester);
    final center = find.text('Center');
    expect(center, findsOneWidget);
    await tester.ensureVisible(center);
    await tester.tap(center);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Center'), findsOneWidget);
  });

  testWidgets('WEEKS panel opens after sign-in', (tester) async {
    await signIn(tester);
    await tester.tap(find.text('WEEKS'));
    await tester.pumpAndSettle();
    expect(find.text('The Programme'), findsOneWidget);
  });

  // The Readings list shows a loading spinner while the (stubbed) network fetch
  // is in flight, so pumpAndSettle won't settle. And the bundled hymn asset is
  // real I/O that only advances inside runAsync — so interleave runAsync turns
  // with pumps until the list has populated.
  Future<void> pumpUntil(WidgetTester tester, Finder f, {int tries = 40}) async {
    for (var i = 0; i < tries; i++) {
      if (f.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  final firstHymn = find.text('O for a Thousand Tongues to Sing');

  Future<void> openHymns(WidgetTester tester) async {
    await signIn(tester);
    await tester.tap(find.byIcon(Icons.auto_stories_outlined));
    await tester.pump();
    await tester.tap(find.text('Hymns'));
    await tester.pump();
    await pumpUntil(tester, firstHymn);
  }

  testWidgets('Library switches to Hymns and lists bundled hymns',
      (tester) async {
    await openHymns(tester);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Readings'), findsOneWidget);
    expect(firstHymn, findsOneWidget);
  });

  testWidgets('tradition filter narrows the hymn list', (tester) async {
    await openHymns(tester);
    expect(firstHymn, findsOneWidget);
    await tester.tap(find.text('Psalms'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Methodist hymn gone; first psalm now at the top.
    expect(firstHymn, findsNothing);
    expect(find.text('All People That on Earth Do Dwell'), findsOneWidget);
  });

  testWidgets('opening a hymn shows its verses', (tester) async {
    await openHymns(tester);
    await tester.tap(firstHymn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('O for a thousand tongues to sing'),
        findsWidgets);
    expect(find.text('METHODIST'), findsWidgets);
  });
}
