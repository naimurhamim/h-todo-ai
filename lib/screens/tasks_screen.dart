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
  late DateTime _selectedDay;
  bool _timelineMode = false;
  bool _showCompletedOnly = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  List<DateTime> _weekDaysFor(DateTime anchor) {
    final startOffset = anchor.weekday % 7;
    final sunday = anchor.subtract(Duration(days: startOffset));
    return List.generate(7, (i) => sunday.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.railBreakpoint;

    final now = DateTime.now();
    final today = _normalize(now);
    final weekDays = _weekDaysFor(_selectedDay);

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

    final timelineRows = <_TimelineRow>[];
    if (_timelineMode) {
      for (final entry in timelineEntries) {
        timelineRows.add(_TimelineRow.header(entry.key));
        for (final t in entry.value) {
          timelineRows.add(_TimelineRow.task(t));
        }
      }
    }

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                sliver: SliverToBoxAdapter(
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
                                  onTap: () =>
                                      setState(() => _timelineMode = false),
                                ),
                                _ViewToggleIcon(
                                  icon: Icons.view_agenda_outlined,
                                  tooltip: 'Full Timeline View',
                                  selected: _timelineMode,
                                  onTap: () =>
                                      setState(() => _timelineMode = true),
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
                                      onTap: () => setState(
                                        () => _showCompletedOnly = false,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: _SegmentItem(
                                      label: 'Completed',
                                      selected: _showCompletedOnly,
                                      onTap: () => setState(
                                        () => _showCompletedOnly = true,
                                      ),
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
                              onTap: () => setState(() {
                                _selectedDay = _selectedDay.subtract(
                                  const Duration(days: 7),
                                );
                              }),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            GlassCircleButton(
                              icon: Icons.chevron_right_rounded,
                              tooltip: 'Next week',
                              size: 38,
                              onTap: () => setState(() {
                                _selectedDay = _selectedDay.add(
                                  const Duration(days: 7),
                                );
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: weekDays.map((day) {
                            final selected = day == _selectedDay;
                            final isToday = day == today;
                            final dayItems = statusFiltered
                                .where((t) => _normalize(t.dueDate) == day)
                                .toList();

                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: GlassContainer(
                                  borderRadius: AppRadius.md,
                                  blur: 0,
                                  elevated: selected,
                                  borderColor: selected
                                      ? colors.primary
                                      : (isToday
                                          ? colors.textSecondary
                                          : colors.glassBorder),
                                  onTap: () =>
                                      setState(() => _selectedDay = day),
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
                                          style:
                                              textTheme.titleSmall?.copyWith(
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
                                                  alignment:
                                                      WrapAlignment.center,
                                                  spacing: 2,
                                                  runSpacing: 4,
                                                  children: dayItems
                                                      .take(4)
                                                      .map(
                                                        (item) => Icon(
                                                          taskTypeIcon(
                                                            item.type,
                                                          ),
                                                          size: 13,
                                                          color: item
                                                                  .isCompleted
                                                              ? colors
                                                                  .textSecondary
                                                              : colors
                                                                  .textPrimary,
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
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          Text(
                            _timelineMode ? 'All Scheduled' : 'Agenda',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
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
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  wide ? AppSpacing.xl : AppLayout.navClearance,
                ),
                sliver: !_timelineMode
                    ? (selectedDayTasks.isEmpty
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
                          ))
                    : (timelineRows.isEmpty
                        ? SliverToBoxAdapter(
                            child: _EmptyAgendaCard(
                              onGoToAiChat: widget.onGoToAiChat,
                              onAddManual: () => TaskEditorSheet.show(context),
                            ),
                          )
                        : SliverList.builder(
                            itemCount: timelineRows.length,
                            itemBuilder: (context, index) {
                              final row = timelineRows[index];
                              if (row.headerDate != null) {
                                final d = row.headerDate!;
                                return Padding(
                                  padding: EdgeInsets.only(
                                    top: index == 0
                                        ? AppSpacing.xs
                                        : AppSpacing.lg,
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: Text(
                                    d == today
                                        ? 'Today • ${DateFormat('d MMM yyyy').format(d)}'
                                        : DateFormat('EEE, d MMM yyyy')
                                            .format(d),
                                    style: textTheme.labelLarge?.copyWith(
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              }
                              final item = row.task!;
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: TaskCard(
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
                                ),
                              );
                            },
                          )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineRow {
  const _TimelineRow.header(this.headerDate) : task = null;
  const _TimelineRow.task(this.task) : headerDate = null;

  final DateTime? headerDate;
  final TaskItem? task;
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
