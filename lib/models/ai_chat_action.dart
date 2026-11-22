import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'task_item.dart';

/// Action kinds the multilingual H-TODO AI chat assistant can perform.
enum AiActionType {
  add,
  addRecurring,
  complete,
  uncomplete,
  delete,
  reschedule,
  update,
  bulkDelete,
  bulkReschedule,
  bulkUpdate,
  bulkComplete,
  bulkUncomplete,
  completeSubtask,
  uncompleteSubtask,
  updateReminderSettings;

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
      case 'addrecurring':
      case 'recurring':
      case 'repeat':
      case 'createrecurring':
      case 'addseries':
      case 'schedulerecurring':
        return AiActionType.addRecurring;
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
      case 'bulkdelete':
      case 'deletemany':
      case 'deleteseries':
      case 'deleteall':
      case 'removemany':
      case 'removeseries':
      case 'cancelmany':
      case 'cancelseries':
      case 'cleartasks':
        return AiActionType.bulkDelete;
      case 'bulkreschedule':
      case 'reschedulemany':
      case 'rescheduleseries':
      case 'movemany':
      case 'shifttasks':
        return AiActionType.bulkReschedule;
      case 'bulkupdate':
      case 'updatemany':
      case 'updateseries':
      case 'editmany':
        return AiActionType.bulkUpdate;
      case 'bulkcomplete':
      case 'completemany':
      case 'completeseries':
      case 'markalldone':
        return AiActionType.bulkComplete;
      case 'bulkuncomplete':
      case 'uncompletemany':
      case 'reopenmany':
        return AiActionType.bulkUncomplete;
      case 'completesubtask':
      case 'subtaskdone':
      case 'checksubtask':
        return AiActionType.completeSubtask;
      case 'uncompletesubtask':
      case 'subtaskundone':
      case 'unchecksubtask':
        return AiActionType.uncompleteSubtask;
      case 'updateremindersettings':
      case 'remindersettings':
      case 'setremindertime':
      case 'changereminder':
        return AiActionType.updateReminderSettings;
      default:
        return null;
    }
  }
}

/// Supported cadence patterns for recurring schedule generation.
enum RecurrenceFrequency {
  daily,
  everyNDays,
  weekly,
  monthly;

  static RecurrenceFrequency fromString(String? raw) {
    final norm = (raw ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll('-', '')
        .replaceAll(' ', '');
    switch (norm) {
      case 'everyndays':
      case 'intervaldays':
      case 'everyxdays':
      case 'ndays':
        return RecurrenceFrequency.everyNDays;
      case 'weekly':
      case 'everyweek':
      case 'week':
        return RecurrenceFrequency.weekly;
      case 'monthly':
      case 'everymonth':
      case 'month':
        return RecurrenceFrequency.monthly;
      case 'daily':
      case 'everyday':
      case 'day':
      default:
        return RecurrenceFrequency.daily;
    }
  }
}

/// Rule describing a repeating schedule expanded locally into concrete tasks.
@immutable
class RecurringTaskSpec {
  static const int maxTasksPerCommand = 400;
  static const int maxHorizonDays = 366;

  const RecurringTaskSpec({
    required this.title,
    this.courseOrCategory = '',
    this.taskType = TaskType.task,
    this.priority = TaskPriority.medium,
    this.notes = '',
    this.subtasks = const [],
    this.frequency = RecurrenceFrequency.daily,
    this.interval = 1,
    required this.startDate,
    this.endDate,
    this.durationDays,
    this.durationMonths,
    this.maxOccurrences,
    this.weekdays = const [],
    this.dayOfMonth,
    this.times = const [],
  });

  final String title;
  final String courseOrCategory;
  final TaskType taskType;
  final TaskPriority priority;
  final String notes;
  final List<String> subtasks;
  final RecurrenceFrequency frequency;
  final int interval;
  final DateTime startDate;
  final DateTime? endDate;
  final int? durationDays;
  final int? durationMonths;
  final int? maxOccurrences;
  final List<int> weekdays; // ISO 1 (Mon) .. 7 (Sun)
  final int? dayOfMonth; // 1 .. 31
  final List<(int, int)> times; // 24-hour (hour, minute) slots per active date
}

/// Filter selecting a batch of existing tasks for bulk operations.
@immutable
class BulkTaskFilter {
  const BulkTaskFilter({
    this.seriesId,
    this.titleQuery,
    this.courseQuery,
    this.taskType,
    this.dateFrom,
    this.dateTo,
    this.matchTime,
    this.completedOnly = false,
    this.pendingOnly = false,
    this.confirmAll = false,
  });

