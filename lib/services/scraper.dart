import 'dart:convert';
import 'package:html/parser.dart' as htmlparser;
import 'package:http/http.dart' as http;
import '../models/models.dart';

class Scraper {
  static const _ua =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 dictation_app/0.1';

  // In-memory cache for category metas (index page is small but we want one round-trip per app run).
  Map<String, CategoryMeta>? _categoryMetasCache;

  Future<String> _get(String url) async {
    final res = await http.get(Uri.parse(url), headers: {'User-Agent': _ua});
    if (res.statusCode != 200) {
      throw Exception('GET $url failed: ${res.statusCode}');
    }
    return res.body;
  }

  Future<Map<String, CategoryMeta>> fetchCategoryMetas() async {
    if (_categoryMetasCache != null) return _categoryMetasCache!;
    final body = await _get('https://dailydictation.com/exercises');
    final doc = htmlparser.parse(body);
    final result = <String, CategoryMeta>{};
    // Each category is wrapped in `<div class="card ...">` whose body contains
    // an anchor `/exercises/<slug>`, an h2 name, optional Video badge, a
    // `Levels: ...` muted span, an `<N> lessons` span and a hidden
    // `<div id="course-desc-N"><p>...</p></div>` description block.
    for (final card in doc.querySelectorAll('.card')) {
      final link = card.querySelector('a[href*="/exercises/"]');
      final href = link?.attributes['href'] ?? '';
      final m = RegExp(r'/exercises/([^/"]+)$').firstMatch(href);
      if (m == null) continue;
      final slug = m.group(1)!;
      final h2a = card.querySelector('h2 a');
      final displayName = (h2a?.text ?? '').trim();
      if (displayName.isEmpty) continue;
      final isVideo =
          card.querySelectorAll('.badge').any((b) => b.text.trim() == 'Video');

      String? levelRange;
      int? lessonCount;
      for (final span in card.querySelectorAll('.text-muted span, span.text-muted')) {
        final t = span.text.trim();
        final levelMatch = RegExp(r'Levels?:\s*([A-C][12](?:\s*-\s*[A-C][12])?)').firstMatch(t);
        if (levelMatch != null) levelRange = levelMatch.group(1);
        final lessonMatch = RegExp(r'(\d+)\s*lessons?').firstMatch(t);
        if (lessonMatch != null) lessonCount = int.parse(lessonMatch.group(1)!);
      }

      String? description;
      final descBlock = card.querySelector('[id^="course-desc-"]');
      if (descBlock != null) {
        description = descBlock.text.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (description.isEmpty) description = null;
      }

      String? imageUrl;
      final img = card.querySelector('img');
      if (img != null) imageUrl = img.attributes['src'];

      result[slug] = CategoryMeta(
        slug: slug,
        displayName: displayName,
        levelRange: levelRange,
        description: description,
        lessonCount: lessonCount,
        isVideo: isVideo,
        imageUrl: imageUrl,
      );
    }
    _categoryMetasCache = result;
    return result;
  }

  Future<List<ExerciseSummary>> fetchExerciseList(Category cat) async {
    final body = await _get(cat.url);
    final doc = htmlparser.parse(body);
    final items = <ExerciseSummary>[];
    String? currentSection;

    // Walk the document in document order, switching `currentSection` when we
    // see an h2/h3/h4 that contains "Section". Anchors inside each lesson card
    // point to "/exercises/<slug>/.../listen-and-type"; the same card has a
    // sibling `.text-muted` div with "<N> parts · Vocab level: <X>".
    for (final el in doc.querySelectorAll('h2, h3, h4, a')) {
      final tag = el.localName ?? '';
      if (tag.startsWith('h')) {
        final t = el.text.trim();
        if (t.toLowerCase().contains('section')) currentSection = t;
        continue;
      }
      final href = el.attributes['href'] ?? '';
      if (!href.contains('/exercises/${cat.slug}/') ||
          !href.contains('/listen-and-type')) {
        continue;
      }
      final path = href.startsWith('http') ? Uri.parse(href).path : href;
      final title = el.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (title.isEmpty) continue;
      if (items.any((e) => e.path == path)) continue;

      // Look for sibling muted line near this anchor. The card layout puts a
      // `<div class="text-muted">N parts · Vocab level: X</div>` close to the
      // anchor. Walk up a couple of parents and search descendants.
      String? vocabLevel;
      int? partsCount;
      var node = el.parent;
      var depth = 0;
      while (node != null && depth < 4) {
        for (final muted in node.querySelectorAll('.text-muted')) {
          final t = muted.text.trim();
          final lv = RegExp(r'Vocab\s*level:\s*([A-C][12])').firstMatch(t);
          if (lv != null) vocabLevel ??= lv.group(1);
          final pm = RegExp(r'(\d+)\s*parts?').firstMatch(t);
          if (pm != null) partsCount ??= int.parse(pm.group(1)!);
        }
        if (vocabLevel != null && partsCount != null) break;
        node = node.parent;
        depth++;
      }
      // Fallback: parse from title (legacy categories).
      vocabLevel ??= RegExp(r'\b([ABC][12])\b').firstMatch(title)?.group(1);
      if (partsCount == null) {
        final m = RegExp(r'(\d+)\s*parts?').firstMatch(title);
        if (m != null) partsCount = int.parse(m.group(1)!);
      }

      items.add(ExerciseSummary(
        title: title
            .replaceAll(RegExp(r'\s*\b[ABC][12]\b\s*'), ' ')
            .replaceAll(RegExp(r'\s*\d+\s*parts?\s*'), ' ')
            .trim(),
        path: path,
        vocabLevel: vocabLevel,
        partsCount: partsCount,
        section: currentSection,
      ));
    }
    return items;
  }

  Future<Lesson> fetchLesson(String exercisePath) async {
    final url = exercisePath.startsWith('http')
        ? exercisePath
        : 'https://dailydictation.com$exercisePath';
    final body = await _get(url);

    final match = RegExp(
      r'window\.appGlobals\s*=\s*(\{.*?\});\s*</script>',
      dotAll: true,
    ).firstMatch(body);
    if (match == null) {
      throw Exception('appGlobals not found on page');
    }
    final jsonStr = match.group(1)!;
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    return Lesson.fromAppGlobals(data);
  }
}
