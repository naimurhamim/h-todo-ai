import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/reminder_settings.dart';
import '../models/task_item.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/task_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_tokens.dart';
import 'glass_surface.dart';
import 'task_card.dart';

/// Frosted read-only notifications modal showing upcoming deadlines, remaining days, and alert times.
class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const NotificationsSheet(),
    );
  }

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

    if (dayDiff < 0) {
      final overdueDays = -dayDiff;
      return overdueDays == 1
          ? 'Overdue by 1 day'
          : 'Overdue by $overdueDays days';
    }
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
    return 'Due in $dayDiff days (${DateFormat('EEE, d MMM').format(task.dueDate)})';
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final reminder = context.watch<AiSettingsProvider>().reminderSettings;
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();

    final pending = taskProvider.tasks.where((t) => !t.isCompleted).toList()
      ..sort((a, b) => _effectiveDue(a).compareTo(_effectiveDue(b)));

    final dayBeforeLabel = ReminderSettings.formatHourMinute(
      reminder.dayBeforeHour,
      reminder.dayBeforeMinute,
    );
    final dueDayLabel = ReminderSettings.formatHourMinute(
      reminder.endOfDayHour,
      reminder.endOfDayMinute,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: GlassContainer(
        borderRadius: AppRadius.xl,
        blur: 18,
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
                        reminder.enabled
                            ? '${pending.length} upcoming • Alerts at $dayBeforeLabel & $dueDayLabel'
                            : '${pending.length} upcoming • Reminders paused',
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
            if (pending.isEmpty)
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
                      'All caught up',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No upcoming deadlines or pending reminders right now.',
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
                  itemCount: pending.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final task = pending[index];
                    final alerts = NotificationScheduleCalculator.compute(
                      task,
                      reminder,
                      now: now,
                    );
                    final dueDayOnly = DateTime(
                      task.dueDate.year,
                      task.dueDate.month,
                      task.dueDate.day,
                    );
                    final todayOnly = DateTime(now.year, now.month, now.day);
                    final isOverdue = dueDayOnly.isBefore(todayOnly);

                    return GlassContainer(
                      borderRadius: AppRadius.lg,
                      blur: 0,
                      borderColor:
                          isOverdue ? colors.danger : colors.glassBorder,
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
                                    color: isOverdue
                                        ? colors.danger
                                        : colors.primary,
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
