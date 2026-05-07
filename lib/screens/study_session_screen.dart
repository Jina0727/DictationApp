import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/progress.dart';
import '../utils/answer_check.dart';
import '../widgets/answer_result_card.dart';
import '../widgets/shadowing_card.dart';

class StudySessionScreen extends StatefulWidget {
  final String exercisePath;
  const StudySessionScreen({super.key, required this.exercisePath});

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  Lesson? _lesson;
  Object? _error;
  final _player = AudioPlayer();
  YoutubePlayerController? _yt;
  Timer? _ytStopTimer;
  final _input = TextEditingController();

  int _idx = 0;
  SpeedTier _speed = SpeedTier.x10;
  bool _revealed = false;
  int _listenCount = 0;
  int _shadowCount = 0;
  String? _loadedAudioFor;

  // round-scoped wrong tracking: position -> wrong this round?
  final Map<int, bool> _wrongAtX10 = {};
  final Map<int, bool> _wrongAtX15 = {};

  @override
  void initState() {
    super.initState();
    progress.pushRecent(widget.exercisePath);
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await scraper.fetchLesson(widget.exercisePath);
      if (!mounted) return;
      if (l.isYouTube) {
        _yt = YoutubePlayerController(
          initialVideoId: l.youtubeVideoId!,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            disableDragSeek: true,
            controlsVisibleAtStart: false,
            hideControls: true,
            enableCaption: false,
          ),
        );
      }
      setState(() => _lesson = l);
      _prepareAudio();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Challenge get _current => _lesson!.challenges[_idx];

  String _sentenceId(int position) => SentenceRef(
        exercisePath: widget.exercisePath,
        sentenceIdx: position,
      ).id;

