class Category {
  final String slug;
  final String name;
  const Category({required this.slug, required this.name});

  String get url => 'https://dailydictation.com/exercises/$slug';
}

const kCategories = <Category>[
  Category(slug: 'short-stories', name: 'Short Stories'),
  Category(slug: 'english-conversations', name: 'Daily Conversations'),
  Category(slug: 'toeic', name: 'TOEIC Listening'),
  Category(slug: 'youtube', name: 'YouTube'),
  Category(slug: 'ielts-listening', name: 'IELTS Listening'),
  Category(slug: 'toefl-listening', name: 'TOEFL Listening'),
  Category(slug: 'spelling-names', name: 'Spelling Names'),
  Category(slug: 'numbers', name: 'Numbers'),
];

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
  final String audioSrc;
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
        audioSrc: j['audioSrc'] as String,
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
  final List<Challenge> challenges;
  final String? nextExerciseUrl;
  final String? previousExerciseUrl;

  Lesson({
    required this.lessonId,
    required this.lessonName,
    required this.fullAudioSrc,
    required this.challenges,
    this.nextExerciseUrl,
    this.previousExerciseUrl,
  });

  factory Lesson.fromAppGlobals(Map<String, dynamic> j) => Lesson(
        lessonId: j['lessonId'] as int,
        lessonName: j['lessonName'] as String,
        fullAudioSrc: j['audioSrc'] as String,
        challenges: (j['challenges'] as List)
            .map((c) => Challenge.fromJson(c as Map<String, dynamic>))
            .toList(),
        nextExerciseUrl: j['nextExerciseUrl'] as String?,
        previousExerciseUrl: j['previousExerciseUrl'] as String?,
      );
}
