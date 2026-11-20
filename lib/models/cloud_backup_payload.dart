import 'package:flutter/foundation.dart';

import 'ai_provider_config.dart';
import 'chat_message.dart';
import 'reminder_settings.dart';
import 'task_item.dart';

/// Complete, self-contained cloud snapshot synced to `users/{uid}/backup/state`.
@immutable
class CloudBackupPayload {
  const CloudBackupPayload({
    this.schemaVersion = 1,
    required this.updatedAt,
    required this.activeProviderType,
    required this.providers,
    required this.reminderSettings,
    required this.tasks,
    required this.chatMessages,
  });

  final int schemaVersion;
  final DateTime updatedAt;
  final AiProviderType activeProviderType;
  final Map<AiProviderType, AiProviderConfig> providers;
  final ReminderSettings reminderSettings;
  final List<TaskItem> tasks;
  final List<ChatMessage> chatMessages;

  bool get isMeaningfullyEmpty =>
      tasks.isEmpty &&
      chatMessages.isEmpty &&
      providers.values.every((p) => !p.hasKey);

  Map<String, dynamic> toFirestoreMap() => {
        'schemaVersion': schemaVersion,
        'updatedAt': updatedAt.toIso8601String(),
        'activeProviderType': activeProviderType.name,
        'providers': {
          for (final entry in providers.entries)
            entry.key.name: entry.value.toJson(),
        },
        'reminderSettings': reminderSettings.toJson(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'chatMessages': chatMessages.map((m) => m.toJson()).toList(),
      };

  factory CloudBackupPayload.fromFirestoreMap(Map<String, dynamic> map) {
    final defaults = Map<AiProviderType, AiProviderConfig>.from(
      AiProviderConfig.defaults(),
    );
    final rawProviders = map['providers'];
    if (rawProviders is Map) {
      for (final entry in rawProviders.entries) {
        final type = AiProviderType.fromString(entry.key.toString());
        final base = defaults[type];
        final value = entry.value;
        if (base != null && value is Map) {
          defaults[type] = base.mergePersisted(
            Map<String, dynamic>.from(value),
          );
        }
      }
    }

    final rawReminder = map['reminderSettings'];
    final reminder = rawReminder is Map
        ? ReminderSettings.fromJson(Map<String, dynamic>.from(rawReminder))
        : const ReminderSettings();

    final rawTasks = map['tasks'] as List<dynamic>? ?? const [];
    final tasks = rawTasks
        .whereType<Map>()
        .map((m) => TaskItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    final rawMessages = map['chatMessages'] as List<dynamic>? ?? const [];
    final messages = rawMessages
        .whereType<Map>()
        .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    return CloudBackupPayload(
      schemaVersion: (map['schemaVersion'] as int?) ?? 1,
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      activeProviderType: AiProviderType.fromString(
        map['activeProviderType']?.toString(),
      ),
      providers: defaults,
      reminderSettings: reminder,
      tasks: tasks,
      chatMessages: messages,
    );
  }

  /// Merges this cloud snapshot with [local] on initial login so neither device loses data.
  CloudBackupPayload mergeWithLocal(CloudBackupPayload local) {
    final taskById = <String, TaskItem>{
      for (final t in local.tasks) t.id: t,
    };
    for (final cloudTask in tasks) {
      final existing = taskById[cloudTask.id];
      if (existing == null) {
        taskById[cloudTask.id] = cloudTask;
      } else {
        final localComp = existing.completedAt;
        final cloudComp = cloudTask.completedAt;
        if (localComp != null &&
            (cloudComp == null || localComp.isAfter(cloudComp))) {
          taskById[cloudTask.id] = existing;
        } else {
          taskById[cloudTask.id] = cloudTask;
        }
      }
    }

    final msgById = <String, ChatMessage>{
      for (final m in local.chatMessages) m.id: m,
    };
    for (final m in chatMessages) {
      msgById[m.id] = m;
    }
    final mergedMessages = msgById.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final mergedProviders = Map<AiProviderType, AiProviderConfig>.from(
      AiProviderConfig.defaults(),
    );
    final cloudIsNewer = updatedAt.isAfter(local.updatedAt);

    for (final type in AiProviderType.values) {
      final cloudCfg = providers[type] ?? mergedProviders[type]!;
      final localCfg = local.providers[type] ?? mergedProviders[type]!;
      if (cloudCfg.hasKey && localCfg.hasKey) {
        mergedProviders[type] = cloudIsNewer ? cloudCfg : localCfg;
      } else if (cloudCfg.hasKey) {
        mergedProviders[type] = cloudCfg;
      } else if (localCfg.hasKey) {
        mergedProviders[type] = localCfg;
      } else {
        mergedProviders[type] = cloudIsNewer ? cloudCfg : localCfg;
      }
    }

    final hasCloudKeys = providers.values.any((p) => p.hasKey);
    final useCloudMeta =
        !isMeaningfullyEmpty && (cloudIsNewer || hasCloudKeys);

    final dedupedBySignature = <String, TaskItem>{};
    for (final task in taskById.values) {
      final normTitle = task.title
          .toLowerCase()
          .replaceAll(RegExp(r'[\s\-–—_:,./\\()\[\]]+'), ' ')
          .trim();
      final normCourse = task.courseOrCategory
          .toLowerCase()
          .replaceAll(RegExp(r'[\s\-–—_:,./\\()\[\]]+'), ' ')
          .trim();
      final signature =
          '$normTitle|${task.dateKey}|${task.dueHour ?? -1}:${task.dueMinute ?? -1}|$normCourse';
      final prior = dedupedBySignature[signature];
      if (prior == null) {
        dedupedBySignature[signature] = task;
      } else {
        final keepCurrent = task.subtasks.length > prior.subtasks.length ||
            (task.isCompleted && !prior.isCompleted);
        if (keepCurrent) {
          dedupedBySignature[signature] = task;
        }
      }
    }

    return CloudBackupPayload(
      schemaVersion: schemaVersion,
      updatedAt: DateTime.now(),
      activeProviderType: useCloudMeta
          ? activeProviderType
          : local.activeProviderType,
      providers: mergedProviders,
      reminderSettings:
          useCloudMeta ? reminderSettings : local.reminderSettings,
      tasks: dedupedBySignature.values.toList(),
      chatMessages: mergedMessages,
    );
  }
}
