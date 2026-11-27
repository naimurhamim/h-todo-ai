import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:h_todo_ai/models/ai_chat_action.dart';
import 'package:h_todo_ai/models/ai_provider_config.dart';
import 'package:h_todo_ai/models/reminder_settings.dart';
import 'package:h_todo_ai/models/task_item.dart';
import 'package:h_todo_ai/providers/chat_provider.dart';
import 'package:h_todo_ai/providers/task_provider.dart';
import 'package:h_todo_ai/services/ai_parser_service.dart';
import 'package:h_todo_ai/services/local_command_parser.dart';
import 'package:h_todo_ai/services/notification_service.dart';
import 'package:h_todo_ai/services/storage_service.dart';

void main() {
  final fixedNow = DateTime(2026, 11, 27, 9, 30);
  final today = DateTime(2026, 11, 27);
  final tomorrow = DateTime(2026, 11, 28);

  group('LocalCommandParser & Single-Router Exclusivity', () {
    final sampleTasks = [
      TaskItem(
        id: 't-today',
        notificationBaseId: 101,
        title: 'AI Assignment 01',
        type: TaskType.assignment,
        dueDate: today,
        dueHour: 18,
        dueMinute: 0,
        createdAt: fixedNow,
      ),
      TaskItem(
        id: 't-tmr',
        notificationBaseId: 102,
        title: 'Networks Quiz',
        type: TaskType.classTest,
        dueDate: tomorrow,
        dueHour: 10,
        dueMinute: 0,
        createdAt: fixedNow,
      ),
      TaskItem(
        id: 't-over',
        notificationBaseId: 100,
        title: 'Missed Lab Report',
        type: TaskType.lab,
        dueDate: DateTime(2026, 11, 25),
        createdAt: fixedNow,
      ),
      TaskItem(
        id: 't-done',
        notificationBaseId: 99,
        title: 'Finished Task',
        dueDate: today,
        isCompleted: true,
        createdAt: fixedNow,
      ),
    ];

    test('handles all Q&A presets & Bengali queries with zero AI calls', () {
      const reminders = ReminderSettings();

      final todayRes = LocalCommandParser.tryParse(
        'What is due today?',
        existingTasks: sampleTasks,
        reminderSettings: reminders,
        now: fixedNow,
      );
      expect(todayRes, isNotNull);
      expect(todayRes!.handledLocally, isTrue);
      expect(todayRes.reply, contains('AI Assignment 01'));
      expect(todayRes.referencedTaskIds, ['t-today']);

      final bnTodayRes = LocalCommandParser.tryParse(
        'আজ কী আছে?',
        existingTasks: sampleTasks,
        reminderSettings: reminders,
        now: fixedNow,
      );
      expect(bnTodayRes, isNotNull);
      expect(bnTodayRes!.reply, contains('AI Assignment 01'));

      final tmrRes = LocalCommandParser.tryParse(
        'What is due tomorrow?',
        existingTasks: sampleTasks,
        reminderSettings: reminders,
        now: fixedNow,
      );
      expect(tmrRes!.reply, contains('Networks Quiz'));
      expect(tmrRes.referencedTaskIds, ['t-tmr']);

      final weekRes = LocalCommandParser.tryParse(
        'Show tasks for this week',
        existingTasks: sampleTasks,
        reminderSettings: reminders,
        now: fixedNow,
      );
      expect(weekRes!.referencedTaskIds, containsAll(['t-today', 't-tmr']));

      final nextRes = LocalCommandParser.tryParse(
        'What is my next deadline?',
        existingTasks: sampleTasks,
        reminderSettings: reminders,
        now: fixedNow,
      );
      expect(nextRes!.reply, contains('AI Assignment 01'));

      final overdueRes = LocalCommandParser.tryParse(
        'Show overdue tasks',
        existingTasks: sampleTasks,
        reminderSettings: reminders,
        now: fixedNow,
      );
      expect(overdueRes!.reply, contains('Missed Lab Report'));
      expect(overdueRes.referencedTaskIds, ['t-over']);

      final summaryRes = LocalCommandParser.tryParse(
        'Show task summary',
        existingTasks: sampleTasks,
        reminderSettings: reminders,
        now: fixedNow,
      );
      expect(summaryRes!.reply, contains('1 left today'));

      final remRes = LocalCommandParser.tryParse(
        'Show reminder settings',
        existingTasks: sampleTasks,
        reminderSettings: reminders,
        now: fixedNow,
      );
      expect(remRes!.reply, contains('4:00 PM'));
    });

    test('parses recurring templates, Bengali routines, quick tasks, and rejects complex notices', () {
      const reminders = ReminderSettings();

      final twice = LocalCommandParser.tryParse(
        'Daily 8:00 AM & 9:00 PM Revision for 40 days',
        existingTasks: const [],
        reminderSettings: reminders,
        now: fixedNow,
      );
      expect(twice, isNotNull);
      expect(twice!.actions.single.type, AiActionType.addRecurring);
      expect(twice.actions.single.recurringSpec!.times, [(8, 0), (21, 0)]);
      expect(twice.actions.single.recurringSpec!.durationDays, 40);

      final bnDaily = LocalCommandParser.tryParse(
        'প্রতিদিন সকাল ৮টায় পড়া ৩০ দিন',
        existingTasks: const [],
        reminderSettings: reminders,
        now: fixedNow,
      );
      expect(bnDaily, isNotNull);
      expect(bnDaily!.actions.single.type, AiActionType.addRecurring);
      expect(bnDaily.actions.single.recurringSpec!.times, [(8, 0)]);
      expect(bnDaily.actions.single.recurringSpec!.durationDays, 30);

      final weekly = LocalCommandParser.tryParse(
        'Every Sun, Tue, Thu 9:00 AM Class for 3 months',
        existingTasks: const [],
        reminderSettings: reminders,
        now: fixedNow,
      );
      expect(weekly!.actions.single.recurringSpec!.frequency, RecurrenceFrequency.weekly);
      expect(weekly.actions.single.recurringSpec!.weekdays, [7, 2, 4]);

      final quickBn = LocalCommandParser.tryParse(
        'কাল সকাল ১০টায় কুইজ',
        existingTasks: const [],
        reminderSettings: reminders,
        now: fixedNow,
      );
      expect(quickBn, isNotNull);
      expect(quickBn!.actions.single.type, AiActionType.add);
      expect(quickBn.actions.single.newTask!.dueHour, 10);
      expect(quickBn.actions.single.newTask!.dueDate, tomorrow);

      // Complex notice / multi-line / syllabus MUST return null so Cloud AI handles it cleanly.
      final complex = LocalCommandParser.tryParse(
        'IRE 415 Class Test tomorrow syllabus: Ch 1 Filtering',
        existingTasks: const [],
        reminderSettings: reminders,
        now: fixedNow,
      );
      expect(complex, isNull);

      final multiLine = LocalCommandParser.tryParse(
        'Tomorrow 10:00 AM Physics Quiz\nSyllabus: Optics',
        existingTasks: const [],
        reminderSettings: reminders,
        now: fixedNow,
      );
      expect(multiLine, isNull);
    });

    test('ChatProvider runs Local presets with 0 HTTP calls & caps stored messages at 200', () async {
      SharedPreferences.setMockInitialValues({});
      var httpCalls = 0;
      final client = MockClient((_) async {
        httpCalls++;
        return http.Response('should not run', 500);
      });

      final storage = StorageService();
      final tasks = TaskProvider(
        storage: storage,
        notifications: NotificationService(),
      );
      final chat = ChatProvider(
        storage: storage,
        parser: AiParserService(client: client),
      );
      await Future.wait([tasks.load(), chat.load()]);

      final defaults = AiProviderConfig.defaults();
      await chat.sendScheduleMessage(
        'Daily 8:00 AM Study for 5 days',
        activeProvider: defaults[AiProviderType.groq]!, // intentionally NO API key
        allProviders: defaults.values.toList(),
        taskProvider: tasks,
      );

      expect(httpCalls, 0);
      expect(tasks.tasks, hasLength(5));
      expect(chat.messages.last.providerName, LocalCommandParser.localProviderLabel);

      // Seed 205 messages and verify history trims cleanly to 200 without deleting any tasks.
      for (var i = 0; i < 105; i++) {
        await chat.sendScheduleMessage(
          'What is due today?',
          activeProvider: defaults[AiProviderType.groq]!,
          allProviders: defaults.values.toList(),
          taskProvider: tasks,
        );
      }
      expect(httpCalls, 0);
      expect(chat.messages.length, ChatProvider.maxStoredMessages);
      expect(tasks.tasks, hasLength(5));
    });
  });

  group('Atomic Multi-Model / Multi-Key / Multi-Provider Auto-Failover', () {
    test('discards truncated/incomplete JSON & rate-limited responses atomically and fails over cleanly', () async {
      SharedPreferences.setMockInitialValues({});
      final calls = <String>[];

      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final model = body['model']?.toString() ?? '';
        final auth = request.headers['Authorization'] ?? '';
        calls.add('${request.url.host}|$model|$auth');

        // 1. Primary Groq model hits 429 rate limit
        if (model == 'llama-3.3-70b-versatile') {
          return http.Response(
            jsonEncode({'error': {'message': 'Rate limit exceeded'}}),
            429,
          );
        }
        // 2. Fallback Groq model returns truncated/incomplete JSON (finish_reason: length)
        if (model == 'llama-3.1-8b-instant') {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'finish_reason': 'length',
                  'message': {
                    'content': '{"reply":"Added","actions":[{"type":"add","title":"Broken',
                  },
                },
              ],
            }),
            200,
          );
        }
        // 3. OpenAI-compatible 3rd model on key 1 throws broken JSON without finish_reason
        if (request.url.host == 'api.groq.com' &&
            auth == 'Bearer gsk-key-1') {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'finish_reason': 'stop',
                  'message': {'content': '{"reply": "incomplete'},
                },
              ],
            }),
            200,
          );
        }
        // 4. Backup Gemini key completes cleanly with valid full JSON!
        if (request.url.host == 'generativelanguage.googleapis.com') {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'finishReason': 'STOP',
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({
                          'reply': 'Scheduled CSE 415 class test cleanly.',
                          'offTopic': false,
                          'referencedTaskIds': [],
                          'actions': [
                            {
                              'type': 'add',
                              'title': 'CSE 415 Class Test',
                              'dueDate': '2026-12-01',
                              'dueTime': '10:30',
                              'taskType': 'classTest',
                              'priority': 'high',
                            },
                          ],
                        }),
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'error': {'message': 'Quota exceeded'}}),
          429,
        );
      });

      final storage = StorageService();
      final tasks = TaskProvider(
        storage: storage,
        notifications: NotificationService(),
      );
      final chat = ChatProvider(
        storage: storage,
        parser: AiParserService(client: client),
      );
      await Future.wait([tasks.load(), chat.load()]);

      final defaults = AiProviderConfig.defaults();
      final groq = defaults[AiProviderType.groq]!.copyWith(
        apiKey: 'gsk-key-1',
        model: 'llama-3.3-70b-versatile',
      );
      final gemini = defaults[AiProviderType.gemini]!.copyWith(
        apiKey: 'AIza-backup-key',
      );

      // Complex multi-line notice forces Gate 2 (Cloud AI Failover)
      await chat.sendScheduleMessage(
        'CSE 415 notice\nClass Test on 1 Dec 10:30 AM syllabus chapter 1 to 3',
        activeProvider: groq,
        allProviders: [groq, gemini],
        taskProvider: tasks,
      );

      // Truncated & partial JSON replies were discarded; ONLY the valid Gemini result committed!
      expect(tasks.tasks, hasLength(1));
      expect(tasks.tasks.single.title, 'CSE 415 Class Test');
      expect(chat.messages.last.isError, isFalse);
      expect(chat.messages.last.providerName, contains('Google Gemini'));
      expect(calls.any((c) => c.contains('llama-3.3-70b-versatile')), isTrue);
      expect(calls.any((c) => c.contains('llama-3.1-8b-instant')), isTrue);
      expect(calls.any((c) => c.contains('generativelanguage.googleapis.com')), isTrue);
    });

    test('multi-key rotation tries second comma-separated API key before leaving provider', () async {
      SharedPreferences.setMockInitialValues({});
      final authHeadersSeen = <String>[];

      final client = MockClient((request) async {
        final auth = request.headers['Authorization'] ?? '';
        authHeadersSeen.add(auth);
        if (auth == 'Bearer gsk-first-expired') {
          return http.Response(
            jsonEncode({'error': {'message': 'Invalid API Key'}}),
            401,
          );
        }
        if (auth == 'Bearer gsk-second-valid') {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'finish_reason': 'stop',
                  'message': {
                    'content': jsonEncode({
                      'reply': 'Added Physics Midterm cleanly.',
                      'offTopic': false,
                      'referencedTaskIds': [],
                      'actions': [
                        {
                          'type': 'add',
                          'title': 'Physics Midterm',
                          'dueDate': '2026-12-03',
                          'taskType': 'exam',
                        },
                      ],
                    }),
                  },
                },
              ],
            }),
            200,
          );
        }
        return http.Response('Unauthorized', 401);
      });

      final parser = AiParserService(client: client);
      final groq = AiProviderConfig.defaults()[AiProviderType.groq]!.copyWith(
        apiKey: 'gsk-first-expired, gsk-second-valid',
      );

      final res = await parser.processChatCommandWithFailover(
        'Notice:\nPhysics Midterm on Dec 3 covering Wave Optics syllabus',
        activeProvider: groq,
        allProviders: [groq],
        now: fixedNow,
      );

      expect(res.actions.single.newTask?.title, 'Physics Midterm');
      expect(authHeadersSeen, [
        'Bearer gsk-first-expired',
        'Bearer gsk-second-valid',
      ]);
    });

    test('when all models and providers fail with incomplete JSON or quota, existing tasks stay 100% intact', () async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'finish_reason': 'length',
                'message': {'content': '{"reply":"Half output'},
              },
            ],
          }),
          200,
        );
      });

      final storage = StorageService();
      final tasks = TaskProvider(
        storage: storage,
        notifications: NotificationService(),
      );
      await tasks.load();
      await tasks.addTask(
        TaskItem(
          id: 'existing-safe',
          notificationBaseId: 500,
          title: 'Existing Safe Task',
          dueDate: tomorrow,
          createdAt: fixedNow,
        ),
      );

      final chat = ChatProvider(
        storage: storage,
        parser: AiParserService(client: client),
      );
      await chat.load();

      final groq = AiProviderConfig.defaults()[AiProviderType.groq]!.copyWith(
        apiKey: 'gsk-only-key',
      );
      await chat.sendScheduleMessage(
        'Complex multi-line schedule:\nDelete existing tasks and add new ones',
        activeProvider: groq,
        allProviders: [groq],
        taskProvider: tasks,
      );

      expect(chat.messages.last.isError, isTrue);
      expect(tasks.tasks.map((t) => t.id), ['existing-safe']);
    });
  });
}
