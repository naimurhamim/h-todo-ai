import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/custom_task_type.dart';
import '../models/reminder_settings.dart';
import '../models/task_item.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_tokens.dart';
import 'glass_surface.dart';
import 'task_type_icons.dart';

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
  String? _customTypeId;
  String? _customTypeLabel;
  String? _customTypeIconKey;
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
    _customTypeId = e?.customTypeId;
    _customTypeLabel = e?.customTypeLabel;
    _customTypeIconKey = e?.customTypeIconKey;
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
    final customTypes = context.watch<TaskProvider>().customTaskTypes;
    final reminder = context.watch<AiSettingsProvider>().reminderSettings;
    final dayBeforeStr = ReminderSettings.formatHourMinute(
      reminder.dayBeforeHour,
      reminder.dayBeforeMinute,
    );
    final endOfDayStr = ReminderSettings.formatHourMinute(
      reminder.endOfDayHour,
      reminder.endOfDayMinute,
    );
    final isEditing = widget.existing != null;

    final entries = <_TypeChipEntry>[
      for (final custom in customTypes)
        _TypeChipEntry.custom(
          custom: custom,
          icon: customTypeIconByKey(custom.iconKey),
          label: custom.name,
        ),
      for (final builtIn in TaskType.values)
        _TypeChipEntry.builtIn(
          taskType: builtIn,
          icon: taskTypeIcon(builtIn),
          label: builtIn.label,
        ),
    ];
    final split = (entries.length + 1) ~/ 2;
    final row1 = entries.sublist(0, split);
    final row2 = entries.sublist(split);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: GlassContainer(
        borderRadius: AppRadius.xl,
        blur: 10,
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
                    hintText: 'e.g. Send Mail, Bank Visit or Class Test',
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
                    hintText: 'e.g. IRE 415, Personal or Office',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text('Type', style: textTheme.labelLarge),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _openCreateCustomTypeDialog,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: const Text('Custom'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < row1.length; i++) ...[
                            if (i > 0) const SizedBox(width: AppSpacing.sm),
                            _buildTypeChip(row1[i]),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          for (var i = 0; i < row2.length; i++) ...[
                            if (i > 0) const SizedBox(width: AppSpacing.sm),
                            _buildTypeChip(row2[i]),
                          ],
                        ],
                      ),
                    ],
                  ),
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
                  !reminder.enabled
                      ? 'Notifications are paused in Profile -> Reminders.'
                      : (_dueTime != null
                          ? 'Custom alert active: fires only at ${_dueTime!.format(context)} on due date (default alerts disabled).'
                          : 'Default alerts: $dayBeforeStr day before & $endOfDayStr on due date. Set a custom time to override.'),
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

  Widget _buildTypeChip(_TypeChipEntry entry) {
    final custom = entry.custom;
    if (custom != null) {
      return InputChip(
        avatar: Icon(entry.icon, size: 16),
        label: Text(entry.label),
        selected: _customTypeId == custom.id,
        showCheckmark: false,
        onSelected: (_) => setState(() {
          _customTypeId = custom.id;
          _customTypeLabel = custom.name;
          _customTypeIconKey = custom.iconKey;
          _type = TaskType.task;
        }),
        deleteIcon: const Icon(Icons.close_rounded, size: 15),
        deleteButtonTooltipMessage: 'Remove ${custom.name}',
        onDeleted: () async {
          final provider = context.read<TaskProvider>();
          if (_customTypeId == custom.id) {
            setState(() {
              _customTypeId = null;
              _customTypeLabel = null;
              _customTypeIconKey = null;
              _type = TaskType.task;
            });
          }
          await provider.deleteCustomTaskType(custom.id);
        },
      );
    }

    final t = entry.taskType!;
    return ChoiceChip(
      avatar: Icon(entry.icon, size: 16),
      label: Text(entry.label),
      selected: _customTypeId == null && _type == t,
      showCheckmark: false,
      onSelected: (_) => setState(() {
        _customTypeId = null;
        _customTypeLabel = null;
        _customTypeIconKey = null;
        _type = t;
      }),
    );
  }

  Future<void> _openCreateCustomTypeDialog() async {
    final result = await showDialog<({String name, String iconKey})>(
      context: context,
      builder: (_) => const _CustomTaskTypeDialog(),
    );
    if (result == null || !mounted) return;
    final created = await context.read<TaskProvider>().addCustomTaskType(
          name: result.name,
          iconKey: result.iconKey,
        );
    if (created == null || !mounted) return;
    setState(() {
      _customTypeId = created.id;
      _customTypeLabel = created.name;
      _customTypeIconKey = created.iconKey;
      _type = TaskType.task;
    });
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
      customTypeId: _customTypeId,
      customTypeLabel: _customTypeLabel,
      customTypeIconKey: _customTypeIconKey,
      priority: _priority,
      dueDate: _dueDate,
      dueHour: _dueTime?.hour,
      dueMinute: _dueTime?.minute,
      notes: _notesCtrl.text.trim(),
      subtasks: _subtasks,
      isCompleted: existing?.isCompleted ?? false,
      completedAt: existing?.completedAt,
      createdAt: existing?.createdAt ?? DateTime.now(),
      seriesId: existing?.seriesId,
    );

    if (existing != null) {
      await provider.updateTask(item);
    } else {
      await provider.addTask(item);
    }

    if (mounted) Navigator.of(context).pop();
  }
}

class _TypeChipEntry {
  const _TypeChipEntry.custom({
    required this.custom,
    required this.icon,
    required this.label,
  }) : taskType = null;

  const _TypeChipEntry.builtIn({
    required this.taskType,
    required this.icon,
    required this.label,
  }) : custom = null;

  final CustomTaskType? custom;
  final TaskType? taskType;
  final IconData icon;
  final String label;
}

class _CustomTaskTypeDialog extends StatefulWidget {
  const _CustomTaskTypeDialog();

  @override
  State<_CustomTaskTypeDialog> createState() => _CustomTaskTypeDialogState();
}

class _CustomTaskTypeDialogState extends State<_CustomTaskTypeDialog> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedIconKey = kCustomTypeIconOptions.first.key;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('New Custom Task Type'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Type Name *',
                  hintText: 'e.g. Tuition, Visa, Client',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter a type name'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Choose Icon', style: textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 210,
                child: GridView.builder(
                  itemCount: kCustomTypeIconOptions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final opt = kCustomTypeIconOptions[index];
                    final selected = _selectedIconKey == opt.key;
                    return Tooltip(
                      message: opt.label,
                      child: Semantics(
                        label: '${opt.label} icon',
                        selected: selected,
                        button: true,
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedIconKey = opt.key),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            decoration: BoxDecoration(
                              color: selected
                                  ? colors.primarySoft
                                  : colors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: selected
                                    ? colors.primary
                                    : colors.glassBorder,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Icon(
                              opt.icon,
                              size: 22,
                              color: selected
                                  ? colors.primary
                                  : colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop((
              name: _nameCtrl.text.trim(),
              iconKey: _selectedIconKey,
            ));
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
