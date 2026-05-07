import 'dart:convert';
import 'package:html/parser.dart' as htmlparser;
import 'package:http/http.dart' as http;
import '../models/models.dart';

class Scraper {
  static const _ua =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 dictation_app/0.1';

  Future<String> _get(String url) async {
    final res = await http.get(Uri.parse(url), headers: {'User-Agent': _ua});
    if (res.statusCode != 200) {
      throw Exception('GET $url failed: ${res.statusCode}');
    }
    return res.body;
  }

  Future<List<ExerciseSummary>> fetchExerciseList(Category cat) async {
    final body = await _get(cat.url);
    final doc = htmlparser.parse(body);
    final items = <ExerciseSummary>[];
    String? currentSection;

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
      final path = href.startsWith('http')
          ? Uri.parse(href).path
          : href;
      final title = el.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (title.isEmpty) continue;
      if (items.any((e) => e.path == path)) continue;

      final levelMatch =
          RegExp(r'\b([ABC][12])\b').firstMatch(title);
      final partsMatch = RegExp(r'(\d+)\s*parts?').firstMatch(title);
      items.add(ExerciseSummary(
        title: title
            .replaceAll(RegExp(r'\s*\b[ABC][12]\b\s*'), ' ')
            .replaceAll(RegExp(r'\s*\d+\s*parts?\s*'), ' ')
            .trim(),
        path: path,
        vocabLevel: levelMatch?.group(1),
        partsCount: partsMatch != null ? int.parse(partsMatch.group(1)!) : null,
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
