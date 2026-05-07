import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/daily.dart';
import '../theme/app_theme.dart';
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
  Map<String, CategoryMeta> _metas = {};

  @override
  void initState() {
    super.initState();
    _loadMetas();
  }

  Future<void> _loadMetas() async {
    try {
      final m = await scraper.fetchCategoryMetas();
      if (!mounted) return;
      setState(() => _metas = m);
    } catch (_) {
      // Offline / network error — leave metas empty, UI gracefully omits the extras.
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Rank a level token like "A1", "B2", "C1" from 1..6. Returns 99 if unknown
  // so unknowns sink to the bottom of the sort.
  int _levelRank(String? token) {
    if (token == null) return 99;
    final m = RegExp(r'([A-C])([12])').firstMatch(token);
    if (m == null) return 99;
    final letter = m.group(1)!.codeUnitAt(0) - 'A'.codeUnitAt(0); // 0..2
    final num = int.parse(m.group(2)!); // 1..2
    return letter * 2 + num; // A1=1 .. C2=6
  }

  /// Categories sorted by their starting CEFR level (Stories for Kids first,
  /// Medical OET last). Falls back to declaration order while metas are loading.
  List<Category> get _sortedCategories {
    if (_metas.isEmpty) return kCategories;
    final list = kCategories.toList();
    list.sort((a, b) {
      final ra = _metas[a.slug]?.levelRange;
      final rb = _metas[b.slug]?.levelRange;
      // Compare starting level first.
      final startA = _levelRank(ra?.split('-').first.trim());
      final startB = _levelRank(rb?.split('-').first.trim());
      if (startA != startB) return startA.compareTo(startB);
      // Tie-breaker: end level (narrower range first).
      final endA = _levelRank((ra?.contains('-') == true)
          ? ra!.split('-').last.trim()
          : ra);
      final endB = _levelRank((rb?.contains('-') == true)
          ? rb!.split('-').last.trim()
          : rb);
      return endA.compareTo(endB);
    });
    return list;
  }

  DayCellState _stateFor(DateTime day) {
    final set = progress.dailySetFor(day);
    final sentenceCount = set?.length ?? kDailyTarget;
    return DayCellState(
      // Each sentence is studied at 1.0x and 1.5x → 2 round-entries per sentence.
      doneCount: progress.dailyDoneCount(day),
      targetCount: sentenceCount * 2,
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
    // 10 sentences × 2 rounds (1.0x + 1.5x) = 20 progress steps per day.
    final todayTotal = (todaySet?.length ?? kDailyTarget) * 2;
    final todayCompleted = progress.isDayFullyDone(today);
    final wrongsCount = progress.wrongs.length;
    final wordbookCount = dictionary.savedCount;
    final favoritesCount = progress.favorites.length;
    final streak = progress.currentStreak();
    final completedDays = progress.totalCompletedDays;
    final totalSentences = progress.totalSentencesDone;

    String streakEmoji;
    if (streak >= 100) {
      streakEmoji = '🏆';
    } else if (streak >= 30) {
      streakEmoji = '💎';
    } else if (streak >= 7) {
      streakEmoji = '🌟';
    } else if (streak >= 1) {
      streakEmoji = '🔥';
    } else {
      streakEmoji = '💤';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dictation Loop')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatBadge(
                  emoji: streakEmoji,
                  value: '$streak',
                  label: 'day streak',
                  highlight: streak > 0,
                  index: 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBadge(
                  emoji: '📚',
                  value: '$completedDays',
                  label: 'days done',
                  index: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBadge(
                  emoji: '📝',
                  value: '$totalSentences',
                  label: 'sentences',
                  index: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MonthCalendar(
            dailyTarget: kDailyTarget * 2,
            stateFor: _stateFor,
            onTapDay: _onTapDay,
          ),
          const SizedBox(height: 12),
          _TodayHeroCard(
            completed: todayCompleted,
            done: todayDone,
            total: todayTotal,
            onTap: () => _openDaily(today),
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
          ..._sortedCategories.map((cat) {
            final accent = AppPalette.categoryAccent(cat.slug);
            final meta = _metas[cat.slug];
            final subtitleParts = <String>[
              if (meta?.levelRange != null) 'Levels ${meta!.levelRange}',
              if (meta?.lessonCount != null) '${meta!.lessonCount} lessons',
            ];
            return Card(
              child: ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    meta?.isVideo == true
                        ? Icons.play_circle_outline
                        : Icons.folder_open,
                    color: accent,
                    size: 20,
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        meta?.displayName ?? cat.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (meta?.isVideo == true) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppPalette.warn.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Video',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppPalette.warn,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: subtitleParts.isEmpty
                    ? null
                    : Text(
                        subtitleParts.join(' · '),
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppPalette.textMid,
                                ),
                      ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExerciseListScreen(
                        category: cat,
                        meta: meta,
                      ),
                    ),
                  );
                  if (mounted) setState(() {});
                },
              ),
            );
          }),
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

class _TodayHeroCard extends StatelessWidget {
  final bool completed;
  final int done;
  final int total;
  final VoidCallback onTap;
  const _TodayHeroCard({
    required this.completed,
    required this.done,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;
    Widget card = InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: completed
                ? [
                    AppPalette.success.withValues(alpha: 0.42),
                    AppPalette.success.withValues(alpha: 0.30),
                  ]
                : [
                    AppPalette.primary,
                    AppPalette.primaryStrong,
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  completed ? '🏆 Today complete!' : "📚 Today's lesson",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$done / $total',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              completed
                  ? 'Come back tomorrow for the next 10 sentences!'
                  : "Continue today's 10 sentences →",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, val, _) => Stack(
                  children: [
                    Container(
                      height: 12,
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                    FractionallySizedBox(
                      widthFactor: val.clamp(0.0, 1.0),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.white, Color(0xFFE0E7FF)],
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return card
        .animate()
        .fadeIn(delay: 280.ms, duration: 400.ms)
        .slideY(begin: 0.15, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}

class _StatBadge extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final bool highlight;
  final int index;
  const _StatBadge({
    required this.emoji,
    required this.value,
    required this.label,
    this.highlight = false,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final accent = highlight ? AppPalette.streak : AppPalette.primary;
    final intValue = int.tryParse(value) ?? 0;

    Widget emojiWidget = Text(emoji, style: const TextStyle(fontSize: 22));
    if (highlight) {
      // gentle pulse (-20% from previous)
      emojiWidget = emojiWidget
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.10, 1.10),
            duration: 1100.ms,
            curve: Curves.easeInOut,
          );
    }

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: highlight
              ? [
                  AppPalette.streak.withValues(alpha: 0.26),
                  AppPalette.streak.withValues(alpha: 0.06),
                ]
              : [
                  AppPalette.surfaceHigh,
                  AppPalette.surface,
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? AppPalette.streak.withValues(alpha: 0.44)
              : Colors.white.withValues(alpha: 0.04),
          width: highlight ? 1.3 : 1,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: AppPalette.streak.withValues(alpha: 0.20),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          emojiWidget,
          const SizedBox(height: 4),
          // count-up
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: intValue),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, val, _) => Text(
              '$val',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: highlight ? AppPalette.streak : accent,
                  ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppPalette.textMid,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    return badge
        .animate()
        .fadeIn(delay: (80 * index).ms, duration: 350.ms)
        .slideY(begin: 0.3, end: 0, duration: 350.ms, curve: Curves.easeOutBack);
  }
}
