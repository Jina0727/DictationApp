import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Azure HundredMark grading is lenient — even noticeably bad pronunciation
/// often returns 80+. We squash the curve so the score reflects real differences
/// for accuracy/fluency/completeness. Prosody uses a much gentler curve since
/// it already penalizes mic re-recording loss heavily.
double _strict(double raw, {double exponent = 1.9}) {
  if (raw <= 0) return 0;
  if (raw >= 100) return 100;
  return 100 * math.pow(raw / 100, exponent).toDouble();
}

/// Per-word breakdown returned by Azure Pronunciation Assessment.
/// `errorType` can be: None, Mispronunciation, Omission, Insertion,
/// UnexpectedBreak (paused mid-word), MissingBreak (no pause where expected),
/// Monotone (flat intonation on this word).
class WordScore {
  final String word;
  final double accuracyScore; // 0-100
  final String errorType;
  final List<SyllableScore> syllables;
  final BreakFeedback? breakFeedback;
  final IntonationFeedback? intonationFeedback;
  WordScore({
    required this.word,
    required this.accuracyScore,
    required this.errorType,
    this.syllables = const [],
    this.breakFeedback,
    this.intonationFeedback,
  });
}

/// Syllable-level (and per-grapheme) accuracy from Azure.
class SyllableScore {
  final String syllable;   // pronounced syllable e.g. "tu-de"
  final String grapheme;   // spelled chunk e.g. "to-day"
  final double accuracyScore;
  const SyllableScore({
    required this.syllable,
    required this.grapheme,
    required this.accuracyScore,
  });
}

/// Word-level Break feedback (where pauses were unexpected or missing).
class BreakFeedback {
  /// e.g. "UnexpectedBreak", "MissingBreak", or null if normal.
  final String? errorType;
  final double? confidence;
  const BreakFeedback({this.errorType, this.confidence});
}

/// Word-level Intonation feedback (Monotone / pitch contour).
class IntonationFeedback {
  /// "Monotone" or null.
  final String? errorType;
  /// Stress level: e.g. "Strong" / "Weak" — useful for telling the learner
  /// which word should carry sentence stress.
  final String? stress;
  const IntonationFeedback({this.errorType, this.stress});
}

class PronunciationResult {
  final double pronunciationScore; // overall 0-100
  final double accuracyScore;      // phoneme-level accuracy
  final double fluencyScore;       // silent-break smoothness
  final double prosodyScore;       // stress/intonation/speed/rhythm (0 if not available)
  final double completenessScore;  // % of reference covered
  final String recognizedText;
  final List<WordScore> words;
  final String? koFeedback;        // Korean coaching from Claude (optional)

  PronunciationResult({
    required this.pronunciationScore,
    required this.accuracyScore,
    required this.fluencyScore,
    required this.prosodyScore,
    required this.completenessScore,
    required this.recognizedText,
    required this.words,
    this.koFeedback,
  });

  PronunciationResult copyWith({String? koFeedback}) => PronunciationResult(
        pronunciationScore: pronunciationScore,
        accuracyScore: accuracyScore,
        fluencyScore: fluencyScore,
        prosodyScore: prosodyScore,
        completenessScore: completenessScore,
        recognizedText: recognizedText,
        words: words,
        koFeedback: koFeedback ?? this.koFeedback,
      );
}

class PronunciationService {
  // Memory cache of TTS audio for the current app run.
  final Map<String, Uint8List> _ttsCache = {};

