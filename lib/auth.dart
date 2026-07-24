import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The signed-in member. Either a Google account or a social handle.
class AppUser {
  final String name;
  final String? email;
  final String? handle;
  final String provider; // Google · Apple · Facebook · X · Instagram

  const AppUser({
    required this.name,
    this.email,
    this.handle,
    required this.provider,
  });

  String get initials {
    final source = (handle ?? name).replaceAll('@', '').trim();
    if (source.isEmpty) return '·';
    return source[0].toUpperCase();
  }

  String get subtitle =>
      handle != null ? '$handle · via $provider' : 'Signed in with $provider';

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'handle': handle,
        'provider': provider,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        name: j['name'] as String? ?? 'You',
        email: j['email'] as String?,
        handle: j['handle'] as String?,
        provider: j['provider'] as String? ?? 'Google',
      );
}

/// Holds the session and persists it across launches.
///
/// NOTE: real Google OAuth requires your own Firebase / OAuth client id.
/// [signInWithGoogle] models a successful session so the whole app flow is
/// exercised; swap its body for `google_sign_in` once credentials exist.
class AuthController extends ChangeNotifier {
  AppUser? _user;
  bool _loading = true;
  bool _busy = false;
  bool _disposed = false;

  AppUser? get user => _user;
  bool get signedIn => _user != null;
  bool get loading => _loading;
  bool get busy => _busy;

  static const _key = 'seance_user';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Notify only while alive — restore/sign-in can resolve after disposal.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        _user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      // corrupt / unavailable store → start signed out
    }
    _loading = false;
    _notify();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_user != null) {
        await prefs.setString(_key, jsonEncode(_user!.toJson()));
      } else {
        await prefs.remove(_key);
      }
    } catch (_) {/* best effort */}
  }

  Future<void> signInWithGoogle() async {
    _busy = true;
    _notify();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _user = const AppUser(
      name: 'You',
      email: 'you@gmail.com',
      provider: 'Google',
    );
    _busy = false;
    await _persist();
    _notify();
  }

  Future<void> signInWithHandle(String provider, String rawHandle) async {
    final handle =
        rawHandle.startsWith('@') ? rawHandle.trim() : '@${rawHandle.trim()}';
    _busy = true;
    _notify();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _user = AppUser(name: handle, handle: handle, provider: provider);
    _busy = false;
    await _persist();
    _notify();
  }

  Future<void> signOut() async {
    _user = null;
    await _persist();
    _notify();
  }
}
