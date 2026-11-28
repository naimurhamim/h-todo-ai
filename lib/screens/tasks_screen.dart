import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task_item.dart';
import '../providers/task_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/glass_surface.dart';
import '../widgets/task_card.dart';
import '../widgets/task_detail_sheet.dart';
import '../widgets/task_editor_sheet.dart';

/// "Plan Your Day" screen matching the middle glassmorphism reference layout.
class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    required this.onGoToAiChat,
    required this.onGoToSettings,
  });

  final VoidCallback onGoToAiChat;
  final VoidCallback onGoToSettings;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static const int _initialWeekPage = 5000;

  late DateTime _selectedDay;
  late final DateTime _anchorSunday;
  late PageController _weekPageController;
  final ScrollController _timelineScrollCtrl = ScrollController();
  final GlobalKey _todayAnchorKey = GlobalKey();
  bool _timelineMode = false;
  bool _showCompletedOnly = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _anchorSunday = _sundayOf(_selectedDay);
    _weekPageController = PageController(initialPage: _initialWeekPage);
  }

  @override
  void dispose() {
    _weekPageController.dispose();
    _timelineScrollCtrl.dispose();
    super.dispose();
  }

  void _jumpToToday() {
    if (!_timelineScrollCtrl.hasClients) return;
    _timelineScrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _resetTimelineOffsetNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _timelineScrollCtrl.hasClients) {
        _timelineScrollCtrl.jumpTo(0);
      }
    });
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _sundayOf(DateTime anchor) {
    final normalized = _normalize(anchor);
    final startOffset = normalized.weekday % 7;
    return normalized.subtract(Duration(days: startOffset));
  }

  int _pageForDate(DateTime date) {
    final diffDays = _sundayOf(date).difference(_anchorSunday).inDays;
    return _initialWeekPage + (diffDays ~/ 7);
  }

  List<DateTime> _weekDaysForPage(int page) {
    final sunday = _anchorSunday.add(Duration(days: (page - _initialWeekPage) * 7));
    return List.generate(7, (i) => sunday.add(Duration(days: i)));
  }

  void _stepWeek(int deltaPages) {
    if (_weekPageController.hasClients) {
      if (deltaPages < 0) {
        _weekPageController.previousPage(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        _weekPageController.nextPage(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      setState(() {
        _selectedDay = _selectedDay.add(Duration(days: deltaPages * 7));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.railBreakpoint;

    final now = DateTime.now();
    final today = _normalize(now);

    final statusFiltered = taskProvider.tasks.where((t) {
      return _showCompletedOnly ? t.isCompleted : true;
    }).toList()
      ..sort((a, b) {
        final d = a.dueDate.compareTo(b.dueDate);
        if (d != 0) return d;
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return a.priority.index.compareTo(b.priority.index);
      });

    final selectedDayTasks = statusFiltered
        .where((t) => _normalize(t.dueDate) == _selectedDay)
        .toList();

    final groupedTimeline = <DateTime, List<TaskItem>>{};
    for (final t in statusFiltered) {
      final key = _normalize(t.dueDate);
      groupedTimeline.putIfAbsent(key, () => []).add(t);
    }
    final timelineEntries = groupedTimeline.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final pastRowsReversed = <_TimelineRow>[];
    final fromTodayRows = <_TimelineRow>[];
    if (_timelineMode && timelineEntries.isNotEmpty) {
      final pastEntries =
          timelineEntries.where((e) => e.key.isBefore(today)).toList();
      final fromTodayEntries =
          timelineEntries.where((e) => !e.key.isBefore(today)).toList();

      // If every scheduled item is in the past, anchor the latest past date at 0.0
      // so All Scheduled never opens on an empty viewport.
      if (fromTodayEntries.isEmpty && pastEntries.isNotEmpty) {
        fromTodayEntries.add(pastEntries.removeLast());
      }

      final pastRowsChrono = <_TimelineRow>[];
      for (var i = 0; i < pastEntries.length; i++) {
        final entry = pastEntries[i];
        pastRowsChrono.add(_TimelineRow.header(entry.key, isFirst: i == 0));
        for (final t in entry.value) {
          pastRowsChrono.add(_TimelineRow.task(t));
        }
      }
      pastRowsReversed.addAll(pastRowsChrono.reversed);

      final showTodayGapAnchor = pastEntries.isNotEmpty &&
          fromTodayEntries.isNotEmpty &&
          fromTodayEntries.first.key.isAfter(today);
      if (showTodayGapAnchor) {
        fromTodayRows.add(_TimelineRow.emptyTodayAnchor(today));
      }
      for (var i = 0; i < fromTodayEntries.length; i++) {
        final entry = fromTodayEntries[i];
        fromTodayRows.add(
          _TimelineRow.header(
            entry.key,
            isFirst: i == 0 && !showTodayGapAnchor,
          ),
        );
        for (final t in entry.value) {
          fromTodayRows.add(_TimelineRow.task(t));
        }
      }
    }

    Widget buildHeaderControls({required bool pinned}) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          pinned ? AppSpacing.sm : AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Plan Your Day',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GlassContainer(
                  borderRadius: AppRadius.pill,
                  blur: 0,
                  elevated: true,
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ViewToggleIcon(
                        icon: Icons.calendar_today_outlined,
                        tooltip: 'Week Grid View',
                        selected: !_timelineMode,
                        onTap: () {
                          if (!_timelineMode) return;
                          final targetPage = _pageForDate(_selectedDay);
                          _weekPageController.dispose();
                          _weekPageController = PageController(
                            initialPage: targetPage,
                          );
                          setState(() => _timelineMode = false);
                        },
                      ),
                      _ViewToggleIcon(
                        icon: Icons.view_agenda_outlined,
                        tooltip: 'Full Timeline View',
                        selected: _timelineMode,
                        onTap: () {
                          if (_timelineMode) return;
                          setState(() => _timelineMode = true);
                          _resetTimelineOffsetNextFrame();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: GlassContainer(
                    borderRadius: AppRadius.pill,
                    blur: 0,
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SegmentItem(
                            label: 'All Tasks',
                            selected: !_showCompletedOnly,
                            onTap: () {
                              setState(() => _showCompletedOnly = false);
                              if (_timelineMode) _resetTimelineOffsetNextFrame();
                            },
                          ),
                        ),
                        Expanded(
                          child: _SegmentItem(
                            label: 'Completed',
                            selected: _showCompletedOnly,
                            onTap: () {
                              setState(() => _showCompletedOnly = true);
                              if (_timelineMode) _resetTimelineOffsetNextFrame();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                GlassPillButton(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: colors.primary,
                  label: 'Auto-Plan',
                  selected: true,
                  onTap: widget.onGoToAiChat,
                ),
              ],
            ),
            if (!_timelineMode) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('d MMMM, yyyy').format(_selectedDay),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  GlassCircleButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Previous week',
                    size: 38,
                    onTap: () => _stepWeek(-1),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  GlassCircleButton(
                    icon: Icons.chevron_right_rounded,
                    tooltip: 'Next week',
                    size: 38,
                    onTap: () => _stepWeek(1),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 142,
                child: PageView.builder(
                  controller: _weekPageController,
                  onPageChanged: (page) {
                    final days = _weekDaysForPage(page);
                    final slot = _selectedDay.weekday % 7;
                    final nextSelected = days[slot];
                    if (nextSelected != _selectedDay) {
                      setState(() => _selectedDay = nextSelected);
                    }
                  },
                  itemBuilder: (context, page) {
                    final pageWeekDays = _weekDaysForPage(page);
                    return Row(
                      children: pageWeekDays.map((day) {
                        final selected = day == _selectedDay;
                        final isToday = day == today;
                        final dayItems = statusFiltered
                            .where((t) => _normalize(t.dueDate) == day)
                            .toList();

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                            ),
                            child: GlassContainer(
                              borderRadius: AppRadius.md,
                              blur: 0,
                              elevated: selected,
                              borderColor: selected
                                  ? colors.primary
                                  : (isToday
                                      ? colors.textSecondary
                                      : colors.glassBorder),
                              onTap: () => setState(() => _selectedDay = day),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 4,
                              ),
                              child: SizedBox(
                                height: 118,
                                child: Column(
                                  children: [
                                    Text(
                                      '${day.day}',
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('E')
                                          .format(day)
                                          .substring(0, 2),
                                      style: textTheme.labelSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: dayItems.isEmpty
                                          ? const SizedBox.shrink()
                                          : Wrap(
                                              alignment: WrapAlignment.center,
                                              spacing: 2,
                                              runSpacing: 4,
                                              children: dayItems
                                                  .take(4)
                                                  .map(
                                                    (item) => Icon(
                                                      taskIconForItem(
                                                        item,
                                                        taskProvider
                                                            .customTaskTypes,
                                                      ),
                                                      size: 13,
                                                      color: item.isCompleted
                                                          ? colors.textSecondary
                                                          : colors.textPrimary,
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
            SizedBox(height: _timelineMode ? AppSpacing.lg : AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _timelineMode ? 'All Scheduled' : 'Agenda',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (_timelineMode && timelineEntries.isNotEmpty) ...[
                  GlassPillButton(
                    icon: Icons.today_rounded,
                    iconColor: colors.primary,
                    label: 'Today',
                    onTap: _jumpToToday,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                GlassPillButton(
                  icon: Icons.add_rounded,
                  label: 'Add',
                  onTap: () => TaskEditorSheet.show(
                    context,
                    initialDate: _selectedDay,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget buildTimelineRow(_TimelineRow row) {
      if (row.headerDate != null) {
        final d = row.headerDate!;
        final label = row.isEmptyAnchor
            ? 'Today • ${DateFormat('d MMM yyyy').format(d)} • Nothing scheduled'
            : (d == today
                ? 'Today • ${DateFormat('d MMM yyyy').format(d)}'
                : DateFormat('EEE, d MMM yyyy').format(d));
        return Padding(
          padding: EdgeInsets.only(
            top: row.isFirst ? AppSpacing.xs : AppSpacing.lg,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: (d == today && !row.isEmptyAnchor)
                  ? colors.primary
                  : colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }
      final item = row.task!;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: TaskCard(
          task: item,
          onToggleComplete: () => taskProvider.toggleTaskComplete(item.id),
          onToggleSubtask: (subId) =>
              taskProvider.toggleSubtaskComplete(item.id, subId),
          onDelete: () => taskProvider.deleteTask(item.id),
          onTap: () => TaskDetailSheet.show(context, item.id),
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
          child: _timelineMode
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildHeaderControls(pinned: true),
                    Expanded(
                      child: timelineEntries.isEmpty
                          ? SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                wide ? AppSpacing.xl : AppLayout.navClearance,
                              ),
                              child: _EmptyAgendaCard(
                                onGoToAiChat: widget.onGoToAiChat,
                                onAddManual: () =>
                                    TaskEditorSheet.show(context),
                              ),
                            )
                          : CustomScrollView(
                              controller: _timelineScrollCtrl,
                              center: _todayAnchorKey,
                              cacheExtent: 500,
                              slivers: [
                                if (pastRowsReversed.isNotEmpty)
                                  SliverPadding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg,
                                    ),
                                    sliver: SliverList.builder(
                                      itemCount: pastRowsReversed.length,
                                      itemBuilder: (context, index) =>
                                          buildTimelineRow(
                                        pastRowsReversed[index],
                                      ),
                                    ),
                                  ),
                                SliverPadding(
                                  key: _todayAnchorKey,
                                  padding: EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    0,
                                    AppSpacing.lg,
                                    wide
                                        ? AppSpacing.xl
                                        : AppLayout.navClearance,
                                  ),
                                  sliver: SliverList.builder(
                                    itemCount: fromTodayRows.length,
                                    itemBuilder: (context, index) =>
                                        buildTimelineRow(fromTodayRows[index]),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                )
              : CustomScrollView(
                  cacheExtent: 500,
                  slivers: [
                    SliverToBoxAdapter(
                      child: buildHeaderControls(pinned: false),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        wide ? AppSpacing.xl : AppLayout.navClearance,
                      ),
                      sliver: selectedDayTasks.isEmpty
                          ? SliverToBoxAdapter(
                              child: _EmptyAgendaCard(
                                onGoToAiChat: widget.onGoToAiChat,
                                onAddManual: () => TaskEditorSheet.show(
                                  context,
                                  initialDate: _selectedDay,
                                ),
                              ),
                            )
                          : SliverList.separated(
                              itemCount: selectedDayTasks.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) {
                                final item = selectedDayTasks[index];
                                return TaskCard(
                                  task: item,
                                  onToggleComplete: () =>
                                      taskProvider.toggleTaskComplete(item.id),
                                  onToggleSubtask: (subId) =>
                                      taskProvider.toggleSubtaskComplete(
                                    item.id,
                                    subId,
                                  ),
                                  onDelete: () =>
                                      taskProvider.deleteTask(item.id),
                                  onTap: () =>
                                      TaskDetailSheet.show(context, item.id),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TimelineRow {
  const _TimelineRow.header(this.headerDate, {this.isFirst = false})
      : task = null,
        isEmptyAnchor = false;

  const _TimelineRow.emptyTodayAnchor(this.headerDate)
      : task = null,
        isFirst = true,
        isEmptyAnchor = true;

  const _TimelineRow.task(this.task)
      : headerDate = null,
        isFirst = false,
        isEmptyAnchor = false;

  final DateTime? headerDate;
  final TaskItem? task;
  final bool isFirst;
  final bool isEmptyAnchor;
}

class _ViewToggleIcon extends StatelessWidget {
  const _ViewToggleIcon({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 40,
          height: 36,
          decoration: BoxDecoration(
            color: selected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? colors.textPrimary : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? colors.textPrimary : colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _EmptyAgendaCard extends StatelessWidget {
  const _EmptyAgendaCard({
    required this.onGoToAiChat,
    required this.onAddManual,
  });

  final VoidCallback onGoToAiChat;
  final VoidCallback onAddManual;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    return GlassContainer(
      borderRadius: AppRadius.lg,
      blur: 0,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Icon(
            Icons.event_note_rounded,
            size: 28,
            color: colors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nothing planned for this day',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Switch days above, paste a schedule in Auto-Plan, or tap Add.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              GlassPillButton(
                icon: Icons.auto_awesome_rounded,
                iconColor: colors.primary,
                label: 'AI Auto-Plan',
                selected: true,
                onTap: onGoToAiChat,
              ),
              GlassPillButton(
                icon: Icons.add_rounded,
                label: 'Add Manually',
                onTap: onAddManual,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
