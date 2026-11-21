import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/task_item.dart';
import '../providers/task_provider.dart';
import '../theme/app_tokens.dart';
import 'glass_surface.dart';

/// Frosted modal editor to create or update a task manually.
class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({super.key, this.existing, this.initialDate});

  final TaskItem? existing;
  final DateTime? initialDate;

  static Future<void> show(
    BuildContext context, {
    TaskItem? existing,
    DateTime? initialDate,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          TaskEditorSheet(existing: existing, initialDate: initialDate),
    );
  }

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  static const _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _courseCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _subtaskInputCtrl;

  late TaskType _type;
  late TaskPriority _priority;
  late DateTime _dueDate;
  TimeOfDay? _dueTime;
  late List<SubTaskItem> _subtasks;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _courseCtrl = TextEditingController(text: e?.courseOrCategory ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _subtaskInputCtrl = TextEditingController();
    _type = e?.type ?? TaskType.task;
    _priority = e?.priority ?? TaskPriority.medium;
    final base = widget.initialDate ?? DateTime.now();
    _dueDate = e?.dueDate ?? DateTime(base.year, base.month, base.day);
    _dueTime = (e != null && e.hasDueTime)
        ? TimeOfDay(hour: e.dueHour!, minute: e.dueMinute!)
        : null;
    _subtasks = List<SubTaskItem>.from(e?.subtasks ?? const []);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _courseCtrl.dispose();
    _notesCtrl.dispose();
    _subtaskInputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isEditing ? 'Edit Task' : 'New Task',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    GlassCircleButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Task Title *',
                    hintText: 'e.g. Assignment 03 or Class Test',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _courseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Course / Category',
                    hintText: 'e.g. IRE 415 – Computer Vision',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Type', style: textTheme.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: TaskType.values.map((t) {
                    return ChoiceChip(
                      label: Text(t.label),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Priority', style: textTheme.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: TaskPriority.values.map((p) {
                    return ChoiceChip(
                      label: Text(p.label),
                      selected: _priority == p,
                      onSelected: (_) => setState(() => _priority = p),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_rounded, size: 18),
                        label: Text(DateFormat('d MMM yyyy').format(_dueDate)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule_rounded, size: 18),
                        label: Text(
                          _dueTime == null
                              ? 'Custom reminder time'
                              : _dueTime!.format(context),
                        ),
                      ),
                    ),
                    if (_dueTime != null)
                      IconButton(
                        tooltip: 'Clear time',
                        onPressed: () => setState(() => _dueTime = null),
                        icon: const Icon(Icons.clear_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Default alerts fire at 4:00 PM day before & 10:00 PM due day (plus custom time if set).',
                  style: textTheme.labelSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Checklist / Syllabus Topics', style: textTheme.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _subtaskInputCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Add topic or sub-task...',
                        ),
                        onSubmitted: (_) => _addSubtask(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      onPressed: _addSubtask,
                      child: const Text('Add'),
                    ),
                  ],
                ),
                if (_subtasks.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  for (var i = 0; i < _subtasks.length; i++)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(_subtasks[i].title),
                      trailing: IconButton(
                        tooltip: 'Remove item',
                        onPressed: () => setState(() => _subtasks.removeAt(i)),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Details',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(isEditing ? 'Save Changes' : 'Create Task'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _dueDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 23, minute: 59),
    );
    if (picked != null) {
      setState(() => _dueTime = picked);
    }
  }

  void _addSubtask() {
    final text = _subtaskInputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _subtasks.add(SubTaskItem(id: _uuid.v4(), title: text));
      _subtaskInputCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final provider = context.read<TaskProvider>();
    final existing = widget.existing;
    final id = existing?.id ?? _uuid.v4();

    final item = TaskItem(
      id: id,
      notificationBaseId:
          existing?.notificationBaseId ?? TaskItem.stableBaseIdFromUuid(id),
      title: _titleCtrl.text.trim(),
      courseOrCategory: _courseCtrl.text.trim(),
      type: _type,
      priority: _priority,
      dueDate: _dueDate,
      dueHour: _dueTime?.hour,
      dueMinute: _dueTime?.minute,
      notes: _notesCtrl.text.trim(),
      subtasks: _subtasks,
      isCompleted: existing?.isCompleted ?? false,
      completedAt: existing?.completedAt,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    if (existing != null) {
      await provider.updateTask(item);
    } else {
      await provider.addTask(item);
    }

    if (mounted) Navigator.of(context).pop();
  }
}
