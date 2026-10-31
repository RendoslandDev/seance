import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seance/main.dart';
import 'package:seance/services/content_service.dart';
import 'package:seance/services/video_service.dart';

/// Drives every interactive flow at phone size (narrow layout, bottom nav).
/// Any framework assertion during these steps fails the test.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ContentService.networkEnabled = false;
    VideoService.networkEnabled = false;
    rootBundle.clear();
  });

  Future<void> settleAsync(WidgetTester tester, {int turns = 60}) async {
    for (var i = 0; i < turns; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> waitFor(WidgetTester tester, Finder f, {int tries = 150}) async {
    for (var i = 0; i < tries && f.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(f, findsWidgets);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // A common small Android width, and a typical iPhone.
  for (final size in const [Size(360, 740), Size(390, 844)]) {
    testWidgets('every phone flow runs without framework errors '
        '(${size.width.toInt()}×${size.height.toInt()})', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SeanceApp());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await rootBundle.loadString('assets/data/hymns.json');
        await rootBundle.loadString('assets/data/wesley_1876.json');
        await rootBundle.loadString('assets/data/videos_snapshot.json');
        await rootBundle.loadString('assets/data/bible/kjv.json');
      });

      // Sign-in screen → Terms → back → Begin.
      await tester.tapOnText(find.textRange.ofSubstring('Terms of Service'));
      await waitFor(tester, find.text('1. What séance is'));
      await back(tester);
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();

      // Today: toggle a practice, a future day, the Reflect composer, WEEKS.
      final center = find.text('Center');
      await tester.ensureVisible(center);
      await tester.tap(center);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'A quiet morning.');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WEEKS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finding your Center').last);
      await tester.pumpAndSettle();

      // Library: open a reading, bookmark it, back.
      await tab(tester, Icons.auto_stories_outlined);
      await waitFor(tester, find.text('The Art of Beginning Again'));
      await tester.ensureVisible(find.text('The Art of Beginning Again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('The Art of Beginning Again'));
      await tester.pumpAndSettle();
      await back(tester);

      // Hymns: open No. 1, back, switch books, filter, search.
      await tester.tap(find.text('Hymns'));
      await waitFor(tester, find.text('O for a thousand tongues to sing'));
      await tester.ensureVisible(find.text('O for a thousand tongues to sing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('O for a thousand tongues to sing'));
      await tester.pumpAndSettle();
      await back(tester);
      await tester.fling(
          find.byType(CustomScrollView).first, const Offset(0, 3000), 4000);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hymns of the World'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Methodist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wesley’s Hymns · 1876'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '501');
      await tester.pumpAndSettle();

      // Bible: picker → book → chapter, reference jump, phrase search, result.
      await tab(tester, Icons.menu_book_outlined);
      await waitFor(tester, find.text('John 1'));
      await tester.tap(find.text('John 1').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ruth'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(find.text('Ruth 2'), findsWidgets);
      await tester.enterText(find.byType(TextField), 'ps 23');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Psalms 23'), findsWidgets);
      await tester.enterText(find.byType(TextField), 'love one another');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('JOHN 13').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Next'),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WEB'));
      await settleAsync(tester);

      // Watch: list and category filter (playback needs a real web view).
      await tester.tap(find.text('Watch'));
      await waitFor(tester, find.text('Debates & Apologetics'));
      await tester.tap(find.text('Debates & Apologetics'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read'));
      await tester.pumpAndSettle();

      // Journey, Saved.
      await tab(tester, Icons.self_improvement_outlined);
      await tester.pumpAndSettle();
      await tab(tester, Icons.bookmark_border);
      await tester.pumpAndSettle();

      // Journal: the entry written above, then delete it.
      await tab(tester, Icons.edit_note);
      await tester.pumpAndSettle();
      expect(find.text('A quiet morning.'), findsOneWidget);
      // Entries are deleted with a long press.
      await tester.longPress(find.text('A quiet morning.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('A quiet morning.'), findsNothing);

      // Profile: legal pages, then sign out back to the gate.
      await tab(tester, Icons.person_outline);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Privacy Policy'));
      await waitFor(tester, find.text('The short version'));
      await back(tester);
      await tester.ensureVisible(find.text('Sign out'));
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Begin'), findsOneWidget);
    });
  }
}
