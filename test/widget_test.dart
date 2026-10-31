import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seance/main.dart';
import 'package:seance/services/content_service.dart';
import 'package:seance/services/video_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Keep tests deterministic + leak-free: no live network fetch.
    ContentService.networkEnabled = false;
    VideoService.networkEnabled = false;
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
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/data/hymns.json');
      await rootBundle.loadString('assets/data/wesley_1876.json');
    });
  }

  Future<void> signIn(WidgetTester tester) async {
    await bootLoggedOut(tester);
    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
  }

  testWidgets('without Firebase config, the gate offers on-device mode only',
      (tester) async {
    await bootLoggedOut(tester);
    expect(find.text('Begin'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('TODAY'), findsNothing);
  });

  testWidgets('entering reveals today with real dates', (tester) async {
    await signIn(tester);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Rendosland'), findsOneWidget);
    expect(find.text('Finding your Center'), findsOneWidget);
    // The strip shows this week's real day-of-month numbers.
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final other = monday.day == now.day
        ? DateTime(monday.year, monday.month, monday.day + 1)
        : monday;
    expect(find.text('${other.day}'), findsWidgets);
  });

  testWidgets('completing a practice persists across restarts',
      (tester) async {
    await signIn(tester);
    final center = find.text('Center');
    await tester.ensureVisible(center);
    await tester.tap(center);
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('seance_progress'), contains('Center'));
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

  // The full Wesley book opens by default; No. 1 heads Part I.
  final wesleyOne = find.text('O for a thousand tongues to sing');
  final curatedFirst = find.text('O for a Thousand Tongues to Sing');

  Future<void> openHymns(WidgetTester tester) async {
    await signIn(tester);
    await tester.tap(find.byIcon(Icons.auto_stories_outlined));
    await tester.pump();
    await tester.tap(find.text('Hymns'));
    await tester.pump();
    await pumpUntil(tester, wesleyOne);
  }

  testWidgets('Hymns opens on the complete Wesley hymn book', (tester) async {
    await openHymns(tester);
    expect(find.text('Library'), findsOneWidget);
    expect(wesleyOne, findsOneWidget);
    expect(find.textContaining('the complete book, 1,026 hymns'), findsOneWidget);
    expect(find.text('Exhorting Sinners to return to God'), findsOneWidget);
  });

  testWidgets('searching by number finds that hymn', (tester) async {
    await openHymns(tester);
    await tester.enterText(find.byType(TextField), '1026');
    await tester.pump();
    expect(wesleyOne, findsNothing);
    expect(find.text('1026'), findsWidgets);
  });

  testWidgets('tradition filter narrows the curated selection',
      (tester) async {
    await openHymns(tester);
    await tester.tap(find.text('Hymns of the World'));
    await tester.pump();
    expect(curatedFirst, findsOneWidget);
    await tester.tap(find.text('Psalms'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Methodist hymn gone; first psalm now at the top.
    expect(curatedFirst, findsNothing);
    expect(find.text('All People That on Earth Do Dwell'), findsOneWidget);
  });

  testWidgets('opening a hymn shows its verses', (tester) async {
    await openHymns(tester);
    await tester.tap(wesleyOne);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('My great Redeemer\'s praise'), findsWidgets);
    expect(find.text('No. 1'), findsWidgets);
  });

  testWidgets('Bible tab opens the KJV at John 1 and lists videos',
      (tester) async {
    await signIn(tester);
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump();
    final heading = find.text('John 1');
    for (var i = 0; i < 100 && heading.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    expect(heading, findsWidgets);
    expect(find.text('KJV'), findsOneWidget);

    await tester.tap(find.text('Watch'));
    await tester.pump();
    final debates = find.text('Debates & Apologetics');
    for (var i = 0; i < 60 && debates.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(debates, findsOneWidget);
    expect(find.textContaining('Offline'), findsOneWidget);
  });

  testWidgets('Profile links the legal documents and deletes the account',
      (tester) async {
    await signIn(tester);
    // Complete a practice so there is data to erase.
    final center = find.text('Center');
    await tester.ensureVisible(center);
    await tester.tap(center);
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('seance_progress'), contains('Center'));

    await tester.tap(find.byIcon(Icons.person_outline).last);
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);

    // The policy opens in-app from the bundled Markdown.
    await tester.tap(find.text('Privacy Policy'));
    await tester.pump();
    for (var i = 0; i < 40 && find.text('The short version').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.text('The short version'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Delete account'));
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    // Back at the gate, with nothing left on the device.
    expect(find.text('Begin'), findsOneWidget);
    expect(prefs.getString('seance_progress') ?? '', isNot(contains('Center')));
    expect(prefs.getString('seance_user'), isNull);
  });
}