  final String? seriesId;
  final String? titleQuery;
  final String? courseQuery;
  final TaskType? taskType;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final (int, int)? matchTime;
  final bool completedOnly;
  final bool pendingOnly;
  final bool confirmAll;

  bool get hasExplicitSelector =>
      (seriesId != null && seriesId!.trim().isNotEmpty) ||
      (titleQuery != null && titleQuery!.trim().isNotEmpty) ||
      (courseQuery != null && courseQuery!.trim().isNotEmpty) ||
      taskType != null ||
      dateFrom != null ||
      dateTo != null ||
      matchTime != null ||
      completedOnly ||
      pendingOnly ||
      confirmAll;
}

/// Pure, deterministic expander turning a [RecurringTaskSpec] into [TaskItem]s.
abstract final class RecurringTaskExpander {
  static const _uuid = Uuid();

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static DateTime _addMonthsClamped(DateTime date, int monthsToAdd) {
    final zeroMonth = (date.year * 12 + (date.month - 1)) + monthsToAdd;
    final targetYear = zeroMonth ~/ 12;
    final targetMonth = (zeroMonth % 12) + 1;
    final maxDay = _daysInMonth(targetYear, targetMonth);
    final targetDay = date.day.clamp(1, maxDay);
    return DateTime(targetYear, targetMonth, targetDay);
  }

