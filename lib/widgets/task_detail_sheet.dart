import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/reminder_settings.dart';
import '../models/task_item.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_tokens.dart';
import 'glass_surface.dart';
import 'task_editor_sheet.dart';

/// Frosted glass modal showing full task metadata, reminders, checklist, and notes.
class TaskDetailSheet extends StatelessWidget {
  const TaskDetailSheet({super.key, required this.taskId});

  final String taskId;

  static Future<void> show(BuildContext context, String taskId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TaskDetailSheet(taskId: taskId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final task = taskProvider.findById(taskId);
    if (task == null) return const SizedBox.shrink();

    final settings = context.watch<AiSettingsProvider>().reminderSettings;
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final done = task.isCompleted;

    final dueDateLabel = DateFormat('EEE, d MMM yyyy').format(task.dueDate);
    final dayBeforeDate = task.dueDate.subtract(const Duration(days: 1));
    final dayBeforeDateLabel = DateFormat('EEE, d MMM').format(dayBeforeDate);
    final dueDayLabel = DateFormat('EEE, d MMM').format(task.dueDate);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: GlassContainer(
        borderRadius: AppRadius.xl,
        blur: 18,
        elevated: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GlassPillButton(
                      icon: done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      iconColor: done ? colors.primary : colors.textPrimary,
                      label: done ? 'Completed' : 'Mark Complete',
                      selected: done,
                      onTap: () => taskProvider.toggleTaskComplete(task.id),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  GlassCircleButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit task',
                    onTap: () {
                      Navigator.of(context).pop();
                      TaskEditorSheet.show(context, existing: task);
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  GlassCircleButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete task',
                    iconColor: colors.danger,
                    onTap: () => _confirmDelete(context, taskProvider, task),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  GlassCircleButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                task.title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: done ? colors.textSecondary : colors.textPrimary,
                  decoration:
                      done ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationThickness: 2.0,
                  decorationColor: colors.textSecondary,
                ),
              ),
              if (task.courseOrCategory.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  task.courseOrCategory,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _DetailChip(
                    icon: Icons.event_rounded,
                    label: task.formattedDueTime != null
                        ? '$dueDateLabel • ${task.formattedDueTime}'
                        : dueDateLabel,
                  ),
                  _DetailChip(
                    icon: Icons.label_outline_rounded,
                    label: task.type.label,
                  ),
                  _DetailChip(
                    icon: Icons.flag_outlined,
                    label: '${task.priority.label} priority',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              GlassContainer(
                borderRadius: AppRadius.md,
                blur: 0,
                fillColor: done ? colors.surfaceSubtle : colors.primarySoft,
                borderColor: done ? colors.border : colors.primary.withValues(alpha: 0.35),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          done
                              ? Icons.notifications_off_outlined
                              : Icons.notifications_active_outlined,
                          size: AppIconSize.sm,
                          color: done ? colors.textSecondary : colors.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          done
                              ? 'Task completed — reminders cleared'
                              : (settings.enabled
                                  ? 'Automatic Reminders'
                                  : 'Reminders paused in Profile'),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (!done) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Day-before alert: $dayBeforeDateLabel at ${ReminderSettings.formatHourMinute(settings.dayBeforeHour, settings.dayBeforeMinute)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      if (task.hasDueTime) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Custom task alert: $dueDayLabel at ${task.formattedDueTime}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'End-of-day check-in: $dueDayLabel at ${ReminderSettings.formatHourMinute(settings.endOfDayHour, settings.endOfDayMinute)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (task.subtasks.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Text(
                      'Syllabus / Checklist',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${task.subtasks.where((s) => s.isCompleted).length}/${task.subtasks.length}',
                      style: textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                GlassContainer(
                  borderRadius: AppRadius.md,
                  blur: 0,
                  fillColor: colors.surfaceSubtle,
                  child: Column(
                    children: [
                      for (var i = 0; i < task.subtasks.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _SubtaskRow(
                          subtask: task.subtasks[i],
                          onTap: () => taskProvider.toggleSubtaskComplete(
                            task.id,
                            task.subtasks[i].id,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (task.notes.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Details & Notes',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GlassContainer(
                  borderRadius: AppRadius.md,
                  blur: 0,
                  fillColor: colors.surfaceSubtle,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SelectableText(
                    task.notes,
                    style: textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TaskProvider taskProvider,
    TaskItem task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Remove "${task.title}" and cancel its reminders?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await taskProvider.deleteTask(task.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({required this.subtask, required this.onTap});

  final SubTaskItem subtask;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final done = subtask.isCompleted;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                done
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: AppIconSize.md,
                color: done ? colors.primary : colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  subtask.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: done ? colors.textSecondary : colors.textPrimary,
                        decoration: done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: colors.textSecondary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