  /// Synthesize the given English word/phrase via Azure TTS, return the mp3
  /// bytes, and cache them in memory. Same Azure key/region as the
  /// pronunciation assessment endpoint — F0 free tier covers ~0.5M chars/month
  /// of neural voice, which is essentially unlimited for single-word lookups.
  Future<Uint8List> synthesizeWord(String word, {String voice = 'en-US-JennyNeural'}) async {
    final key = '$voice|${word.toLowerCase().trim()}';
    final cached = _ttsCache[key];
    if (cached != null) return cached;

    final azureKey = dotenv.env['AZURE_SPEECH_KEY']?.trim();
    final azureRegion = dotenv.env['AZURE_SPEECH_REGION']?.trim();
    if (azureKey == null || azureKey.isEmpty) {
      throw Exception('AZURE_SPEECH_KEY missing in .env');
    }
    if (azureRegion == null || azureRegion.isEmpty) {
      throw Exception('AZURE_SPEECH_REGION missing in .env');
    }

    // Escape characters that break SSML.
    final safe = word
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    final ssml =
        "<speak version='1.0' xml:lang='en-US'><voice name='$voice'>$safe</voice></speak>";

    final res = await http.post(
      Uri.parse(
          'https://$azureRegion.tts.speech.microsoft.com/cognitiveservices/v1'),
      headers: {
        'Ocp-Apim-Subscription-Key': azureKey,
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': 'audio-24khz-48kbitrate-mono-mp3',
        'User-Agent': 'dictation_app',
      },
      body: ssml,
    );

    if (res.statusCode != 200) {
      throw Exception('Azure TTS ${res.statusCode}: ${res.body}');
    }
    final bytes = res.bodyBytes;
    _ttsCache[key] = bytes;
    return bytes;
  }

