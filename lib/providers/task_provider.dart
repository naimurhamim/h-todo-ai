import 'package:flutter/foundation.dart';

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