  static ({List<TaskItem> tasks, bool wasCapped}) expand(
    RecurringTaskSpec spec, {
    required String seriesId,
    DateTime? createdAt,
  }) {
    final title = spec.title.trim();
    if (title.isEmpty) {
      return (tasks: const [], wasCapped: false);
    }

    final start = DateTime(
      spec.startDate.year,
      spec.startDate.month,
      spec.startDate.day,
    );
    final interval = spec.interval < 1 ? 1 : spec.interval;
    final hardEnd = DateTime(
      start.year,
      start.month,
      start.day + RecurringTaskSpec.maxHorizonDays - 1,
    );

    final DateTime requestedEnd;
    if (spec.endDate != null) {
      requestedEnd = DateTime(
        spec.endDate!.year,
        spec.endDate!.month,
        spec.endDate!.day,
      );
    } else if (spec.durationDays != null && spec.durationDays! > 0) {
      requestedEnd = DateTime(
        start.year,
        start.month,
        start.day + spec.durationDays! - 1,
      );
    } else if (spec.durationMonths != null && spec.durationMonths! > 0) {
      final exclusiveEnd = _addMonthsClamped(start, spec.durationMonths!);
      requestedEnd = DateTime(
        exclusiveEnd.year,
        exclusiveEnd.month,
        exclusiveEnd.day - 1,
      );
    } else if (spec.maxOccurrences != null && spec.maxOccurrences! > 0) {
      requestedEnd = hardEnd;
    } else {
      switch (spec.frequency) {
        case RecurrenceFrequency.daily:
        case RecurrenceFrequency.everyNDays:
          requestedEnd = DateTime(start.year, start.month, start.day + 29);
        case RecurrenceFrequency.weekly:
          requestedEnd = DateTime(start.year, start.month, start.day + 83);
        case RecurrenceFrequency.monthly:
          final exclusiveEnd = _addMonthsClamped(start, 6);
          requestedEnd = DateTime(
            exclusiveEnd.year,
            exclusiveEnd.month,
            exclusiveEnd.day - 1,
          );
      }
    }

    if (requestedEnd.isBefore(start)) {
      return (tasks: const [], wasCapped: false);
    }

    var wasCapped = false;
    final DateTime effectiveEnd;
    if (requestedEnd.isAfter(hardEnd)) {
      effectiveEnd = hardEnd;
      wasCapped = true;
    } else {
      effectiveEnd = requestedEnd;
    }

    final dates = <DateTime>[];
    switch (spec.frequency) {
      case RecurrenceFrequency.daily:
      case RecurrenceFrequency.everyNDays:
        for (var d = start;
            !d.isAfter(effectiveEnd);
            d = DateTime(d.year, d.month, d.day + interval)) {
          dates.add(d);
          if (dates.length >= RecurringTaskSpec.maxTasksPerCommand) break;
        }
      case RecurrenceFrequency.weekly:
        final validWeekdays =
            spec.weekdays.where((w) => w >= 1 && w <= 7).toSet();
        if (validWeekdays.isEmpty) {
          validWeekdays.add(start.weekday);
        }
        for (var offset = 0;; offset++) {
          final d = DateTime(start.year, start.month, start.day + offset);
          if (d.isAfter(effectiveEnd)) break;
          final weekIndex = offset ~/ 7;
          if (weekIndex % interval == 0 && validWeekdays.contains(d.weekday)) {
            dates.add(d);
            if (dates.length >= RecurringTaskSpec.maxTasksPerCommand) break;
          }
        }
      case RecurrenceFrequency.monthly:
        final anchorDay = (spec.dayOfMonth ?? start.day).clamp(1, 31);
        for (var step = 0;; step += interval) {
          final totalMonths = (start.year * 12 + (start.month - 1)) + step;
          final y = totalMonths ~/ 12;
          final m = (totalMonths % 12) + 1;
          final maxDay = _daysInMonth(y, m);
          final d = DateTime(y, m, anchorDay.clamp(1, maxDay));
          if (d.isBefore(start)) continue;
          if (d.isAfter(effectiveEnd)) break;
          dates.add(d);
          if (dates.length >= RecurringTaskSpec.maxTasksPerCommand) break;
        }
    }

    // Deduplicate and chronologically sort time-of-day slots.
    final seenSlots = <int>{};
    final uniqueTimes = <(int, int)>[];
    for (final slot in spec.times) {
      final h = slot.$1.clamp(0, 23);
      final m = slot.$2.clamp(0, 59);
      if (seenSlots.add(h * 60 + m)) {
        uniqueTimes.add((h, m));
      }
    }
    uniqueTimes.sort((a, b) => (a.$1 * 60 + a.$2).compareTo(b.$1 * 60 + b.$2));

    final stamp = createdAt ?? DateTime.now();
    final tasks = <TaskItem>[];
    final occCap =
        (spec.maxOccurrences != null && spec.maxOccurrences! > 0)
            ? spec.maxOccurrences!
            : null;

    outer:
    for (final d in dates) {
      final slots = uniqueTimes.isEmpty ? const <(int?, int?)>[(null, null)] : uniqueTimes;
      for (final slot in slots) {
        if (occCap != null && tasks.length >= occCap) {
          break outer;
        }
        if (tasks.length >= RecurringTaskSpec.maxTasksPerCommand) {
          wasCapped = true;
          break outer;
        }
        final id = _uuid.v4();
        tasks.add(
          TaskItem(
            id: id,
            notificationBaseId: TaskItem.stableBaseIdFromUuid(id),
            title: title,
            courseOrCategory: spec.courseOrCategory.trim(),
            type: spec.taskType,
            priority: spec.priority,
            dueDate: d,
            dueHour: slot.$1,
            dueMinute: slot.$2,
            notes: spec.notes.trim(),
            subtasks: spec.subtasks
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .map((s) => SubTaskItem(id: _uuid.v4(), title: s))
                .toList(),
            createdAt: stamp,
            seriesId: seriesId,
          ),
        );
      }
    }

    return (tasks: tasks, wasCapped: wasCapped);
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
    this.newDayBeforeTime,
    this.newEndOfDayTime,
    this.remindersEnabled,
    this.recurringSpec,
    this.bulkFilter,
    this.shiftDays,
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
  final (int, int)? newDayBeforeTime;
  final (int, int)? newEndOfDayTime;
  final bool? remindersEnabled;
  final RecurringTaskSpec? recurringSpec;
  final BulkTaskFilter? bulkFilter;
  final int? shiftDays;
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
