import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/content_service.dart';
import 'services/hymn_service.dart';

/// Worship tradition a hymn belongs to.
enum HymnTradition {
  methodist('Methodist'),
  presbyterian('Presbyterian'),
  global('Global'),
  psalms('Psalms');

  const HymnTradition(this.label);
  final String label;

  static HymnTradition fromId(String? id) {
    return HymnTradition.values.firstWhere(
      (t) => t.name == id,
      orElse: () => HymnTradition.global,
    );
  }
}

/// A single public-domain hymn with its verses + metadata.
class Hymn {
  final String title;
  final String firstLine;
  final String author;
  final int? year;
  final HymnTradition tradition;
  final String? tune;
  final String? meter;
  final String? scripture;
  final String? hymnalRef;
  final List<String> verses;
  final String? refrain;
  final String source;

  const Hymn({
    required this.title,
    required this.firstLine,
    required this.author,
    required this.tradition,
    required this.verses,
    this.year,
    this.tune,
    this.meter,
    this.scripture,
    this.hymnalRef,
    this.refrain,
    this.source = 'Public domain',
  });

  factory Hymn.fromJson(Map<String, dynamic> j) => Hymn(
        title: j['title'] as String? ?? 'Hymn',
        firstLine: j['firstLine'] as String? ?? '',
        author: j['author'] as String? ?? 'Unknown',
        year: (j['year'] as num?)?.toInt(),
        tradition: HymnTradition.fromId(j['tradition'] as String?),
        tune: j['tune'] as String?,
        meter: j['meter'] as String?,
        scripture: j['scripture'] as String?,
        hymnalRef: j['hymnalRef'] as String?,
        refrain: j['refrain'] as String?,
        source: j['source'] as String? ?? 'Public domain',
        verses: ((j['verses'] as List?) ?? const [])
            .map((v) => v.toString())
            .toList(),
      );

  int get verseCount => verses.length;
}

/// A long-form reading. Sourced live from the web, with a bundled
/// template that always ships offline.
class Reading {
  final String title;
  final String author;
  final String body;
  final int minutes;
  final String? image;
  final bool remote;

  const Reading({
    required this.title,
    required this.author,
    required this.body,
    required this.minutes,
    this.image,
    this.remote = false,
  });
}

/// A written reflection. Either free-form (from the Journal tab) or attached
/// to a specific session (written from a card's Reflect action). Persisted
/// across launches via [AppState].
class JournalEntry {
  final String id; // millis-since-epoch string; also the sort key
  final DateTime createdAt;
  final String body;
  final String? sessionTitle; // set when written from a session card
  final int? dayNumber; // the DaySchedule.dayNumber it was attached to

  const JournalEntry({
    required this.id,
    required this.createdAt,
    required this.body,
    this.sessionTitle,
    this.dayNumber,
  });

  bool get linkedToSession => sessionTitle != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'body': body,
        'sessionTitle': sessionTitle,
        'dayNumber': dayNumber,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        id: j['id'] as String? ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        body: j['body'] as String? ?? '',
        sessionTitle: j['sessionTitle'] as String?,
        dayNumber: (j['dayNumber'] as num?)?.toInt(),
      );
}

/// A single practice within a day.
class Session {
  final String title;
  final int minutes;
  final String? description;
  final String? image;
  bool done;

  Session({
    required this.title,
    required this.minutes,
    this.description,
    this.image,
    this.done = false,
  });

  /// Expanded cards (image + copy) vs. compact one-line cards.
  bool get expanded => description != null;

  Session copy() => Session(
        title: title,
        minutes: minutes,
        description: description,
        image: image,
        done: done,
      );
}

/// A part of the day — Morning, Day, Evening, Night.
class DayPart {
  final String label;
  final String range;
  final List<Session> sessions;

  DayPart({required this.label, required this.range, required this.sessions});

  DayPart copy() => DayPart(
        label: label,
        range: range,
        sessions: sessions.map((s) => s.copy()).toList(),
      );
}

