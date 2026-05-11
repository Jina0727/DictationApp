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

/// LCS-based word diff so a single missing/extra word doesn't cascade into
/// every following word being marked wrong.
///
/// Example — answer: "what he called cosmic fireflies",
///           input:  "what called cosmic fireflies"
///   Position-based diff would mark called/cosmic/fireflies all wrong.
///   LCS-based diff marks only "he" as missing; the rest is OK.
///
/// After LCS alignment we run a small post-pass: an adjacent (extra → missing)
/// or (missing → extra) pair is collapsed into a single `wrong` token (the
/// learner's word displayed, the answer word used as the lookup key for the
/// dictionary sheet).
List<TokenDiff> diffWords(String input, String answer) {
  final inputTokens =
      normalizeAnswer(input).split(' ').where((w) => w.isNotEmpty).toList();
  final answerTokens =
      normalizeAnswer(answer).split(' ').where((w) => w.isNotEmpty).toList();
  final inputOriginal = input
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .split(' ')
      .where((w) => w.isNotEmpty)
      .toList();
  final answerOriginal = answer
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .split(' ')
      .where((w) => w.isNotEmpty)
      .toList();

  final m = inputTokens.length;
  final n = answerTokens.length;

  // Standard LCS DP on normalized tokens.
  final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      if (inputTokens[i - 1] == answerTokens[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] =
            dp[i - 1][j] >= dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
      }
    }
  }

  // Backtrack to produce ordered diff. We prefer answer order when both
  // skip directions are tied so the on-screen row reads as the correct sentence.
  final raw = <TokenDiff>[];
  var i = m, j = n;
  while (i > 0 && j > 0) {
    if (inputTokens[i - 1] == answerTokens[j - 1]) {
      // ok — display the answer original (preserves case/punctuation)
      raw.add(TokenDiff(
        answerOriginal[j - 1],
        answerOriginal[j - 1],
        TokenStatus.ok,
      ));
      i--;
      j--;
    } else if (dp[i - 1][j] >= dp[i][j - 1]) {
      // input has an extra word that's not in the LCS
      raw.add(TokenDiff(
        inputOriginal[i - 1],
        inputOriginal[i - 1],
        TokenStatus.extra,
      ));
      i--;
    } else {
      // answer has a word that input skipped
      raw.add(TokenDiff(
        answerOriginal[j - 1],
        answerOriginal[j - 1],
        TokenStatus.missing,
      ));
      j--;
    }
  }
  while (i > 0) {
    raw.add(TokenDiff(
      inputOriginal[i - 1],
      inputOriginal[i - 1],
      TokenStatus.extra,
    ));
    i--;
  }
  while (j > 0) {
    raw.add(TokenDiff(
      answerOriginal[j - 1],
      answerOriginal[j - 1],
      TokenStatus.missing,
    ));
    j--;
  }
  final ordered = raw.reversed.toList();

  // Post-pass: collapse adjacent (extra, missing) or (missing, extra) pairs
  // into a single `wrong` token — that's a substitution, the typical
  // "I typed the wrong word in this slot" case. Display = the answer word,
  // so the row still reads as the correct sentence.
  final out = <TokenDiff>[];
  var k = 0;
  while (k < ordered.length) {
    final cur = ordered[k];
    final nxt = k + 1 < ordered.length ? ordered[k + 1] : null;
    if (nxt != null &&
        ((cur.status == TokenStatus.extra && nxt.status == TokenStatus.missing) ||
         (cur.status == TokenStatus.missing && nxt.status == TokenStatus.extra))) {
      // Use the answer word as the visible text and as the lookup target.
      final answerWord = cur.status == TokenStatus.missing ? cur.text : nxt.text;
      out.add(TokenDiff(answerWord, answerWord, TokenStatus.wrong));
      k += 2;
    } else {
      out.add(cur);
      k++;
    }
  }
  return out;
}
