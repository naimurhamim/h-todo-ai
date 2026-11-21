import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_chat_action.dart';
import '../models/reminder_settings.dart';
import '../models/task_item.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

/// Filter options displayed on the Tasks screen.
enum TaskFilter {
  all,
  today,
  upcoming,
  completed;

  String get label {
    switch (this) {
      case TaskFilter.all:
        return 'All';
      case TaskFilter.today:
        return 'Today';
      case TaskFilter.upcoming:
        return 'Upcoming';
      case TaskFilter.completed:
        return 'Completed';
    }
  }
}

/// Result of reconciling newly parsed tasks against already saved tasks.
class TaskUpsertResult {
  const TaskUpsertResult({
    required this.added,
    required this.updated,
    required this.skipped,
    required this.affectedTaskIds,
  });

  final int added;
  final int updated;
  final int skipped;
  final List<String> affectedTaskIds;
}

/// Summary of executing batch To-Do actions parsed from AI chat.
class TaskActionExecutionResult {
  const TaskActionExecutionResult({
    this.added = 0,
    this.updated = 0,
    this.skipped = 0,
    this.completed = 0,
    this.uncompleted = 0,
    this.rescheduled = 0,
    this.deleted = 0,
    this.subtasksUpdated = 0,
    this.affectedTaskIds = const [],
    this.deletedTasks = const [],
  });

  final int added;
  final int updated;
  final int skipped;
  final int completed;
  final int uncompleted;
  final int rescheduled;
  final int deleted;
  final int subtasksUpdated;
  final List<String> affectedTaskIds;
  final List<TaskItem> deletedTasks;

  bool get hasChanges =>
      added > 0 ||
      updated > 0 ||
      completed > 0 ||
      uncompleted > 0 ||
      rescheduled > 0 ||
      deleted > 0 ||
      subtasksUpdated > 0;
}

/// Manages tasks, filters, completion cross-off state, and reminder syncing.
class TaskProvider extends ChangeNotifier {
  TaskProvider({
    required StorageService storage,
    required NotificationService notifications,
    ReminderSettings Function()? readReminderSettings,
  })  : _storage = storage,
        _notifications = notifications,
        _readReminderSettings =
            readReminderSettings ?? (() => const ReminderSettings());

  final StorageService _storage;
  final NotificationService _notifications;
  final ReminderSettings Function() _readReminderSettings;

  List<TaskItem> _tasks = [];
  TaskFilter _filter = TaskFilter.all;
  String _searchQuery = '';
  bool _loaded = false;
  VoidCallback? _onDataChanged;

  void setOnDataChanged(VoidCallback? callback) {
    _onDataChanged = callback;
  }

  List<TaskItem> get tasks => List.unmodifiable(_tasks);
  TaskFilter get filter => _filter;
  String get searchQuery => _searchQuery;
  bool get isLoaded => _loaded;

  int get pendingCount => _tasks.where((t) => !t.isCompleted).length;
  int get completedCount => _tasks.where((t) => t.isCompleted).length;

