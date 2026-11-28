import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'ai_provider_config.dart';
import 'chat_message.dart';
import 'custom_task_type.dart';
import 'reminder_settings.dart';
import 'task_item.dart';

/// Complete, self-contained cloud snapshot synced to `users/{uid}/backup/state`
/// or private Google Drive `appDataFolder`.
@immutable
class CloudBackupPayload {
  static const String backupAppId = 'h_todo_ai';
  static const int maxDeletedTombstones = 1000;

  const CloudBackupPayload({
    this.schemaVersion = 1,
    required this.updatedAt,
    required this.activeProviderType,
    required this.providers,
    required this.reminderSettings,
    required this.tasks,
    required this.chatMessages,
    this.deletedTaskIds = const [],
    this.customTaskTypes = const [],
  });

  final int schemaVersion;
  final DateTime updatedAt;
  final AiProviderType activeProviderType;
  final Map<AiProviderType, AiProviderConfig> providers;
  final ReminderSettings reminderSettings;
  final List<TaskItem> tasks;
  final List<ChatMessage> chatMessages;
  final List<String> deletedTaskIds;
  final List<CustomTaskType> customTaskTypes;

  bool get isMeaningfullyEmpty =>
      tasks.isEmpty &&
      chatMessages.isEmpty &&
      deletedTaskIds.isEmpty &&
      customTaskTypes.isEmpty &&
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
        'deletedTaskIds': deletedTaskIds,
        'customTaskTypes': customTaskTypes.map((c) => c.toJson()).toList(),
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

    final rawDeleted = map['deletedTaskIds'] as List<dynamic>? ?? const [];
    final deletedIds = rawDeleted
        .map((e) => e.toString().trim())
        .where((id) => id.isNotEmpty)
        .toList();

