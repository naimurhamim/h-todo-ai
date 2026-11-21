import 'package:flutter/foundation.dart';

import 'task_item.dart';

/// Action kinds the multilingual H-TODO AI chat assistant can perform.
enum AiActionType {
  add,
  complete,
  uncomplete,
  delete,
  reschedule,
  update,
  completeSubtask,
  uncompleteSubtask;

  static AiActionType? fromString(String? raw) {
    final normalized = (raw ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll('-', '')
        .replaceAll(' ', '');
    switch (normalized) {
      case 'add':
      case 'create':
      case 'new':
        return AiActionType.add;
      case 'complete':
      case 'done':
      case 'finish':
      case 'completed':
      case 'markdone':
        return AiActionType.complete;
      case 'uncomplete':
      case 'undo':
      case 'reopen':
      case 'incomplete':
      case 'markundone':
        return AiActionType.uncomplete;
      case 'delete':
      case 'remove':
      case 'cancel':
        return AiActionType.delete;
      case 'reschedule':
      case 'move':
      case 'postpone':
        return AiActionType.reschedule;
      case 'update':
      case 'edit':
      case 'modify':
        return AiActionType.update;
      case 'completesubtask':
      case 'subtaskdone':
      case 'checksubtask':
        return AiActionType.completeSubtask;
      case 'uncompletesubtask':
      case 'subtaskundone':
      case 'unchecksubtask':
        return AiActionType.uncompleteSubtask;
      default:
        return null;
    }
  }
}

/// Single parsed To-Do operation returned by the AI chat assistant.
@immutable
class AiTaskAction {
  const AiTaskAction({
    required this.type,
    this.taskId,
    this.taskQuery,
    this.newTask,
    this.newDueDate,
    this.newDueHour,
    this.newDueMinute,
    this.clearDueTime = false,
    this.newTitle,
    this.newCourseOrCategory,
    this.newTaskType,
    this.newPriority,
    this.newNotes,
    this.addSubtasks = const [],
    this.subtaskTitle,
  });

  final AiActionType type;
  final String? taskId;
  final String? taskQuery;
  final TaskItem? newTask;
  final DateTime? newDueDate;
  final int? newDueHour;
  final int? newDueMinute;
  final bool clearDueTime;
  final String? newTitle;
  final String? newCourseOrCategory;
  final TaskType? newTaskType;
  final TaskPriority? newPriority;
  final String? newNotes;
  final List<String> addSubtasks;
  final String? subtaskTitle;
}

/// Complete multilingual response from the focused H-TODO AI assistant.
@immutable
class AiAssistantResponse {
  const AiAssistantResponse({
    required this.reply,
    this.actions = const [],
    this.referencedTaskIds = const [],
    this.offTopic = false,
    this.resolvedModel,
  });

  final String reply;
  final List<AiTaskAction> actions;
  final List<String> referencedTaskIds;
  final bool offTopic;
  final String? resolvedModel;
}