  int get dueTodayCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _tasks
        .where(
          (t) =>
              !t.isCompleted &&
              DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day) == today,
        )
        .length;
  }

  TaskItem? findById(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> load() async {
    _tasks = await _storage.loadTasks();
    _loaded = true;
    final settings = await _storage.loadReminderSettings();
    await _notifications.rescheduleAll(_tasks, settings);
    notifyListeners();
  }

  void setFilter(TaskFilter next) {
    if (_filter == next) return;
    _filter = next;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> addTask(TaskItem task) async {
    await addTasks([task]);
  }

  Future<void> addTasks(List<TaskItem> newTasks) async {
    if (newTasks.isEmpty) return;
    _tasks = [..._tasks, ...newTasks];
    await _storage.saveTasks(_tasks);
    final settings = _readReminderSettings();
    for (final task in newTasks) {
      await _notifications.scheduleForTask(task, settings);
    }
    notifyListeners();
    _onDataChanged?.call();
  }

  /// Inserts new AI-parsed tasks while skipping exact duplicates and merging
  /// newly discovered syllabus items, notes, or due times into matching tasks.
  Future<TaskUpsertResult> upsertParsedTasks(List<TaskItem> incoming) async {
    if (incoming.isEmpty) {
      return const TaskUpsertResult(
        added: 0,
        updated: 0,
        skipped: 0,
        affectedTaskIds: [],
      );
    }

    final working = List<TaskItem>.from(_tasks);
    final toSchedule = <TaskItem>[];
    final affectedIds = <String>[];
    var added = 0;
    var updated = 0;
    var skipped = 0;

    for (final candidate in incoming) {
      final matchIndex =
          working.indexWhere((existing) => _isSameScheduledTask(existing, candidate));

      if (matchIndex == -1) {
        working.add(candidate);
        toSchedule.add(candidate);
        affectedIds.add(candidate.id);
        added++;
        continue;
      }

      final existing = working[matchIndex];
      final merged = _mergeTaskDetails(existing, candidate);
      if (merged != null) {
        working[matchIndex] = merged;
        if (!merged.isCompleted) {
          toSchedule.add(merged);
        }
        if (!affectedIds.contains(merged.id)) {
          affectedIds.add(merged.id);
        }
        updated++;
      } else {
        if (!affectedIds.contains(existing.id)) {
          affectedIds.add(existing.id);
        }
        skipped++;
      }
    }

    if (added > 0 || updated > 0) {
      _tasks = working;
      await _storage.saveTasks(_tasks);
      final settings = _readReminderSettings();
      for (final task in toSchedule) {
        await _notifications.scheduleForTask(task, settings);
      }
      notifyListeners();
      _onDataChanged?.call();
    }

    return TaskUpsertResult(
      added: added,
      updated: updated,
      skipped: skipped,
      affectedTaskIds: affectedIds,
    );
  }

  /// Executes a batch of conversational To-Do actions (add, complete, uncomplete,
  /// delete, reschedule, update, subtask toggle) atomically with one save & sync.
  Future<TaskActionExecutionResult> executeAiActions(
    List<AiTaskAction> actions,
  ) async {
    if (actions.isEmpty) {
      return const TaskActionExecutionResult();
    }

    const uuid = Uuid();
    final working = List<TaskItem>.from(_tasks);
    final toSchedule = <TaskItem>[];
    final toCancel = <TaskItem>[];
    final affectedIds = <String>[];
    final deletedSnapshots = <TaskItem>[];

    var added = 0;
    var updated = 0;
    var skipped = 0;
    var completed = 0;
    var uncompleted = 0;
    var rescheduled = 0;
    var deleted = 0;
    var subtasksUpdated = 0;

    void markAffected(String id) {
      if (!affectedIds.contains(id)) {
        affectedIds.add(id);
      }
    }

    for (final action in actions) {
      if (action.type == AiActionType.add) {
        final candidate = action.newTask;
        if (candidate == null) continue;
        final dupIndex = working.indexWhere(
          (existing) => _isSameScheduledTask(existing, candidate),
        );
        if (dupIndex == -1) {
          working.add(candidate);
          toSchedule.add(candidate);
          markAffected(candidate.id);
          added++;
        } else {
          final existing = working[dupIndex];
          final merged = _mergeTaskDetails(existing, candidate);
          if (merged != null) {
            working[dupIndex] = merged;
            if (!merged.isCompleted) {
              toSchedule.add(merged);
            }
            markAffected(merged.id);
            updated++;
          } else {
            markAffected(existing.id);
            skipped++;
          }
        }
        continue;
      }

      final idx = _resolveTargetIndex(working, action.taskId, action.taskQuery);
      if (idx == -1) continue;
      final current = working[idx];

      switch (action.type) {
        case AiActionType.add:
        case AiActionType.updateReminderSettings:
          break;
        case AiActionType.complete:
          if (!current.isCompleted) {
            final next = current.copyWith(
              isCompleted: true,
              completedAt: DateTime.now(),
            );
            working[idx] = next;
            toCancel.add(next);
            completed++;
          }
          markAffected(current.id);
        case AiActionType.uncomplete:
          if (current.isCompleted) {
            final next = current.copyWith(
              isCompleted: false,
              clearCompletedAt: true,
            );
            working[idx] = next;
            toSchedule.add(next);
            uncompleted++;
          }
          markAffected(current.id);
        case AiActionType.delete:
          deletedSnapshots.add(current);
          toCancel.add(current);
          working.removeAt(idx);
          affectedIds.remove(current.id);
          deleted++;
        case AiActionType.reschedule:
        case AiActionType.update:
          final nextDate = action.newDueDate ?? current.dueDate;
          final hasNewTime =
              action.newDueHour != null && action.newDueMinute != null;
          final mergedSubs = _mergeNewSubtaskTitles(
            current.subtasks,
            action.addSubtasks,
            uuid,
          );
          final nextNotes = _mergeActionNotes(current.notes, action.newNotes);
          final next = current.copyWith(
            title: action.newTitle ?? current.title,
            courseOrCategory:
                action.newCourseOrCategory ?? current.courseOrCategory,
            type: action.newTaskType ?? current.type,
            priority: action.newPriority ?? current.priority,
            dueDate: nextDate,
            dueHour: hasNewTime ? action.newDueHour : current.dueHour,
            dueMinute: hasNewTime ? action.newDueMinute : current.dueMinute,
            clearDueTime: action.clearDueTime && !hasNewTime,
            notes: nextNotes,
            subtasks: mergedSubs,
          );
          final dateOrTimeChanged = next.dateKey != current.dateKey ||
              next.dueHour != current.dueHour ||
              next.dueMinute != current.dueMinute;
          working[idx] = next;
          if (!next.isCompleted &&
              (dateOrTimeChanged || next.title != current.title)) {
            toSchedule.add(next);
          }
          if (action.type == AiActionType.reschedule || dateOrTimeChanged) {
            rescheduled++;
          } else {
            updated++;
          }
          markAffected(next.id);
        case AiActionType.completeSubtask:
        case AiActionType.uncompleteSubtask:
          final targetDone = action.type == AiActionType.completeSubtask;
          final queryNorm = _normalizeKey(action.subtaskTitle ?? '');
          if (queryNorm.isEmpty) break;
          var changedSub = false;
          final updatedSubs = current.subtasks.map((s) {
            final subNorm = _normalizeKey(s.title);
            final matches = subNorm == queryNorm ||
                subNorm.contains(queryNorm) ||
                queryNorm.contains(subNorm);
            if (matches && s.isCompleted != targetDone) {
              changedSub = true;
              return s.copyWith(isCompleted: targetDone);
            }
            return s;
          }).toList();
          if (changedSub) {
            working[idx] = current.copyWith(subtasks: updatedSubs);
            subtasksUpdated++;
          }
          markAffected(current.id);
      }
    }

    final result = TaskActionExecutionResult(
      added: added,
      updated: updated,
      skipped: skipped,
      completed: completed,
      uncompleted: uncompleted,
      rescheduled: rescheduled,
      deleted: deleted,
      subtasksUpdated: subtasksUpdated,
      affectedTaskIds: affectedIds,
      deletedTasks: deletedSnapshots,
    );

    if (result.hasChanges) {
      _tasks = working;
      await _storage.saveTasks(_tasks);
      final settings = _readReminderSettings();
      for (final task in toCancel) {
        await _notifications.cancelForTask(task);
      }
      for (final task in toSchedule) {
        await _notifications.scheduleForTask(task, settings);
      }
      notifyListeners();
      _onDataChanged?.call();
    }

    return result;
  }

  /// Restores tasks deleted via AI chat when the user taps Undo.
  Future<void> restoreDeletedTasks(List<TaskItem> restored) async {
    if (restored.isEmpty) return;
    final existingIds = _tasks.map((t) => t.id).toSet();
    final toAdd = restored.where((t) => !existingIds.contains(t.id)).toList();
    if (toAdd.isEmpty) return;

    _tasks = [..._tasks, ...toAdd];
    await _storage.saveTasks(_tasks);
    final settings = _readReminderSettings();
    for (final task in toAdd) {
      if (!task.isCompleted) {
        await _notifications.scheduleForTask(task, settings);
      }
    }
    notifyListeners();
    _onDataChanged?.call();
  }

  static int _resolveTargetIndex(
    List<TaskItem> working,
    String? taskId,
    String? taskQuery,
  ) {
    final cleanedId = taskId?.trim() ?? '';
    if (cleanedId.isNotEmpty) {
      final exact = working.indexWhere((t) => t.id == cleanedId);
      if (exact != -1) return exact;
    }

    final queryNorm = _normalizeKey(taskQuery ?? '');
    if (queryNorm.isEmpty) return -1;

    final exactIndices = <int>[];
    final fuzzyIndices = <int>[];
    for (var i = 0; i < working.length; i++) {
      final t = working[i];
      final titleNorm = _normalizeKey(t.title);
      final combinedNorm = _normalizeKey('${t.courseOrCategory} ${t.title}');
      if (titleNorm == queryNorm || combinedNorm == queryNorm) {
        exactIndices.add(i);
      } else if (titleNorm.contains(queryNorm) ||
          combinedNorm.contains(queryNorm) ||
          (titleNorm.length >= 3 && queryNorm.contains(titleNorm))) {
        fuzzyIndices.add(i);
      }
    }

    if (exactIndices.length == 1) return exactIndices.first;
    if (exactIndices.isEmpty && fuzzyIndices.length == 1) {
      return fuzzyIndices.first;
    }
    return -1;
  }

  static List<SubTaskItem> _mergeNewSubtaskTitles(
    List<SubTaskItem> existing,
    List<String> incomingTitles,
    Uuid uuid,
  ) {
    if (incomingTitles.isEmpty) return existing;
    final seen = existing
        .map((s) => _normalizeKey(s.title))
        .where((k) => k.isNotEmpty)
        .toSet();
    final added = <SubTaskItem>[];
    for (final raw in incomingTitles) {
      final trimmed = raw.trim();
      final key = _normalizeKey(trimmed);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      added.add(SubTaskItem(id: uuid.v4(), title: trimmed));
    }
    return added.isEmpty ? existing : [...existing, ...added];
  }

  static String _mergeActionNotes(String existingNotes, String? incomingNotes) {
    final incoming = incomingNotes?.trim() ?? '';
    if (incoming.isEmpty) return existingNotes;
    if (_normalizeKey(existingNotes).contains(_normalizeKey(incoming))) {
      return existingNotes;
    }
    return existingNotes.trim().isEmpty
        ? incoming
        : '${existingNotes.trim()}\n\n$incoming';
  }

  static String _normalizeKey(String raw) => raw
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-–—_:,./\\()\[\]]+'), ' ')
      .trim();

  static bool _isSameScheduledTask(TaskItem existing, TaskItem incoming) {
    if (existing.dateKey != incoming.dateKey) return false;

    if (existing.hasDueTime &&
        incoming.hasDueTime &&
        (existing.dueHour != incoming.dueHour ||
            existing.dueMinute != incoming.dueMinute)) {
      return false;
    }

    final existingCourse = _normalizeKey(existing.courseOrCategory);
    final incomingCourse = _normalizeKey(incoming.courseOrCategory);
    final courseCompatible = existingCourse.isEmpty ||
        incomingCourse.isEmpty ||
        existingCourse == incomingCourse ||
        existingCourse.contains(incomingCourse) ||
        incomingCourse.contains(existingCourse);
    if (!courseCompatible) return false;

    final existingTitle = _normalizeKey(existing.title);
    final incomingTitle = _normalizeKey(incoming.title);
    if (existingTitle == incomingTitle) return true;

    return existing.type == incoming.type &&
        existingCourse.isNotEmpty &&
        incomingCourse.isNotEmpty &&
        (existingTitle.contains(incomingTitle) ||
            incomingTitle.contains(existingTitle));
  }

  static TaskItem? _mergeTaskDetails(TaskItem existing, TaskItem incoming) {
    final existingSubKeys = existing.subtasks
        .map((s) => _normalizeKey(s.title))
        .where((k) => k.isNotEmpty)
        .toSet();
    final extraSubtasks = <SubTaskItem>[];
    for (final sub in incoming.subtasks) {
      final key = _normalizeKey(sub.title);
      if (key.isEmpty || existingSubKeys.contains(key)) continue;
      existingSubKeys.add(key);
      extraSubtasks.add(sub);
    }

    final existingNotesNorm = _normalizeKey(existing.notes);
    final incomingNotesTrimmed = incoming.notes.trim();
    final incomingNotesNorm = _normalizeKey(incomingNotesTrimmed);
    final hasNewNotes = incomingNotesNorm.isNotEmpty &&
        !existingNotesNorm.contains(incomingNotesNorm);

    final addsDueTime = !existing.hasDueTime && incoming.hasDueTime;
    final addsCourse = existing.courseOrCategory.trim().isEmpty &&
        incoming.courseOrCategory.trim().isNotEmpty;

    if (extraSubtasks.isEmpty && !hasNewNotes && !addsDueTime && !addsCourse) {
      return null;
    }

    final combinedNotes = hasNewNotes
        ? (existing.notes.trim().isEmpty
            ? incomingNotesTrimmed
            : '${existing.notes.trim()}\n\n$incomingNotesTrimmed')
        : existing.notes;

    return existing.copyWith(
      courseOrCategory:
          addsCourse ? incoming.courseOrCategory : existing.courseOrCategory,
      dueHour: addsDueTime ? incoming.dueHour : existing.dueHour,
      dueMinute: addsDueTime ? incoming.dueMinute : existing.dueMinute,
      notes: combinedNotes,
      subtasks: extraSubtasks.isEmpty
          ? existing.subtasks
          : [...existing.subtasks, ...extraSubtasks],
    );
  }

  Future<void> updateTask(TaskItem updated) async {
    final index = _tasks.indexWhere((t) => t.id == updated.id);
    if (index == -1) return;
    _tasks[index] = updated;
    await _storage.saveTasks(_tasks);
    final settings = _readReminderSettings();
    if (updated.isCompleted) {
      await _notifications.cancelForTask(updated);
    } else {
      await _notifications.scheduleForTask(updated, settings);
    }
    notifyListeners();
    _onDataChanged?.call();
  }

  Future<void> deleteTask(String id) async {
    final target = findById(id);
    if (target == null) return;
    _tasks.removeWhere((t) => t.id == id);
    await _storage.saveTasks(_tasks);
    await _notifications.cancelForTask(target);
    notifyListeners();
    _onDataChanged?.call();
  }

  Future<void> toggleTaskComplete(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final current = _tasks[index];
    final nextDone = !current.isCompleted;
    final updated = current.copyWith(
      isCompleted: nextDone,
      completedAt: nextDone ? DateTime.now() : null,
      clearCompletedAt: !nextDone,
    );
    _tasks[index] = updated;
    await _storage.saveTasks(_tasks);
    if (nextDone) {
      await _notifications.cancelForTask(updated);
    } else {
      await _notifications.scheduleForTask(updated, _readReminderSettings());
    }
    notifyListeners();
    _onDataChanged?.call();
  }

  Future<void> toggleSubtaskComplete(String taskId, String subtaskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final current = _tasks[index];
    final updatedSubs = current.subtasks
        .map(
          (s) => s.id == subtaskId
              ? s.copyWith(isCompleted: !s.isCompleted)
              : s,
        )
        .toList();
    _tasks[index] = current.copyWith(subtasks: updatedSubs);
    await _storage.saveTasks(_tasks);
    notifyListeners();
    _onDataChanged?.call();
  }

  /// Replaces local tasks from a cloud restore without triggering re-upload.
  Future<void> applyRestoredState(
    List<TaskItem> restoredTasks,
    ReminderSettings settings,
  ) async {
    _tasks = List<TaskItem>.from(restoredTasks);
    _loaded = true;
    await _storage.saveTasks(_tasks);
    await _notifications.rescheduleAll(_tasks, settings);
    notifyListeners();
  }

  Future<void> rescheduleAllNotifications(ReminderSettings settings) async {
    await _notifications.rescheduleAll(_tasks, settings);
  }

  /// Returns filtered tasks sorted by due date, then completion state, then priority.
  List<TaskItem> filteredTasks({DateTime? now}) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final query = _searchQuery.trim().toLowerCase();

    final list = _tasks.where((t) {
      final dueDay = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      final matchesFilter = switch (_filter) {
        TaskFilter.all => true,
        TaskFilter.today => !t.isCompleted && !dueDay.isAfter(today),
        TaskFilter.upcoming => !t.isCompleted && dueDay.isAfter(today),
        TaskFilter.completed => t.isCompleted,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return t.title.toLowerCase().contains(query) ||
          t.courseOrCategory.toLowerCase().contains(query) ||
          t.notes.toLowerCase().contains(query);
    }).toList();

    list.sort((a, b) {
      final dateCmp = a.dueDate.compareTo(b.dueDate);
      if (dateCmp != 0) return dateCmp;
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      return a.priority.index.compareTo(b.priority.index);
    });

    return list;
  }

  /// Groups filtered tasks cleanly by normalized due DateTime (year/month/day).
  List<MapEntry<DateTime, List<TaskItem>>> groupedTasksByDate({DateTime? now}) {
    final grouped = <DateTime, List<TaskItem>>{};
    for (final task in filteredTasks(now: now)) {
      final day = DateTime(
        task.dueDate.year,
        task.dueDate.month,
        task.dueDate.day,
      );
      grouped.putIfAbsent(day, () => []).add(task);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }
}