  /// Save synthesized audio to a temp file and return the path. just_audio's
  /// setFilePath consumes a path; this is the easiest interop point.
  Future<String> synthesizeWordToTempFile(String word) async {
    final bytes = await synthesizeWord(word);
    final dir = await getTemporaryDirectory();
    final safe = word.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final f = File('${dir.path}/tts_$safe.mp3');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  /// Run pronunciation assessment on a recorded WAV file against the reference text.
  ///
  /// Audio must be 16kHz mono PCM WAV. Azure Speech endpoint is the
  /// region-scoped STT endpoint with a `Pronunciation-Assessment` header.
  Future<PronunciationResult> assess({
    required File wavFile,
    required String referenceText,
  }) async {
    final azureKey = dotenv.env['AZURE_SPEECH_KEY']?.trim();
    final azureRegion = dotenv.env['AZURE_SPEECH_REGION']?.trim();
    if (azureKey == null || azureKey.isEmpty) {
      throw Exception('AZURE_SPEECH_KEY missing in .env');
    }
    if (azureRegion == null || azureRegion.isEmpty) {
      throw Exception('AZURE_SPEECH_REGION missing in .env');
    }

    if (!wavFile.existsSync()) {
      throw Exception('Recording file not found: ${wavFile.path}');
    }
    final wavBytes = await wavFile.readAsBytes();
    if (wavBytes.length < 8 * 1024) {
      throw Exception(
          'Recording too short (${wavBytes.length} bytes). Hold Record and speak the sentence clearly for ~2-5 seconds.');
    }

    // Microsoft REST spec for Pronunciation Assessment header.
    //   - "Dimension":"Comprehensive" is required for accuracy/fluency/completeness scores.
    //   - "EnableMiscue" is documented as a *string* "True"/"False", not a bool.
    //   - "EnableProsodyAssessment" turns on stress/intonation/speed/rhythm scoring
    //     and adds new word-level error types: UnexpectedBreak, MissingBreak, Monotone.
    final paConfig = jsonEncode({
      'ReferenceText': referenceText,
      'GradingSystem': 'HundredMark',
      'Granularity': 'Phoneme',
      'Dimension': 'Comprehensive',
      'EnableMiscue': 'True',
      'EnableProsodyAssessment': 'True',
    });
    final paHeader = base64Encode(utf8.encode(paConfig));

    final url = Uri.parse(
      'https://$azureRegion.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1'
      '?language=en-US&format=detailed',
    );

    http.Response res;
    try {
      res = await http.post(
        url,
        headers: {
          'Ocp-Apim-Subscription-Key': azureKey,
          'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
          'Pronunciation-Assessment': paHeader,
          'Accept': 'application/json',
        },
        body: wavBytes,
      );
    } catch (e) {
      throw Exception('Network error reaching Azure ($azureRegion): $e');
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception(
          'Azure auth failed (${res.statusCode}). Check AZURE_SPEECH_KEY and AZURE_SPEECH_REGION in .env.');
    }
    if (res.statusCode != 200) {
      final preview =
          res.body.length > 300 ? '${res.body.substring(0, 300)}…' : res.body;
      throw Exception('Azure HTTP ${res.statusCode}: $preview');
    }

    Map<String, dynamic> decoded;
    try {
      final jsonStr = res.body;
      if (jsonStr.isEmpty) {
        throw Exception('Azure returned an empty response.');
      }
      decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Could not parse Azure response: $e');
    }

    final status = decoded['RecognitionStatus'] as String?;
    if (status != 'Success') {
      // Common non-Success values: InitialSilenceTimeout, BabbleTimeout,
      // NoMatch, Error. Map to a friendlier message.
      final hint = switch (status) {
        'InitialSilenceTimeout' =>
          'Silence detected at the start. Start speaking right after pressing Record.',
        'BabbleTimeout' => 'Too much background noise. Try a quieter spot.',
        'NoMatch' =>
          'Could not match any speech. Speak the sentence a bit louder and clearer.',
        _ => 'Try again with a clearer recording.',
      };
      throw Exception('Recognition: ${status ?? "unknown"} — $hint');
    }

    final nbestList = (decoded['NBest'] as List?) ?? const [];
    if (nbestList.isEmpty) {
      throw Exception('Azure returned no recognition results.');
    }
    final nbest = nbestList.first as Map<String, dynamic>;
    final wordsRaw = (nbest['Words'] as List?) ?? const [];

    // Azure puts pronunciation scores directly on the NBest entry (not in a
    // nested PronunciationAssessment object) — same for each word. We also
    // pull syllable/grapheme scores and prosody Feedback (Break, Intonation)
    // when they're present.
    //
    // Word-level scores are kept as Azure raw (no strictify): some specific
    // words ("finally", "excited", anything with schwa or weak final consonants)
    // routinely score in the high 80s even from native audio, because of mic
    // re-recording loss + Azure's conservative phoneme matching. Strictifying
    // those would penalize the learner for things they can't fix.
    // Aggregate scores (Overall/Accuracy/Fluency/Prosody/Completeness) keep
    // strictify so the learner still sees real variance in their attempts.
    final words = wordsRaw.map((w) {
      final m = w as Map<String, dynamic>;
      final raw = (m['AccuracyScore'] as num?)?.toDouble() ?? 0;

      final syllList = (m['Syllables'] as List?) ?? const [];
      final syllables = syllList.map((s) {
        final sm = s as Map<String, dynamic>;
        return SyllableScore(
          syllable: (sm['Syllable'] as String?) ?? '',
          grapheme: (sm['Grapheme'] as String?) ?? '',
          accuracyScore: (sm['AccuracyScore'] as num?)?.toDouble() ?? 0,
        );
      }).toList();

      final fb = m['Feedback'] as Map<String, dynamic>?;
      BreakFeedback? brk;
      IntonationFeedback? itn;
      if (fb != null) {
        final brkRaw = fb['Break'] as Map<String, dynamic>?;
        if (brkRaw != null) {
          brk = BreakFeedback(
            errorType: brkRaw['ErrorTypes'] is List
                ? (brkRaw['ErrorTypes'] as List).join(',')
                : brkRaw['ErrorType'] as String?,
            confidence: (brkRaw['BreakLength'] as num?)?.toDouble(),
          );
        }
        final itnRaw = fb['Intonation'] as Map<String, dynamic>?;
        if (itnRaw != null) {
          final mono = itnRaw['Monotone'] as Map<String, dynamic>?;
          itn = IntonationFeedback(
            errorType:
                mono != null ? 'Monotone' : itnRaw['ErrorType'] as String?,
            stress: itnRaw['ErrorTypes'] is List
                ? (itnRaw['ErrorTypes'] as List).join(',')
                : null,
          );
        }
      }

      return WordScore(
        word: (m['Word'] as String?) ?? '',
        accuracyScore: raw, // raw Azure score, no strictify
        errorType: (m['ErrorType'] as String?) ?? 'None',
        syllables: syllables,
        breakFeedback: brk,
        intonationFeedback: itn,
      );
    }).toList();

    final rawPron = (nbest['PronScore'] as num?)?.toDouble() ??
        (nbest['PronunciationScore'] as num?)?.toDouble() ??
        0;

    if (rawPron == 0 && words.isEmpty) {
      // Sanity check: header was probably ignored.
      final preview = res.body.length > 600
          ? '${res.body.substring(0, 600)}…'
          : res.body;
      throw Exception('No pronunciation scores returned. Raw: $preview');
    }

    return PronunciationResult(
      pronunciationScore: _strict(rawPron),
      accuracyScore: _strict((nbest['AccuracyScore'] as num?)?.toDouble() ?? 0),
      fluencyScore: _strict((nbest['FluencyScore'] as num?)?.toDouble() ?? 0),
      // Prosody: gentler curve (^1.3) — re-recording through speakers loses
      // intonation/rhythm fidelity, so the raw is already pessimistic.
      prosodyScore: _strict(
        (nbest['ProsodyScore'] as num?)?.toDouble() ?? 0,
        exponent: 1.3,
      ),
      completenessScore:
          _strict((nbest['CompletenessScore'] as num?)?.toDouble() ?? 0),
      recognizedText: (nbest['Display'] as String?) ?? '',
      words: words,
    );
  }

  /// Send raw scores to Claude (Haiku 4.5) and ask for short Korean coaching
  /// targeted at common Korean-speaker pronunciation patterns.
  Future<String> generateKoreanFeedback({
    required PronunciationResult result,
    required String referenceText,
  }) async {
    final apiKey = dotenv.env['ANTHROPIC_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('ANTHROPIC_API_KEY not set in .env');
    }

    // Words are now raw Azure scores; threshold tuned to that scale.
    final mispronouncedWords = result.words
        .where((w) =>
            w.errorType == 'Mispronunciation' ||
            (w.errorType == 'None' && w.accuracyScore < 75))
        .map((w) => '${w.word}(${w.accuracyScore.round()})')
        .toList();
    final omitted = result.words
        .where((w) => w.errorType == 'Omission')
        .map((w) => w.word)
        .toList();
    final unexpectedBreak = result.words
        .where((w) => w.errorType == 'UnexpectedBreak')
        .map((w) => w.word)
        .toList();
    final missingBreak = result.words
        .where((w) => w.errorType == 'MissingBreak')
        .map((w) => w.word)
        .toList();
    final monotone = result.words
        .where((w) => w.errorType == 'Monotone')
        .map((w) => w.word)
        .toList();

    // Build a richer per-word breakdown: include the weakest syllables of any
    // word with reduced accuracy. This lets Claude pinpoint the exact failing
    // sound rather than guessing from the word as a whole.
    final perWord = result.words.map((w) {
      final weakSyls = w.syllables
          .where((s) => s.accuracyScore < 80)
          .map((s) => '${s.grapheme}/${s.syllable}(${s.accuracyScore.round()})')
          .toList();
      return {
        'word': w.word,
        'accuracy': w.accuracyScore.round(),
        'errorType': w.errorType,
        if (weakSyls.isNotEmpty) 'weakSyllables': weakSyls,
        if (w.breakFeedback?.errorType != null)
          'breakIssue': w.breakFeedback!.errorType,
        if (w.intonationFeedback?.errorType != null)
          'intonationIssue': w.intonationFeedback!.errorType,
      };
    }).toList();

    final summary = jsonEncode({
      'reference': referenceText,
      'recognized': result.recognizedText,
      'overallScore': result.pronunciationScore.round(),
      'accuracyScore': result.accuracyScore.round(),
      'fluencyScore': result.fluencyScore.round(),
      'prosodyScore': result.prosodyScore.round(),
      'completenessScore': result.completenessScore.round(),
      'mispronounced': mispronouncedWords,
      'omitted': omitted,
      'unexpectedBreaks': unexpectedBreak,
      'missingBreaks': missingBreak,
      'monotoneWords': monotone,
      'perWord': perWord,
    });

    final body = jsonEncode({
      'model': 'claude-haiku-4-5-20251001',
      'max_tokens': 500,
      'system':
          'You are an expert English-pronunciation coach giving live feedback to ONE specific learner about the ONE recording they just made on a dictation app. The learner reads a target sentence aloud; Azure Speech returns scores, per-word error types, syllable-level scores, and prosody feedback.\n\n'
          'Inputs:\n'
          '- reference: the target sentence the learner tried to say\n'
          '- recognized: what Azure transcribed from the recording\n'
          '- overallScore (0-100): combined pronunciation quality\n'
          '- accuracyScore: phoneme-level correctness of individual sounds\n'
          '- fluencyScore: smoothness of silent breaks between words\n'
          '- prosodyScore: stress, intonation, speaking speed, rhythm — natural flow and accent\n'
          '- completenessScore: percent of reference text covered\n'
          '- mispronounced[]: words with wrong sounds\n'
          '- omitted[]: words the learner skipped\n'
          '- unexpectedBreaks[]: words where the learner paused mid-phrase awkwardly\n'
          '- missingBreaks[]: words where a natural pause was expected but missing\n'
          '- monotoneWords[]: words spoken with flat intonation\n'
          '- perWord[]: detailed per-word objects. Each has accuracy, errorType, optional weakSyllables (failing parts of the word like "to/tu(40)" meaning the spelled chunk "to" sounded as "tu" with 40% accuracy), breakIssue, intonationIssue.\n\n'
          'How to use perWord[].weakSyllables:\n'
          '- "ber/bə(45)" means the spelled chunk "ber" was pronounced as "bə" with 45% accuracy → the learner likely dropped the final r-sound. Mention the exact chunk and the failing sound.\n'
          '- This is your strongest signal. Prefer it over guessing from the word as a whole.\n\n'
          'Your job: deliver coaching that goes BEYOND surface phoneme accuracy. Comment on rhythm, stress, intonation, and flow as relevant. Use weakSyllables to be precise about WHERE inside a word the issue is.\n\n'
          'Rules:\n'
          '1. Speak directly about THIS attempt and THIS recording. Do NOT generalize ("한국인들은…", "한국 화자는…", "Koreans tend to…" are forbidden).\n'
          '2. Pick at most 2 things to comment on. Prioritize the lowest score / most-impactful weakness.\n'
          '3. For mispronounced words / weakSyllables: name the exact English word AND the failing chunk. Give a concrete tongue/lip/sound tip (where the tongue goes, lip shape, which sound is failing, what to listen for).\n'
          '4. For unexpectedBreaks / missingBreaks / low fluency: describe the rhythm problem and where to pause or connect.\n'
          '5. For monotoneWords / low prosody: name which words to stress, where pitch should rise or fall, or how the sentence melody should move.\n'
          '6. Praise specifically when warranted ("억양이 자연스러웠어요", "끝까지 끊김 없이 말했어요"). For overall ≥85 with no obvious weak words, give a brief, warm congratulation in one sentence.\n'
          '7. If recognized is empty or wildly different from reference, say so and suggest re-recording closer to the mic.\n'
          '8. Output: 2-3 sentences, plain Korean, no numbered/bulleted lists, no emojis.\n'
          '9. Keep English words/phrases in English (do NOT transliterate "November" to "노벰버").\n'
          '10. Friendly but not overly cheerful tone. Like a private tutor who notices things.\n'
          '11. NO markdown formatting at all. Do NOT use **bold**, *italic*, _underscore_, `code`, # headers, or any markdown syntax. Plain text only — your output is rendered raw.',
      'messages': [
        {'role': 'user', 'content': summary},
      ],
    });

    final res = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
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
    return _stripMarkdown(text.trim());
  }

  /// Strip common markdown markers Claude sometimes emits despite instructions.
  /// Keeps the text content intact.
  String _stripMarkdown(String s) {
    var out = s;
    // **bold** and *italic* — handle nested forms.
    out = out.replaceAll(RegExp(r'\*\*\*'), '');
    out = out.replaceAll(RegExp(r'\*\*'), '');
    out = out.replaceAll(RegExp(r'(?<!\w)\*(?!\s)'), '');
    out = out.replaceAll(RegExp(r'(?<!\s)\*(?!\w)'), '');
    // _underscore_ — only when wrapping non-space (avoid stripping URLs/IDs).
    out = out.replaceAll(RegExp(r'(?<!\w)_(?=\S)'), '');
    out = out.replaceAll(RegExp(r'(?<=\S)_(?!\w)'), '');
    // `code`
    out = out.replaceAll('`', '');
    // # headings at line start
    out = out.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');
    // - / * bullets at line start
    out = out.replaceAll(RegExp(r'^[\-\*]\s+', multiLine: true), '');
    return out.trim();
  }
}
