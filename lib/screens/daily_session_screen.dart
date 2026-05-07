import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../main.dart';
import '../services/daily.dart';
import '../services/progress.dart';
import '../utils/answer_check.dart';
import '../widgets/answer_result_card.dart';
import '../widgets/shadowing_card.dart';

class DailySessionScreen extends StatefulWidget {
  final DateTime date;
  const DailySessionScreen({super.key, required this.date});

  @override
  State<DailySessionScreen> createState() => _DailySessionScreenState();
}

class _DailySessionScreenState extends State<DailySessionScreen> {
  List<DailyHydrated>? _items;
  Object? _error;

  final _player = AudioPlayer();
  final _input = TextEditingController();

  int _idx = 0;
  SpeedTier _speed = SpeedTier.x10;
  bool _revealed = false;
  int _listenCount = 0;
  int _shadowCount = 0;
  String? _loadedAudioFor;

  final Map<String, bool> _wrongAtX10 = {};
  final Map<String, bool> _wrongAtX15 = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final refs = await daily.ensureTodaySet(widget.date);
      final hydrated = await daily.hydrate(refs);
      if (!mounted) return;
      setState(() => _items = hydrated);
      _prepareAudio();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  DailyHydrated get _current => _items![_idx];

  Future<void> _prepareAudio() async {
    if (_items == null || _items!.isEmpty) return;
    final url = _current.challenge.audioSrc;
    if (_loadedAudioFor != url) {
      try {
        await _player.setUrl(url);
        await _player.setSpeed(_speed.value);
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
    await _player.setSpeed(_speed.value);
    await _player.play();
    setState(() => _listenCount++);
  }

  void _reveal() {
    final correct = isAnswerCorrect(_input.text, _current.challenge.content);
    final id = _current.ref.id;
    if (_speed == SpeedTier.x10) {
      _wrongAtX10[id] = !correct;
    } else {
      _wrongAtX15[id] = !correct;
    }
    setState(() => _revealed = true);
  }

  Future<void> _next() async {
    if (_items == null) return;
    if (_speed == SpeedTier.x15) {
      // mark this sentence as daily-done after 1.5x reveal
      await progress.markDailyDone(widget.date, _current.ref.id);
    }
    if (_idx + 1 < _items!.length) {
      setState(() {
        _idx++;
        _revealed = false;
        _listenCount = 0;
        _shadowCount = 0;
        _input.clear();
      });
      await _prepareAudio();
    } else {
      await _onRoundComplete();
    }
  }

  Future<void> _onRoundComplete() async {
    final isX10 = _speed == SpeedTier.x10;
    if (!mounted) return;

    if (isX10) {
      final res = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('🎉 1.0x round complete'),
          content: const Text('Now repeat the same 10 sentences at 1.5x.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'home'),
              child: const Text('Quit'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'next-speed'),
              child: const Text('Start 1.5x'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (res == 'next-speed') {
        setState(() {
          _speed = SpeedTier.x15;
          _idx = 0;
          _revealed = false;
          _listenCount = 0;
          _shadowCount = 0;
          _input.clear();
        });
        await _prepareAudio();
      } else {
        Navigator.of(context).pop();
      }
      return;
    }

    // 1.5x complete -> commit wrongs and advance cursor
    for (final h in _items!) {
      final id = h.ref.id;
      if (_wrongAtX10[id] == true && _wrongAtX15[id] == true) {
        await progress.addWrong(id);
      }
    }
    await daily.advanceCursorPast(_items!.map((h) => h.ref).toList());

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🏆 Today complete!'),
        content: const Text('Great job. Tomorrow\'s 10 sentences will continue from where you left off.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
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
        appBar: AppBar(title: const Text('Daily session')),
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
        appBar: AppBar(title: const Text('Daily session')),
        body: const Center(child: Text('No sentences available.')),
      );
    }
    final h = _current;
    final c = h.challenge;
    final total = _items!.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Today  ·  ${_speed.key}  ·  ${_idx + 1}/$total'),
      ),
      body: SafeArea(
        child: Padding(
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
                  hintText: _revealed ? 'Locked' : 'Type what you hear (don\'t peek)',
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
                const SizedBox(height: 12),
                ShadowingCard(
                  sentenceId: h.ref.id,
                  referenceText: c.content,
                  shadowCount: _shadowCount,
                  onIncrement: () => setState(() => _shadowCount++),
                  onPlayOriginal: () async {
                    await _player.seek(Duration.zero);
                    await _player.play();
                  },
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _next,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(_idx + 1 < total
                      ? 'Next sentence'
                      : (_speed == SpeedTier.x10 ? 'Finish 1.0x round' : 'Finish today')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
