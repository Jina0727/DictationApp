import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';
import '../widgets/empty_state.dart';
import 'study_session_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _titleFromPath(String path) {
    final parts = path.split('/');
    if (parts.length < 4) return path;
    return parts[3]
        .replaceAll(RegExp(r'\.\d+$'), '')
        .replaceAll('-', ' ');
  }

  Category _catFromPath(String path) => kCategories.firstWhere(
        (c) => path.contains('/exercises/${c.slug}/'),
        orElse: () => kCategories.first,
      );

  @override
  Widget build(BuildContext context) {
    final favorites = progress.favorites.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favorites.isEmpty
          ? const EmptyState(
              emoji: '⭐',
              title: 'No favorites yet',
              body: 'Tap the star next to a lesson to save it here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: favorites.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final path = favorites[i];
                final cat = _catFromPath(path);
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text(_titleFromPath(path)),
                    subtitle: Text(cat.name),
                    trailing: IconButton(
                      tooltip: 'Remove from favorites',
                      icon: const Icon(Icons.star_border),
                      onPressed: () async {
                        await progress.toggleFavorite(path);
                        if (mounted) setState(() {});
                      },
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              StudySessionScreen(exercisePath: path),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                );
              },
            ),
    );
  }
}
