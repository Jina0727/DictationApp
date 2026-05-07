import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DayCellState {
  final int doneCount;
  final int targetCount;
  final bool hasSet;
  const DayCellState({
    required this.doneCount,
    required this.targetCount,
    required this.hasSet,
  });

  bool get fullyDone => hasSet && doneCount >= targetCount && targetCount > 0;
  bool get partial => hasSet && doneCount > 0 && !fullyDone;
}

class MonthCalendar extends StatefulWidget {
  final int dailyTarget;
  final DayCellState Function(DateTime day) stateFor;
  final void Function(DateTime day) onTapDay;
  const MonthCalendar({
    super.key,
    required this.dailyTarget,
    required this.stateFor,
    required this.onTapDay,
  });

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _visible;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visible = DateTime(now.year, now.month);
  }

  void _shift(int delta) {
    setState(() {
      _visible = DateTime(_visible.year, _visible.month + delta);
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final firstOfMonth = DateTime(_visible.year, _visible.month, 1);
    final daysInMonth = DateTime(_visible.year, _visible.month + 1, 0).day;
    // weekday: Mon=1..Sun=7. Display Sun-first grid.
    final leading = firstOfMonth.weekday % 7; // Sun=0..Sat=6

    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_visible.year, _visible.month, d);
      final isFuture = day.isAfter(DateTime(today.year, today.month, today.day));
      final isToday = _sameDay(day, today);
      final st = widget.stateFor(day);

      Color? bg;
      Color? fg;
      Border? border;
      Widget? mark;

      if (isFuture) {
        fg = Theme.of(context).disabledColor;
      } else if (st.fullyDone) {
        bg = AppPalette.success.withValues(alpha: 0.45);
        fg = Colors.white;
        mark = const Icon(Icons.check, size: 14, color: Colors.white);
      } else if (st.partial) {
        bg = AppPalette.warn.withValues(alpha: 0.30);
        fg = AppPalette.warn;
      }
      if (isToday) {
        border = Border.all(color: scheme.primary, width: 2.5);
      }

      cells.add(InkWell(
        onTap: isFuture ? null : () => widget.onTapDay(day),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: border,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$d',
                    style: TextStyle(
                      color: fg,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    )),
                ?mark,
                if (isToday && !st.fullyDone)
                  Text('${st.doneCount}/${widget.dailyTarget}',
                      style: TextStyle(fontSize: 9, color: scheme.primary)),
              ],
            ),
          ),
        ),
      ));
    }

    final monthLabel = '${_visible.year}.${_visible.month.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(monthLabel,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                IconButton(
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: const [
                _Wd('S'), _Wd('M'), _Wd('T'), _Wd('W'), _Wd('T'), _Wd('F'), _Wd('S'),
              ],
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.95,
              children: cells,
            ),
          ],
        ),
      ),
    );
  }
}

class _Wd extends StatelessWidget {
  final String text;
  const _Wd(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary)),
      ),
    );
  }
}
