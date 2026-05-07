import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/progress.dart';
import '../theme/app_theme.dart';
import 'study_session_screen.dart';

class ExerciseListScreen extends StatefulWidget {
  final Category category;
  final CategoryMeta? meta;
  const ExerciseListScreen({super.key, required this.category, this.meta});

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  late Future<List<ExerciseSummary>> _future;
  CategoryMeta? _meta;

  @override
  void initState() {
    super.initState();
    _future = scraper.fetchExerciseList(widget.category);
    _meta = widget.meta;
    if (_meta == null) _resolveMeta();
  }

  Future<void> _resolveMeta() async {
    try {
      final all = await scraper.fetchCategoryMetas();
      if (!mounted) return;
      setState(() => _meta = all[widget.category.slug]);
    } catch (_) {/* ignore */}
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppPalette.categoryAccent(widget.category.slug);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.18),
                accent.withValues(alpha: 0.04),
              ],
            ),
          ),
        ),
      ),
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
          if (_meta != null &&
              ((_meta!.description != null && _meta!.description!.isNotEmpty) ||
                  _meta!.levelRange != null ||
                  _meta!.lessonCount != null ||
                  _meta!.isVideo)) {
            widgets.add(_CategoryHeaderCard(meta: _meta!, accent: accent));
          }
          for (final item in items) {
            if (item.section != null && item.section != lastSection) {
              lastSection = item.section;
              widgets.add(Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Text(
                  item.section!,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ));
            }
            final c10 = progress.isCompleted(item.id, SpeedTier.x10);
            final c15 = progress.isCompleted(item.id, SpeedTier.x15);
            final isFav = progress.isFavorite(item.id);
            widgets.add(ListTile(
              leading: Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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

class _CategoryHeaderCard extends StatelessWidget {
  final CategoryMeta meta;
  final Color accent;
  const _CategoryHeaderCard({required this.meta, required this.accent});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (meta.levelRange != null)
        _MetaChip(label: 'Levels ${meta.levelRange}', color: accent),
      if (meta.lessonCount != null)
        _MetaChip(label: '${meta.lessonCount} lessons', color: accent),
      if (meta.isVideo)
        _MetaChip(label: 'Video', color: AppPalette.warn),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Card(
        color: accent.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accent.withValues(alpha: 0.30), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meta.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: chips),
              ],
              if (meta.description != null) ...[
                const SizedBox(height: 10),
                Text(
                  meta.description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMid,
                        height: 1.4,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MetaChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
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
