import 'package:flutter/material.dart';

import '../models/task_item.dart';
import '../theme/app_tokens.dart';
import 'glass_surface.dart';
import 'task_type_icons.dart';

export 'task_type_icons.dart'
    show customTypeIconByKey, taskIconForItem, taskLabelForItem, taskTypeIcon;

/// Frosted glass task card with strikethrough completion and expandable subtask drop-down.
class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggleComplete,
    required this.onTap,
    this.onToggleSubtask,
    this.onDelete,
    this.compact = false,
  });

  final TaskItem task;
  final VoidCallback onToggleComplete;
  final VoidCallback onTap;
  final void Function(String subtaskId)? onToggleSubtask;
  final VoidCallback? onDelete;
  final bool compact;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final task = widget.task;
    final done = task.isCompleted;
    final completedSubtasks = task.subtasks.where((s) => s.isCompleted).length;
    final canExpand = !widget.compact &&
        (task.subtasks.isNotEmpty ||
            task.notes.trim().isNotEmpty ||
            widget.onDelete != null);

    return GlassContainer(
      borderRadius: AppRadius.lg,
      blur: 0,
      elevated: !done,
      borderColor: colors.glassBorder,
      onTap: widget.onTap,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: widget.compact ? AppSpacing.sm : AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: done
                    ? 'Mark ${task.title} as incomplete'
                    : 'Mark ${task.title} as complete',
                button: true,
                checked: done,
                child: InkResponse(
                  onTap: widget.onToggleComplete,
                  radius: 24,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done ? colors.primary : colors.surfaceSubtle,
                          border: Border.all(
                            color: done ? colors.primary : colors.glassBorder,
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          done ? Icons.check_rounded : taskIconForItem(task),
                          size: AppIconSize.md,
                          color: done ? colors.onPrimary : colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: done
                                  ? colors.textSecondary
                                  : colors.textPrimary,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              decorationThickness: 2.0,
                              decorationColor: colors.textSecondary,
                            ),
                          ),
                        ),
                        if (done) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceSubtle,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              'Done',
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (task.courseOrCategory.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        task.courseOrCategory,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                          decoration: done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: colors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _GlassTag(label: taskLabelForItem(task)),
                        if (task.formattedDueTime != null)
                          _GlassTag(
                            icon: Icons.schedule_rounded,
                            label: task.formattedDueTime!,
                          ),
                        if (task.subtasks.isNotEmpty)
                          _GlassTag(
                            icon: Icons.checklist_rounded,
                            label: '$completedSubtasks/${task.subtasks.length}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canExpand)
                Semantics(
                  label: _expanded
                      ? 'Collapse ${task.title} details'
                      : 'Expand ${task.title} details',
                  button: true,
                  child: IconButton(
                    tooltip: _expanded ? 'Collapse' : 'Drop down',
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _ExpandedDropSection(
              task: task,
              onToggleSubtask: widget.onToggleSubtask,
              onOpenDetail: widget.onTap,
              onDelete: widget.onDelete,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

class _GlassTag extends StatelessWidget {
  const _GlassTag({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: colors.textSecondary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedDropSection extends StatelessWidget {
  const _ExpandedDropSection({
    required this.task,
    required this.onToggleSubtask,
    required this.onOpenDetail,
    required this.onDelete,
  });

  final TaskItem task;
  final void Function(String subtaskId)? onToggleSubtask;
  final VoidCallback onOpenDetail;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          if (task.subtasks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final sub in task.subtasks)
              InkWell(
                onTap: onToggleSubtask != null
                    ? () => onToggleSubtask!(sub.id)
                    : null,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        sub.isCompleted
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 18,
                        color: sub.isCompleted
                            ? colors.primary
                            : colors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          sub.title,
                          style: textTheme.bodySmall?.copyWith(
                            color: sub.isCompleted
                                ? colors.textSecondary
                                : colors.textPrimary,
                            decoration: sub.isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (task.notes.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              task.notes.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onOpenDetail,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text(
                      'Details',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              if (onDelete != null)
                TextButton.icon(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: colors.danger,
                  ),
                  label: Text(
                    'Delete',
                    style: TextStyle(color: colors.danger),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
