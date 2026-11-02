import 'package:flutter_test/flutter_test.dart';
import 'package:seance/models.dart';
import 'package:seance/services/content_service.dart';

void main() {
  setUp(() => ContentService.networkEnabled = false);

  // Thursday 30 October 2025, mid-morning.
  final thursday = DateTime(2025, 10, 30, 10);

  test('the strip is the real Monday–Sunday week with today selected', () {
    final s = AppState(clock: () => thursday);
    addTearDown(s.dispose);
    expect(s.days.map((d) => d.dayNumber), [27, 28, 29, 30, 31, 1, 2]);
    expect(s.days.first.weekday, 'MON');
    expect(s.day.isToday, isTrue);
    expect(s.day.dayNumber, 30);
  });

  test('nothing starts completed', () {
    final s = AppState(clock: () => thursday);
    addTearDown(s.dispose);
    expect(s.days.every((d) => d.completed == 0), isTrue);
    expect(s.totalSessions, 0);
    expect(s.streak, 0);
  });

  test('future days cannot be completed; today and past can', () {
    final s = AppState(clock: () => thursday);
    addTearDown(s.dispose);
    s.selectDay(5); // Saturday
    final future = s.day.allSessions.first;
    expect(s.toggle(future), isFalse);
    expect(future.done, isFalse);

    s.selectDay(3); // today
    expect(s.toggle(s.day.allSessions.first), isTrue);
    s.selectDay(2); // yesterday
    expect(s.toggle(s.day.allSessions.first), isTrue);
    expect(s.totalSessions, 2);
    expect(s.activeDays, 2);
    expect(s.streak, 2);
  });

  test('only weeks already reached are unlocked', () {
    final s = AppState(clock: () => thursday);
    addTearDown(s.dispose);
    expect(s.currentWeekNumber, 1);
    expect(s.isLocked(AppState.weeks[0]), isFalse);
    expect(s.isLocked(AppState.weeks[1]), isTrue);
  });

  test('daily topics rotate', () {
    final a = ContentService.topicsFor(DateTime(2025, 10, 30));
    final b = ContentService.topicsFor(DateTime(2025, 10, 31));
    expect(a, hasLength(8));
    expect(a, isNot(equals(b)));
  });
}
