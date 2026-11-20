import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:h_todo_ai/models/ai_provider_config.dart';
import 'package:h_todo_ai/models/task_item.dart';
import 'package:h_todo_ai/services/ai_parser_service.dart';

void main() {
  group('AiParserService.parseJsonResponse', () {
    test('extracts assignment and class test with Bengali/English syllabus', () {
      const mockModelOutput = '''
```json
{
  "summary": "IRE 415 – Computer Vision এর Assignment 03 (২১ নভেম্বর) এবং Class Test (২২ নভেম্বর) যোগ করা হয়েছে।",
  "tasks": [
    {
      "title": "Assignment 03",
      "courseOrCategory": "IRE 415 – Computer Vision",
      "type": "assignment",
      "dueDate": "2026-11-21",
      "dueTime": "23:59",
      "priority": "high",
      "notes": "জমা দেওয়ার শেষ তারিখ: ২১ নভেম্বর ২০২৬ (শনিবার)।",
      "subtasks": []
    },
    {
      "title": "Class Test (Image Enhancement, Filtering, Morphology)",
      "courseOrCategory": "IRE 415 – Computer Vision",
      "type": "classTest",
      "dueDate": "2026-11-22",
      "dueTime": null,
      "priority": "high",
      "notes": "Filtering (Sessional ক্লাসে যা পড়ানো হয়েছে only those filters).",
      "subtasks": [
        "Image Enhancement",
        "Filtering: Basic Techniques, Use Cases, Gaussian & Median Filter, Limitations",
        "Morphological Operations: Erosion, Dilation, Opening, Closing"
      ]
    }
  ]
}
```
''';

      final result = AiParserService.parseJsonResponse(
        mockModelOutput,
        fallbackDate: DateTime(2026, 11, 20),
      );

      expect(result.summary, contains('IRE 415'));
      expect(result.tasks.length, 2);

      final assignment = result.tasks[0];
      expect(assignment.title, 'Assignment 03');
      expect(assignment.courseOrCategory, 'IRE 415 – Computer Vision');
      expect(assignment.type, TaskType.assignment);
      expect(assignment.priority, TaskPriority.high);
      expect(assignment.dueDate, DateTime(2026, 11, 21));
      expect(assignment.dueHour, 23);
      expect(assignment.dueMinute, 59);
      expect(assignment.formattedDueTime, '11:59 PM');

      final ct = result.tasks[1];
      expect(ct.type, TaskType.classTest);
      expect(ct.dueDate, DateTime(2026, 11, 22));
      expect(ct.hasDueTime, isFalse);
      expect(ct.subtasks.length, 3);
      expect(ct.subtasks.first.title, 'Image Enhancement');
    });

    test('parses Bengali numerals and DD.MM.YYYY date format', () {
      const raw = '''
{
  "summary": "Class test added.",
  "tasks": [
    {
      "title": "Lab Quiz",
      "courseOrCategory": "CSE 401",
      "type": "lab",
      "dueDate": "২২.১১.২০২৬",
      "dueTime": "10:30 am",
      "priority": "medium",
      "notes": "",
      "subtasks": []
    }
  ]
}
''';

      final result = AiParserService.parseJsonResponse(
        raw,
        fallbackDate: DateTime(2026, 11, 20),
      );

      expect(result.tasks.single.dueDate, DateTime(2026, 11, 22));
      expect(result.tasks.single.dueHour, 10);
      expect(result.tasks.single.dueMinute, 30);
      expect(result.tasks.single.type, TaskType.lab);
    });

    test('throws AiParserException on invalid JSON or empty tasks', () {
      expect(
        () => AiParserService.parseJsonResponse(
          'Sorry I could not help.',
          fallbackDate: DateTime(2026, 11, 20),
        ),
        throwsA(isA<AiParserException>()),
      );

      expect(
        () => AiParserService.parseJsonResponse(
          '{"summary": "None", "tasks": []}',
          fallbackDate: DateTime(2026, 11, 20),
        ),
        throwsA(isA<AiParserException>()),
      );
    });
  });

  group('AiParserService live model discovery & fallback', () {
    test('fetchAvailableModels filters & ranks Gemini models', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v1beta/models');
        expect(request.headers['x-goog-api-key'], 'test-key');
        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/text-embedding-004',
                'supportedGenerationMethods': ['embedContent'],
              },
              {
                'name': 'models/imagen-4.0-generate-001',
                'supportedGenerationMethods': ['predict'],
              },
              {
                'name': 'models/gemma-4-27b-it',
                'supportedGenerationMethods': ['generateContent'],
              },
              {
                'name': 'models/gemini-3.5-flash-lite',
                'supportedGenerationMethods': ['generateContent'],
              },
              {
                'name': 'models/gemini-3.8-flash',
                'supportedGenerationMethods': ['generateContent'],
              },
            ],
          }),
          200,
        );
      });

      final service = AiParserService(client: client);
      final config = AiProviderConfig.defaults()[AiProviderType.gemini]!
          .copyWith(apiKey: 'test-key');

      final models = await service.fetchAvailableModels(config);
      expect(models.first, 'gemini-3.8-flash');
      expect(models, containsAll(['gemini-3.8-flash', 'gemini-3.5-flash-lite', 'gemma-4-27b-it']));
      expect(models, isNot(contains('text-embedding-004')));
      expect(models, isNot(contains('imagen-4.0-generate-001')));
    });

    test('fetchAvailableModels filters & ranks Groq models', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://api.groq.com/openai/v1/models');
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'whisper-large-v3'},
              {'id': 'openai/gpt-oss-120b'},
              {'id': 'llama-3.3-70b-versatile'},
            ],
          }),
          200,
        );
      });

      final service = AiParserService(client: client);
      final config = AiProviderConfig.defaults()[AiProviderType.groq]!
          .copyWith(apiKey: 'gsk_test');

      final models = await service.fetchAvailableModels(config);
      expect(models.first, 'llama-3.3-70b-versatile');
      expect(models, contains('openai/gpt-oss-120b'));
      expect(models, isNot(contains('whisper-large-v3')));
    });

    test('testConnection auto-switches to live working model on retired model', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/v1beta/models') {
          return http.Response(
            jsonEncode({
              'models': [
                {
                  'name': 'models/gemini-3.8-flash',
                  'supportedGenerationMethods': ['generateContent'],
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.contains('gemini-3.8-flash')) {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'OK'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'error': {'message': 'Model is no longer available.'},
          }),
          404,
        );
      });

      final service = AiParserService(client: client);
      final config = AiProviderConfig.defaults()[AiProviderType.gemini]!
          .copyWith(apiKey: 'test-key', model: 'retired-old-model');

      final res = await service.testConnection(config);
      expect(res.ok, isTrue);
      expect(res.resolvedModel, 'gemini-3.8-flash');
      expect(res.message, contains('Auto-selected live model: gemini-3.8-flash'));
    });

    test('extractTasks auto-recovers when configured model returns 404', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/openai/v1/models') {
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'llama-3.3-70b-versatile'},
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/openai/v1/chat/completions') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['model'] == 'dead-model') {
            return http.Response(
              jsonEncode({
                'error': {'message': 'Model dead-model is no longer available'},
              }),
              404,
            );
          }
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'summary': 'Added Assignment 03',
                      'tasks': [
                        {
                          'title': 'Assignment 03',
                          'courseOrCategory': 'IRE 415',
                          'type': 'assignment',
                          'dueDate': '2026-11-21',
                          'dueTime': '23:59',
                          'priority': 'high',
                          'notes': '',
                          'subtasks': [],
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
        return http.Response('Not Found', 404);
      });

      final service = AiParserService(client: client);
      final config = AiProviderConfig.defaults()[AiProviderType.groq]!
          .copyWith(apiKey: 'gsk_test', model: 'dead-model');

      final result = await service.extractTasks(
        'Assignment 03 due 21 Nov 2026',
        config,
        now: DateTime(2026, 11, 20),
      );
      expect(result.tasks.single.title, 'Assignment 03');
      expect(result.resolvedModel, 'llama-3.3-70b-versatile');
    });
  });
}
