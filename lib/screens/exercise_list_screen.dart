import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/progress.dart';
import 'study_session_screen.dart';

class ExerciseListScreen extends StatefulWidget {
  final Category category;
  const ExerciseListScreen({super.key, required this.category});

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  late Future<List<ExerciseSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = scraper.fetchExerciseList(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name)),
      body: FutureBuilder<List<ExerciseSummary>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text('Failed to load:\n${snap.error}',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() {
                        _future = scraper.fetchExerciseList(widget.category);
                      }),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No exercises found.'));
          }
          String? lastSection;
          final widgets = <Widget>[];
          for (final item in items) {
            if (item.section != null && item.section != lastSection) {
              lastSection = item.section;
              widgets.add(Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Text(
                  item.section!,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ));
            }
            final c10 = progress.isCompleted(item.id, SpeedTier.x10);
            final c15 = progress.isCompleted(item.id, SpeedTier.x15);
            final isFav = progress.isFavorite(item.id);
            widgets.add(ListTile(
              title: Text(item.title),
              subtitle: Row(
                children: [
                  if (item.vocabLevel != null) ...[
                    _Chip(text: item.vocabLevel!, color: Colors.purple),
                    const SizedBox(width: 6),
                  ],
                  if (item.partsCount != null) ...[
                    _Chip(
                        text: '${item.partsCount} parts',
                        color: Colors.blueGrey),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: isFav ? 'Remove favorite' : 'Add favorite',
                    icon: Icon(
                      isFav ? Icons.star : Icons.star_border,
                      color: isFav ? Colors.amber : null,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      await progress.toggleFavorite(item.id);
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(width: 2),
                  _Badge(label: '1.0x', filled: c10),
                  const SizedBox(width: 4),
                  _Badge(label: '1.5x', filled: c15),
                ],
              ),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        StudySessionScreen(exercisePath: item.path),
                  ),
                );
                if (mounted) setState(() {});
              },
            ));
          }
          return ListView(children: widgets);
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: 1))),
      );
}

class _Badge extends StatelessWidget {
  final String label;
  final bool filled;
  const _Badge({required this.label, required this.filled});

  @override
  Widget build(BuildContext context) {
    final color =
        filled ? Colors.greenAccent : Theme.of(context).disabledColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
        color: filled ? color.withValues(alpha: 0.2) : null,
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