/// One calendar day in the strip.
class DaySchedule {
  final int dayNumber;
  final String weekday;
  final bool isToday;
  final List<DayPart> parts;

  DaySchedule({
    required this.dayNumber,
    required this.weekday,
    required this.isToday,
    required this.parts,
  });

  Iterable<Session> get allSessions => parts.expand((p) => p.sessions);

  int get total => allSessions.length;
  int get completed => allSessions.where((s) => s.done).length;
  double get progress => total == 0 ? 0 : completed / total;
  bool get hasActivity => completed > 0;
}

/// A programme week (powers the hero card + WEEKS panel).
class WeekInfo {
  final int number;
  final String title;
  final String image;
  final bool locked;

  const WeekInfo({
    required this.number,
    required this.title,
    required this.image,
    this.locked = false,
  });
}

/// App-wide state. Plain [ChangeNotifier] — no external deps.
class AppState extends ChangeNotifier {
  AppState() {
    _days = _buildDays();
  }

  late final List<DaySchedule> _days;
  int _selectedDay = 3; // "16" → TODAY
  int _nav = 0; // home
  WeekInfo _activeWeek = weeks.first;

  final ContentService _content = ContentService();
  List<Reading> _readings = List<Reading>.of(seedReadings);
  bool _readingsLoading = false;
  bool _readingsOffline = false;
  bool _loadedOnce = false;
  final Set<String> _saved = <String>{};

  final HymnService _hymnService = HymnService();
  List<Hymn> _hymns = const <Hymn>[];
  bool _hymnsLoading = false;
  bool _hymnsLoaded = false;
  HymnTradition? _hymnFilter; // null == All
  String _hymnQuery = '';
  final Set<String> _savedHymns = <String>{};

  final List<JournalEntry> _journal = <JournalEntry>[];
  static const _journalKey = 'seance_journal';

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Notify only while alive — async loads can complete after the widget that
  /// owns this state has been disposed (e.g. navigating away mid-fetch).
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  List<DaySchedule> get days => _days;
  DaySchedule get day => _days[_selectedDay];
  int get selectedDay => _selectedDay;
  int get nav => _nav;
  WeekInfo get activeWeek => _activeWeek;

  List<Reading> get readings => _readings;
  bool get readingsLoading => _readingsLoading;
  bool get readingsOffline => _readingsOffline;

  bool isSaved(Reading r) => _saved.contains(r.title);
  List<Reading> get savedReadings =>
      _readings.where((r) => _saved.contains(r.title)).toList();

  /// The reading featured for the current calendar week. Deterministic by
  /// week-of-year so the home-screen widget and the weekly notification always
  /// agree, and it rotates to a new piece each week.
  Reading get weeklyReading {
    final pool = _readings.isNotEmpty ? _readings : seedReadings;
    final week = weekOfYear(DateTime.now());
    return pool[week % pool.length];
  }

