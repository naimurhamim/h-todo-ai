import 'package:flutter/foundation.dart';

/// Semantic category for a scheduled task.
enum TaskType {
  assignment,
  classTest,
  exam,
  lab,
  meeting,
  mail,
  travel,
  bank,
  institution,
  call,
  work,
  study,
  bill,
  shopping,
  health,
  fitness,
  event,
  family,
  document,
  personal,
  task;

  String get label {
    switch (this) {
      case TaskType.assignment:
        return 'Assignment';
      case TaskType.classTest:
        return 'Class Test';
      case TaskType.exam:
        return 'Exam';
      case TaskType.lab:
        return 'Lab';
      case TaskType.meeting:
        return 'Meeting';
      case TaskType.mail:
        return 'Mail';
      case TaskType.travel:
        return 'Travel';
      case TaskType.bank:
        return 'Bank';
      case TaskType.institution:
        return 'Institution';
      case TaskType.call:
        return 'Call';
      case TaskType.work:
        return 'Work';
      case TaskType.study:
        return 'Study';
      case TaskType.bill:
        return 'Bill';
      case TaskType.shopping:
        return 'Shopping';
      case TaskType.health:
        return 'Health';
      case TaskType.fitness:
        return 'Fitness';
      case TaskType.event:
        return 'Event';
      case TaskType.family:
        return 'Family';
      case TaskType.document:
        return 'Document';
      case TaskType.personal:
        return 'Personal';
      case TaskType.task:
        return 'Task';
    }
  }

  static TaskType fromString(String? raw) {
    final normalized =
        (raw ?? '').trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
    switch (normalized) {
      case 'assignment':
        return TaskType.assignment;
      case 'classtest':
      case 'quiz':
      case 'ct':
        return TaskType.classTest;
      case 'exam':
      case 'midterm':
      case 'final':
        return TaskType.exam;
      case 'lab':
      case 'sessional':
        return TaskType.lab;
      case 'meeting':
        return TaskType.meeting;
      case 'mail':
      case 'email':
        return TaskType.mail;
      case 'travel':
      case 'trip':
      case 'flight':
      case 'tour':
        return TaskType.travel;
      case 'bank':
      case 'banking':
      case 'finance':
        return TaskType.bank;
      case 'institution':
      case 'university':
      case 'college':
      case 'school':
      case 'office':
      case 'govt':
        return TaskType.institution;
      case 'call':
      case 'phone':
        return TaskType.call;
      case 'work':
      case 'job':
      case 'project':
        return TaskType.work;
      case 'study':
      case 'revision':
      case 'reading':
        return TaskType.study;
      case 'bill':
      case 'bills':
      case 'payment':
      case 'rent':
      case 'fee':
        return TaskType.bill;
      case 'shopping':
      case 'shop':
      case 'grocery':
      case 'buy':
      case 'market':
        return TaskType.shopping;
      case 'health':
      case 'doctor':
      case 'medicine':
      case 'hospital':
        return TaskType.health;
      case 'fitness':
      case 'gym':
      case 'workout':
      case 'exercise':
        return TaskType.fitness;
      case 'event':
      case 'ceremony':
      case 'program':
        return TaskType.event;
      case 'family':
      case 'parents':
      case 'home':
        return TaskType.family;
      case 'document':
      case 'documents':
      case 'docs':
      case 'passport':
      case 'visa':
      case 'paperwork':
      case 'form':
        return TaskType.document;
      case 'personal':
      case 'self':
        return TaskType.personal;
      default:
        return TaskType.task;
    }
  }
}

/// Urgency level of a task.
enum TaskPriority {
  high,
  medium,
  low;

  String get label {
    switch (this) {
      case TaskPriority.high:
        return 'High';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.low:
        return 'Low';
    }
  }

  static TaskPriority fromString(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'high':
        return TaskPriority.high;
      case 'low':
        return TaskPriority.low;
      default:
        return TaskPriority.medium;
    }
  }
}

/// Single syllabus point or checklist sub-item belonging to a task.
@immutable
class SubTaskItem {
  const SubTaskItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final bool isCompleted;

  SubTaskItem copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return SubTaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
      };

  factory SubTaskItem.fromJson(Map<String, dynamic> json) => SubTaskItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        isCompleted: json['isCompleted'] == true,
      );
}

/// Core scheduled task item with dual-reminder support.
@immutable
class TaskItem {
  const TaskItem({
    required this.id,
    required this.notificationBaseId,
    required this.title,
    required this.dueDate,
    required this.createdAt,
    this.courseOrCategory = '',
    this.type = TaskType.task,
    this.customTypeId,
    this.customTypeLabel,
    this.customTypeIconKey,
    this.priority = TaskPriority.medium,
    this.dueHour,
    this.dueMinute,
    this.notes = '',
    this.subtasks = const [],
    this.isCompleted = false,
    this.completedAt,
    this.seriesId,
  });

  final String id;
  final int notificationBaseId;
  final String title;
  final String courseOrCategory;
  final TaskType type;
  final String? customTypeId;
  final String? customTypeLabel;
  final String? customTypeIconKey;
  final TaskPriority priority;
  final DateTime dueDate;
  final int? dueHour;
  final int? dueMinute;
  final String notes;
  final List<SubTaskItem> subtasks;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final String? seriesId;

