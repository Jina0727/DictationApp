import 'package:flutter/material.dart';
import '../main.dart';
import '../services/dictionary.dart';

class WordbookScreen extends StatefulWidget {
  const WordbookScreen({super.key});

  @override
  State<WordbookScreen> createState() => _WordbookScreenState();
}

class _WordbookScreenState extends State<WordbookScreen> {
  List<DictionaryEntry>? _entries;
  Object? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await dictionary.savedEntries();
      if (!mounted) return;
      setState(() => _entries = entries);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _remove(String word) async {
    await dictionary.removeFromWordbook(word);
    if (!mounted) return;
    setState(() {
      _entries = _entries
          ?.where((e) => e.word.toLowerCase() != word.toLowerCase())
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('단어장'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load:\n$_error', textAlign: TextAlign.center),
        ),
      );
    }
    final all = _entries;
    if (all == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (all.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Empty.\nTap a wrong word during dictation and add it from the meaning sheet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final filtered = _query.trim().isEmpty
        ? all
        : all
            .where((e) =>
                e.word.toLowerCase().contains(_query.toLowerCase()))
            .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search saved words',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _WordCard(
              key: ValueKey(filtered[i].word.toLowerCase()),
              entry: filtered[i],
              onRemove: _remove,
            ),
          ),
        ),
      ],
    );
  }
}

class _WordCard extends StatelessWidget {
  final DictionaryEntry entry;
  final Future<void> Function(String word) onRemove;
  const _WordCard({super.key, required this.entry, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    entry.word,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove from wordbook',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onRemove(entry.word),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(entry.ko, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 6),
            Text(
              entry.en,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (entry.examples.isNotEmpty) ...[
              const Divider(height: 20),
              ...entry.examples.map((ex) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(
                          child: Text(
                            ex,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
