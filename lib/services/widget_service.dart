import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:home_widget/home_widget.dart';

import '../models.dart';

/// Bridges Flutter to the native home-screen widgets (Android App Widget /
/// iOS WidgetKit). Data is written into a shared store the native side reads.
class WidgetService {
  /// Must match the App Group configured on iOS (see ios/ReadingWidget/README).
  static const appGroupId = 'group.com.rendosland.seance';

  /// The Android [AppWidgetProvider] class name.
  static const _androidProvider = 'ReadingWidgetProvider';

  /// The iOS WidgetKit widget `kind`.
  static const _iosWidget = 'ReadingWidget';

  static Future<void> init() async {
    if (kIsWeb) return; // home-screen widgets are native-only
    // No-op on Android; required so iOS reads from the shared App Group.
    await HomeWidget.setAppGroupId(appGroupId);
  }

  /// Publish [r] to the home-screen widget and ask the OS to redraw it.
  static Future<void> pushWeeklyReading(Reading r) async {
    if (kIsWeb) return;
    try {
      await HomeWidget.saveWidgetData<String>('reading_title', r.title);
      await HomeWidget.saveWidgetData<String>(
        'reading_excerpt',
        _excerpt(r.body),
      );
      await HomeWidget.saveWidgetData<String>(
        'reading_meta',
        '${r.author.toUpperCase()} · ${r.minutes} MIN READ',
      );
      await HomeWidget.updateWidget(
        androidName: _androidProvider,
        iOSName: _iosWidget,
      );
    } catch (_) {
      // Widget not installed / platform unsupported → ignore.
    }
  }

  static String _excerpt(String body) {
    final text = body.trim().replaceAll('\n', ' ');
    final dot = text.indexOf('. ');
    final sentence = dot == -1 ? text : text.substring(0, dot + 1);
    if (sentence.length <= 160) return sentence;
    return '${sentence.substring(0, 157).trimRight()}…';
  }
}
