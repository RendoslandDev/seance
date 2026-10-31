import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/bible_service.dart';
import 'services/content_service.dart';
import 'services/hymn_service.dart';
import 'services/progress_store.dart';
import 'services/video_service.dart';

export 'services/bible_service.dart';
export 'services/progress_store.dart' show dateKey;
export 'services/video_service.dart';

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

/// The hymn books the Library offers.
enum HymnBook {
  wesley('Wesley’s Hymns · 1876'),
  selected('Hymns of the World');

  const HymnBook(this.label);
  final String label;
}

/// A heading within a hymn book, e.g. "Part IV · For Believers Rejoicing",
/// covering hymns from [start] until the next section.
class HymnSection {
  final int start;
  final String part;
  final String title;

  const HymnSection({
    required this.start,
    required this.part,
    required this.title,
  });

  factory HymnSection.fromJson(Map<String, dynamic> j) => HymnSection(
    start: (j['start'] as num).toInt(),
    part: j['part'] as String? ?? '',
    title: j['title'] as String? ?? '',
  );
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

  /// Number within its hymn book, when it has one.
  final int? number;
  final HymnBook book;

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
    this.number,
    this.book = HymnBook.selected,
  });

  /// Stable key for bookmarks. Curated hymns keep their title so earlier
  /// bookmarks still match.
  String get id => number != null ? '${book.name}-$number' : title;

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
    id: j['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
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
  final DateTime date;
  final bool isToday;
  final List<DayPart> parts;

  DaySchedule({required this.date, required this.isToday, required this.parts});

  static const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  int get dayNumber => date.day;
  String get weekday => _weekdays[date.weekday - 1];
  String get key => dateKey(date);

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

  const WeekInfo({
    required this.number,
    required this.title,
    required this.image,
  });
}

/// App-wide state. Plain [ChangeNotifier]; the member's data streams in from
/// a [ProgressStore] (on-device for guests, Firestore for accounts).
class AppState extends ChangeNotifier {
  AppState({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _rebuildDays(selectToday: true);
    _scheduleRollover();
  }

  final DateTime Function() _clock;
  Timer? _rollover;

  late List<DaySchedule> _days;
  int _selectedDay = 0;
  int _nav = 0; // home
  int? _chosenWeek; // null == follow the programme

  final ContentService _content = ContentService();
  List<Reading> _readings = List<Reading>.of(seedReadings);
  bool _readingsLoading = false;
  bool _readingsOffline = false;
  bool _loadedOnce = false;

  final HymnService _hymnService = HymnService();
  List<Hymn> _hymns = const <Hymn>[];
  List<Hymn> _wesley = const <Hymn>[];
  List<HymnSection> _wesleySections = const <HymnSection>[];
  HymnBook _hymnBook = HymnBook.wesley;
  bool _hymnsLoading = false;
  bool _hymnsLoaded = false;
  HymnTradition? _hymnFilter; // null == All
  String _hymnQuery = '';

  final BibleService _bibleService = BibleService();
  BibleTranslation _translation = BibleTranslation.kjv;
  Bible? _bible;
  bool _bibleLoading = false;
  int _bibleBook = 42; // John
  int _bibleChapter = 1;
  int? _highlightVerse;
  static const _biblePosKey = 'seance_bible_position';

  final VideoService _videoService = VideoService();
  VideoFeed? _videos;
  bool _videosLoading = false;
  bool _videosLive = false;
  String? _videoCategory; // null == All

  ProgressStore? _store;
  StreamSubscription<UserData>? _storeSub;
  UserData _data = UserData(startedAt: DateTime.now());
  bool _syncError = false;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _rollover?.cancel();
    _storeSub?.cancel();
    _store?.dispose();
    super.dispose();
  }

  /// Notify only while alive — async loads can complete after the widget that
  /// owns this state has been disposed (e.g. navigating away mid-fetch).
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ----- data source -----

