import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../main.dart';
import '../services/pronunciation.dart';

Future<void> showPronunciationCheckSheet({
  required BuildContext context,
  required File wavFile,
  required String referenceText,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _PronunciationCheckSheet(
      wavFile: wavFile,
      referenceText: referenceText,
    ),
  );
}

class _PronunciationCheckSheet extends StatefulWidget {
  final File wavFile;
  final String referenceText;
  const _PronunciationCheckSheet({
    required this.wavFile,
    required this.referenceText,
  });

  @override
  State<_PronunciationCheckSheet> createState() =>
      _PronunciationCheckSheetState();
}

enum _Stage { processing, done, error }

class _PronunciationCheckSheetState extends State<_PronunciationCheckSheet> {
  _Stage _stage = _Stage.processing;
  PronunciationResult? _result;
  Object? _error;
  bool _gettingFeedback = false;

  // TTS playback for tapping words.
  final _ttsPlayer = AudioPlayer();
  String? _playingWord;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  @override
  void dispose() {
    _ttsPlayer.dispose();
    super.dispose();
  }

  Future<void> _playWord(String word) async {
    if (word.isEmpty) return;
    try {
      // If currently playing the same word, treat as stop.
      if (_playingWord == word) {
        await _ttsPlayer.stop();
        if (mounted) setState(() => _playingWord = null);
        return;
      }
      setState(() => _playingWord = word);
      final path = await pronunciation.synthesizeWordToTempFile(word);
      await _ttsPlayer.setFilePath(path);
      await _ttsPlayer.play();
      // Reset highlight when playback completes.
      _ttsPlayer.processingStateStream
          .firstWhere((s) => s == ProcessingState.completed)
          .then((_) {
        if (mounted) setState(() => _playingWord = null);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _playingWord = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('TTS failed: $e')),
      );
    }
  }

  Future<void> _evaluate() async {
    setState(() {
      _stage = _Stage.processing;
      _result = null;
      _error = null;
    });
    try {
      final result = await pronunciation.assess(
        wavFile: widget.wavFile,
        referenceText: widget.referenceText,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _stage = _Stage.done;
      });
      _fetchKoreanFeedback();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = e;
      });
    }
  }

  Future<void> _fetchKoreanFeedback() async {
    final r = _result;
    if (r == null) return;
    setState(() => _gettingFeedback = true);
    try {
      final fb = await pronunciation.generateKoreanFeedback(
        result: r,
        referenceText: widget.referenceText,
      );
      if (!mounted) return;
      setState(() {
        _result = r.copyWith(koFeedback: fb);
        _gettingFeedback = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _gettingFeedback = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pronunciation check',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.referenceText,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 16),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case _Stage.processing:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Evaluating with Azure Speech…'),
            ],
          ),
        );
      case _Stage.error:
        final msg = _error == null
            ? 'Unknown error'
            : (_error is Exception
                ? _error.toString().replaceFirst('Exception: ', '')
                : _error.toString());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pronunciation check failed',
              style: TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(msg, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _evaluate,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        );
      case _Stage.done:
        final r = _result!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ScoreRow(label: 'Overall', score: r.pronunciationScore, big: true),
            const SizedBox(height: 4),
            _ScoreRow(label: 'Accuracy', score: r.accuracyScore),
            _ScoreRow(label: 'Fluency', score: r.fluencyScore),
            if (r.prosodyScore > 0)
              _ScoreRow(label: 'Prosody', score: r.prosodyScore),
            _ScoreRow(label: 'Completeness', score: r.completenessScore),
            const SizedBox(height: 12),
            Text('What Azure heard',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              r.recognizedText.isEmpty ? '(silence)' : r.recognizedText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (r.words.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('Per-word',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(width: 8),
                  Text('tap to hear',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: r.words.map((w) {
                  Color bg;
                  String? badge;
                  if (w.errorType == 'Omission') {
                    bg = Colors.orangeAccent.withValues(alpha: 0.30);
                    badge = '✕'; // skipped
                  } else if (w.errorType == 'Insertion') {
                    bg = Colors.purpleAccent.withValues(alpha: 0.25);
                    badge = '+';
                  } else if (w.errorType == 'UnexpectedBreak') {
                    bg = Colors.cyanAccent.withValues(alpha: 0.25);
                    badge = '||'; // awkward pause
                  } else if (w.errorType == 'MissingBreak') {
                    bg = Colors.tealAccent.withValues(alpha: 0.22);
                    badge = '~';
                  } else if (w.errorType == 'Monotone') {
                    bg = Colors.blueAccent.withValues(alpha: 0.22);
                    badge = '—'; // flat
                  } else if (w.errorType == 'Mispronunciation' ||
                      w.accuracyScore < 60) {
                    bg = Colors.redAccent.withValues(alpha: 0.30);
                  } else if (w.accuracyScore >= 80) {
                    bg = Colors.greenAccent.withValues(alpha: 0.25);
                  } else {
                    bg = Colors.amber.withValues(alpha: 0.30);
                  }
                  final isPlaying = _playingWord == w.word;
                  return InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _playWord(w.word),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(4),
                        border: isPlaying
                            ? Border.all(
                                color: Colors.white.withValues(alpha: 0.7),
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPlaying ? Icons.volume_up : Icons.play_arrow,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            badge != null
                                ? '${w.word} $badge'
                                : '${w.word} ${w.accuracyScore.round()}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            Text('코칭',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            if (_gettingFeedback)
              const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Generating…'),
                ],
              )
            else
              Text(
                r.koFeedback ?? '(피드백 생성 실패)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 8),
            Text(
              'Tip: 다시 녹음하려면 이 시트를 닫고 셰도잉 카드의 Re-record를 누르세요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        );
    }
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final double score;
  final bool big;
  const _ScoreRow({required this.label, required this.score, this.big = false});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (score >= 80) {
      color = Colors.greenAccent.shade400;
    } else if (score >= 60) {
      color = Colors.amber.shade400;
    } else {
      color = Colors.redAccent.shade200;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: big ? 16 : 13,
                fontWeight: big ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: big ? 8 : 6,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              score.round().toString(),
              style: TextStyle(
                fontSize: big ? 16 : 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
