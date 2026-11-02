import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// Everything a member accumulates: completed practices per calendar day,
/// bookmarks, reflections and when they started the programme.
class UserData {
  const UserData({
    required this.startedAt,
    this.completed = const {},
    this.savedReadings = const {},
    this.savedHymns = const {},
    this.journal = const [],
  });

  final DateTime startedAt;

  /// `yyyy-mm-dd` → titles of the sessions finished that day.
  final Map<String, Set<String>> completed;
  final Set<String> savedReadings;
  final Set<String> savedHymns;
  final List<JournalEntry> journal;

  UserData copyWith({
    Map<String, Set<String>>? completed,
    Set<String>? savedReadings,
    Set<String>? savedHymns,
    List<JournalEntry>? journal,
  }) => UserData(
    startedAt: startedAt,
    completed: completed ?? this.completed,
    savedReadings: savedReadings ?? this.savedReadings,
    savedHymns: savedHymns ?? this.savedHymns,
    journal: journal ?? this.journal,
  );

  static Map<String, Set<String>> completedFromJson(Object? raw) {
    if (raw is! Map) return {};
    return {
      for (final e in raw.entries)
        if (e.value is List)
          e.key.toString(): (e.value as List).map((v) => v.toString()).toSet(),
    };
  }

  static Set<String> setFromJson(Object? raw) =>
      raw is List ? raw.map((v) => v.toString()).toSet() : <String>{};
}

/// `yyyy-mm-dd` for a local calendar date.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Where a member's [UserData] lives. [watch] emits the current value and
/// again on every change — including changes made on other devices for the
/// cloud store.
abstract class ProgressStore {
  Stream<UserData> watch();
  Future<void> setCompleted(String day, String session, bool done);
  Future<void> setSavedReading(String title, bool saved);
  Future<void> setSavedHymn(String title, bool saved);
  Future<void> addJournal(JournalEntry entry);
  Future<void> deleteJournal(String id);

  /// Permanently remove everything this store holds for the member.
  Future<void> deleteAll();
  Future<void> dispose();
}

/// On-device store for guests (and for builds without Firebase configured).
class LocalProgressStore implements ProgressStore {
  LocalProgressStore();

  static const _key = 'seance_progress';
  static const _legacyJournalKey = 'seance_journal';

  final _controller = StreamController<UserData>.broadcast();
  UserData? _data;

  Future<UserData> _load() async {
    if (_data != null) return _data!;
    var data = UserData(startedAt: DateTime.now());
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        data = UserData(
          startedAt:
              DateTime.tryParse(j['startedAt'] as String? ?? '') ??
              DateTime.now(),
          completed: UserData.completedFromJson(j['completed']),
          savedReadings: UserData.setFromJson(j['savedReadings']),
          savedHymns: UserData.setFromJson(j['savedHymns']),
          journal: ((j['journal'] as List?) ?? const [])
              .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      } else {
        // Carry over reflections written before progress was persisted.
        final legacy = prefs.getString(_legacyJournalKey);
        if (legacy != null) {
          data = data.copyWith(
            journal: (jsonDecode(legacy) as List)
                .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
                .toList(),
          );
        }
        _data = data;
        await _persist();
      }
    } catch (_) {
      // corrupt / unavailable store → start fresh
    }
    return _data = data;
  }

  Future<void> _persist() async {
    final d = _data;
    if (d == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'startedAt': d.startedAt.toIso8601String(),
          'completed': d.completed.map((k, v) => MapEntry(k, v.toList())),
          'savedReadings': d.savedReadings.toList(),
          'savedHymns': d.savedHymns.toList(),
          'journal': d.journal.map((e) => e.toJson()).toList(),
        }),
      );
    } catch (_) {
      /* best effort */
    }
  }

  Future<void> _update(UserData Function(UserData) change) async {
    _data = change(await _load());
    if (!_controller.isClosed) _controller.add(_data!);
    await _persist();
  }

  @override
  Stream<UserData> watch() async* {
    yield await _load();
    yield* _controller.stream;
  }

  @override
  Future<void> setCompleted(String day, String session, bool done) =>
      _update((d) {
        final map = {
          for (final e in d.completed.entries) e.key: {...e.value},
        };
        final set = map.putIfAbsent(day, () => <String>{});
        done ? set.add(session) : set.remove(session);
        if (set.isEmpty) map.remove(day);
        return d.copyWith(completed: map);
      });

  @override
  Future<void> setSavedReading(String title, bool saved) => _update(
    (d) => d.copyWith(savedReadings: _toggled(d.savedReadings, title, saved)),
  );

  @override
  Future<void> setSavedHymn(String title, bool saved) => _update(
    (d) => d.copyWith(savedHymns: _toggled(d.savedHymns, title, saved)),
  );

  @override
  Future<void> addJournal(JournalEntry entry) =>
      _update((d) => d.copyWith(journal: [...d.journal, entry]));

  @override
  Future<void> deleteJournal(String id) => _update(
    (d) => d.copyWith(journal: d.journal.where((e) => e.id != id).toList()),
  );

  @override
  Future<void> deleteAll() async {
    _data = UserData(startedAt: DateTime.now());
    if (!_controller.isClosed) _controller.add(_data!);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      await prefs.remove(_legacyJournalKey);
    } catch (_) {
      /* best effort */
    }
  }

  @override
  Future<void> dispose() => _controller.close();
}

