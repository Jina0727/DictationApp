import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Per-word breakdown returned by Azure Pronunciation Assessment.
class WordScore {
  final String word;
  final double accuracyScore; // 0-100
  final String errorType;     // "None", "Mispronunciation", "Omission", "Insertion"
  WordScore({
    required this.word,
    required this.accuracyScore,
    required this.errorType,
  });
}

class PronunciationResult {
  final double pronunciationScore; // overall 0-100
  final double accuracyScore;
  final double fluencyScore;
  final double completenessScore;
  final String recognizedText;
  final List<WordScore> words;
  final String? koFeedback; // Korean coaching from Claude (optional)

  PronunciationResult({
    required this.pronunciationScore,
    required this.accuracyScore,
    required this.fluencyScore,
    required this.completenessScore,
    required this.recognizedText,
    required this.words,
    this.koFeedback,
  });
}

class PronunciationService {
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
      throw Exception('AZURE_SPEECH_KEY not set in .env');
    }
    if (azureRegion == null || azureRegion.isEmpty) {
      throw Exception('AZURE_SPEECH_REGION not set in .env');
    }

    final paConfig = jsonEncode({
      'ReferenceText': referenceText,
      'GradingSystem': 'HundredMark',
      'Granularity': 'Phoneme',
      'EnableMiscue': true,
    });
    final paHeader = base64Encode(utf8.encode(paConfig));

    final url = Uri.parse(
      'https://$azureRegion.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1'
      '?language=en-US&format=detailed',
    );

    final res = await http.post(
      url,
      headers: {
        'Ocp-Apim-Subscription-Key': azureKey,
        'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
        'Pronunciation-Assessment': paHeader,
        'Accept': 'application/json',
      },
      body: await wavFile.readAsBytes(),
    );

    if (res.statusCode != 200) {
      throw Exception('Azure ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final status = decoded['RecognitionStatus'] as String?;
    if (status != 'Success') {
      throw Exception('Recognition status: $status — try speaking clearly');
    }

    final nbest = (decoded['NBest'] as List).first as Map<String, dynamic>;
    final pa = nbest['PronunciationAssessment'] as Map<String, dynamic>;
    final wordsRaw = (nbest['Words'] as List?) ?? const [];

    final words = wordsRaw.map((w) {
      final m = w as Map<String, dynamic>;
      final wpa = (m['PronunciationAssessment'] as Map<String, dynamic>?) ?? {};
      return WordScore(
        word: m['Word'] as String,
        accuracyScore: (wpa['AccuracyScore'] as num?)?.toDouble() ?? 0,
        errorType: (wpa['ErrorType'] as String?) ?? 'None',
      );
    }).toList();

    return PronunciationResult(
      pronunciationScore:
          (pa['PronScore'] as num?)?.toDouble() ?? (pa['PronunciationScore'] as num?)?.toDouble() ?? 0,
      accuracyScore: (pa['AccuracyScore'] as num?)?.toDouble() ?? 0,
      fluencyScore: (pa['FluencyScore'] as num?)?.toDouble() ?? 0,
      completenessScore: (pa['CompletenessScore'] as num?)?.toDouble() ?? 0,
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

    final mispronouncedWords = result.words
        .where((w) =>
            w.errorType == 'Mispronunciation' ||
            (w.errorType == 'None' && w.accuracyScore < 70))
        .map((w) => '${w.word}(${w.accuracyScore.round()})')
        .toList();
    final omitted = result.words
        .where((w) => w.errorType == 'Omission')
        .map((w) => w.word)
        .toList();

    final summary = jsonEncode({
      'reference': referenceText,
      'recognized': result.recognizedText,
      'pronunciationScore': result.pronunciationScore.round(),
      'accuracy': result.accuracyScore.round(),
      'fluency': result.fluencyScore.round(),
      'completeness': result.completenessScore.round(),
      'mispronounced': mispronouncedWords,
      'omitted': omitted,
    });

    final body = jsonEncode({
      'model': 'claude-haiku-4-5-20251001',
      'max_tokens': 400,
      'system':
          'You are a pronunciation coach for Korean learners of English. '
          'You receive Azure Pronunciation Assessment scores. '
          'Return one short Korean coaching paragraph (2-3 sentences). '
          'Acknowledge strengths first, then point out 1-2 specific weak points '
          'with concrete tips relevant to common Korean-speaker patterns '
          '(e.g. L/R distinction, TH sounds, final consonants, vowel length). '
          'Tone: warm, concise, actionable. Korean only. No numbered lists.',
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
    return text.trim();
  }
}
