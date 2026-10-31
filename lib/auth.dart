import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

/// The signed-in member: a phone-number account, or (only in builds without
/// Firebase config) an on-device guest.
class AppUser {
  final String uid;

  /// A real name when the account has one; phone accounts usually don't.
  final String? displayName;
  final String? phone;
  final String provider; // Phone · Guest (older accounts: Google · Email)

  const AppUser({
    required this.uid,
    this.displayName,
    this.phone,
    required this.provider,
  });

  bool get isGuest => provider == 'Guest';

  /// What to call the member on screen.
  String get name =>
      isGuest ? 'Guest' : (displayName ?? phone ?? 'You');

  /// First name for greetings, or null when we only know a phone number
  /// (or it's an on-device session, which older versions saved as "Guest").
  String? get firstName =>
      isGuest ? null : displayName?.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final source = isGuest ? '' : (displayName?.trim() ?? '');
    return source.isEmpty ? '' : source[0].toUpperCase();
  }

  String get subtitle => isGuest
      ? 'Saved on this device'
      : (provider == 'Phone'
            ? 'Signed in with your phone number'
            : 'Signed in with $provider');

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': displayName,
    'phone': phone,
    'provider': provider,
  };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    uid: j['uid'] as String? ?? 'guest',
    displayName: j['name'] as String?,
    phone: j['phone'] as String?,
    provider: j['provider'] as String? ?? 'Guest',
  );

  factory AppUser.fromFirebase(User u) {
    final ids = u.providerData.map((p) => p.providerId).toSet();
    final name = u.displayName?.trim();
    return AppUser(
      uid: u.uid,
      displayName: (name?.isNotEmpty ?? false) ? name : null,
      phone: u.phoneNumber,
      provider: ids.contains('phone')
          ? 'Phone'
          : (ids.contains('google.com') ? 'Google' : 'Email'),
    );
  }
}

/// Turns what someone typed into an E.164 number (`+233241234567`), or null
/// if it can't be one. [dialCode] is used unless the input starts with `+`;
/// a national trunk `0` (as in Ghana's `024…`) is dropped.
String? normalizePhone(String input, String dialCode) {
  final raw = input.trim();
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  final String e164;
  if (raw.startsWith('+')) {
    e164 = '+$digits';
  } else if (digits.startsWith('00')) {
    e164 = '+${digits.substring(2)}';
  } else {
    if (digits.startsWith('0')) digits = digits.substring(1);
    e164 = '$dialCode$digits';
  }
  // E.164: a country code plus subscriber number, 8–15 digits in all.
  return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(e164) ? e164 : null;
}

/// Holds the session. Members sign in (and sign up — it's the same step) with
/// their phone number and a one-time SMS code. Firebase restores the session
/// on later launches.
class AuthController extends ChangeNotifier {
  AppUser? _user;
  bool _loading = true;
  bool _busy = false;
  bool _disposed = false;
  String? _error;
  StreamSubscription<User?>? _sub;

  // Phone verification in progress.
  String? _pendingPhone;
  ConfirmationResult? _webConfirmation; // web
  String? _verificationId; // Android / iOS
  int? _resendToken;
  DateTime? _codeSentAt;

  AppUser? get user => _user;
  bool get signedIn => _user != null;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;

  /// The number a code was sent to, while waiting for it to be entered.
  String? get pendingPhone => _pendingPhone;
  bool get awaitingCode => _pendingPhone != null;
  DateTime? get codeSentAt => _codeSentAt;

  /// True once Firebase initialised with real project values.
  static bool cloudEnabled = false;

  static const _guestKey = 'seance_user';
  static const resendAfter = Duration(seconds: 60);

