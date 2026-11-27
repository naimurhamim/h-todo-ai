import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_chat_action.dart';
import '../models/ai_provider_config.dart';
import '../models/chat_message.dart';
import '../models/reminder_settings.dart';
import '../models/task_item.dart';
import '../services/ai_parser_service.dart';
import '../services/local_command_parser.dart';
import '../services/storage_service.dart';
import 'task_provider.dart';

/// Coordinates Hybrid Local-First zero-token command routing, Cloud AI failover,
/// and bounded chat history storage.
class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required StorageService storage,
    AiParserService? parser,
  })  : _storage = storage,
        _parser = parser ?? AiParserService();

  static const _uuid = Uuid();
  static const int maxStoredMessages = 200;

  final StorageService _storage;
  final AiParserService _parser;

  List<ChatMessage> _messages = [];
  bool _isSending = false;
  bool _loaded = false;
  VoidCallback? _onDataChanged;

  void setOnDataChanged(VoidCallback? callback) {
    _onDataChanged = callback;
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;
  bool get isLoaded => _loaded;

  static List<ChatMessage> _trimMessages(List<ChatMessage> source) {
    if (source.length <= maxStoredMessages) return source;
    return source.sublist(source.length - maxStoredMessages);
  }

  Future<void> load() async {
    _messages = _trimMessages(await _storage.loadChatMessages());
    _loaded = true;
    notifyListeners();
  }

  Future<List<TaskItem>> sendScheduleMessage(
    String text, {
    required AiProviderConfig activeProvider,
    required TaskProvider taskProvider,
    List<AiProviderConfig> allProviders = const [],
    Map<AiProviderType, List<String>> cachedModels = const {},
    ReminderSettings reminderSettings = const ReminderSettings(),
    bool allowLocalParser = true,
    Future<void> Function(String newModel)? onModelResolved,
    Future<void> Function(AiProviderType type, String newModel)?
        onProviderModelResolved,
    Future<void> Function(AiTaskAction action)? onReminderSettingsAction,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return const [];

    _isSending = true;
    final priorHistory = List<ChatMessage>.from(_messages);
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      text: trimmed,
      timestamp: DateTime.now(),
    );
    _messages = _trimMessages([..._messages, userMessage]);
    await _storage.saveChatMessages(_messages);
    notifyListeners();

    var deletedTasks = const <TaskItem>[];
    var changedData = false;
    try {
      // Gate 1 (Exclusive Local Router): runs with AI completely switched off (0 tokens).
      final localResult = allowLocalParser
          ? LocalCommandParser.tryParse(
              trimmed,
              existingTasks: taskProvider.tasks,
              reminderSettings: reminderSettings,
            )
          : null;

      if (localResult != null) {
        final applied = await _applyAssistantResponse(
          localResult,
          providerLabel: LocalCommandParser.localProviderLabel,
          taskProvider: taskProvider,
          onReminderSettingsAction: onReminderSettingsAction,
        );
        deletedTasks = applied.deletedTasks;
        changedData = applied.changedData;
        return deletedTasks;
      }

      // Gate 2: Complex notices / natural language migrate exclusively to Cloud AI failover.
      final hasAnyKey =
          activeProvider.hasKey || allProviders.any((p) => p.hasKey);
      if (!hasAnyKey) {
        final errMsg = ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          text:
              'Quick presets and simple commands work offline without an API key. To parse long notices or complex messages, add a free key in Profile -> AI API Keys.',
          timestamp: DateTime.now(),
          isError: true,
          providerName: activeProvider.displayName,
        );
        _messages = _trimMessages([..._messages, errMsg]);
        changedData = true;
        return const [];
      }

      final result = await _parser.processChatCommandWithFailover(
        trimmed,
        activeProvider: activeProvider,
        allProviders: allProviders,
        cachedModels: cachedModels,
        existingTasks: taskProvider.tasks,
        recentMessages: priorHistory,
      );

      final usedType = result.resolvedProviderType ?? activeProvider.id;
      final usedConfig = usedType == activeProvider.id
          ? activeProvider
          : allProviders.firstWhere(
              (p) => p.id == usedType,
              orElse: () => activeProvider,
            );

      if (result.resolvedModel != null &&
          result.resolvedModel != usedConfig.model.trim()) {
        if (onProviderModelResolved != null) {
          await onProviderModelResolved(usedType, result.resolvedModel!);
        } else if (usedType == activeProvider.id && onModelResolved != null) {
          await onModelResolved(result.resolvedModel!);
        }
      }

      final baseName = result.resolvedProviderName ?? activeProvider.displayName;
      final switchedAway = usedType != activeProvider.id ||
          (result.resolvedModel != null &&
              result.resolvedModel != activeProvider.model.trim());
      final badgeLabel = switchedAway && result.resolvedModel != null
          ? '$baseName • ${result.resolvedModel}'
          : baseName;

      final applied = await _applyAssistantResponse(
        result,
        providerLabel: badgeLabel,
        taskProvider: taskProvider,
        onReminderSettingsAction: onReminderSettingsAction,
      );
      deletedTasks = applied.deletedTasks;
      changedData = true;
    } on AiParserException catch (e) {
      final errMessage = ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        text: e.message,
        timestamp: DateTime.now(),
        isError: true,
        providerName: activeProvider.displayName,
      );
      _messages = _trimMessages([..._messages, errMessage]);
      changedData = true;
    } catch (e) {
      final errMessage = ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        text: 'Failed to process request: $e',
        timestamp: DateTime.now(),
        isError: true,
        providerName: activeProvider.displayName,
      );
      _messages = _trimMessages([..._messages, errMessage]);
      changedData = true;
    } finally {
      _isSending = false;
      await _storage.saveChatMessages(_messages);
      notifyListeners();
      if (changedData) {
        _onDataChanged?.call();
      }
    }
    return deletedTasks;
  }

  Future<({List<TaskItem> deletedTasks, bool changedData})>
      _applyAssistantResponse(
    AiAssistantResponse result, {
    required String providerLabel,
    required TaskProvider taskProvider,
    Future<void> Function(AiTaskAction action)? onReminderSettingsAction,
  }) async {
    final reminderActions = result.actions
        .where((a) => a.type == AiActionType.updateReminderSettings)
        .toList();
    final taskActions = result.actions
        .where((a) => a.type != AiActionType.updateReminderSettings)
        .toList();

    for (final remAction in reminderActions) {
      await onReminderSettingsAction?.call(remAction);
    }

    final exec = await taskProvider.executeAiActions(taskActions);

    final linkedIds = <String>[
      ...exec.affectedTaskIds,
      for (final id in result.referencedTaskIds)
        if (!exec.affectedTaskIds.contains(id) &&
            taskProvider.findById(id) != null)
          id,
    ].take(10).toList();

    final extraNotes = <String>[
      if (exec.skipped > 0) '${exec.skipped} skipped as duplicate',
      if (exec.wasCapped)
        'Capped at ${RecurringTaskSpec.maxTasksPerCommand} tasks / 366 days per command',
    ];
    final replyText = extraNotes.isEmpty
        ? result.reply
        : '${result.reply}\n(${extraNotes.join('; ')})';

    final assistantMessage = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.assistant,
      text: replyText,
      timestamp: DateTime.now(),
      createdTaskIds: linkedIds,
      providerName: providerLabel,
    );
    _messages = _trimMessages([..._messages, assistantMessage]);

    final changed = reminderActions.isNotEmpty || exec.hasChanges;
    return (deletedTasks: exec.deletedTasks, changedData: changed);
  }

  Future<void> clearHistory() async {
    _messages = [];
    await _storage.saveChatMessages(_messages);
    notifyListeners();
    _onDataChanged?.call();
  }

  /// Replaces local chat messages from a cloud restore without triggering re-upload.
  Future<void> applyRestoredState(List<ChatMessage> restoredMessages) async {
    _messages = _trimMessages(List<ChatMessage>.from(restoredMessages));
    _loaded = true;
    await _storage.saveChatMessages(_messages);
    notifyListeners();
  }
}
