import 'dart:io';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _evaluate();
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
        _result = PronunciationResult(
          pronunciationScore: r.pronunciationScore,
          accuracyScore: r.accuracyScore,
          fluencyScore: r.fluencyScore,
          completenessScore: r.completenessScore,
          recognizedText: r.recognizedText,
          words: r.words,
          koFeedback: fb,
        );
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Failed: ${_error ?? "unknown"}',
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 8),
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
              Text('Per-word',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: r.words.map((w) {
                  Color bg;
                  if (w.errorType == 'Omission') {
                    bg = Colors.orangeAccent.withValues(alpha: 0.3);
                  } else if (w.errorType == 'Insertion') {
                    bg = Colors.purpleAccent.withValues(alpha: 0.25);
                  } else if (w.accuracyScore >= 80) {
                    bg = Colors.greenAccent.withValues(alpha: 0.25);
                  } else if (w.accuracyScore >= 60) {
                    bg = Colors.amber.withValues(alpha: 0.3);
                  } else {
                    bg = Colors.redAccent.withValues(alpha: 0.3);
                  }
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${w.word} ${w.accuracyScore.round()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            Text('한국어 코칭',
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