  /// Initialise Firebase if this build carries project config. Safe to call
  /// when it doesn't: the app then runs in an on-device mode for development.
  static Future<void> initFirebase() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options.apiKey.isEmpty || options.appId.isEmpty) return;
    try {
      await Firebase.initializeApp(options: options);
      cloudEnabled = true;
    } catch (e) {
      debugPrint('Firebase unavailable, running on-device only: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }

  /// Notify only while alive — restore/sign-in can resolve after disposal.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
    if (!cloudEnabled) {
      // Development builds without Firebase: an on-device session.
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_guestKey);
        if (raw != null) {
          final u = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          if (u.isGuest) _user = u;
        }
      } catch (_) {
        // corrupt / unavailable store → start signed out
      }
      _loading = false;
      _notify();
      return;
    }

    _sub = FirebaseAuth.instance.authStateChanges().listen((u) {
      _user = u == null ? null : AppUser.fromFirebase(u);
      if (u != null) _clearPending();
      _loading = false;
      _notify();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    _notify();
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      debugPrint('Phone sign-in failed: ${e.code} ${e.message}');
      _error = _describe(e);
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
      debugPrint('Sign-in failed: $e');
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Step 1: text a one-time code to [phone] (E.164, e.g. +233241234567).
  /// New numbers get an account automatically once the code is confirmed.
  Future<void> sendCode(String phone, {bool resend = false}) => _run(() async {
    if (kIsWeb) {
      // Firebase shows an invisible reCAPTCHA check before sending.
      _webConfirmation = await FirebaseAuth.instance.signInWithPhoneNumber(
        phone,
      );
      _codeSent(phone);
      return;
    }
    final sent = Completer<void>();
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: resend ? _resendToken : null,
      timeout: const Duration(seconds: 60),
      // Android can read the SMS itself and finish without typing the code.
      verificationCompleted: (credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        if (!sent.isCompleted) sent.complete();
      },
      verificationFailed: (e) {
        if (!sent.isCompleted) sent.completeError(e);
      },
      codeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        _codeSent(phone);
        if (!sent.isCompleted) sent.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
    await sent.future;
  });

  void _codeSent(String phone) {
    _pendingPhone = phone;
    _codeSentAt = DateTime.now();
  }

  /// Step 2: confirm the 6-digit code from the SMS.
  Future<void> verifyCode(String code) => _run(() async {
    final sms = code.replaceAll(RegExp(r'\D'), '');
    if (sms.length != 6) {
      throw FirebaseAuthException(code: 'invalid-verification-code');
    }
    if (kIsWeb) {
      final c = _webConfirmation;
      if (c == null) throw FirebaseAuthException(code: 'session-expired');
      await c.confirm(sms);
    } else {
      final id = _verificationId;
      if (id == null) throw FirebaseAuthException(code: 'session-expired');
      await FirebaseAuth.instance.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: id, smsCode: sms),
      );
    }
  });

  /// Go back and enter a different number.
  void changeNumber() {
    _clearPending();
    _error = null;
    _notify();
  }

  void _clearPending() {
    _pendingPhone = null;
    _webConfirmation = null;
    _verificationId = null;
    _codeSentAt = null;
  }

  /// Development builds without Firebase only.
  Future<void> continueOnDevice() async {
    _user = const AppUser(uid: 'guest', provider: 'Guest');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_guestKey, jsonEncode(_user!.toJson()));
    } catch (_) {
      /* best effort */
    }
    _notify();
  }

  Future<void> signOut() async {
    final wasGuest = _user?.isGuest ?? true;
    _user = null;
    _clearPending();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestKey);
    } catch (_) {}
    if (!wasGuest && cloudEnabled) await FirebaseAuth.instance.signOut();
    _notify();
  }

  /// Delete the signed-in account itself (call after its data is erased).
  /// Returns false when Firebase needs a fresh sign-in first — confirm the
  /// number again with [sendCode] / [verifyCode], then call this again.
  Future<bool> deleteSignedInAccount() async {
    final current = cloudEnabled ? FirebaseAuth.instance.currentUser : null;
    if (current == null || (_user?.isGuest ?? true)) {
      await signOut();
      return true;
    }
    try {
      await current.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') return false;
      _error = _describe(e);
      _notify();
      rethrow;
    }
    _user = null;
    _clearPending();
    _notify();
    return true;
  }

  static String _describe(FirebaseAuthException e) {
    if (e.code.startsWith('api-key-not-valid')) {
      return 'Sign-in isn’t set up for this site yet.';
    }
    switch (e.code) {
      case 'invalid-phone-number':
      case 'missing-phone-number':
        return 'That phone number doesn’t look right. Check the country code.';
      case 'invalid-verification-code':
        return 'That code isn’t right. Check the SMS and try again.';
      case 'code-expired':
      case 'session-expired':
        return 'That code has expired. Send a new one.';
      case 'too-many-requests':
      case 'quota-exceeded':
        return 'Too many attempts. Please wait a while and try again.';
      case 'captcha-check-failed':
        return 'The security check failed. Reload the page and try again.';
      case 'network-request-failed':
        return 'No connection. Check your network and try again.';
      case 'operation-not-allowed':
      case 'admin-restricted-operation':
        return 'Phone sign-in isn’t available for this region yet.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'invalid-api-key':
      case 'app-not-authorized':
      case 'unauthorized-domain':
        return 'Sign-in isn’t set up for this site yet.';
      default:
        // Firebase's own messages are often terse ("Error"); keep ours.
        final m = e.message ?? '';
        return m.length > 24
            ? m
            : 'Couldn’t complete sign-in. Please try again.';
    }
  }
}
