import 'package:flutter/material.dart';
import '../utils/answer_check.dart';
import 'dictionary_sheet.dart';

class AnswerResultCard extends StatelessWidget {
  final String userInput;
  final String answer;
  const AnswerResultCard({super.key, required this.userInput, required this.answer});

  @override
  Widget build(BuildContext context) {
    final correct = isAnswerCorrect(userInput, answer);
    final scheme = Theme.of(context).colorScheme;
    final headerColor = correct ? Colors.greenAccent.shade400 : Colors.redAccent.shade200;

    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  correct ? Icons.check_circle : Icons.cancel,
                  color: headerColor,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  correct ? 'Correct' : 'Wrong',
                  style: TextStyle(
                    color: headerColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!correct)
                  Text(
                    'Tap a wrong word for meaning',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Correct Answer', style: Theme.of(context).textTheme.labelSmall),
            Text(answer, style: Theme.of(context).textTheme.titleMedium),
            if (userInput.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Your Answer', style: Theme.of(context).textTheme.labelSmall),
              _DiffText(userInput: userInput, answer: answer),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiffText extends StatelessWidget {
  final String userInput;
  final String answer;
  const _DiffText({required this.userInput, required this.answer});

  @override
  Widget build(BuildContext context) {
    final tokens = diffWords(userInput, answer);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tokens.map((t) {
        Color? bg;
        Color? fg;
        switch (t.status) {
          case TokenStatus.ok:
            bg = Colors.greenAccent.withValues(alpha: 0.2);
            fg = Colors.greenAccent.shade400;
            break;
          case TokenStatus.wrong:
            bg = Colors.redAccent.withValues(alpha: 0.25);
            fg = Colors.redAccent.shade100;
            break;
          case TokenStatus.missing:
            bg = Colors.orangeAccent.withValues(alpha: 0.25);
            fg = Colors.orangeAccent.shade200;
            break;
          case TokenStatus.extra:
            bg = Colors.purpleAccent.withValues(alpha: 0.2);
            fg = Colors.purpleAccent.shade100;
            break;
        }

        final isLookupable = t.status == TokenStatus.wrong ||
            t.status == TokenStatus.missing;
        final displayText =
            t.status == TokenStatus.missing ? '_${t.text}' : t.text;
        final lookupWord = _stripPunct(t.lookupWord);

        final chip = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            displayText,
            style: TextStyle(color: fg, fontWeight: FontWeight.w500),
          ),
        );

        if (!isLookupable || lookupWord.isEmpty) return chip;

        return InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => showDictionarySheet(
            context: context,
            word: lookupWord,
            contextSentence: answer,
          ),
          child: chip,
        );
      }).toList(),
    );
  }

  String _stripPunct(String s) =>
      s.replaceAll(RegExp(r"[^A-Za-z0-9'\-]"), '').trim();
}