  /// Point the app at a member's data. Replaces any previous source.
  Future<void> attach(ProgressStore store) async {
    await detach();
    _store = store;
    _storeSub = store.watch().listen(
      (data) {
        _data = data;
        _syncError = false;
        _applyCompletion();
        _notify();
      },
      onError: (Object e) {
        debugPrint('Sync error: $e');
        _syncError = true;
        _notify();
      },
    );
  }

  /// Drop the current member's data (e.g. on sign-out).
  Future<void> detach() async {
    await _storeSub?.cancel();
    _storeSub = null;
    await _store?.dispose();
    _store = null;
    _data = UserData(startedAt: _clock());
    _chosenWeek = null;
    _nav = 0;
    _applyCompletion();
    _notify();
  }

  bool get syncError => _syncError;

  /// Permanently erase the current member's progress, bookmarks and journal
  /// from wherever they're stored, then forget them here.
  Future<void> deleteAllData() async {
    await _store?.deleteAll();
    await detach();
  }

  // ----- calendar -----

  DateTime get _today {
    final n = _clock();
    return DateTime(n.year, n.month, n.day);
  }

  /// Monday → Sunday of the current week, with completion from [_data].
  void _rebuildDays({bool selectToday = false}) {
    final today = _today;
    final monday = today.subtract(Duration(days: today.weekday - 1));
    _days = [
      for (var i = 0; i < 7; i++)
        DaySchedule(
          date: DateTime(monday.year, monday.month, monday.day + i),
          isToday: i == today.weekday - 1,
          parts: _template(),
        ),
    ];
    if (selectToday) _selectedDay = today.weekday - 1;
    _applyCompletion();
  }

  void _applyCompletion() {
    for (final d in _days) {
      final done = _data.completed[d.key] ?? const <String>{};
      for (final s in d.allSessions) {
        s.done = done.contains(s.title);
      }
    }
  }

  /// Roll the strip over to the new day/week at local midnight.
  void _scheduleRollover() {
    final now = _clock();
    final next = DateTime(now.year, now.month, now.day + 1);
    _rollover = Timer(next.difference(now) + const Duration(seconds: 1), () {
      _rebuildDays(selectToday: true);
      _notify();
      _scheduleRollover();
    });
  }

  List<DaySchedule> get days => _days;
  DaySchedule get day => _days[_selectedDay];
  int get selectedDay => _selectedDay;
  int get nav => _nav;

  bool isFuture(DaySchedule d) => d.date.isAfter(_today);

  // ----- programme -----

  /// The furthest week this member has reached (1-based).
  int get currentWeekNumber {
    final s = _data.startedAt;
    final start = DateTime(s.year, s.month, s.day);
    final weeksIn = _today.difference(start).inDays ~/ 7;
    return (weeksIn + 1).clamp(1, weeks.length);
  }

  bool isLocked(WeekInfo w) => w.number > currentWeekNumber;

  WeekInfo get activeWeek => weeks[(_chosenWeek ?? currentWeekNumber) - 1];

  void selectWeek(WeekInfo w) {
    if (isLocked(w)) return;
    _chosenWeek = w.number;
    notifyListeners();
  }

  // ----- stats -----

  int get totalSessions =>
      _data.completed.values.fold<int>(0, (sum, s) => sum + s.length);

  int get activeDays =>
      _data.completed.values.where((s) => s.isNotEmpty).length;

