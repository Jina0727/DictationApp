class Category {
  final String slug;
  final String name;
  const Category({required this.slug, required this.name});

  String get url => 'https://dailydictation.com/exercises/$slug';
}

const kCategories = <Category>[
  Category(slug: 'stories-for-kids', name: 'Stories for Kids'),
  Category(slug: 'short-stories', name: 'Short Stories'),
  Category(slug: 'english-conversations', name: 'Daily Conversations'),
  Category(slug: 'english-pronunciation', name: 'English Pronunciation'),
  Category(slug: 'ted-ed', name: 'TED-Ed'),
  Category(slug: 'news', name: 'News'),
  Category(slug: 'toeic', name: 'TOEIC Listening'),
  Category(slug: 'youtube', name: 'YouTube'),
  Category(slug: 'ielts-listening', name: 'IELTS Listening'),
  Category(slug: 'toefl-listening', name: 'TOEFL Listening'),
  Category(slug: 'medical-english-oet', name: 'Medical English OET'),
];

/// Meta about a category as scraped from the index page (/exercises).
class CategoryMeta {
  final String slug;
  final String displayName; // exact name shown on the site (e.g. "TED", "Random Videos")
  final String? levelRange; // e.g. "A1-C1"
  final String? description;
  final int? lessonCount;
  final bool isVideo;
  final String? imageUrl;

  const CategoryMeta({
    required this.slug,
    required this.displayName,
    this.levelRange,
    this.description,
    this.lessonCount,
    this.isVideo = false,
    this.imageUrl,
  });
}

class ExerciseSummary {
  final String title;
  final String path;
  final String? vocabLevel;
  final int? partsCount;
  final String? section;
  ExerciseSummary({
    required this.title,
    required this.path,
    this.vocabLevel,
    this.partsCount,
    this.section,
  });

  String get url => 'https://dailydictation.com$path';
  String get id => path;
}

class Challenge {
  final int id;
  final int position;
  final String content;
  final String audioSrc;       // empty string when source has no mp3 (e.g. YouTube)
  final double timeStart;
  final double timeEnd;
  final String? explanation;

  Challenge({
    required this.id,
    required this.position,
    required this.content,
    required this.audioSrc,
    required this.timeStart,
    required this.timeEnd,
    this.explanation,
  });

  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
        id: j['id'] as int,
        position: j['position'] as int,
        content: j['content'] as String,
        // Some categories (e.g. YouTube) return null. Coerce to '' so callers
        // can easily detect "no audio available".
        audioSrc: (j['audioSrc'] as String?) ?? '',
        timeStart: (j['timeStart'] as num).toDouble(),
        timeEnd: (j['timeEnd'] as num).toDouble(),
        explanation: j['explanation'] as String?,
      );
}

class SentenceRef {
  final String exercisePath;
  final int sentenceIdx;
  const SentenceRef({required this.exercisePath, required this.sentenceIdx});

  String get id => '$exercisePath#$sentenceIdx';

  static SentenceRef? tryParse(String id) {
    final i = id.lastIndexOf('#');
    if (i <= 0) return null;
    final idx = int.tryParse(id.substring(i + 1));
    if (idx == null) return null;
    return SentenceRef(exercisePath: id.substring(0, i), sentenceIdx: idx);
  }
}

class Lesson {
  final int lessonId;
  final String lessonName;
  final String fullAudioSrc;
  final String? youtubeVideoId; // present when source is a YouTube video
  final List<Challenge> challenges;
  final String? nextExerciseUrl;
  final String? previousExerciseUrl;

  Lesson({
    required this.lessonId,
    required this.lessonName,
    required this.fullAudioSrc,
    this.youtubeVideoId,
    required this.challenges,
    this.nextExerciseUrl,
    this.previousExerciseUrl,
  });

  bool get isYouTube => (youtubeVideoId ?? '').isNotEmpty;

  factory Lesson.fromAppGlobals(Map<String, dynamic> j) => Lesson(
        lessonId: j['lessonId'] as int,
        lessonName: j['lessonName'] as String,
        fullAudioSrc: (j['audioSrc'] as String?) ?? '',
        youtubeVideoId: j['youtubeVideoId'] as String?,
        challenges: (j['challenges'] as List)
            .map((c) => Challenge.fromJson(c as Map<String, dynamic>))
            .toList(),
        nextExerciseUrl: j['nextExerciseUrl'] as String?,
        previousExerciseUrl: j['previousExerciseUrl'] as String?,
      );
}
