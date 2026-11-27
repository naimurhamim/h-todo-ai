import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task_item.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/task_provider.dart';
import '../providers/update_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_tokens.dart';
import 'glass_surface.dart';
import 'task_card.dart';

/// Frosted read-only notifications modal with app-update banner and Today/Tomorrow panels.
class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key, this.onOpenUpdate});

  final VoidCallback? onOpenUpdate;

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onOpenUpdate,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => NotificationsSheet(onOpenUpdate: onOpenUpdate),
    );
  }

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  int _selectedPanel = 0; // 0 = Today, 1 = Tomorrow

  DateTime _effectiveDue(TaskItem task) {
    return DateTime(
      task.dueDate.year,
      task.dueDate.month,
      task.dueDate.day,
      task.dueHour ?? 23,
      task.dueMinute ?? 59,
    );
  }

  String _countdownText(TaskItem task, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(
      task.dueDate.year,
      task.dueDate.month,
      task.dueDate.day,
    );
    final dayDiff = dueDay.difference(today).inDays;

    if (dayDiff == 0) {
      final dueAt = _effectiveDue(task);
      final diff = dueAt.difference(now);
      if (diff.isNegative) {
        return 'Due earlier today';
      }
      if (task.hasDueTime && diff.inHours < 12) {
        final hrs = diff.inHours;
        final mins = diff.inMinutes.remainder(60);
        if (hrs == 0) return 'Due in ${mins}m';
        return 'Due in ${hrs}h ${mins}m';
      }
      return task.formattedDueTime != null
          ? 'Due today (${task.formattedDueTime})'
          : 'Due today';
    }
    if (dayDiff == 1) {
      return task.formattedDueTime != null
          ? 'Due tomorrow • ${task.formattedDueTime}'
          : 'Due tomorrow';
    }
    return DateFormat('EEE, d MMM').format(task.dueDate);
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final reminder = context.watch<AiSettingsProvider>().reminderSettings;
    final updateInfo = context.watch<UpdateProvider>().availableUpdate;
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();

    final todayOnly = DateTime(now.year, now.month, now.day);
    final tomorrowOnly = todayOnly.add(const Duration(days: 1));

    final todayTasks = <TaskItem>[];
    final tomorrowTasks = <TaskItem>[];

    for (final task in taskProvider.tasks) {
      if (task.isCompleted) continue;
      final dueDay = DateTime(
        task.dueDate.year,
        task.dueDate.month,
        task.dueDate.day,
      );
      if (dueDay == todayOnly) {
        todayTasks.add(task);
      } else if (dueDay == tomorrowOnly) {
        tomorrowTasks.add(task);
      }
    }

    todayTasks.sort((a, b) => _effectiveDue(a).compareTo(_effectiveDue(b)));
    tomorrowTasks.sort((a, b) => _effectiveDue(a).compareTo(_effectiveDue(b)));

    final visibleTasks = _selectedPanel == 0 ? todayTasks : tomorrowTasks;
    final subtitleText = reminder.enabled
        ? '${todayTasks.length} left today • ${tomorrowTasks.length} tomorrow'
        : 'Reminders paused • ${todayTasks.length} left today';

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: GlassContainer(
        borderRadius: AppRadius.xl,
        blur: 10,
        elevated: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (updateInfo != null) ...[
              GlassContainer(
                borderRadius: AppRadius.lg,
                blur: 0,
                borderColor: colors.primary,
                fillColor: colors.primarySoft,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onOpenUpdate?.call();
                },
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary,
                      ),
                      child: Icon(
                        Icons.system_update_rounded,
                        size: 18,
                        color: colors.onPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update Available • v${updateInfo.latestVersion}',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            'Tap to view in Profile -> Check for Updates',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            GlassContainer(
              borderRadius: AppRadius.pill,
              blur: 0,
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _NotifPanelTab(
                      label: 'Today (${todayTasks.length})',
                      selected: _selectedPanel == 0,
                      onTap: () => setState(() => _selectedPanel = 0),
                    ),
                  ),
                  Expanded(
                    child: _NotifPanelTab(
                      label: 'Tomorrow (${tomorrowTasks.length})',
                      selected: _selectedPanel == 1,
                      onTap: () => setState(() => _selectedPanel = 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (visibleTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Column(
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 36,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _selectedPanel == 0
                          ? 'All caught up'
                          : 'Nothing for tomorrow',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedPanel == 0
                          ? 'No pending tasks left for today.'
                          : 'No pending tasks scheduled for tomorrow.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: visibleTasks.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final task = visibleTasks[index];
                    final alerts = NotificationScheduleCalculator.compute(
                      task,
                      reminder,
                      now: now,
                    );

                    return GlassContainer(
                      borderRadius: AppRadius.lg,
                      blur: 0,
                      borderColor: colors.glassBorder,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.surfaceSubtle,
                              border: Border.all(
                                color: colors.glassBorder,
                              ),
                            ),
                            child: Icon(
                              taskTypeIcon(task.type),
                              size: AppIconSize.md,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (task.courseOrCategory.trim().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    task.courseOrCategory,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  _countdownText(task, now),
                                  style: textTheme.labelMedium?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (alerts.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  for (final alert in alerts)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 2),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.alarm_rounded,
                                            size: 13,
                                            color: colors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '${alert.isCustomTime ? 'Task alert' : (alert.isDayBefore ? 'Day before' : 'Due day')}: ${DateFormat('EEE, d MMM • h:mm a').format(alert.scheduledAt)}',
                                              style: textTheme.labelSmall
                                                  ?.copyWith(
                                                color: colors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotifPanelTab extends StatelessWidget {
  const _NotifPanelTab({
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
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            color: selected ? colors.primary : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? colors.onPrimary : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
