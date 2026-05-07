import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'pronunciation_check_sheet.dart';

class ShadowingCard extends StatefulWidget {
  final String sentenceId;
  final String referenceText;
  final int shadowCount;
  final VoidCallback onIncrement;
  final Future<void> Function() onPlayOriginal;

  const ShadowingCard({
    super.key,
    required this.sentenceId,
    required this.referenceText,
    required this.shadowCount,
    required this.onIncrement,
    required this.onPlayOriginal,
  });

  @override
  State<ShadowingCard> createState() => _ShadowingCardState();
}

class _ShadowingCardState extends State<ShadowingCard> {
  final _recorder = AudioRecorder();
  final _playback = AudioPlayer();
  bool _recording = false;
  bool _playingMine = false;
  String? _recordingPath;
  Object? _error;

  @override
  void didUpdateWidget(ShadowingCard old) {
    super.didUpdateWidget(old);
    if (old.sentenceId != widget.sentenceId) {
      _resetForNewSentence();
    }
  }

  Future<void> _resetForNewSentence() async {
    if (_recording) await _recorder.stop();
    if (_playingMine) await _playback.stop();
    setState(() {
      _recording = false;
      _playingMine = false;
      _recordingPath = null;
      _error = null;
    });
  }

  Future<void> _toggleRecord() async {
    setState(() => _error = null);
    try {
      if (_recording) {
        final path = await _recorder.stop();
        if (!mounted) return;
        setState(() {
          _recording = false;
          _recordingPath = path;
        });
        return;
      }
      if (_playingMine) {
        await _playback.stop();
        if (mounted) setState(() => _playingMine = false);
      }
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        if (!mounted) return;
        setState(() => _error = 'Microphone permission denied');
        return;
      }
      final dir = await getTemporaryDirectory();
      final safeId = widget.sentenceId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
      final path = '${dir.path}/shadow_$safeId.wav';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordingPath = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _error = '$e';
      });
    }
  }

  Future<void> _playMine() async {
    final p = _recordingPath;
    if (p == null) return;
    try {
      if (!File(p).existsSync()) {
        setState(() => _error = 'Recording file missing');
        return;
      }
      if (_playingMine) {
        await _playback.stop();
        if (mounted) setState(() => _playingMine = false);
        return;
      }
      await _playback.setFilePath(p);
      setState(() => _playingMine = true);
      await _playback.play();
      await _playback.processingStateStream
          .firstWhere((s) => s == ProcessingState.completed);
      if (mounted) setState(() => _playingMine = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _playingMine = false;
        _error = '$e';
      });
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasRecording = _recordingPath != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mic),
                const SizedBox(width: 8),
                Text(
                  'Shadow practice  ${widget.shadowCount} / 3',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await widget.onPlayOriginal();
                    },
                    icon: const Icon(Icons.replay),
                    label: const Text('Original'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: widget.onIncrement,
                    icon: const Icon(Icons.add),
                    label: const Text('+1 repeat'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _recording
                      ? FilledButton.icon(
                          onPressed: _toggleRecord,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.redAccent.shade200,
                          ),
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                        )
                      : OutlinedButton.icon(
                          onPressed: _toggleRecord,
                          icon: const Icon(Icons.fiber_manual_record,
                              color: Colors.redAccent),
                          label: Text(hasRecording ? 'Re-record' : 'Record'),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasRecording && !_recording ? _playMine : null,
                    icon: Icon(_playingMine ? Icons.stop : Icons.play_arrow),
                    label: Text(_playingMine ? 'Stop' : 'Your voice'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: (hasRecording && !_recording)
                    ? () => showPronunciationCheckSheet(
                          context: context,
                          wavFile: File(_recordingPath!),
                          referenceText: widget.referenceText,
                        )
                    : null,
                icon: const Icon(Icons.assessment_outlined),
                label: Text(hasRecording
                    ? 'Check pronunciation'
                    : 'Record first to check'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error.toString(),
                style: TextStyle(
                  color: scheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
