import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:h_todo_ai/models/ai_provider_config.dart';
import 'package:h_todo_ai/models/cloud_backup_payload.dart';
import 'package:h_todo_ai/models/reminder_settings.dart';
import 'package:h_todo_ai/models/task_item.dart';
import 'package:h_todo_ai/providers/task_provider.dart';
import 'package:h_todo_ai/services/notification_service.dart';
import 'package:h_todo_ai/services/storage_service.dart';
import 'package:h_todo_ai/services/update_service.dart';

void main() {
  group('TaskProvider.upsertParsedTasks deduplication', () {
    late TaskProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = TaskProvider(
        storage: StorageService(),
        notifications: NotificationService(),
      );
    });

    TaskItem buildTask({
      required String id,
      required String title,
      String course = 'IRE 415 - Computer Vision',
      int day = 21,
      int? dueHour = 23,
      int? dueMinute = 59,
      List<SubTaskItem> subtasks = const [],
      String notes = '',
    }) {
      return TaskItem(
        id: id,
        notificationBaseId: TaskItem.stableBaseIdFromUuid(id),
        title: title,
        courseOrCategory: course,
        type: TaskType.assignment,
        dueDate: DateTime(2026, 11, day),
        dueHour: dueHour,
        dueMinute: dueMinute,
        subtasks: subtasks,
        notes: notes,
        createdAt: DateTime(2026, 11, 20),
      );
    }

    test('inserts new task, skips identical duplicate, and merges new details',
        () async {
      final first = buildTask(
        id: 't-1',
        title: 'Assignment 03',
        subtasks: const [SubTaskItem(id: 's-1', title: 'Gaussian Filter')],
      );
      final r1 = await provider.upsertParsedTasks([first]);
      expect(r1.added, 1);
      expect(r1.updated, 0);
      expect(r1.skipped, 0);
      expect(provider.tasks, hasLength(1));

      // Identical repeat with different UUID and formatting differences.
      final exactDuplicate = buildTask(
        id: 't-2',
        title: 'assignment-03',
        course: 'IRE 415 Computer Vision',
        subtasks: const [SubTaskItem(id: 's-2', title: 'gaussian filter')],
      );
      final r2 = await provider.upsertParsedTasks([exactDuplicate]);
      expect(r2.added, 0);
      expect(r2.updated, 0);
      expect(r2.skipped, 1);
      expect(r2.affectedTaskIds, ['t-1']);
      expect(provider.tasks, hasLength(1));

      // Repeat bringing extra syllabus item and notes merges in-place.
      final enrichment = buildTask(
        id: 't-3',
        title: 'Assignment 03',
        subtasks: const [
          SubTaskItem(id: 's-3', title: 'Gaussian Filter'),
          SubTaskItem(id: 's-4', title: 'Median Filter'),
        ],
        notes: 'Submit PDF via LMS',
      );
      final r3 = await provider.upsertParsedTasks([enrichment]);
      expect(r3.added, 0);
      expect(r3.updated, 1);
      expect(r3.skipped, 0);
      expect(provider.tasks, hasLength(1));
      expect(provider.tasks.first.id, 't-1');
      expect(provider.tasks.first.subtasks.map((s) => s.title), [
        'Gaussian Filter',
        'Median Filter',
      ]);
      expect(provider.tasks.first.notes, 'Submit PDF via LMS');
    });

    test('keeps tasks on same date with different explicit due times separate',
        () async {
      final morning = buildTask(
        id: 'm-1',
        title: 'Lab Viva',
        dueHour: 10,
        dueMinute: 0,
      );
      final afternoon = buildTask(
        id: 'm-2',
        title: 'Lab Viva',
        dueHour: 15,
        dueMinute: 0,
      );

      final res = await provider.upsertParsedTasks([morning, afternoon]);
      expect(res.added, 2);
      expect(res.skipped, 0);
      expect(provider.tasks, hasLength(2));
    });
  });

  test('CloudBackupPayload.mergeWithLocal collapses duplicate signatures', () {
    final tLocal = TaskItem(
      id: 'local-1',
      notificationBaseId: 11,
      title: 'Class Test 02',
      courseOrCategory: 'CSE 410',
      type: TaskType.classTest,
      dueDate: DateTime(2026, 11, 25),
      dueHour: 11,
      dueMinute: 0,
      subtasks: const [SubTaskItem(id: 's1', title: 'Topic A')],
      createdAt: DateTime(2026, 11, 18),
    );
    final tCloudDup = TaskItem(
      id: 'cloud-99',
      notificationBaseId: 99,
      title: 'Class Test-02',
      courseOrCategory: 'CSE 410',
      type: TaskType.classTest,
      dueDate: DateTime(2026, 11, 25),
      dueHour: 11,
      dueMinute: 0,
      subtasks: const [
        SubTaskItem(id: 's1', title: 'Topic A'),
        SubTaskItem(id: 's2', title: 'Topic B'),
      ],
      createdAt: DateTime(2026, 11, 19),
    );

    final localPayload = CloudBackupPayload(
      updatedAt: DateTime(2026, 11, 19),
      activeProviderType: AiProviderType.gemini,
      providers: AiProviderConfig.defaults(),
      reminderSettings: const ReminderSettings(),
      tasks: [tLocal],
      chatMessages: const [],
    );
    final cloudPayload = CloudBackupPayload(
      updatedAt: DateTime(2026, 11, 20),
      activeProviderType: AiProviderType.gemini,
      providers: AiProviderConfig.defaults(),
      reminderSettings: const ReminderSettings(),
      tasks: [tCloudDup],
      chatMessages: const [],
    );

    final merged = cloudPayload.mergeWithLocal(localPayload);
    expect(merged.tasks, hasLength(1));
    expect(merged.tasks.first.subtasks, hasLength(2));
  });

  test('UpdateService.isNewerVersion compares semver strings accurately', () {
    expect(UpdateService.isNewerVersion('v1.2.0', '1.0.0'), isTrue);
    expect(UpdateService.isNewerVersion('1.0.1', '1.0.0+1'), isTrue);
    expect(UpdateService.isNewerVersion('2.0', '1.9.9'), isTrue);
    expect(UpdateService.isNewerVersion('v1.0.0', '1.0.0'), isFalse);
    expect(UpdateService.isNewerVersion('0.9.9', '1.0.0'), isFalse);
  });

  test('UpdateService.parseReleaseNotes strips Markdown syntax cleanly', () {
    const markdown = '''
## What's New
- **Private Google Drive Backup:** Auto-syncs to `appDataFolder` cleanly.
* *Smart* updates with [Release Page](https://github.com/naimurhamim/h-todo-ai)
1. Added top rounded `Undo` and `OK` popup.
---
''';
    final blocks = UpdateService.parseReleaseNotes(markdown);
    expect(blocks, hasLength(4));
    expect(blocks[0].kind, ReleaseNoteKind.heading);
    expect(blocks[0].segments.map((s) => s.text).join(), "What's New");

    expect(blocks[1].kind, ReleaseNoteKind.bullet);
    expect(
      blocks[1].segments.where((s) => s.bold).map((s) => s.text).join(),
      'Private Google Drive Backup:',
    );
    expect(
      blocks[1].segments.where((s) => s.code).map((s) => s.text).join(),
      'appDataFolder',
    );
    expect(blocks[1].segments.map((s) => s.text).join(), isNot(contains('**')));
    expect(blocks[1].segments.map((s) => s.text).join(), isNot(contains('`')));

    expect(blocks[2].kind, ReleaseNoteKind.bullet);
    expect(
      blocks[2].segments.map((s) => s.text).join(),
      'Smart updates with Release Page',
    );

    expect(blocks[3].kind, ReleaseNoteKind.numbered);
    expect(blocks[3].marker, '1.');
  });
}
