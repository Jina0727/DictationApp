import 'package:flutter/material.dart';
import '../main.dart';
import '../services/dictionary.dart';

Future<void> showDictionarySheet({
  required BuildContext context,
  required String word,
  required String contextSentence,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _DictionarySheet(
      word: word,
      contextSentence: contextSentence,
    ),
  );
}

class _DictionarySheet extends StatefulWidget {
  final String word;
  final String contextSentence;
  const _DictionarySheet({
    required this.word,
    required this.contextSentence,
  });

  @override
  State<_DictionarySheet> createState() => _DictionarySheetState();
}

class _DictionarySheetState extends State<_DictionarySheet> {
  Future<DictionaryEntry>? _future;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _saved = dictionary.isSavedSync(widget.word);
    _future = dictionary.lookup(
      word: widget.word,
      contextSentence: widget.contextSentence,
    );
  }

  void _retry() {
    setState(() {
      _future = dictionary.lookup(
        word: widget.word,
        contextSentence: widget.contextSentence,
      );
    });
  }

  Future<void> _toggleSave() async {
    if (_saved) {
      await dictionary.removeFromWordbook(widget.word);
    } else {
      await dictionary.addToWordbook(widget.word);
    }
    if (!mounted) return;
    setState(() => _saved = !_saved);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: FutureBuilder<DictionaryEntry>(
        future: _future,
        builder: (context, snap) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    widget.word,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(width: 8),
                  if (snap.connectionState != ConnectionState.done)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (snap.connectionState != ConnectionState.done) ...[
                const Text('Looking up…'),
              ] else if (snap.hasError) ...[
                Text(
                  'Lookup failed',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.redAccent,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${snap.error}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ] else ...[
                _Section(label: '뜻 (Korean)', body: snap.data!.ko),
                const SizedBox(height: 12),
                _Section(label: 'Definition (English)', body: snap.data!.en),
                const SizedBox(height: 12),
                Text('Examples',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: 6),
                ...snap.data!.examples.map((ex) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(ex)),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: _saved
                      ? OutlinedButton.icon(
                          onPressed: _toggleSave,
                          icon: const Icon(Icons.bookmark),
                          label: const Text('Saved — tap to remove'),
                        )
                      : FilledButton.icon(
                          onPressed: _toggleSave,
                          icon: const Icon(Icons.bookmark_add_outlined),
                          label: const Text('단어장에 추가'),
                        ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final String body;
  const _Section({required this.label, required this.body});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                )),
        const SizedBox(height: 4),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}