  /// Consecutive days with at least one practice, ending today (or
  /// yesterday, so an unfinished today doesn't break the run).
  int get streak {
    var d = _today;
    bool active(DateTime x) =>
        (_data.completed[dateKey(x)]?.isNotEmpty ?? false);
    if (!active(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (active(d)) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  // ----- readings -----

  List<Reading> get readings => _readings;
  bool get readingsLoading => _readingsLoading;
  bool get readingsOffline => _readingsOffline;

  bool isSaved(Reading r) => _data.savedReadings.contains(r.title);
  List<Reading> get savedReadings =>
      _readings.where((r) => isSaved(r)).toList();

  /// The reading featured for the current calendar week. Deterministic by
  /// week-of-year so the home-screen widget and the weekly notification always
  /// agree, and it rotates to a new piece each week.
  Reading get weeklyReading {
    final pool = _readings.isNotEmpty ? _readings : seedReadings;
    final week = weekOfYear(_clock());
    return pool[week % pool.length];
  }

  /// Zero-based week index within the year (good enough for rotation).
  static int weekOfYear(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(firstDay).inDays;
    return ((dayOfYear + firstDay.weekday - 1) / 7).floor();
  }

  void toggleSaved(Reading r) {
    final on = !isSaved(r);
    _data = _data.copyWith(
      savedReadings: on
          ? {..._data.savedReadings, r.title}
          : ({..._data.savedReadings}..remove(r.title)),
    );
    notifyListeners();
    _store?.setSavedReading(r.title, on);
  }

  // ----- hymns -----

  bool get hymnsLoading => _hymnsLoading;
  HymnBook get hymnBook => _hymnBook;
  HymnTradition? get hymnFilter => _hymnFilter;
  String get hymnQuery => _hymnQuery;
  List<HymnSection> get hymnSections => _wesleySections;

  List<Hymn> hymnsIn(HymnBook book) =>
      book == HymnBook.wesley ? _wesley : _hymns;

  List<Hymn> get visibleHymns {
    final q = _hymnQuery.trim().toLowerCase();
    final number = int.tryParse(q);
    return hymnsIn(_hymnBook).where((h) {
      if (_hymnBook == HymnBook.selected &&
          _hymnFilter != null &&
          h.tradition != _hymnFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      if (number != null) return h.number == number;
      return h.title.toLowerCase().contains(q) ||
          h.firstLine.toLowerCase().contains(q) ||
          h.author.toLowerCase().contains(q) ||
          h.verses.any((v) => v.toLowerCase().contains(q));
    }).toList();
  }

  /// The section a Wesley hymn number falls in.
  HymnSection? sectionFor(int number) {
    HymnSection? found;
    for (final s in _wesleySections) {
      if (s.start > number) break;
      found = s;
    }
    return found;
  }

  void setHymnBook(HymnBook b) {
    if (_hymnBook == b) return;
    _hymnBook = b;
    notifyListeners();
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

  bool isHymnSaved(Hymn h) => _data.savedHymns.contains(h.id);
  List<Hymn> get savedHymns =>
      [..._hymns, ..._wesley].where((h) => isHymnSaved(h)).toList();

  void toggleHymnSaved(Hymn h) {
    final on = !isHymnSaved(h);
    _data = _data.copyWith(
      savedHymns: on
          ? {..._data.savedHymns, h.id}
          : ({..._data.savedHymns}..remove(h.id)),
    );
    notifyListeners();
    _store?.setSavedHymn(h.id, on);
  }

  /// Load the bundled hymn books once (offline-safe assets).
  Future<void> loadHymns() async {
    if (_hymnsLoaded || _hymnsLoading) return;
    _hymnsLoading = true;
    _notify();
    try {
      _hymns = await _hymnService.loadBundledHymns();
    } catch (_) {
      _hymns = const <Hymn>[];
    }
    try {
      final book = await _hymnService.loadWesley();
      _wesleySections = book.sections;
      _wesley = book.hymns;
    } catch (_) {
      _wesley = const <Hymn>[];
    }
    _hymnsLoading = false;
    _hymnsLoaded = true;
    _notify();
  }

  /// Pull live readings; on any failure we silently keep the template.
  Future<void> loadReadings({bool force = false}) async {
    if (_loadedOnce && !force) return;
    _readingsLoading = true;
    _notify();
    try {
      final live = await _content.fetchReadings(_clock());
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

  /// Mark a practice done / not done. Returns false (and changes nothing) for
  /// days that haven't happened yet.
  bool toggle(Session s) {
    final d = _days.firstWhere(
      (d) => d.allSessions.contains(s),
      orElse: () => day,
    );
    if (isFuture(d)) return false;
    final on = !s.done;
    s.done = on;
    final map = {
      for (final e in _data.completed.entries) e.key: {...e.value},
    };
    final set = map.putIfAbsent(d.key, () => <String>{});
    on ? set.add(s.title) : set.remove(s.title);
    if (set.isEmpty) map.remove(d.key);
    _data = _data.copyWith(completed: map);
    notifyListeners();
    _store?.setCompleted(d.key, s.title, on);
    return true;
  }

  // ----- bible -----

  BibleTranslation get translation => _translation;
  Bible? get bible => _bible;
  bool get bibleLoading => _bibleLoading;
  int get bibleBook => _bibleBook;
  int get bibleChapter => _bibleChapter;
  int? get highlightVerse => _highlightVerse;

  BibleBook? get currentBook =>
      _bible == null ? null : _bible!.books[_bibleBook];
  List<String> get currentChapter =>
      currentBook?.chapters[_bibleChapter - 1] ?? const [];

  /// Load the chosen translation (and the last place read) once.
  Future<void> loadBible() async {
    if (_bible != null || _bibleLoading) return;
    _bibleLoading = true;
    _notify();
    try {
      final prefs = await SharedPreferences.getInstance();
      final pos = prefs.getString(_biblePosKey)?.split(':');
      if (pos != null && pos.length == 3) {
        _translation = BibleTranslation.fromName(pos[0]);
        _bibleBook = int.tryParse(pos[1]) ?? _bibleBook;
        _bibleChapter = int.tryParse(pos[2]) ?? _bibleChapter;
      }
    } catch (_) {
      /* first visit */
    }
    await _loadTranslation(_translation);
  }

  Future<void> _loadTranslation(BibleTranslation t) async {
    _bibleLoading = true;
    _notify();
    try {
      _bible = await _bibleService.load(t);
      _translation = t;
      _bibleBook = _bibleBook.clamp(0, _bible!.books.length - 1);
      _bibleChapter = _bibleChapter.clamp(
        1,
        _bible!.books[_bibleBook].chapters.length,
      );
    } catch (e) {
      debugPrint('Bible failed to load: $e');
    } finally {
      _bibleLoading = false;
      _notify();
    }
  }

  Future<void> setTranslation(BibleTranslation t) async {
    if (t == _translation && _bible != null) return;
    await _loadTranslation(t);
    _saveBiblePosition();
  }

  void openChapter(int book, int chapter, {int? verse}) {
    final b = _bible;
    if (b == null) return;
    if (book < 0 || book >= b.books.length) return;
    final count = b.books[book].chapters.length;
    _bibleBook = book;
    _bibleChapter = chapter.clamp(1, count);
    _highlightVerse = verse;
    notifyListeners();
    _saveBiblePosition();
  }

  /// Step to the next/previous chapter, crossing book boundaries.
  void stepChapter(int delta) {
    final b = _bible;
    if (b == null) return;
    var book = _bibleBook;
    var chapter = _bibleChapter + delta;
    if (chapter < 1 && book > 0) {
      book--;
      chapter = b.books[book].chapters.length;
    } else if (chapter > b.books[book].chapters.length &&
        book < b.books.length - 1) {
      book++;
      chapter = 1;
    }
    openChapter(book, chapter);
  }

  bool get hasPreviousChapter => _bibleBook > 0 || _bibleChapter > 1;
  bool get hasNextChapter =>
      _bible != null &&
      (_bibleBook < _bible!.books.length - 1 ||
          _bibleChapter < currentBook!.chapters.length);

  Future<void> _saveBiblePosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _biblePosKey,
        '${_translation.name}:$_bibleBook:$_bibleChapter',
      );
    } catch (_) {
      /* best effort */
    }
  }

  // ----- videos -----

  VideoFeed? get videoFeed => _videos;
  bool get videosLoading => _videosLoading;
  bool get videosLive => _videosLive;
  String? get videoCategory => _videoCategory;

  List<Video> get visibleVideos {
    final all = _videos?.videos ?? const <Video>[];
    if (_videoCategory == null) return all;
    return all.where((v) => v.category == _videoCategory).toList();
  }

  void setVideoCategory(String? c) {
    if (_videoCategory == c) return;
    _videoCategory = c;
    notifyListeners();
  }

  /// Show the bundled snapshot at once, then replace it with the live feed.
  Future<void> loadVideos({bool force = false}) async {
    if (_videosLoading || (_videosLive && !force)) return;
    _videosLoading = true;
    _notify();
    try {
      _videos ??= await _videoService.loadSnapshot();
      _notify();
      _videos = await _videoService.fetchLive(_videos!);
      _videosLive = true;
    } catch (e) {
      debugPrint('Live video feed unavailable: $e');
    } finally {
      _videosLoading = false;
      _notify();
    }
  }

  // ----- journal -----

  /// Entries, newest first.
  List<JournalEntry> get journal {
    final out = List<JournalEntry>.of(_data.journal);
    out.sort((a, b) => b.id.compareTo(a.id));
    return out;
  }

  void addJournalEntry(String body, {String? sessionTitle, int? dayNumber}) {
    final text = body.trim();
    if (text.isEmpty) return;
    final entry = JournalEntry(
      id: _clock().millisecondsSinceEpoch.toString(),
      createdAt: _clock(),
      body: text,
      sessionTitle: sessionTitle,
      dayNumber: dayNumber,
    );
    _data = _data.copyWith(journal: [..._data.journal, entry]);
    notifyListeners();
    _store?.addJournal(entry);
  }

  void deleteJournalEntry(String id) {
    _data = _data.copyWith(
      journal: _data.journal.where((e) => e.id != id).toList(),
    );
    notifyListeners();
    _store?.deleteJournal(id);
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

  /// The programme. Week N unlocks N-1 weeks after the member starts.
  static const List<WeekInfo> weeks = [
    WeekInfo(
      number: 1,
      title: 'Finding your Center',
      image: 'assets/images/coderend.jpg',
    ),
    WeekInfo(
      number: 2,
      title: 'Softening the Edges',
      image: 'assets/images/center.jpg',
    ),
    WeekInfo(
      number: 3,
      title: 'Holding Stillness',
      image: 'assets/images/reflect.jpg',
    ),
    WeekInfo(
      number: 4,
      title: 'Returning to Breath',
      image: 'assets/images/rest.jpg',
    ),
    WeekInfo(
      number: 5,
      title: 'The Quiet Mind',
      image: 'assets/images/hero.jpg',
    ),
  ];

  // ----- daily practice template -----

  List<DayPart> _template() => [
    DayPart(
      label: 'Morning',
      range: '6 – 9AM',
      sessions: [
        Session(
          title: 'Rendosland',
          minutes: 7,
          description:
              'A new guided meditation each week to explore what resonates.',
          image: 'assets/images/coderend.jpg',
        ),
        Session(title: 'Receive', minutes: 5),
      ],
    ),
    DayPart(
      label: 'Day',
      range: '9AM – 6PM',
      sessions: [
        Session(
          title: 'Center',
          minutes: 1,
          description:
              'A moment of pause to reconnect. Tune into body, environment or guiding thought.',
          image: 'assets/images/center.jpg',
        ),
      ],
    ),
    DayPart(
      label: 'Evening',
      range: '6 – 9PM',
      sessions: [
        Session(title: 'Move', minutes: 5),
        Session(
          title: 'Reflect',
          minutes: 1,
          description:
              'A brief journaling session to capture what surfaced today. Discard when done.',
          image: 'assets/images/reflect.jpg',
        ),
      ],
    ),
    DayPart(
      label: 'Night',
      range: '9PM',
      sessions: [
        Session(
          title: 'Rest',
          minutes: 8,
          description:
              'A slow wind-down to release the day and prepare the body for sleep.',
          image: 'assets/images/rest.jpg',
        ),
      ],
    ),
  ];
}