Set<String> _toggled(Set<String> s, String v, bool on) =>
    on ? {...s, v} : ({...s}..remove(v));

/// Firestore-backed store. Data lives at `users/{uid}` (progress + bookmarks)
/// and `users/{uid}/journal/{id}` (reflections), and streams live via
/// snapshot listeners so every signed-in device stays in step.
class CloudProgressStore implements ProgressStore {
  CloudProgressStore(this.uid, {FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> get _journal =>
      _doc.collection('journal');

  @override
  Stream<UserData> watch() {
    late final StreamController<UserData> out;
    StreamSubscription? docSub;
    StreamSubscription? journalSub;
    Map<String, dynamic>? doc;
    List<JournalEntry>? journal;

    void emit() {
      if (doc == null || journal == null) return;
      final started = doc!['startedAt'];
      out.add(
        UserData(
          startedAt: started is Timestamp ? started.toDate() : DateTime.now(),
          completed: UserData.completedFromJson(doc!['completed']),
          savedReadings: UserData.setFromJson(doc!['savedReadings']),
          savedHymns: UserData.setFromJson(doc!['savedHymns']),
          journal: journal!,
        ),
      );
    }

    out = StreamController<UserData>(
      onListen: () {
        docSub = _doc.snapshots().listen((snap) {
          if (!snap.exists) {
            // First visit: stamp the programme start; the listener fires again.
            _doc.set({
              'startedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
          doc = snap.data() ?? <String, dynamic>{};
          emit();
        }, onError: out.addError);
        journalSub = _journal.snapshots().listen((snap) {
          journal = snap.docs
              .map((d) => JournalEntry.fromJson({...d.data(), 'id': d.id}))
              .toList();
          emit();
        }, onError: out.addError);
      },
      onCancel: () async {
        await docSub?.cancel();
        await journalSub?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<void> setCompleted(String day, String session, bool done) => _doc.set({
    'completed': {
      day: done
          ? FieldValue.arrayUnion([session])
          : FieldValue.arrayRemove([session]),
    },
  }, SetOptions(merge: true));

  @override
  Future<void> setSavedReading(String title, bool saved) => _doc.set({
    'savedReadings': saved
        ? FieldValue.arrayUnion([title])
        : FieldValue.arrayRemove([title]),
  }, SetOptions(merge: true));

  @override
  Future<void> setSavedHymn(String title, bool saved) => _doc.set({
    'savedHymns': saved
        ? FieldValue.arrayUnion([title])
        : FieldValue.arrayRemove([title]),
  }, SetOptions(merge: true));

  @override
  Future<void> addJournal(JournalEntry entry) =>
      _journal.doc(entry.id).set(entry.toJson()..remove('id'));

  @override
  Future<void> deleteJournal(String id) => _journal.doc(id).delete();

  @override
  Future<void> deleteAll() async {
    // Firestore doesn't delete subcollections with their parent document.
    final entries = await _journal.get();
    var batch = _db.batch();
    var n = 0;
    for (final d in entries.docs) {
      batch.delete(d.reference);
      if (++n == 450) {
        await batch.commit();
        batch = _db.batch();
        n = 0;
      }
    }
    batch.delete(_doc);
    await batch.commit();
  }

  @override
  Future<void> dispose() async {}
}
