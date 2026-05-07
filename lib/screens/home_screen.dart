import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/daily.dart';
import '../widgets/month_calendar.dart';
import 'exercise_list_screen.dart';
import 'daily_session_screen.dart';
import 'wrong_answers_screen.dart';
import 'wordbook_screen.dart';
import 'favorites_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DayCellState _stateFor(DateTime day) {
    final set = progress.dailySetFor(day);
    return DayCellState(
      doneCount: progress.dailyDoneCount(day),
      targetCount: set?.length ?? kDailyTarget,
      hasSet: set != null && set.isNotEmpty,
    );
  }

  void _onTapDay(DateTime day) {
    final today = DateTime.now();
    if (_sameDay(day, today)) {
      _openDaily(day);
      return;
    }
    final set = progress.dailySetFor(day);
    if (set == null || set.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No session recorded for that day.')),
      );
      return;
    }
    _showPastDaySheet(day, set);
  }

  Future<void> _openDaily(DateTime day) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DailySessionScreen(date: day)),
    );
    if (mounted) setState(() {});
  }

  void _showPastDaySheet(DateTime day, List<String> ids) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(16),
          children: [
            Text('${day.year}.${day.month.toString().padLeft(2, '0')}.${day.day.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('${ids.length} sentences  ·  ${progress.dailyDoneCount(day)} done',
                style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: 24),
            ...ids.map((id) {
              final ref = SentenceRef.tryParse(id);
              return ListTile(
                dense: true,
                leading: Icon(
                  progress.dailyDoneFor(day).contains(id)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: progress.dailyDoneFor(day).contains(id)
                      ? Colors.greenAccent
                      : null,
                ),
                title: Text(
                  ref != null
                      ? '${ref.exercisePath.split('/').elementAt(3).replaceAll('-', ' ')} #${ref.sentenceIdx + 1}'
                      : id,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todaySet = progress.dailySetFor(today);
    final todayDone = progress.dailyDoneCount(today);
    final todayTotal = todaySet?.length ?? kDailyTarget;
    final todayCompleted = progress.isDayFullyDone(today);
    final wrongsCount = progress.wrongs.length;
    final wordbookCount = dictionary.savedCount;
    final favoritesCount = progress.favorites.length;
    final streak = progress.currentStreak();
    final completedDays = progress.totalCompletedDays;
    final totalSentences = progress.totalSentencesDone;

    return Scaffold(
      appBar: AppBar(title: const Text('Dictation Loop')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatBadge(
                  emoji: '🔥',
                  value: '$streak',
                  label: streak == 1 ? 'day streak' : 'day streak',
                  highlight: streak > 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBadge(
                  emoji: '📚',
                  value: '$completedDays',
                  label: 'days done',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBadge(
                  emoji: '📝',
                  value: '$totalSentences',
                  label: 'sentences',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MonthCalendar(
            dailyTarget: kDailyTarget,
            stateFor: _stateFor,
            onTapDay: _onTapDay,
          ),
          const SizedBox(height: 12),
          Card(
            color: todayCompleted
                ? Colors.greenAccent.withValues(alpha: 0.15)
                : null,
            child: ListTile(
              leading: Icon(
                todayCompleted ? Icons.check_circle : Icons.today,
                color: todayCompleted ? Colors.greenAccent : null,
              ),
              title: Text(todayCompleted
                  ? 'Today complete  ·  $todayTotal/$todayTotal'
                  : 'Today  ·  $todayDone/$todayTotal'),
              subtitle: Text(todayCompleted
                  ? 'Come back tomorrow for the next 10.'
                  : 'Continue today\'s 10 sentences'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openDaily(today),
            ),
          ),
          if (wrongsCount > 0) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.redAccent),
                title: Text('Wrong answers  ·  $wrongsCount'),
                subtitle: const Text('Review sentences you missed at both speeds'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WrongAnswersScreen()),
                  );
                  if (mounted) setState(() {});
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined, color: Colors.amberAccent),
              title: Text(wordbookCount > 0
                  ? '단어장  ·  $wordbookCount words'
                  : '단어장'),
              subtitle: const Text('Words you saved from dictation'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WordbookScreen()),
                );
                if (mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: Text(favoritesCount > 0
                  ? 'Favorites  ·  $favoritesCount lessons'
                  : 'Favorites'),
              subtitle: const Text('Lessons you starred'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                );
                if (mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(height: 16),
          if (progress.recent.isNotEmpty) ...[
            const _SectionHeader('Recent'),
            ...progress.recent.take(3).map((path) => Card(
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.history),
                    title: Text(_titleFromPath(path)),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ExerciseListScreen(
                            category: kCategories.firstWhere(
                              (c) => path.contains('/exercises/${c.slug}/'),
                              orElse: () => kCategories.first,
                            ),
                          ),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                )),
            const SizedBox(height: 8),
          ],
          const _SectionHeader('Categories'),
          ...kCategories.map((cat) => Card(
                child: ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: Text(cat.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExerciseListScreen(category: cat),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                ),
              )),
        ],
      ),
    );
  }

  String _titleFromPath(String path) {
    final parts = path.split('/');
    if (parts.length < 4) return path;
    return parts[3].replaceAll(RegExp(r'\.\d+$'), '').replaceAll('-', ' ');
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      );
}

class _StatBadge extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final bool highlight;
  const _StatBadge({
    required this.emoji,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: highlight
          ? Colors.orange.withValues(alpha: 0.15)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: highlight ? Colors.orangeAccent : null,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
