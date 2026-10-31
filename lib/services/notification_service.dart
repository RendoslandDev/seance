import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';

/// Local notifications for the weekly reading nudge (Monday 08:00, repeating).
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'weekly_readings';
  static const _channelName = 'Weekly readings';
  static const _weeklyNotificationId = 1001;

  static bool _ready = false;

  static Future<void> init() async {
    if (kIsWeb) return; // scheduled local notifications are native-only
    tzdata.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      // Falls back to UTC; the notification still fires, just on UTC clock.
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      // We request explicitly later so the prompt is well-timed.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
      );
      _ready = true;
    } catch (_) {
      // Unsupported platform (e.g. desktop) → reminders stay off.
    }
  }

  /// Ask the user to allow notifications (Android 13+ and iOS).
  static Future<void> requestPermissions() async {
    if (!_ready) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// (Re)schedule the recurring Monday-08:00 reading reminder for [r].
  static Future<void> scheduleWeeklyReading(Reading r) async {
    if (!_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'A fresh séance reading at the start of each week.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        id: _weeklyNotificationId,
        title: 'This week in séance',
        body: '${r.title} — a ${r.minutes} min reading to begin your week.',
        scheduledDate: _nextMonday8am(),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (_) {
      // Scheduling unsupported (e.g. desktop/web) → ignore.
    }
  }

  /// The next Monday at 08:00 local time that is still in the future.
  static tz.TZDateTime _nextMonday8am() {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8);
    while (d.weekday != DateTime.monday || !d.isAfter(now)) {
      final next = d.add(const Duration(days: 1));
      d = tz.TZDateTime(tz.local, next.year, next.month, next.day, 8);
    }
    return d;
  }
}
