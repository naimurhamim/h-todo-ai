import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:h_todo_ai/models/ai_chat_action.dart';
import 'package:h_todo_ai/models/ai_provider_config.dart';
import 'package:h_todo_ai/models/chat_message.dart';
import 'package:h_todo_ai/models/task_item.dart';
import 'package:h_todo_ai/providers/ai_settings_provider.dart';
import 'package:h_todo_ai/providers/chat_provider.dart';
import 'package:h_todo_ai/providers/task_provider.dart';
import 'package:h_todo_ai/screens/ai_chat_screen.dart';
import 'package:h_todo_ai/services/ai_parser_service.dart';
import 'package:h_todo_ai/services/notification_service.dart';
import 'package:h_todo_ai/services/storage_service.dart';
import 'package:h_todo_ai/theme/app_theme.dart';

void main() {
  group('AiParserService.parseAssistantResponse', () {
    test('parses multi-action multilingual command JSON cleanly', () {
      const raw = '''
{
  "reply": "Marked Assignment 03 done, moved Class Test to Nov 28 at 3:00 PM, and checked Gaussian Filter.",
  "offTopic": false,
  "referencedTaskIds": ["t-assign", "t-ct"],
  "actions": [
    {"type": "complete", "taskId": "t-assign"},
    {"type": "reschedule", "taskId": "t-ct", "dueDate": "2026-11-28", "dueTime": "15:00"},
    {"type": "complete_subtask", "taskId": "t-ct", "subtaskTitle": "Gaussian Filter"},
    {"type": "delete", "taskQuery": "Lab Quiz"},
    {
      "type": "add",
      "title": "Project Demo",
      "courseOrCategory": "CSE 499",
      "dueDate": "2026-11-30",
      "dueTime": "10:00",
      "priority": "high",
      "addSubtasks": ["Prepare slides"]
    }
  ]
}
''';

      final res = AiParserService.parseAssistantResponse(
        raw,
        fallbackDate: DateTime(2026, 11, 21),
      );

      expect(res.offTopic, isFalse);
      expect(res.referencedTaskIds, ['t-assign', 't-ct']);
      expect(res.actions, hasLength(5));
      expect(res.actions[0].type, AiActionType.complete);
      expect(res.actions[0].taskId, 't-assign');
      expect(res.actions[1].type, AiActionType.reschedule);
      expect(res.actions[1].newDueDate, DateTime(2026, 11, 28));
      expect(res.actions[1].newDueHour, 15);
      expect(res.actions[1].newDueMinute, 0);
      expect(res.actions[2].type, AiActionType.completeSubtask);
      expect(res.actions[2].subtaskTitle, 'Gaussian Filter');
      expect(res.actions[3].type, AiActionType.delete);
      expect(res.actions[3].taskQuery, 'Lab Quiz');
      expect(res.actions[4].type, AiActionType.add);
      expect(res.actions[4].newTask?.title, 'Project Demo');
      expect(res.actions[4].newTask?.subtasks.single.title, 'Prepare slides');
    });

    test('supports off-topic polite refusal with empty actions', () {
      const raw = '''
{
  "reply": "I only manage H-TODO AI tasks, deadlines, syllabi, and reminders.",
  "offTopic": true,
  "referencedTaskIds": [],
  "actions": []
}
''';

      final res = AiParserService.parseAssistantResponse(
        raw,
        fallbackDate: DateTime(2026, 11, 21),
      );

      expect(res.offTopic, isTrue);
      expect(res.actions, isEmpty);
      expect(res.reply, contains('H-TODO AI'));
    });

    test('falls back cleanly to legacy tasks-only schema', () {
      const raw = '''
{
  "summary": "Added Viva.",
  "tasks": [
    {
      "title": "Final Viva",
      "courseOrCategory": "IRE 415",
      "type": "exam",
      "dueDate": "2026-12-01",
      "dueTime": "09:30",
      "priority": "high",
      "subtasks": ["Module 1"]
    }
  ]
}
''';

      final res = AiParserService.parseAssistantResponse(
        raw,
        fallbackDate: DateTime(2026, 11, 21),
      );

      expect(res.actions, hasLength(1));
      expect(res.actions.single.type, AiActionType.add);
      expect(res.actions.single.newTask?.title, 'Final Viva');
      expect(res.reply, 'Added Viva.');
    });

    test('parses update_reminder_settings actions from natural language', () {
      const raw = '''
{
  "reply": "Updated default reminders to 5:30 PM day before and 9:00 PM due day.",
  "offTopic": false,
  "referencedTaskIds": [],
  "actions": [
    {
      "type": "update_reminder_settings",
      "dayBeforeTime": "17:30",
      "endOfDayTime": "21:00",
      "remindersEnabled": true
    }
  ]
}
''';

      final res = AiParserService.parseAssistantResponse(
        raw,
        fallbackDate: DateTime(2026, 11, 21),
      );

      expect(res.actions, hasLength(1));
      final action = res.actions.single;
      expect(action.type, AiActionType.updateReminderSettings);
      expect(action.newDayBeforeTime, (17, 30));
      expect(action.newEndOfDayTime, (21, 0));
      expect(action.remindersEnabled, isTrue);
    });
  });

  group('TaskProvider.executeAiActions & Undo', () {
    late TaskProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = TaskProvider(
        storage: StorageService(),
        notifications: NotificationService(),
      );
      await provider.load();
      await provider.addTasks([
        TaskItem(
          id: 't-assign',
          notificationBaseId: 10,
          title: 'Assignment 03',
          courseOrCategory: 'IRE 415',
          type: TaskType.assignment,
          dueDate: DateTime(2026, 11, 22),
          dueHour: 23,
          dueMinute: 59,
          createdAt: DateTime(2026, 11, 20),
        ),
        TaskItem(
          id: 't-ct',
          notificationBaseId: 20,
          title: 'Class Test 01',
          courseOrCategory: 'IRE 415',
          type: TaskType.classTest,
          dueDate: DateTime(2026, 11, 23),
          dueHour: 11,
          dueMinute: 0,
          subtasks: const [
            SubTaskItem(id: 'sub-1', title: 'Gaussian Filter'),
            SubTaskItem(id: 'sub-2', title: 'Median Filter'),
          ],
          createdAt: DateTime(2026, 11, 20),
        ),
        TaskItem(
          id: 't-dup-1',
          notificationBaseId: 30,
          title: 'Lab Report',
          courseOrCategory: 'CSE 401',
          type: TaskType.lab,
          dueDate: DateTime(2026, 11, 24),
          createdAt: DateTime(2026, 11, 20),
        ),
        TaskItem(
          id: 't-dup-2',
          notificationBaseId: 31,
          title: 'Lab Report',
          courseOrCategory: 'EEE 402',
          type: TaskType.lab,
          dueDate: DateTime(2026, 11, 25),
          createdAt: DateTime(2026, 11, 20),
        ),
      ]);
    });

    test('completes, uncompletes, reschedules preserving time, and updates syllabus',
        () async {
      final exec = await provider.executeAiActions([
        const AiTaskAction(type: AiActionType.complete, taskId: 't-assign'),
        AiTaskAction(
          type: AiActionType.reschedule,
          taskId: 't-ct',
          newDueDate: DateTime(2026, 11, 27),
        ),
        const AiTaskAction(
          type: AiActionType.update,
          taskId: 't-ct',
          newPriority: TaskPriority.high,
          addSubtasks: ['Gaussian Filter', 'Morphological Operations'],
        ),
        const AiTaskAction(
          type: AiActionType.completeSubtask,
          taskId: 't-ct',
          subtaskTitle: 'Gaussian Filter',
        ),
      ]);

      expect(exec.completed, 1);
      expect(exec.rescheduled, 1);
      expect(exec.updated, 1);
      expect(exec.subtasksUpdated, 1);

      final assign = provider.findById('t-assign')!;
      expect(assign.isCompleted, isTrue);

      final ct = provider.findById('t-ct')!;
      expect(ct.dateKey, '2026-11-27');
      // Preserves existing 11:00 AM time when only date is moved.
      expect(ct.dueHour, 11);
      expect(ct.dueMinute, 0);
      expect(ct.priority, TaskPriority.high);
      expect(ct.subtasks.map((s) => s.title), [
        'Gaussian Filter',
        'Median Filter',
        'Morphological Operations',
      ]);
      expect(ct.subtasks.first.isCompleted, isTrue);
      expect(ct.subtasks[1].isCompleted, isFalse);

      // Reopen completed task.
      final reopen = await provider.executeAiActions(const [
        AiTaskAction(type: AiActionType.uncomplete, taskId: 't-assign'),
      ]);
      expect(reopen.uncompleted, 1);
      expect(provider.findById('t-assign')!.isCompleted, isFalse);
    });

    test('skips ambiguous query safely and supports delete + Undo restore',
        () async {
      // Ambiguous query without taskId matches 2 tasks -> skipped cleanly.
      final ambiguous = await provider.executeAiActions(const [
        AiTaskAction(type: AiActionType.delete, taskQuery: 'Lab Report'),
      ]);
      expect(ambiguous.deleted, 0);
      expect(provider.tasks, hasLength(4));

      // Unambiguous delete + Undo restore.
      final deleted = await provider.executeAiActions(const [
        AiTaskAction(type: AiActionType.delete, taskId: 't-assign'),
      ]);
      expect(deleted.deleted, 1);
      expect(deleted.deletedTasks.single.id, 't-assign');
      expect(provider.findById('t-assign'), isNull);

      await provider.restoreDeletedTasks(deleted.deletedTasks);
      expect(provider.findById('t-assign'), isNotNull);
      expect(provider.tasks, hasLength(4));
    });
  });

  group('ChatProvider end-to-end multilingual command flow', () {
    test('passes task IDs & recent chat context and returns deleted tasks for Undo',
        () async {
      SharedPreferences.setMockInitialValues({
        'htodo_chat_v1': jsonEncode([
          ChatMessage(
            id: 'prev-1',
            role: ChatRole.user,
            text: 'Added OS Quiz earlier',
            timestamp: DateTime(2026, 11, 21, 9, 0),
          ).toJson(),
        ]),
      });
      final storage = StorageService();
      final taskProvider = TaskProvider(
        storage: storage,
        notifications: NotificationService(),
      );
      await taskProvider.load();
      await taskProvider.addTask(
        TaskItem(
          id: 'ctx-1',
          notificationBaseId: 55,
          title: 'OS Quiz',
          courseOrCategory: 'CSE 305',
          type: TaskType.classTest,
          dueDate: DateTime(2026, 11, 22),
          createdAt: DateTime(2026, 11, 21),
        ),
      );

      late String capturedSystemPrompt;
      final mockClient = MockClient((request) async {
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        final msgs = decoded['messages'] as List<dynamic>;
        capturedSystemPrompt = (msgs.first as Map)['content'].toString();
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'reply': 'Removed OS Quiz as requested.',
                    'offTopic': false,
                    'referencedTaskIds': [],
                    'actions': [
                      {'type': 'delete', 'taskId': 'ctx-1'},
                    ],
                  }),
                },
              },
            ],
          }),
          200,
        );
      });

      final chatProvider = ChatProvider(
        storage: storage,
        parser: AiParserService(client: mockClient),
      );
      await chatProvider.load();

      final providerConfig = AiProviderConfig.defaults()[AiProviderType.groq]!
          .copyWith(apiKey: 'gsk-test-key');

      final deletedForUndo = await chatProvider.sendScheduleMessage(
        'Remove OS Quiz',
        activeProvider: providerConfig,
        taskProvider: taskProvider,
      );

      expect(capturedSystemPrompt, contains('id=ctx-1'));
      expect(capturedSystemPrompt, contains('OS Quiz'));
      expect(capturedSystemPrompt, contains('Added OS Quiz earlier'));
      expect(deletedForUndo, hasLength(1));
      expect(deletedForUndo.single.id, 'ctx-1');
      expect(taskProvider.findById('ctx-1'), isNull);
      expect(chatProvider.messages.last.text, 'Removed OS Quiz as requested.');
    });

    testWidgets(
        'shows top rounded popup with Undo and OK on chat delete and restores task cleanly',
        (WidgetTester tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode({
                    'reply': 'Removed Meeting as requested.',
                    'offTopic': false,
                    'referencedTaskIds': [],
                    'actions': [
                      {'type': 'delete', 'taskId': 'm-1'},
                    ],
                  }),
                },
              },
            ],
          }),
          200,
        );
      });

      final aiSettings = AiSettingsProvider(storage: storage);
      await aiSettings.load();
      await aiSettings.setActiveProvider(AiProviderType.groq);
      await aiSettings.updateProviderConfig(
        aiSettings.providers[AiProviderType.groq]!
            .copyWith(apiKey: 'gsk-test-key'),
      );

      final taskProvider = TaskProvider(
        storage: storage,
        notifications: NotificationService(),
        readReminderSettings: () => aiSettings.reminderSettings,
      );
      await taskProvider.load();
      await taskProvider.addTask(
        TaskItem(
          id: 'm-1',
          notificationBaseId: 77,
          title: 'Project Meeting',
          type: TaskType.meeting,
          dueDate: DateTime(2026, 11, 22),
          createdAt: DateTime(2026, 11, 21),
        ),
      );

      final chatProvider = ChatProvider(
        storage: storage,
        parser: AiParserService(client: mockClient),
      );
      await chatProvider.load();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: aiSettings),
            ChangeNotifierProvider.value(value: taskProvider),
            ChangeNotifierProvider.value(value: chatProvider),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: AiChatScreen(onGoToSettings: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Remove Project Meeting');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(taskProvider.findById('m-1'), isNull);
      expect(find.text('Removed "Project Meeting"'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      // Verify popup sits near top of viewport cleanly.
      final popupY =
          tester.getTopLeft(find.text('Removed "Project Meeting"')).dy;
      expect(popupY, lessThan(120));

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(taskProvider.findById('m-1'), isNotNull);
      expect(find.text('Removed "Project Meeting"'), findsNothing);
    });
  });
}