  /// Zero-based week index within the year (good enough for rotation).
  static int weekOfYear(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDay).inDays;
    return ((dayOfYear + firstDay.weekday - 1) / 7).floor();
  }

  void toggleSaved(Reading r) {
    if (!_saved.remove(r.title)) _saved.add(r.title);
    notifyListeners();
  }

  // ----- hymns -----

  bool get hymnsLoading => _hymnsLoading;
  HymnTradition? get hymnFilter => _hymnFilter;
  String get hymnQuery => _hymnQuery;

  List<Hymn> get visibleHymns {
    final q = _hymnQuery.trim().toLowerCase();
    return _hymns.where((h) {
      if (_hymnFilter != null && h.tradition != _hymnFilter) return false;
      if (q.isEmpty) return true;
      return h.title.toLowerCase().contains(q) ||
          h.firstLine.toLowerCase().contains(q) ||
          h.author.toLowerCase().contains(q);
    }).toList();
  }

  void setHymnFilter(HymnTradition? t) {
    if (_hymnFilter == t) return;
    _hymnFilter = t;
    notifyListeners();
  }

  void setHymnQuery(String q) {
    if (_hymnQuery == q) return;
    _hymnQuery = q;
    notifyListeners();
  }

  bool isHymnSaved(Hymn h) => _savedHymns.contains(h.title);
  List<Hymn> get savedHymns =>
      _hymns.where((h) => _savedHymns.contains(h.title)).toList();

  void toggleHymnSaved(Hymn h) {
    if (!_savedHymns.remove(h.title)) _savedHymns.add(h.title);
    notifyListeners();
  }

  /// Load the bundled hymn library once (offline-safe asset).
  Future<void> loadHymns() async {
    if (_hymnsLoaded || _hymnsLoading) return;
    _hymnsLoading = true;
    _notify();
    try {
      _hymns = await _hymnService.loadBundledHymns();
    } catch (_) {
      _hymns = const <Hymn>[];
    } finally {
      _hymnsLoading = false;
      _hymnsLoaded = true;
      _notify();
    }
  }

  /// Pull live readings; on any failure we silently keep the template.
  Future<void> loadReadings({bool force = false}) async {
    if (_loadedOnce && !force) return;
    _readingsLoading = true;
    _notify();
    try {
      final live = await _content.fetchReadings();
      if (live.isNotEmpty) {
        // Real-world data first, the curated template kept underneath.
        _readings = [...live, ...seedReadings];
        _readingsOffline = false;
      } else {
        _readingsOffline = true;
      }
    } catch (_) {
      _readingsOffline = true;
    } finally {
      _readingsLoading = false;
      _loadedOnce = true;
      _notify();
    }
  }

  void selectDay(int i) {
    if (i == _selectedDay) return;
    _selectedDay = i;
    notifyListeners();
  }

  void selectNav(int i) {
    if (i == _nav) return;
    _nav = i;
    notifyListeners();
  }

  void selectWeek(WeekInfo w) {
    if (w.locked) return;
    _activeWeek = w;
    notifyListeners();
  }

  void toggle(Session s) {
    s.done = !s.done;
    notifyListeners();
  }

  // ----- journal -----

  /// Entries, newest first.
  List<JournalEntry> get journal {
    final out = List<JournalEntry>.of(_journal);
    out.sort((a, b) => b.id.compareTo(a.id));
    return out;
  }

  /// Load persisted entries once at startup. A corrupt / unavailable store
  /// simply yields no entries.
  Future<void> restoreJournal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_journalKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _journal
          ..clear()
          ..addAll(list.map(
              (e) => JournalEntry.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {
      // corrupt / unavailable store → start with no entries
    }
    _notify();
  }

  Future<void> _persistJournal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_journal.map((e) => e.toJson()).toList());
      await prefs.setString(_journalKey, raw);
    } catch (_) {/* best effort */}
  }

  void addJournalEntry(String body, {String? sessionTitle, int? dayNumber}) {
    final text = body.trim();
    if (text.isEmpty) return;
    _journal.add(JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      body: text,
      sessionTitle: sessionTitle,
      dayNumber: dayNumber,
    ));
    notifyListeners();
    _persistJournal();
  }

  void deleteJournalEntry(String id) {
    _journal.removeWhere((e) => e.id == id);
    notifyListeners();
    _persistJournal();
  }

  /// Always-available reading library. Used until live content arrives,
  /// and kept beneath it as a curated, offline-safe set.
  static const List<Reading> seedReadings = [
    Reading(
      title: 'The Art of Beginning Again',
      author: 'séance',
      minutes: 3,
      image: 'assets/images/coderend.jpg',
      body:
          'Every practice is an act of return. We do not arrive at stillness '
          'once and keep it; we lose it a hundred times a day and come back. '
          'The coming back is the practice. There is nothing to perfect here — '
          'only the quiet willingness to begin again, gently, without scorn for '
          'the wandering. Notice where you are. Take one breath that is wholly '
          'yours. That is enough to start.',
    ),
    Reading(
      title: 'On Stillness',
      author: 'séance',
      minutes: 4,
      image: 'assets/images/center.jpg',
      body:
          'Stillness is not the absence of motion but the presence of '
          'attention. The body can be at rest while the mind paces; it can also '
          'move through an ordinary day carrying a steadiness that nothing '
          'disturbs. We practise sitting so that we might stand differently, '
          'walk differently, listen differently. Let the room be quiet. Let the '
          'quiet be large enough to hold whatever arrives.',
    ),
    Reading(
      title: 'A Practice of Attention',
      author: 'séance',
      minutes: 2,
      image: 'assets/images/reflect.jpg',
      body:
          'Attention is the most honest form of generosity. To attend fully to '
          'a breath, a sound, a passing thought — without grasping or pushing '
          'away — is to meet your life as it actually is. Today, choose one '
          'small thing and give it your whole regard. The warmth of a cup. The '
          'weight of your feet on the floor. Begin there.',
    ),
    Reading(
      title: 'Returning to the Breath',
      author: 'séance',
      minutes: 3,
      image: 'assets/images/rest.jpg',
      body:
          'The breath asks nothing of you and is always available. When the '
          'day frays, it is a thread back to the present — not because it calms '
          'the storm, but because it reminds you where you are standing. Follow '
          'one inhale to its end. Follow one exhale all the way down. The mind '
          'will leave; invite it back without comment. This is the whole of it.',
    ),
  ];

  static const List<WeekInfo> weeks = [
    WeekInfo(number: 1, title: 'Finding your Center', image: 'assets/images/coderend.jpg'),
    WeekInfo(number: 2, title: 'Softening the Edges', image: 'assets/images/center.jpg'),
    WeekInfo(number: 3, title: 'Holding Stillness', image: 'assets/images/reflect.jpg'),
    WeekInfo(number: 4, title: 'Returning to Breath', image: 'assets/images/rest.jpg', locked: true),
    WeekInfo(number: 5, title: 'The Quiet Mind', image: 'assets/images/hero.jpg', locked: true),
  ];

  // ----- seed data -----

  List<DayPart> _template() => [
        DayPart(label: 'Morning', range: '6 – 9AM', sessions: [
          Session(
            title: 'Rendosland',
            minutes: 7,
            description:
                'A new guided meditation each week to explore what resonates.',
            image: 'assets/images/coderend.jpg',
          ),
          Session(title: 'Receive', minutes: 5),
        ]),
        DayPart(label: 'Day', range: '9AM – 6PM', sessions: [
          Session(
            title: 'Center',
            minutes: 1,
            description:
                'A moment of pause to reconnect. Tune into body, environment or guiding thought.',
            image: 'assets/images/center.jpg',
          ),
        ]),
        DayPart(label: 'Evening', range: '6 – 9PM', sessions: [
          Session(title: 'Move', minutes: 5),
          Session(
            title: 'Reflect',
            minutes: 1,
            description:
                'A brief journaling session to capture what surfaced today. Discard when done.',
            image: 'assets/images/reflect.jpg',
          ),
        ]),
        DayPart(label: 'Night', range: '9PM', sessions: [
          Session(
            title: 'Rest',
            minutes: 8,
            description:
                'A slow wind-down to release the day and prepare the body for sleep.',
            image: 'assets/images/rest.jpg',
          ),
        ]),
      ];

  List<DaySchedule> _buildDays() {
    const numbers = [13, 14, 15, 16, 17, 18, 19];
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final out = <DaySchedule>[];
    for (var i = 0; i < numbers.length; i++) {
      final parts = _template().map((p) => p.copy()).toList();
      // Pre-complete the past days + the two finished morning practices today.
      if (i < 2) {
        for (final s in parts.expand((p) => p.sessions)) {
          s.done = true;
        }
      } else if (i == 3) {
        parts[0].sessions[0].done = true; // Align
        parts[0].sessions[1].done = true; // Receive
        parts[2].sessions[0].done = true; // Move
      }
      out.add(DaySchedule(
        dayNumber: numbers[i],
        weekday: weekdays[i],
        isToday: i == 3,
        parts: parts,
      ));
    }
    return out;
  }
}