  String get displayTypeLabel {
    final custom = customTypeLabel?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return type.label;
  }

  bool get hasDueTime => dueHour != null && dueMinute != null;

  /// Normalized YYYY-MM-DD key for grouping tasks by due date.
  String get dateKey =>
      '${dueDate.year.toString().padLeft(4, '0')}-'
      '${dueDate.month.toString().padLeft(2, '0')}-'
      '${dueDate.day.toString().padLeft(2, '0')}';

  /// Formatted 12-hour due time string (e.g. "11:59 PM"), or null when unset.
  String? get formattedDueTime {
    if (!hasDueTime) return null;
    final h = dueHour!;
    final m = dueMinute!;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayHour = h % 12 == 0 ? 12 : h % 12;
    return '$displayHour:${m.toString().padLeft(2, '0')} $period';
  }

  /// Generates a stable positive notification base ID from an arbitrary task ID.
  /// Masked to 28 bits so `base * 3 + 2` always fits within 31-bit Android IDs.
  static int stableBaseIdFromUuid(String id) {
    var hash = 2166136261;
    for (final unit in id.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x0FFFFFFF;
    }
    return hash == 0 ? 1 : hash;
  }

  TaskItem copyWith({
    String? id,
    int? notificationBaseId,
    String? title,
    String? courseOrCategory,
    TaskType? type,
    String? customTypeId,
    String? customTypeLabel,
    String? customTypeIconKey,
    bool clearCustomType = false,
    TaskPriority? priority,
    DateTime? dueDate,
    int? dueHour,
    int? dueMinute,
    bool clearDueTime = false,
    String? notes,
    List<SubTaskItem>? subtasks,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? createdAt,
    String? seriesId,
    bool clearSeriesId = false,
  }) {
    return TaskItem(
      id: id ?? this.id,
      notificationBaseId: notificationBaseId ?? this.notificationBaseId,
      title: title ?? this.title,
      courseOrCategory: courseOrCategory ?? this.courseOrCategory,
      type: type ?? this.type,
      customTypeId:
          clearCustomType ? null : (customTypeId ?? this.customTypeId),
      customTypeLabel:
          clearCustomType ? null : (customTypeLabel ?? this.customTypeLabel),
      customTypeIconKey: clearCustomType
          ? null
          : (customTypeIconKey ?? this.customTypeIconKey),
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      dueHour: clearDueTime ? null : (dueHour ?? this.dueHour),
      dueMinute: clearDueTime ? null : (dueMinute ?? this.dueMinute),
      notes: notes ?? this.notes,
      subtasks: subtasks ?? this.subtasks,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt ?? this.createdAt,
      seriesId: clearSeriesId ? null : (seriesId ?? this.seriesId),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'notificationBaseId': notificationBaseId,
        'title': title,
        'courseOrCategory': courseOrCategory,
        'type': type.name,
        if (customTypeId != null && customTypeId!.trim().isNotEmpty)
          'customTypeId': customTypeId!.trim(),
        if (customTypeLabel != null && customTypeLabel!.trim().isNotEmpty)
          'customTypeLabel': customTypeLabel!.trim(),
        if (customTypeIconKey != null && customTypeIconKey!.trim().isNotEmpty)
          'customTypeIconKey': customTypeIconKey!.trim(),
        'priority': priority.name,
        'dueDate': dateKey,
        'dueHour': dueHour,
        'dueMinute': dueMinute,
        'notes': notes,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        if (seriesId != null) 'seriesId': seriesId,
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final parsedDue = DateTime.tryParse(json['dueDate']?.toString() ?? '') ??
        DateTime.now();
    final id = json['id']?.toString() ?? '';
    final rawSeries = json['seriesId']?.toString().trim();
    final rawCustomId = json['customTypeId']?.toString().trim();
    final rawCustomLabel = json['customTypeLabel']?.toString().trim();
    final rawCustomIconKey = json['customTypeIconKey']?.toString().trim();
    return TaskItem(
      id: id,
      notificationBaseId: (json['notificationBaseId'] as int?) ??
          stableBaseIdFromUuid(id),
      title: json['title']?.toString() ?? 'Untitled Task',
      courseOrCategory: json['courseOrCategory']?.toString() ?? '',
      type: TaskType.fromString(json['type']?.toString()),
      customTypeId:
          (rawCustomId == null || rawCustomId.isEmpty) ? null : rawCustomId,
      customTypeLabel: (rawCustomLabel == null || rawCustomLabel.isEmpty)
          ? null
          : rawCustomLabel,
      customTypeIconKey: (rawCustomIconKey == null || rawCustomIconKey.isEmpty)
          ? null
          : rawCustomIconKey,
      priority: TaskPriority.fromString(json['priority']?.toString()),
      dueDate: DateTime(parsedDue.year, parsedDue.month, parsedDue.day),
      dueHour: json['dueHour'] as int?,
      dueMinute: json['dueMinute'] as int?,
      notes: json['notes']?.toString() ?? '',
      subtasks: (json['subtasks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SubTaskItem.fromJson)
          .toList(),
      isCompleted: json['isCompleted'] == true,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      seriesId: (rawSeries == null || rawSeries.isEmpty) ? null : rawSeries,
    );
  }
}
