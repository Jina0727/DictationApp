import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DictionaryEntry {
  final String word;
  final String ko;
  final String en;
  final List<String> examples;

  DictionaryEntry({
    required this.word,
    required this.ko,
    required this.en,
    required this.examples,
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'ko': ko,
        'en': en,
        'examples': examples,
      };

  factory DictionaryEntry.fromJson(Map<String, dynamic> j) => DictionaryEntry(
        word: j['word'] as String,
        ko: j['ko'] as String,
        en: j['en'] as String,
        examples:
            (j['examples'] as List).map((e) => e as String).toList(),
      );
}

class DictionaryService {
  static const _cacheKey = 'dd_dict_cache_v1';
  static const _savedKey = 'dd_dict_saved_v1';
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-haiku-4-5-20251001';
  static const _systemPrompt =
      'You are a dictionary helper for Korean English learners. '
      'Given an English word and a context sentence where it appears, return: '
      'ko (concise Korean meaning fitting the context, single phrase no punctuation), '
      'en (concise English definition, one short sentence), '
      'examples (exactly 2 different example sentences using the word, distinct from the context). '
      'Korean only in "ko". English only in "en" and "examples". '
      'Do not include the word itself as the value of "ko" or "en".';

  Map<String, DictionaryEntry> _cache = {};
  Set<String> _saved = {};
  bool _loaded = false;

  String _cacheKeyFor(String word) => word.toLowerCase().trim();

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKey);
    if (raw != null) {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _cache = m.map(
        (k, v) => MapEntry(k, DictionaryEntry.fromJson(v as Map<String, dynamic>)),
      );
    }
    _saved = (p.getStringList(_savedKey) ?? []).toSet();
    _loaded = true;
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _cacheKey,
      jsonEncode(_cache.map((k, v) => MapEntry(k, v.toJson()))),
    );
    await p.setStringList(_savedKey, _saved.toList());
  }

  DictionaryEntry? cached(String word) => _cache[_cacheKeyFor(word)];

  List<DictionaryEntry> get all => _cache.values.toList();

  // Wordbook (saved entries — manually curated by the user)
  Future<bool> isSaved(String word) async {
    await _ensureLoaded();
    return _saved.contains(_cacheKeyFor(word));
  }

  bool isSavedSync(String word) => _saved.contains(_cacheKeyFor(word));

  int get savedCount => _saved.length;

  Future<void> addToWordbook(String word) async {
    await _ensureLoaded();
    if (_saved.add(_cacheKeyFor(word))) await _persist();
  }

  Future<void> removeFromWordbook(String word) async {
    await _ensureLoaded();
    if (_saved.remove(_cacheKeyFor(word))) await _persist();
  }

  Future<void> toggleSaved(String word) async {
    await _ensureLoaded();
    final k = _cacheKeyFor(word);
    if (!_saved.add(k)) _saved.remove(k);
    await _persist();
  }

  Future<List<DictionaryEntry>> savedEntries() async {
    await _ensureLoaded();
    return _saved
        .map((k) => _cache[k])
        .whereType<DictionaryEntry>()
        .toList()
      ..sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
  }

  Future<DictionaryEntry> lookup({
    required String word,
    required String contextSentence,
  }) async {
    await _ensureLoaded();
    final key = _cacheKeyFor(word);
    final hit = _cache[key];
    if (hit != null) return hit;

    final apiKey = dotenv.env['ANTHROPIC_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
          'ANTHROPIC_API_KEY not set in .env');
    }

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 512,
      'system': _systemPrompt,
      'messages': [
        {
          'role': 'user',
          'content': 'Word: $word\nContext: $contextSentence',
        }
      ],
      'output_config': {
        'format': {
          'type': 'json_schema',
          'schema': {
            'type': 'object',
            'properties': {
              'ko': {'type': 'string'},
              'en': {'type': 'string'},
              'examples': {
                'type': 'array',
                'items': {'type': 'string'},
              },
            },
            'required': ['ko', 'en', 'examples'],
            'additionalProperties': false,
          },
        },
      },
    });

    final res = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: body,
    );

    if (res.statusCode != 200) {
      throw Exception('Claude API ${res.statusCode}: ${res.body}');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final content = decoded['content'] as List;
    final text = (content.firstWhere(
      (b) => (b as Map)['type'] == 'text',
      orElse: () => throw Exception('No text block in response'),
    ) as Map)['text'] as String;

    final parsed = jsonDecode(text) as Map<String, dynamic>;
    final entry = DictionaryEntry(
      word: word,
      ko: parsed['ko'] as String,
      en: parsed['en'] as String,
      examples: (parsed['examples'] as List).map((e) => e as String).toList(),
    );
    _cache[key] = entry;
    await _persist();
    return entry;
  }
}
