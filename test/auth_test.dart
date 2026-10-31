import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seance/auth.dart';
import 'package:seance/screens/login_screen.dart';

void main() {
  group('normalizePhone', () {
    test('Ghana numbers with the trunk 0 drop it', () {
      expect(normalizePhone('024 123 4567', '+233'), '+233241234567');
      expect(normalizePhone('0241234567', '+233'), '+233241234567');
      expect(normalizePhone('24-123-4567', '+233'), '+233241234567');
    });

    test('a typed +number or 00 prefix overrides the picked country', () {
      expect(normalizePhone('+44 7700 900123', '+233'), '+447700900123');
      expect(normalizePhone('0044 7700 900123', '+233'), '+447700900123');
    });

    test('too short or empty is rejected', () {
      expect(normalizePhone('', '+233'), isNull);
      expect(normalizePhone('12', '+233'), isNull);
      expect(normalizePhone('+1234567890123456', '+233'), isNull);
    });
  });

  group('phone sign-in screen', () {
    setUp(() => AuthController.cloudEnabled = true);
    tearDown(() => AuthController.cloudEnabled = false);

    Future<void> pumpLogin(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = AuthController();
      addTearDown(auth.dispose);
      await tester.pumpWidget(MaterialApp(home: LoginScreen(auth: auth)));
      await tester.pump();
    }

    testWidgets('asks only for a phone number, Ghana by default',
        (tester) async {
      await pumpLogin(tester);
      expect(find.text('Your phone number'), findsOneWidget);
      expect(find.text('+233'), findsOneWidget);
      expect(find.text('Send code'), findsOneWidget);
      expect(find.textContaining('Google'), findsNothing);
      expect(find.textContaining('email'), findsNothing);
      expect(find.textContaining('guest'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('an incomplete number is caught before any SMS is sent',
        (tester) async {
      await pumpLogin(tester);
      await tester.enterText(find.byType(TextField), '24');
      await tester.tap(find.text('Send code'));
      await tester.pump();
      expect(find.text('Enter your full phone number.'), findsOneWidget);
      expect(find.text('Enter the code'), findsNothing);
    });
  });

  test('guests and phone-only accounts are never greeted by a fake name', () {
    final legacyGuest = AppUser.fromJson(
        {'uid': 'guest', 'name': 'Guest', 'provider': 'Guest'});
    expect(legacyGuest.firstName, isNull);
    expect(legacyGuest.initials, '');
    const phoneOnly =
        AppUser(uid: 'u1', phone: '+233241234567', provider: 'Phone');
    expect(phoneOnly.firstName, isNull);
    expect(phoneOnly.name, '+233241234567');
    const named = AppUser(
        uid: 'u2', displayName: 'Ama Mensah', phone: '+233200000000',
        provider: 'Phone');
    expect(named.firstName, 'Ama');
  });
}