  Future<void> _prepareAudio() async {
    if (_lesson == null) return;
    if (_lesson!.isYouTube) return; // YT plays segment-by-segment, no preload
    final url = _current.audioSrc;
    if (url.isEmpty) return;
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

  Future<void> _playYtSegment() async {
    final yt = _yt;
    if (yt == null) return;
    final start = _current.timeStart;
    final end = _current.timeEnd;
    final span = end - start;
    // Speed-aware duration so the timer matches when 1.5x is selected.
    final realSeconds = span / _speed.value;
    yt.setPlaybackRate(_speed.value == 1.0
        ? PlaybackRate.normal
        : PlaybackRate.oneAndAHalf);
    yt.seekTo(Duration(milliseconds: (start * 1000).round()));
    yt.play();
    _ytStopTimer?.cancel();
    _ytStopTimer = Timer(
      Duration(milliseconds: (realSeconds * 1000).round() + 250),
      () {
        if (mounted) yt.pause();
      },
    );
  }

  Future<void> _play() async {
    if (_lesson?.isYouTube == true) {
      await _playYtSegment();
    } else {
      await _prepareAudio();
      await _player.seek(Duration.zero);
      await _player.setSpeed(_speed.value);
      await _player.play();
    }
    setState(() => _listenCount++);
  }

  void _reveal() {
    final correct = isAnswerCorrect(_input.text, _current.content);
    final pos = _idx;
    if (_speed == SpeedTier.x10) {
      _wrongAtX10[pos] = !correct;
    } else {
      _wrongAtX15[pos] = !correct;
    }
    setState(() => _revealed = true);
  }

  Future<void> _next() async {
    if (_lesson == null) return;
    if (_idx + 1 < _lesson!.challenges.length) {
      setState(() {
        _idx++;
        _revealed = false;
        _listenCount = 0;
        _shadowCount = 0;
        _input.clear();
      });
      await _prepareAudio();
    } else {
      await _onLessonComplete();
    }
  }

  Future<void> _prev() async {
    if (_idx > 0) {
      setState(() {
        _idx--;
        _revealed = true;
        _listenCount = 0;
        _shadowCount = 0;
        _input.clear();
      });
      await _prepareAudio();
    }
  }

  Future<void> _onLessonComplete() async {
    final id = widget.exercisePath;
    await progress.markCompleted(id, _speed);
    await _commitWrongsIfBothRoundsDone();
    if (!mounted) return;
    final isX10 = _speed == SpeedTier.x10;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isX10
            ? '🎉 1.0x complete!'
            : '🏆 1.5x complete — full lesson done!'),
        content: Text(isX10
            ? 'Now repeat the same lesson at 1.5x to lock it in.'
            : 'Great job. You can now read the full transcript.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'home'),
            child: const Text('Back to list'),
          ),
          if (isX10)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'next-speed'),
              child: const Text('Start 1.5x'),
            )
          else
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'transcript'),
              child: const Text('Show transcript'),
            ),
        ],
      ),
    );
    if (!mounted) return;
    if (result == 'next-speed') {
      setState(() {
        _speed = SpeedTier.x15;
        _idx = 0;
        _revealed = false;
        _listenCount = 0;
        _shadowCount = 0;
        _input.clear();
      });
      await _prepareAudio();
    } else if (result == 'transcript') {
      _showTranscript();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _commitWrongsIfBothRoundsDone() async {
    if (!progress.isCompleted(widget.exercisePath, SpeedTier.x10) ||
        !progress.isCompleted(widget.exercisePath, SpeedTier.x15)) {
      return;
    }
    if (_lesson == null) return;
    for (final ch in _lesson!.challenges) {
      final pos = _lesson!.challenges.indexOf(ch);
      final w10 = _wrongAtX10[pos] == true;
      final w15 = _wrongAtX15[pos] == true;
      if (w10 && w15) {
        await progress.addWrong(_sentenceId(pos));
      }
    }
  }

  void _showTranscript() {
    if (_lesson == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(16),
          children: [
            Text('Full Transcript',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ..._lesson!.challenges.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('${c.position}. ${c.content}'),
                )),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ytStopTimer?.cancel();
    _player.dispose();
    _yt?.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Failed to load:\n$_error')),
      );
    }
    if (_lesson == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final l = _lesson!;
    final c = _current;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.lessonName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: progress.isFavorite(widget.exercisePath)
                ? 'Remove favorite'
                : 'Add favorite',
            icon: Icon(
              progress.isFavorite(widget.exercisePath)
                  ? Icons.star
                  : Icons.star_border,
              color: progress.isFavorite(widget.exercisePath)
                  ? Colors.amber
                  : null,
            ),
            onPressed: () async {
              await progress.toggleFavorite(widget.exercisePath);
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            tooltip: 'Transcript (locked until end)',
            icon: Icon(progress.isCompleted(widget.exercisePath, SpeedTier.x15)
                ? Icons.menu_book
                : Icons.lock_outline),
            onPressed:
                progress.isCompleted(widget.exercisePath, SpeedTier.x15)
                    ? _showTranscript
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Finish 1.5x to unlock the transcript')),
                        ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Sentence ${_idx + 1} / ${l.challenges.length}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  Builder(builder: (context) {
                    final x10Done = progress.isCompleted(
                        widget.exercisePath, SpeedTier.x10);
                    return SegmentedButton<SpeedTier>(
                      segments: [
                        const ButtonSegment(
                            value: SpeedTier.x10, label: Text('1.0x')),
                        ButtonSegment(
                          value: SpeedTier.x15,
                          label: const Text('1.5x'),
                          icon: x10Done
                              ? null
                              : const Icon(Icons.lock_outline, size: 14),
                          enabled: x10Done,
                        ),
                      ],
                      selected: {_speed},
                      onSelectionChanged: (s) async {
                        final newSpeed = s.first;
                        if (newSpeed == SpeedTier.x15 && !x10Done) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Finish 1.0x to unlock 1.5x')),
                          );
                          return;
                        }
                        setState(() => _speed = newSpeed);
                        await _player.setSpeed(_speed.value);
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_idx + 1) / l.challenges.length,
              ),
              const SizedBox(height: 16),
              if (_yt != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: YoutubePlayer(
                      controller: _yt!,
                      showVideoProgressIndicator: false,
                      progressIndicatorColor: Colors.transparent,
                      onReady: () {},
                    ),
                  ),
                ),
              if (_yt != null) const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
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
                              Text('Listened',
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                              Text('$_listenCount',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                            ],
                          ),
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
                  hintText: _revealed
                      ? 'Locked'
                      : 'Type what you hear (don\'t peek)',
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (!_revealed)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _reveal,
                        icon: const Icon(Icons.visibility),
                        label: const Text('Reveal answer'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _next,
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              if (_revealed) ...[
                AnswerResultCard(
                  userInput: _input.text,
                  answer: c.content,
                ),
                const SizedBox(height: 12),
                ShadowingCard(
                  sentenceId: _sentenceId(_idx),
                  referenceText: c.content,
                  shadowCount: _shadowCount,
                  onIncrement: () => setState(() => _shadowCount++),
                  onPlayOriginal: () async {
                    if (_lesson?.isYouTube == true) {
                      await _playYtSegment();
                    } else {
                      await _player.seek(Duration.zero);
                      await _player.play();
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _idx > 0 ? _prev : null,
                      child: const Text('← Prev'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _next,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(_idx + 1 < l.challenges.length
                          ? 'Next sentence'
                          : 'Finish'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
