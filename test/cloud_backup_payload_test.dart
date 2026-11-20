import 'package:flutter_test/flutter_test.dart';

import 'package:h_todo_ai/models/ai_provider_config.dart';
import 'package:h_todo_ai/models/chat_message.dart';
import 'package:h_todo_ai/models/cloud_backup_payload.dart';
import 'package:h_todo_ai/models/reminder_settings.dart';
import 'package:h_todo_ai/models/task_item.dart';

void main() {
  group('CloudBackupPayload', () {
    test('round-trips tasks, subtasks, API keys, active provider, and settings', () {
      final providers = Map<AiProviderType, AiProviderConfig>.from(
        AiProviderConfig.defaults(),
      );
      providers[AiProviderType.gemini] = providers[AiProviderType.gemini]!
          .copyWith(apiKey: 'AIza-test-gemini-key');
      providers[AiProviderType.groq] = providers[AiProviderType.groq]!
          .copyWith(apiKey: 'gsk_test_groq_key');

      final task = TaskItem(
        id: 'task-1',
        notificationBaseId: 42,
        title: 'Class Test',
        courseOrCategory: 'IRE 415 – Computer Vision',
        type: TaskType.classTest,
        priority: TaskPriority.high,
        dueDate: DateTime(2026, 11, 22),
        notes: 'Filtering & Morphology',
        subtasks: const [
          SubTaskItem(id: 'sub-1', title: 'Image Enhancement', isCompleted: true),
        ],
        createdAt: DateTime(2026, 11, 20, 18, 0),
      );

      final chat = ChatMessage(
        id: 'msg-1',
        role: ChatRole.user,
        text: '২২ নভেম্বর ক্লাস টেস্ট',
        timestamp: DateTime(2026, 11, 20, 18, 1),
      );

      final payload = CloudBackupPayload(
        updatedAt: DateTime(2026, 11, 20, 19, 0),
        activeProviderType: AiProviderType.groq,
        providers: providers,
        reminderSettings: const ReminderSettings(),
        tasks: [task],
        chatMessages: [chat],
      );

      final map = payload.toFirestoreMap();
      final decoded = CloudBackupPayload.fromFirestoreMap(map);

      expect(decoded.activeProviderType, AiProviderType.groq);
      expect(decoded.providers[AiProviderType.gemini]?.apiKey, 'AIza-test-gemini-key');
      expect(decoded.providers[AiProviderType.groq]?.apiKey, 'gsk_test_groq_key');
      expect(decoded.reminderSettings.dayBeforeHour, 16);
      expect(decoded.reminderSettings.endOfDayHour, 22);
      expect(decoded.tasks.length, 1);
      expect(decoded.tasks.single.subtasks.single.isCompleted, isTrue);
      expect(decoded.chatMessages.single.text, '২২ নভেম্বর ক্লাস টেস্ট');
    });

    test('mergeWithLocal keeps non-empty keys from both sides and unions tasks', () {
      final cloudProviders = Map<AiProviderType, AiProviderConfig>.from(
        AiProviderConfig.defaults(),
      );
      cloudProviders[AiProviderType.gemini] =
          cloudProviders[AiProviderType.gemini]!.copyWith(apiKey: 'cloud-gemini');

      final localProviders = Map<AiProviderType, AiProviderConfig>.from(
        AiProviderConfig.defaults(),
      );
      localProviders[AiProviderType.gemini] =
          localProviders[AiProviderType.gemini]!.copyWith(apiKey: 'local-gemini-old');
      localProviders[AiProviderType.grok] =
          localProviders[AiProviderType.grok]!.copyWith(apiKey: 'local-grok-key');

      final cloudTask = TaskItem(
        id: 'cloud-task',
        notificationBaseId: 10,
        title: 'Assignment 03',
        dueDate: DateTime(2026, 11, 21),
        createdAt: DateTime(2026, 11, 20),
      );
      final localTask = TaskItem(
        id: 'local-task',
        notificationBaseId: 20,
        title: 'Class Test',
        dueDate: DateTime(2026, 11, 22),
        createdAt: DateTime(2026, 11, 20),
      );

      final cloud = CloudBackupPayload(
        updatedAt: DateTime(2026, 11, 20, 20, 0),
        activeProviderType: AiProviderType.gemini,
        providers: cloudProviders,
        reminderSettings: const ReminderSettings(),
        tasks: [cloudTask],
        chatMessages: const [],
      );

      final local = CloudBackupPayload(
        updatedAt: DateTime(2026, 11, 20, 19, 0),
        activeProviderType: AiProviderType.grok,
        providers: localProviders,
        reminderSettings: const ReminderSettings(),
        tasks: [localTask],
        chatMessages: const [],
      );

      final merged = cloud.mergeWithLocal(local);

      expect(merged.tasks.map((t) => t.id).toSet(), {'cloud-task', 'local-task'});
      expect(merged.providers[AiProviderType.gemini]?.apiKey, 'cloud-gemini');
      expect(merged.providers[AiProviderType.grok]?.apiKey, 'local-grok-key');
      expect(merged.activeProviderType, AiProviderType.gemini);
    });

    test('replacing an API key in payload overwrites old value cleanly', () {
      final providers = Map<AiProviderType, AiProviderConfig>.from(
        AiProviderConfig.defaults(),
      );
      providers[AiProviderType.gemini] =
          providers[AiProviderType.gemini]!.copyWith(apiKey: 'new-rotated-key');

      final updated = CloudBackupPayload(
        updatedAt: DateTime(2026, 11, 20, 20, 5),
        activeProviderType: AiProviderType.gemini,
        providers: providers,
        reminderSettings: const ReminderSettings(),
        tasks: const [],
        chatMessages: const [],
      );

      final restored = CloudBackupPayload.fromFirestoreMap(
        updated.toFirestoreMap(),
      );
      expect(restored.providers[AiProviderType.gemini]?.apiKey, 'new-rotated-key');
    });
  });
}