    final rawCustomTypes = map['customTaskTypes'] as List<dynamic>? ?? const [];
    final customTypes = rawCustomTypes
        .whereType<Map>()
        .map((m) => CustomTaskType.fromJson(Map<String, dynamic>.from(m)))
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
      deletedTaskIds: deletedIds,
      customTaskTypes: customTypes,
    );
  }

  static List<SubTaskItem> _mergeMissingSubtasks(
    List<SubTaskItem> base,
    List<SubTaskItem> extra,
  ) {
    if (extra.isEmpty) return base;
    final seenIds = base.map((s) => s.id).where((id) => id.isNotEmpty).toSet();
    final seenTitles = base
        .map((s) => s.title.toLowerCase().trim())
        .where((t) => t.isNotEmpty)
        .toSet();
    final additions = <SubTaskItem>[];
    for (final s in extra) {
      final normTitle = s.title.toLowerCase().trim();
      final dupId = s.id.isNotEmpty && seenIds.contains(s.id);
      final dupTitle = normTitle.isNotEmpty && seenTitles.contains(normTitle);
      if (dupId || dupTitle) continue;
      if (s.id.isNotEmpty) seenIds.add(s.id);
      if (normTitle.isNotEmpty) seenTitles.add(normTitle);
      additions.add(s);
    }
    return additions.isEmpty ? base : [...base, ...additions];
  }

  static bool _isDefaultReminderSettings(ReminderSettings s) =>
      s.enabled == true &&
      s.dayBeforeHour == 16 &&
      s.dayBeforeMinute == 0 &&
      s.endOfDayHour == 22 &&
      s.endOfDayMinute == 0 &&
      s.themeMode == 'system';

  /// Merges this cloud snapshot with [local] on initial login so neither device loses data.
  CloudBackupPayload mergeWithLocal(CloudBackupPayload local) {
    final cloudIsNewer = updatedAt.isAfter(local.updatedAt);

    final localActiveIds = local.tasks.map((t) => t.id).toSet();
    final cloudActiveIds = tasks.map((t) => t.id).toSet();
    final localDeleted =
        local.deletedTaskIds.where((id) => !localActiveIds.contains(id)).toSet();
    final cloudDeleted = cloudIsNewer
        ? deletedTaskIds.where((id) => !cloudActiveIds.contains(id)).toSet()
        : <String>{};

    final taskById = <String, TaskItem>{
      for (final t in local.tasks) t.id: t,
    };
    for (final cloudTask in tasks) {
      if (localDeleted.contains(cloudTask.id) &&
          !(cloudIsNewer && cloudTask.createdAt.isAfter(local.updatedAt))) {
        continue;
      }

      final existing = taskById[cloudTask.id];
      if (existing == null) {
        taskById[cloudTask.id] = cloudTask;
      } else {
        final localComp = existing.completedAt;
        final cloudComp = cloudTask.completedAt;
        if (localComp != null && cloudComp != null) {
          taskById[cloudTask.id] =
              localComp.isAfter(cloudComp) ? existing : cloudTask;
        } else if (localComp != null) {
          taskById[cloudTask.id] = existing;
        } else if (cloudComp != null) {
          taskById[cloudTask.id] = cloudTask;
        } else if (!cloudIsNewer) {
          final mergedSubs = _mergeMissingSubtasks(
            existing.subtasks,
            cloudTask.subtasks,
          );
          taskById[cloudTask.id] = existing.copyWith(subtasks: mergedSubs);
        } else {
          final mergedSubs = _mergeMissingSubtasks(
            cloudTask.subtasks,
            existing.subtasks,
          );
          final preserveTime = !cloudTask.hasDueTime && existing.hasDueTime;
          taskById[cloudTask.id] = cloudTask.copyWith(
            dueHour: preserveTime ? existing.dueHour : cloudTask.dueHour,
            dueMinute: preserveTime ? existing.dueMinute : cloudTask.dueMinute,
            subtasks: mergedSubs,
          );
        }
      }
    }

    for (final deletedId in cloudDeleted) {
      taskById.remove(deletedId);
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

    final useCloudMeta =
        !isMeaningfullyEmpty && (local.isMeaningfullyEmpty || cloudIsNewer);

    var resolvedActiveProvider =
        useCloudMeta ? activeProviderType : local.activeProviderType;
    if (!(mergedProviders[resolvedActiveProvider]?.hasKey ?? false) &&
        (mergedProviders[activeProviderType]?.hasKey ?? false)) {
      resolvedActiveProvider = activeProviderType;
    }

    final localHasCustomReminder =
        !_isDefaultReminderSettings(local.reminderSettings);
    final cloudIsDefaultReminder =
        _isDefaultReminderSettings(reminderSettings);
    final resolvedReminderSettings =
        useCloudMeta && !(localHasCustomReminder && cloudIsDefaultReminder)
            ? reminderSettings
            : local.reminderSettings;

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

    final survivingTasks = dedupedBySignature.values.toList();
    final survivingIds = survivingTasks.map((t) => t.id).toSet();
    final candidateDeleted = <String>[
      ...local.deletedTaskIds,
      if (cloudIsNewer) ...deletedTaskIds,
    ];
    final seenDeleted = <String>{};
    final reversedKeptDeleted = <String>[];
    for (final id in candidateDeleted.reversed) {
      if (id.isEmpty || survivingIds.contains(id) || !seenDeleted.add(id)) {
        continue;
      }
      reversedKeptDeleted.add(id);
      if (reversedKeptDeleted.length >= maxDeletedTombstones) break;
    }

    final mergedCustomTypesById = <String, CustomTaskType>{};
    final nameToId = <String, String>{};
    void upsertCustom(CustomTaskType item, {required bool preferIncoming}) {
      final normName = item.name.trim().toLowerCase();
      if (normName.isEmpty) return;
      final existingById = mergedCustomTypesById[item.id];
      final existingIdByName = nameToId[normName];
      if (existingById != null) {
        if (preferIncoming) mergedCustomTypesById[item.id] = item;
        return;
      }
      if (existingIdByName != null) {
        if (preferIncoming) {
          mergedCustomTypesById[existingIdByName] = item;
          if (item.id != existingIdByName) {
            mergedCustomTypesById.remove(existingIdByName);
            mergedCustomTypesById[item.id] = item;
            nameToId[normName] = item.id;
          }
        }
        return;
      }
      mergedCustomTypesById[item.id] = item;
      nameToId[normName] = item.id;
    }

    for (final c in local.customTaskTypes) {
      upsertCustom(c, preferIncoming: false);
    }
    for (final c in customTaskTypes) {
      upsertCustom(c, preferIncoming: cloudIsNewer);
    }

    return CloudBackupPayload(
      schemaVersion: schemaVersion,
      updatedAt: DateTime.now(),
      activeProviderType: resolvedActiveProvider,
      providers: mergedProviders,
      reminderSettings: resolvedReminderSettings,
      tasks: survivingTasks,
      chatMessages: mergedMessages,
      deletedTaskIds: reversedKeptDeleted.reversed.toList(),
      customTaskTypes: mergedCustomTypesById.values.toList(),
    );
  }

  /// Serializes backup JSON for Google Drive `appDataFolder` or local `.json` export.
  Map<String, dynamic> toBackupJson({bool includeApiKeys = true}) {
    final serializedProviders = <String, dynamic>{};
    for (final entry in providers.entries) {
      final json = Map<String, dynamic>.from(entry.value.toJson());
      if (!includeApiKeys) {
        json['apiKey'] = '';
      }
      serializedProviders[entry.key.name] = json;
    }
    return {
      'app': backupAppId,
      'schemaVersion': schemaVersion,
      'includesApiKeys': includeApiKeys,
      'updatedAt': updatedAt.toIso8601String(),
      'activeProviderType': activeProviderType.name,
      'providers': serializedProviders,
      'reminderSettings': reminderSettings.toJson(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'chatMessages': chatMessages.map((m) => m.toJson()).toList(),
      'deletedTaskIds': deletedTaskIds,
      'customTaskTypes': customTaskTypes.map((c) => c.toJson()).toList(),
    };
  }

  /// Validates and parses an H-TODO AI backup map from Drive or imported `.json`.
  factory CloudBackupPayload.fromBackupJson(Map<String, dynamic> map) {
    final appTag = map['app']?.toString();
    if (appTag != null && appTag.isNotEmpty && appTag != backupAppId) {
      throw const FormatException('This file is not an H-TODO AI backup.');
    }
    final hasAnySection = map.containsKey('tasks') ||
        map.containsKey('providers') ||
        map.containsKey('chatMessages') ||
        map.containsKey('reminderSettings') ||
        map.containsKey('customTaskTypes');
    if (!hasAnySection) {
      throw const FormatException(
        'Backup file does not contain valid H-TODO AI data.',
      );
    }
    return CloudBackupPayload.fromFirestoreMap(map);
  }

  String toJsonString({bool includeApiKeys = true, bool pretty = false}) {
    final map = toBackupJson(includeApiKeys: includeApiKeys);
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(map);
    }
    return jsonEncode(map);
  }

  factory CloudBackupPayload.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Invalid H-TODO AI backup file.');
    }
    return CloudBackupPayload.fromBackupJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  static ({CloudBackupPayload payload, bool includesApiKeys})
      parseBackupEnvelope(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Invalid H-TODO AI backup file.');
    }
    final map = Map<String, dynamic>.from(decoded);
    final payload = CloudBackupPayload.fromBackupJson(map);
    final hasAnyImportedKey = payload.providers.values.any((p) => p.hasKey);
    final explicitFlag = map['includesApiKeys'];
    final includesKeys =
        explicitFlag is bool ? (explicitFlag || hasAnyImportedKey) : hasAnyImportedKey;
    return (payload: payload, includesApiKeys: includesKeys);
  }

  /// Deterministic content hash excluding [updatedAt] to skip identical auto-backups.
  String computeContentFingerprint() {
    final sortedProviders = {
      for (final type in AiProviderType.values)
        type.name: (providers[type] ?? AiProviderConfig.defaults()[type]!).toJson(),
    };
    final sortedTasks = tasks.map((t) => t.toJson()).toList()
      ..sort((a, b) => (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? ''));
    final sortedChats = chatMessages.map((m) => m.toJson()).toList()
      ..sort((a, b) => (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? ''));
    final sortedDeleted = List<String>.from(deletedTaskIds)..sort();
    final sortedCustomTypes = customTaskTypes.map((c) => c.toJson()).toList()
      ..sort((a, b) => (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? ''));

    final canonical = {
      'schemaVersion': schemaVersion,
      'activeProviderType': activeProviderType.name,
      'providers': sortedProviders,
      'reminderSettings': reminderSettings.toJson(),
      'tasks': sortedTasks,
      'chatMessages': sortedChats,
      'deletedTaskIds': sortedDeleted,
      'customTaskTypes': sortedCustomTypes,
    };
    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }
}
