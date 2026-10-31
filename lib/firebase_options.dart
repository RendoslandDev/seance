import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase client options, read from `--dart-define`s at build time so no
/// project values are hard-coded in the repo:
///
///     flutter build web --dart-define-from-file=config/firebase.json
///
/// (see `config/firebase.example.json`). Running `flutterfire configure`
/// replaces this file with generated values, which also works.
///
/// When the values are absent the app still runs, in on-device guest mode.
class DefaultFirebaseOptions {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.rendosland.seance',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return _options(_webAppId);
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _options(_androidAppId);
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _options(_iosAppId, iosBundleId: _iosBundleId);
      default:
        return _options(_webAppId);
    }
  }

  static FirebaseOptions _options(String appId, {String? iosBundleId}) =>
      FirebaseOptions(
        apiKey: _apiKey,
        appId: appId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        authDomain: _authDomain.isEmpty ? null : _authDomain,
        storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
        iosBundleId: iosBundleId,
      );
}
