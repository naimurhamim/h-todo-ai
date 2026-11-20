import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task_item.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/circular_progress_ring.dart';
import '../widgets/glass_surface.dart';
import '../widgets/notifications_sheet.dart';
import '../widgets/task_card.dart';
import '../widgets/task_detail_sheet.dart';
import '../widgets/task_editor_sheet.dart';

enum _OverviewFilter { all, assignment, classTest, exam, done }

/// Frosted glass daily overview with 7-day strip, progress ring, and countdown widgets.
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({
    super.key,
    required this.onGoToPlan,
    required this.onGoToAiChat,
    required this.onGoToProfile,
  });

  final VoidCallback onGoToPlan;
  final VoidCallback onGoToAiChat;
  final VoidCallback onGoToProfile;

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late DateTime _selectedDay;
  _OverviewFilter _filter = _OverviewFilter.all;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  List<DateTime> _weekDaysFor(DateTime anchor) {
    final startOffset = anchor.weekday % 7; // Sunday = 0
    final sunday = anchor.subtract(Duration(days: startOffset));
    return List.generate(7, (i) => sunday.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final aiSettings = context.watch<AiSettingsProvider>();
    final cloud = context.watch<CloudSyncProvider>();
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.railBreakpoint;

    final now = DateTime.now();
    final today = _normalize(now);
    final weekDays = _weekDaysFor(_selectedDay);

    final dayTasks = taskProvider.tasks
        .where((t) => _normalize(t.dueDate) == _selectedDay)
        .toList()
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return a.priority.index.compareTo(b.priority.index);
      });

    final filteredDayTasks = dayTasks.where((t) {
      switch (_filter) {
        case _OverviewFilter.all:
          return true;
        case _OverviewFilter.assignment:
          return t.type == TaskType.assignment;
        case _OverviewFilter.classTest:
          return t.type == TaskType.classTest;
        case _OverviewFilter.exam:
          return t.type == TaskType.exam;
        case _OverviewFilter.done:
          return t.isCompleted;
      }
    }).toList();

    final dayTotal = dayTasks.length;
    final dayCompleted = dayTasks.where((t) => t.isCompleted).length;
    final dayRatio = dayTotal == 0
        ? (taskProvider.tasks.isEmpty
            ? 0.0
            : taskProvider.completedCount / taskProvider.tasks.length)
        : dayCompleted / dayTotal;

    final pendingSorted = taskProvider.tasks
        .where((t) => !t.isCompleted)
        .toList()
      ..sort((a, b) {
        final d = a.dueDate.compareTo(b.dueDate);
        if (d != 0) return d;
        return (a.dueHour ?? 23).compareTo(b.dueHour ?? 23);
      });
    final nextTask = pendingSorted.isNotEmpty ? pendingSorted.first : null;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              wide ? AppSpacing.xl : AppLayout.navClearance,
            ),
            children: [
              Row(
                children: [
                  _UserAvatarButton(
                    photoUrl: cloud.userPhotoUrl,
                    name: cloud.userName ?? cloud.userEmail,
                    onTap: widget.onGoToProfile,
                  ),
                  Expanded(
                    child: Text(
                      'Overview',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GlassCircleButton(
                    icon: isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    tooltip: isDark
                        ? 'Switch to Light theme'
                        : 'Switch to Dark theme',
                    size: 42,
                    onTap: () => aiSettings.setThemeMode(
                      isDark ? ThemeMode.light : ThemeMode.dark,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  GlassCircleButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'Notifications',
                    badgeCount: taskProvider.pendingCount,
                    size: 42,
                    onTap: () => NotificationsSheet.show(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: weekDays.map((day) {
                  final selected = day == _selectedDay;
                  final isToday = day == today;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: selected
                          ? GlassContainer(
                              borderRadius: AppRadius.md,
                              blur: 0,
                              elevated: true,
                              borderColor: colors.glassBorder,
                              onTap: () => setState(() => _selectedDay = day),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                children: [
                                  Text(
                                    DateFormat('E')
                                        .format(day)
                                        .substring(0, 2),
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${day.day}',
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : InkWell(
                              onTap: () => setState(() => _selectedDay = day),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Column(
                                  children: [
                                    Text(
                                      DateFormat('E')
                                          .format(day)
                                          .substring(0, 2),
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${day.day}',
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: isToday
                                            ? FontWeight.w700
                                            : FontWeight.w500,
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
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterPill(
                      label: 'All',
                      selected: _filter == _OverviewFilter.all,
                      onTap: () => setState(() => _filter = _OverviewFilter.all),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _FilterPill(
                      label: 'Assignment',
                      selected: _filter == _OverviewFilter.assignment,
                      onTap: () => setState(
                        () => _filter = _OverviewFilter.assignment,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _FilterPill(
                      label: 'Class Test',
                      selected: _filter == _OverviewFilter.classTest,
                      onTap: () => setState(
                        () => _filter = _OverviewFilter.classTest,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _FilterPill(
                      label: 'Exam',
                      selected: _filter == _OverviewFilter.exam,
                      onTap: () => setState(
                        () => _filter = _OverviewFilter.exam,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _FilterPill(
                      label: 'Done',
                      selected: _filter == _OverviewFilter.done,
                      onTap: () => setState(
                        () => _filter = _OverviewFilter.done,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GlassContainer(
                borderRadius: AppRadius.lg,
                blur: 0,
                elevated: true,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedDay == today
                                    ? "Today's Progress"
                                    : DateFormat('d MMM Progress')
                                        .format(_selectedDay),
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    dayTotal == 0
                                        ? '${taskProvider.completedCount}'
                                        : '$dayCompleted',
                                    style: textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    dayTotal == 0
                                        ? '/${taskProvider.tasks.length} tasks'
                                        : '/$dayTotal tasks',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        CircularProgressRing(
                          progress: dayRatio,
                          size: 76,
                          strokeWidth: 7,
                          centerChild: Text(
                            '${(dayRatio * 100).round()}%',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStatBox(
                            label: 'Pending',
                            count: taskProvider.pendingCount,
                            total: taskProvider.tasks.length,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _MiniStatBox(
                            label: 'Due Today',
                            count: taskProvider.dueTodayCount,
                            total: taskProvider.tasks.length,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _MiniStatBox(
                            label: 'Completed',
                            count: taskProvider.completedCount,
                            total: taskProvider.tasks.length,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _NextCountdownWidget(
                      nextTask: nextTask,
                      now: now,
                      onTap: nextTask != null
                          ? () => TaskDetailSheet.show(context, nextTask.id)
                          : widget.onGoToAiChat,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _NextTaskPreviewWidget(
                      nextTask: nextTask,
                      onTap: nextTask != null
                          ? () => TaskDetailSheet.show(context, nextTask.id)
                          : widget.onGoToAiChat,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Text(
                    _selectedDay == today
                        ? "Today's Tasks"
                        : DateFormat('EEE, d MMM').format(_selectedDay),
                    style: textTheme.titleMedium?.copyWith(
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
              const SizedBox(height: AppSpacing.md),
              if (filteredDayTasks.isEmpty)
                GlassContainer(
                  borderRadius: AppRadius.lg,
                  blur: 0,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        size: 28,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'No tasks scheduled for this view',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use Auto-Plan to paste a class or work schedule, or add a task manually.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      GlassPillButton(
                        icon: Icons.auto_awesome_rounded,
                        iconColor: colors.primary,
                        label: 'Open AI Auto-Plan',
                        onTap: widget.onGoToAiChat,
                      ),
                    ],
                  ),
                )
              else
                for (var i = 0; i < filteredDayTasks.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  TaskCard(
                    task: filteredDayTasks[i],
                    onToggleComplete: () =>
                        taskProvider.toggleTaskComplete(filteredDayTasks[i].id),
                    onToggleSubtask: (subId) =>
                        taskProvider.toggleSubtaskComplete(
                      filteredDayTasks[i].id,
                      subId,
                    ),
                    onDelete: () =>
                        taskProvider.deleteTask(filteredDayTasks[i].id),
                    onTap: () =>
                        TaskDetailSheet.show(context, filteredDayTasks[i].id),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAvatarButton extends StatelessWidget {
  const _UserAvatarButton({
    required this.photoUrl,
    required this.name,
    required this.onTap,
  });

  final String? photoUrl;
  final String? name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final initial = (name != null && name!.trim().isNotEmpty)
        ? name!.trim().substring(0, 1).toUpperCase()
        : null;

    return Semantics(
      label: 'Open Profile & Settings',
      button: true,
      child: GlassContainer(
        borderRadius: AppRadius.pill,
        blur: 0,
        elevated: true,
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: hasPhoto
              ? ClipOval(
                  child: Image.network(
                    photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const AppLogoMark(size: 46),
                  ),
                )
              : (initial != null
                  ? Center(
                      child: Text(
                        initial,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                      ),
                    )
                  : const AppLogoMark(size: 46)),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
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
    return GlassContainer(
      borderRadius: AppRadius.pill,
      blur: 0,
      elevated: selected,
      borderColor: selected ? colors.primary : colors.glassBorder,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 6),
          Icon(
            selected
                ? Icons.check_circle_outline_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 15,
            color: selected ? colors.primary : colors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  const _MiniStatBox({
    required this.label,
    required this.count,
    required this.total,
  });

  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final ratio = total == 0 ? 0.0 : (count / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: colors.border.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextCountdownWidget extends StatelessWidget {
  const _NextCountdownWidget({
    required this.nextTask,
    required this.now,
    required this.onTap,
  });

  final TaskItem? nextTask;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    String headline = 'Clear';
    String caption = 'No pending deadlines';
    double outer = 0;
    double inner = 0;

    if (nextTask != null) {
      final dueAt = DateTime(
        nextTask!.dueDate.year,
        nextTask!.dueDate.month,
        nextTask!.dueDate.day,
        nextTask!.dueHour ?? 23,
        nextTask!.dueMinute ?? 59,
      );
      final diff = dueAt.difference(now);
      if (diff.isNegative) {
        headline = 'Overdue';
        outer = 1.0;
        inner = 0.85;
      } else if (diff.inHours < 24) {
        final h = diff.inHours;
        final m = diff.inMinutes.remainder(60);
        headline = '${h}h ${m}m';
        outer = (1 - (diff.inMinutes / (24 * 60))).clamp(0.15, 0.95);
        inner = 0.65;
      } else {
        headline = '${diff.inDays}d left';
        outer = (1 - (diff.inDays / 14)).clamp(0.2, 0.9);
        inner = 0.55;
      }
      caption = nextTask!.title;
    }

    return GlassContainer(
      borderRadius: AppRadius.lg,
      blur: 0,
      elevated: true,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Text(
            'Next Due',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          CircularProgressRing(
            progress: outer,
            secondaryProgress: inner,
            doubleArc: true,
            size: 108,
            strokeWidth: 7,
            centerChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nextTask == null ? 'Status' : 'Due in',
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  headline,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _NextTaskPreviewWidget extends StatelessWidget {
  const _NextTaskPreviewWidget({
    required this.nextTask,
    required this.onTap,
  });

  final TaskItem? nextTask;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return GlassContainer(
      borderRadius: AppRadius.lg,
      blur: 0,
      elevated: true,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SizedBox(
        height: 168,
        child: nextTask == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'AI Auto-Plan',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Paste any schedule notice to generate tasks & reminders.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          nextTask!.type.label,
                          style: textTheme.labelSmall?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    nextTask!.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (nextTask!.courseOrCategory.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      nextTask!.courseOrCategory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          nextTask!.formattedDueTime != null
                              ? '${DateFormat('d MMM').format(nextTask!.dueDate)} • ${nextTask!.formattedDueTime}'
                              : DateFormat('EEE, d MMM').format(nextTask!.dueDate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
