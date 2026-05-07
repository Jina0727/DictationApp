import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/daily.dart';
import '../utils/answer_check.dart';
import '../widgets/answer_result_card.dart';
import '../widgets/empty_state.dart';

class WrongAnswersScreen extends StatefulWidget {
  const WrongAnswersScreen({super.key});

  @override
  State<WrongAnswersScreen> createState() => _WrongAnswersScreenState();
}

class _WrongAnswersScreenState extends State<WrongAnswersScreen> {
  List<DailyHydrated>? _items;
  Object? _error;

  final _player = AudioPlayer();
  final _input = TextEditingController();

  int _idx = 0;
  bool _revealed = false;
  int _listenCount = 0;
  String? _loadedAudioFor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ids = progress.wrongs.toList();
      final refs = ids
          .map(SentenceRef.tryParse)
          .whereType<SentenceRef>()
          .toList();
      final hydrated = await daily.hydrate(refs);
      if (!mounted) return;
      setState(() => _items = hydrated);
      _prepareAudio();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  DailyHydrated? get _current => _items != null && _items!.isNotEmpty && _idx < _items!.length
      ? _items![_idx]
      : null;

  Future<void> _prepareAudio() async {
    final h = _current;
    if (h == null) return;
    final url = h.challenge.audioSrc;
    if (_loadedAudioFor != url) {
      try {
        await _player.setUrl(url);
        _loadedAudioFor = url;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Audio load failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _play() async {
    await _prepareAudio();
    await _player.seek(Duration.zero);
    await _player.play();
    setState(() => _listenCount++);
  }

  Future<void> _reveal() async {
    final h = _current;
    if (h == null) return;
    final correct = isAnswerCorrect(_input.text, h.challenge.content);
    if (correct) {
      await progress.removeWrong(h.ref.id);
    }
    setState(() => _revealed = true);
  }

  Future<void> _next() async {
    if (_items == null) return;
    if (_idx + 1 < _items!.length) {
      setState(() {
        _idx++;
        _revealed = false;
        _listenCount = 0;
        _input.clear();
      });
      await _prepareAudio();
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wrong answers')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load:\n$_error', textAlign: TextAlign.center),
        )),
      );
    }
    if (_items == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_items!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wrong answers')),
        body: const EmptyState(
          emoji: '🎉',
          title: 'No mistakes to review',
          body: "You're doing great. New ones will collect here.",
        ),
      );
    }
    final h = _current;
    if (h == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wrong answers')),
        body: const Center(child: Text('All cleared!')),
      );
    }
    final c = h.challenge;
    final total = _items!.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Wrong answers  ·  ${_idx + 1}/$total'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(h.lessonName,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (_idx + 1) / total),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filled(
                        iconSize: 48,
                        onPressed: _play,
                        icon: const Icon(Icons.play_arrow),
                      ),
                      const SizedBox(width: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Listened', style: Theme.of(context).textTheme.bodySmall),
                          Text('$_listenCount',
                              style: Theme.of(context).textTheme.headlineMedium),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _input,
                enabled: !_revealed,
                maxLines: 3,
                minLines: 2,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: _revealed ? 'Locked' : 'Try again',
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (!_revealed)
                OutlinedButton.icon(
                  onPressed: _reveal,
                  icon: const Icon(Icons.visibility),
                  label: const Text('Reveal answer'),
                ),
              if (_revealed) ...[
                AnswerResultCard(userInput: _input.text, answer: c.content),
                const SizedBox(height: 8),
                if (isAnswerCorrect(_input.text, c.content))
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Removed from wrong-answers list.',
                        style: TextStyle(color: Colors.greenAccent)),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Still wrong — kept in the list for next time.',
                        style: TextStyle(color: Colors.orangeAccent)),
                  ),
                FilledButton.icon(
                  onPressed: _next,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(_idx + 1 < total ? 'Next' : 'Finish'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
