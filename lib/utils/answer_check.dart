String normalizeAnswer(String s) {
  return s
      .toLowerCase()
      .replaceAll('.', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool isAnswerCorrect(String input, String answer) {
  if (input.trim().isEmpty) return false;
  return normalizeAnswer(input) == normalizeAnswer(answer);
}

enum TokenStatus { ok, wrong, missing, extra }

class TokenDiff {
  final String text;        // what to display
  final String lookupWord;  // what to look up in the dictionary on tap
  final TokenStatus status;
  const TokenDiff(this.text, this.lookupWord, this.status);
}

List<TokenDiff> diffWords(String input, String answer) {
  final inputTokens = normalizeAnswer(input).split(' ').where((w) => w.isNotEmpty).toList();
  final answerTokens = normalizeAnswer(answer).split(' ').where((w) => w.isNotEmpty).toList();
  final inputOriginalTokens =
      input.replaceAll(RegExp(r'\s+'), ' ').trim().split(' ').where((w) => w.isNotEmpty).toList();
  final answerOriginalTokens =
      answer.replaceAll(RegExp(r'\s+'), ' ').trim().split(' ').where((w) => w.isNotEmpty).toList();

  final result = <TokenDiff>[];
  final maxLen = inputTokens.length > answerTokens.length ? inputTokens.length : answerTokens.length;

  for (var i = 0; i < maxLen; i++) {
    final inWord = i < inputTokens.length ? inputTokens[i] : null;
    final inDisplay = i < inputOriginalTokens.length ? inputOriginalTokens[i] : (inWord ?? '');
    final ansWord = i < answerTokens.length ? answerTokens[i] : null;
    final ansDisplay = i < answerOriginalTokens.length ? answerOriginalTokens[i] : (ansWord ?? '');

    if (inWord == null && ansWord != null) {
      // user skipped this word — show the missing answer word
      result.add(TokenDiff(ansDisplay, ansDisplay, TokenStatus.missing));
    } else if (ansWord == null && inWord != null) {
      // user typed an extra word — show their input
      result.add(TokenDiff(inDisplay, inDisplay, TokenStatus.extra));
    } else if (inWord == ansWord) {
      // match — display answer original (preserves case/punctuation)
      result.add(TokenDiff(ansDisplay, ansDisplay, TokenStatus.ok));
    } else {
      // wrong — display the answer word (so the row reads as the correct
      // sentence with mistakes highlighted in place); look up the answer word
      result.add(TokenDiff(ansDisplay, ansDisplay, TokenStatus.wrong));
    }
  }
  return result;
}
