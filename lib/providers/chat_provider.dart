import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_provider_config.dart';
import '../models/chat_message.dart';
import '../models/task_item.dart';
import '../services/ai_parser_service.dart';
import '../services/storage_service.dart';
import 'task_provider.dart';

/// Manages natural-language schedule chat messages and invokes AI extraction.
class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required StorageService storage,
    AiParserService? parser,
  })  : _storage = storage,
        _parser = parser ?? AiParserService();

  static const _uuid = Uuid();

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

  Future<void> load() async {
    _messages = await _storage.loadChatMessages();
    _loaded = true;
    notifyListeners();
  }

  Future<List<TaskItem>> sendScheduleMessage(
    String text, {
    required AiProviderConfig activeProvider,
    required TaskProvider taskProvider,
    Future<void> Function(String newModel)? onModelResolved,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return const [];

    final priorHistory = List<ChatMessage>.from(_messages);
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      text: trimmed,
      timestamp: DateTime.now(),
    );
    _messages = [..._messages, userMessage];
    await _storage.saveChatMessages(_messages);

    if (!activeProvider.hasKey) {
      final errMsg = ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        text:
            'No API key configured for ${activeProvider.displayName}. Open Profile -> AI API Keys and add your key.',
        timestamp: DateTime.now(),
        isError: true,
        providerName: activeProvider.displayName,
      );
      _messages = [..._messages, errMsg];
      await _storage.saveChatMessages(_messages);
      notifyListeners();
      return const [];
    }

    _isSending = true;
    notifyListeners();

    var deletedTasks = const <TaskItem>[];
    try {
      final result = await _parser.processChatCommand(
        trimmed,
        activeProvider,
        existingTasks: taskProvider.tasks,
        recentMessages: priorHistory,
      );
      if (result.resolvedModel != null &&
          result.resolvedModel != activeProvider.model.trim()) {
        await onModelResolved?.call(result.resolvedModel!);
      }

      final exec = await taskProvider.executeAiActions(result.actions);
      deletedTasks = exec.deletedTasks;

      final linkedIds = <String>[
        ...exec.affectedTaskIds,
        for (final id in result.referencedTaskIds)
          if (!exec.affectedTaskIds.contains(id) &&
              taskProvider.findById(id) != null)
            id,
      ];

      final replyText = exec.skipped > 0
          ? '${result.reply}\n(${exec.skipped} skipped as duplicate)'
          : result.reply;

      final assistantMessage = ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        text: replyText,
        timestamp: DateTime.now(),
        createdTaskIds: linkedIds,
        providerName: activeProvider.displayName,
      );
      _messages = [..._messages, assistantMessage];
    } on AiParserException catch (e) {
      final errMessage = ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        text: e.message,
        timestamp: DateTime.now(),
        isError: true,
        providerName: activeProvider.displayName,
      );
      _messages = [..._messages, errMessage];
    } catch (e) {
      final errMessage = ChatMessage(
        id: _uuid.v4(),
        role: ChatRole.assistant,
        text: 'Failed to process request: $e',
        timestamp: DateTime.now(),
        isError: true,
        providerName: activeProvider.displayName,
      );
      _messages = [..._messages, errMessage];
    } finally {
      _isSending = false;
      await _storage.saveChatMessages(_messages);
      notifyListeners();
      _onDataChanged?.call();
    }
    return deletedTasks;
  }

  Future<void> clearHistory() async {
    _messages = [];
    await _storage.saveChatMessages(_messages);
    notifyListeners();
    _onDataChanged?.call();
  }

  /// Replaces local chat messages from a cloud restore without triggering re-upload.
  Future<void> applyRestoredState(List<ChatMessage> restoredMessages) async {
    _messages = List<ChatMessage>.from(restoredMessages);
    _loaded = true;
    await _storage.saveChatMessages(_messages);
    notifyListeners();
  }
}
