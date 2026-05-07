import '../models/models.dart';
import 'progress.dart';
import 'scraper.dart';

const int kDailyTarget = 10;

class DailyHydrated {
  final SentenceRef ref;
  final Challenge challenge;
  final String lessonName;
  final String? lessonYoutubeVideoId;
  const DailyHydrated({
    required this.ref,
    required this.challenge,
    required this.lessonName,
    this.lessonYoutubeVideoId,
  });
}

class DailyService {
  final Scraper scraper;
  final ProgressService progress;
  final Map<String, Lesson> _lessonCache = {};
  final Map<String, List<ExerciseSummary>> _listCache = {};

  DailyService({required this.scraper, required this.progress});

  Future<List<ExerciseSummary>> _listFor(Category cat) async {
    return _listCache[cat.slug] ??= await scraper.fetchExerciseList(cat);
  }

  Future<Lesson> _lesson(String exercisePath) async {
    return _lessonCache[exercisePath] ??= await scraper.fetchLesson(exercisePath);
  }

  Future<List<SentenceRef>> ensureTodaySet(DateTime today) async {
    final existing = progress.dailySetFor(today);
    if (existing != null && existing.isNotEmpty) {
      return existing
          .map(SentenceRef.tryParse)
          .whereType<SentenceRef>()
          .toList();
    }
    final refs = await _collectFromCursor(kDailyTarget);
    await progress.saveDailySet(today, refs.map((r) => r.id).toList());
    return refs;
  }

  Future<List<SentenceRef>> _collectFromCursor(int n) async {
    var cursor = progress.cursor ?? const DailyCursor(catSlug: 'short-stories');
    final out = <SentenceRef>[];
    var safety = 0;
    while (out.length < n && safety < 50) {
      safety++;
      final cat = kCategories.firstWhere(
        (c) => c.slug == cursor.catSlug,
        orElse: () => kCategories.first,
      );
      final list = await _listFor(cat);
      if (list.isEmpty) {
        cursor = _advanceCategory(cursor);
        continue;
      }

      String exercisePath = cursor.exercisePath ?? list.first.path;
      var lessonIdxInList = list.indexWhere((e) => e.path == exercisePath);
      if (lessonIdxInList < 0) {
        exercisePath = list.first.path;
        lessonIdxInList = 0;
      }

      Lesson lesson;
      try {
        lesson = await _lesson(exercisePath);
      } catch (_) {
        if (lessonIdxInList + 1 < list.length) {
          cursor = DailyCursor(
            catSlug: cursor.catSlug,
            exercisePath: list[lessonIdxInList + 1].path,
            sentenceIdx: 0,
          );
        } else {
          cursor = _advanceCategory(cursor);
        }
        continue;
      }

      var idx = cursor.sentenceIdx;
      while (out.length < n && idx < lesson.challenges.length) {
        out.add(SentenceRef(exercisePath: exercisePath, sentenceIdx: idx));
        idx++;
      }

      if (idx >= lesson.challenges.length) {
        if (lessonIdxInList + 1 < list.length) {
          cursor = DailyCursor(
            catSlug: cursor.catSlug,
            exercisePath: list[lessonIdxInList + 1].path,
            sentenceIdx: 0,
          );
        } else {
          cursor = _advanceCategory(cursor);
        }
      } else {
        cursor = DailyCursor(
          catSlug: cursor.catSlug,
          exercisePath: exercisePath,
          sentenceIdx: idx,
        );
      }
    }
    return out;
  }

  DailyCursor _advanceCategory(DailyCursor c) {
    final i = kCategories.indexWhere((cat) => cat.slug == c.catSlug);
    final next = kCategories[(i + 1) % kCategories.length];
    return DailyCursor(catSlug: next.slug);
  }

  Future<void> advanceCursorPast(List<SentenceRef> refs) async {
    if (refs.isEmpty) return;
    final last = refs.last;
    final cat = kCategories.firstWhere(
      (c) => last.exercisePath.contains('/exercises/${c.slug}/'),
      orElse: () => kCategories.first,
    );
    final list = await _listFor(cat);
    final lessonIdxInList = list.indexWhere((e) => e.path == last.exercisePath);
    final lesson = await _lesson(last.exercisePath);

    final nextIdx = last.sentenceIdx + 1;
    if (nextIdx < lesson.challenges.length) {
      await progress.setCursor(DailyCursor(
        catSlug: cat.slug,
        exercisePath: last.exercisePath,
        sentenceIdx: nextIdx,
      ));
      return;
    }
    if (lessonIdxInList >= 0 && lessonIdxInList + 1 < list.length) {
      await progress.setCursor(DailyCursor(
        catSlug: cat.slug,
        exercisePath: list[lessonIdxInList + 1].path,
        sentenceIdx: 0,
      ));
      return;
    }
    final nextCat = kCategories[(kCategories.indexOf(cat) + 1) % kCategories.length];
    await progress.setCursor(DailyCursor(catSlug: nextCat.slug));
  }

  Future<List<DailyHydrated>> hydrate(List<SentenceRef> refs) async {
    final out = <DailyHydrated>[];
    for (final r in refs) {
      try {
        final lesson = await _lesson(r.exercisePath);
        if (r.sentenceIdx >= lesson.challenges.length) continue;
        out.add(DailyHydrated(
          ref: r,
          challenge: lesson.challenges[r.sentenceIdx],
          lessonName: lesson.lessonName,
          lessonYoutubeVideoId: lesson.youtubeVideoId,
        ));
      } catch (_) {
        continue;
      }
    }
    return out;
  }
}
