import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum SpeedTier { x10, x15 }

extension SpeedTierKey on SpeedTier {
  String get key => this == SpeedTier.x10 ? '1.0x' : '1.5x';
  double get value => this == SpeedTier.x10 ? 1.0 : 1.5;
}

String dateKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

class DailyCursor {
  final String catSlug;
  final String? exercisePath;
  final int sentenceIdx;
  const DailyCursor({
    required this.catSlug,
    this.exercisePath,
    this.sentenceIdx = 0,
  });

  Map<String, dynamic> toJson() => {
        'catSlug': catSlug,
        'exercisePath': exercisePath,
        'sentenceIdx': sentenceIdx,
      };

  factory DailyCursor.fromJson(Map<String, dynamic> j) => DailyCursor(
        catSlug: j['catSlug'] as String,
        exercisePath: j['exercisePath'] as String?,
        sentenceIdx: j['sentenceIdx'] as int? ?? 0,
      );
}

class ProgressService {
  static const _key = 'dd_progress_v1';
  static const _favKey = 'dd_favorites_v1';
  static const _recentKey = 'dd_recent_v1';
  static const _wrongsKey = 'dd_wrongs_v1';
  static const _cursorKey = 'dd_cursor_v1';
  static const _dailySetsKey = 'dd_daily_sets_v1';
  static const _dailyDoneKey = 'dd_daily_done_v1';

  Map<String, Set<String>> _progress = {};
  Set<String> _favorites = {};
  List<String> _recent = [];
  Set<String> _wrongs = {};
  DailyCursor? _cursor;
  Map<String, List<String>> _dailySets = {};
  Map<String, Set<String>> _dailyDone = {};

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw != null) {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _progress = m.map(
        (k, v) => MapEntry(k, (v as List).map((e) => e as String).toSet()),
      );
    }
    _favorites = (p.getStringList(_favKey) ?? []).toSet();
    _recent = p.getStringList(_recentKey) ?? [];
    _wrongs = (p.getStringList(_wrongsKey) ?? []).toSet();

    final cursorRaw = p.getString(_cursorKey);
    if (cursorRaw != null) {
      _cursor = DailyCursor.fromJson(jsonDecode(cursorRaw));
    }

    final setsRaw = p.getString(_dailySetsKey);
    if (setsRaw != null) {
      final m = jsonDecode(setsRaw) as Map<String, dynamic>;
      _dailySets = m.map((k, v) => MapEntry(k, (v as List).map((e) => e as String).toList()));
    }

    final doneRaw = p.getString(_dailyDoneKey);
    if (doneRaw != null) {
      final m = jsonDecode(doneRaw) as Map<String, dynamic>;
      _dailyDone = m.map((k, v) => MapEntry(k, (v as List).map((e) => e as String).toSet()));
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _key,
      jsonEncode(_progress.map((k, v) => MapEntry(k, v.toList()))),
    );
    await p.setStringList(_favKey, _favorites.toList());
    await p.setStringList(_recentKey, _recent);
    await p.setStringList(_wrongsKey, _wrongs.toList());
    if (_cursor != null) {
      await p.setString(_cursorKey, jsonEncode(_cursor!.toJson()));
    }
    await p.setString(
      _dailySetsKey,
      jsonEncode(_dailySets),
    );
    await p.setString(
      _dailyDoneKey,
      jsonEncode(_dailyDone.map((k, v) => MapEntry(k, v.toList()))),
    );
  }

  bool isCompleted(String exerciseId, SpeedTier tier) =>
      _progress[exerciseId]?.contains(tier.key) ?? false;

  Future<void> markCompleted(String exerciseId, SpeedTier tier) async {
    _progress.putIfAbsent(exerciseId, () => <String>{}).add(tier.key);
    await _save();
  }

  bool isFavorite(String exerciseId) => _favorites.contains(exerciseId);

  Future<void> toggleFavorite(String exerciseId) async {
    if (!_favorites.add(exerciseId)) _favorites.remove(exerciseId);
    await _save();
  }

  List<String> get recent => List.unmodifiable(_recent);
  Set<String> get favorites => Set.unmodifiable(_favorites);

  Future<void> pushRecent(String exerciseId) async {
    _recent.remove(exerciseId);
    _recent.insert(0, exerciseId);
    if (_recent.length > 20) _recent = _recent.sublist(0, 20);
    await _save();
  }

  // Wrongs
  Set<String> get wrongs => Set.unmodifiable(_wrongs);
  bool isWrong(String sentenceId) => _wrongs.contains(sentenceId);

  Future<void> addWrong(String sentenceId) async {
    if (_wrongs.add(sentenceId)) await _save();
  }

  Future<void> removeWrong(String sentenceId) async {
    if (_wrongs.remove(sentenceId)) await _save();
  }

  // Daily cursor
  DailyCursor? get cursor => _cursor;

  Future<void> setCursor(DailyCursor c) async {
    _cursor = c;
    await _save();
  }

  // Daily sets
  List<String>? dailySetFor(DateTime d) => _dailySets[dateKey(d)];

  Future<void> saveDailySet(DateTime d, List<String> ids) async {
    _dailySets[dateKey(d)] = ids;
    await _save();
  }

  // Daily completion (per sentence)
  Set<String> dailyDoneFor(DateTime d) =>
      Set.unmodifiable(_dailyDone[dateKey(d)] ?? const <String>{});

  Future<void> markDailyDone(DateTime d, String sentenceId) async {
    final k = dateKey(d);
    _dailyDone.putIfAbsent(k, () => <String>{}).add(sentenceId);
    await _save();
  }

  bool isDayFullyDone(DateTime d) {
    final set = _dailySets[dateKey(d)];
    if (set == null || set.isEmpty) return false;
    final done = _dailyDone[dateKey(d)] ?? const <String>{};
    return set.every(done.contains);
  }

  int dailyDoneCount(DateTime d) => (_dailyDone[dateKey(d)] ?? const <String>{}).length;

  Map<String, List<String>> get allDailySets => Map.unmodifiable(_dailySets);

  // Stats
  bool _isFullyDoneByKey(String key) {
    final set = _dailySets[key];
    if (set == null || set.isEmpty) return false;
    final done = _dailyDone[key] ?? const <String>{};
    return set.every(done.contains);
  }

  int get totalCompletedDays {
    var count = 0;
    for (final k in _dailySets.keys) {
      if (_isFullyDoneByKey(k)) count++;
    }
    return count;
  }

  int get totalSentencesDone {
    final all = <String>{};
    for (final ids in _dailyDone.values) {
      all.addAll(ids);
    }
    return all.length;
  }

  int currentStreak() {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day);
    if (!isDayFullyDone(d)) {
      d = d.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (isDayFullyDone(d)) {
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
