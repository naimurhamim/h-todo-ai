import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_provider_config.dart';
import '../models/task_item.dart';

/// Parsed output from an AI schedule extraction call.
class AiParseResult {
  const AiParseResult({
    required this.summary,
    required this.tasks,
    this.resolvedModel,
  });

  final String summary;
  final List<TaskItem> tasks;
  final String? resolvedModel;
}

/// Result of a live API key connection check.
class ApiTestResult {
  const ApiTestResult({
    required this.ok,
    required this.message,
    this.resolvedModel,
    this.availableModels = const [],
  });

  final bool ok;
  final String message;
  final String? resolvedModel;
  final List<String> availableModels;
}

/// Domain error thrown when AI parsing or API communication fails.
class AiParserException implements Exception {
  const AiParserException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Extracts structured tasks, due dates, and syllabi from natural-language notices.
class AiParserService {
  AiParserService({http.Client? client}) : _client = client ?? http.Client();

  static const _uuid = Uuid();
  static const _requestTimeout = Duration(seconds: 40);
  static const _testTimeout = Duration(seconds: 15);
  static const _maxReturnedModels = 15;

  final http.Client _client;

  /// Sends user schedule text to the configured active AI provider,
  /// automatically falling back to a live model if the saved model is retired.
  Future<AiParseResult> extractTasks(
    String userMessage,
    AiProviderConfig config, {
    DateTime? now,
    List<TaskItem> existingTasks = const [],
  }) async {
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      throw const AiParserException('Please enter a schedule or task message.');
    }
    if (!config.hasKey) {
      throw AiParserException(
        '${config.displayName} API key is empty. Add and save a key in Settings.',
      );
    }
    if (config.model.trim().isEmpty) {
      throw AiParserException(
        'Model name is required for ${config.displayName}.',
      );
    }
    if (config.id == AiProviderType.custom && config.baseUrl.trim().isEmpty) {
      throw const AiParserException(
        'Base URL is required for Custom OpenAI-Compatible provider.',
      );
    }

    final referenceNow = now ?? DateTime.now();
    final systemPrompt = _buildSystemPrompt(
      referenceNow,
      existingTasks: existingTasks,
    );

    try {
      final rawReply = await _invokeChat(
        config: config,
        systemPrompt: systemPrompt,
        userPrompt: trimmed,
        jsonMode: true,
        timeout: _requestTimeout,
      );
      return parseJsonResponse(rawReply, fallbackDate: referenceNow);
    } on AiParserException catch (e) {
      if (!_isModelUnavailableError(e.message, statusCode: e.statusCode)) {
        rethrow;
      }
      final liveModels = await _safeFetchModels(config);
      final fallback = liveModels.firstWhere(
        (m) => m != config.model.trim(),
        orElse: () => '',
      );
      if (fallback.isEmpty) rethrow;

      final retryConfig = config.copyWith(model: fallback);
      final rawReply = await _invokeChat(
        config: retryConfig,
        systemPrompt: systemPrompt,
        userPrompt: trimmed,
        jsonMode: true,
        timeout: _requestTimeout,
      );
      final parsed = parseJsonResponse(rawReply, fallbackDate: referenceNow);
      return AiParseResult(
        summary: parsed.summary,
        tasks: parsed.tasks,
        resolvedModel: fallback,
      );
    }
  }

  /// Queries the provider's live `/models` endpoint using the pasted API key.
  Future<List<String>> fetchAvailableModels(AiProviderConfig config) async {
    if (!config.hasKey) {
      throw const AiParserException('Paste an API key first.');
    }
    if (config.id == AiProviderType.custom && config.baseUrl.trim().isEmpty) {
      throw const AiParserException('Enter a base URL first.');
    }

    if (config.id == AiProviderType.gemini) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?pageSize=100',
      );
      final response = await _sendRequest(
        () => _client.get(
          uri,
          headers: {'x-goog-api-key': config.apiKey.trim()},
        ),
        timeout: _testTimeout,
      );
      final decoded = _decodeMap(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errMsg = (decoded?['error'] as Map<String, dynamic>?)?['message']
            ?.toString();
        throw AiParserException(
          errMsg ?? 'Gemini models error (HTTP ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      final rawModels = decoded?['models'] as List<dynamic>? ?? const [];
      final filtered = <String>[];
      for (final item in rawModels.whereType<Map<String, dynamic>>()) {
        final methods = (item['supportedGenerationMethods'] as List<dynamic>? ??
                const [])
            .map((e) => e.toString())
            .toList();
        if (!methods.contains('generateContent')) continue;

        final rawName = item['name']?.toString() ?? '';
        final id = rawName.startsWith('models/')
            ? rawName.substring('models/'.length)
            : rawName;
        if (id.isEmpty || _isNonTextModel(id)) continue;
        filtered.add(id);
      }

      filtered.sort(_compareGeminiModels);
      return filtered.take(_maxReturnedModels).toList();
    }

    final modelsUri = _deriveOpenAiModelsUri(config);
    if (modelsUri == null) {
      throw const AiParserException('Invalid provider endpoint URL.');
    }

    final response = await _sendRequest(
      () => _client.get(modelsUri, headers: _openAiHeaders(config)),
      timeout: _testTimeout,
    );
    final decoded = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final err = decoded?['error'];
      final errMsg = err is Map<String, dynamic>
          ? err['message']?.toString()
          : err?.toString();
      throw AiParserException(
        errMsg ??
            '${config.displayName} models error (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final rawData = decoded?['data'] as List<dynamic>? ?? const [];
    final ids = <String>[];
    for (final item in rawData.whereType<Map<String, dynamic>>()) {
      final id = (item['id']?.toString() ?? '').trim();
      if (id.isEmpty || _isNonTextModel(id)) continue;
      ids.add(id);
    }

    ids.sort((a, b) => _compareOpenAiModels(config.id, a, b));
    return ids.take(_maxReturnedModels).toList();
  }

  /// Verifies the pasted API key and automatically switches to a verified live model
  /// when the configured model is retired or unavailable.
  Future<ApiTestResult> testConnection(AiProviderConfig config) async {
    if (!config.hasKey) {
      return const ApiTestResult(
        ok: false,
        message: 'Paste an API key first.',
      );
    }
    if (config.id == AiProviderType.custom && config.baseUrl.trim().isEmpty) {
      return const ApiTestResult(
        ok: false,
        message: 'Enter a base URL first.',
      );
    }

    List<String> liveModels = const [];
    try {
      liveModels = await fetchAvailableModels(config);
    } on AiParserException catch (e) {
      if (_isAuthError(e.message, statusCode: e.statusCode)) {
        return ApiTestResult(ok: false, message: e.message);
      }
    }

    final configured = config.model.trim();
    final candidates = <String>[];
    if (configured.isNotEmpty &&
        (liveModels.isEmpty || liveModels.contains(configured))) {
      candidates.add(configured);
    }
    for (final m in liveModels) {
      if (!candidates.contains(m)) {
        candidates.add(m);
      }
    }
    if (candidates.isEmpty && configured.isNotEmpty) {
      candidates.add(configured);
    }
    if (candidates.isEmpty) {
      return ApiTestResult(
        ok: false,
        message: 'No compatible text models found for ${config.displayName}.',
        availableModels: liveModels,
      );
    }

    String lastError = 'Connection check failed.';
    final maxAttempts = candidates.length < 3 ? candidates.length : 3;

    for (var i = 0; i < maxAttempts; i++) {
      final candidate = candidates[i];
      try {
        final reply = await _invokeChat(
          config: config.copyWith(model: candidate),
          systemPrompt: 'Reply concisely.',
          userPrompt: 'Reply with OK.',
          jsonMode: false,
          timeout: _testTimeout,
        );
        if (reply.trim().isEmpty) {
          lastError = 'Received an empty response from $candidate.';
          continue;
        }
        final switched = candidate != configured;
        return ApiTestResult(
          ok: true,
          message: switched
              ? 'Connected! Auto-selected live model: $candidate'
              : 'Connected ($candidate)',
          resolvedModel: candidate,
          availableModels: liveModels,
        );
      } on AiParserException catch (e) {
        lastError = e.message;
        if (_isAuthError(e.message, statusCode: e.statusCode)) {
          return ApiTestResult(
            ok: false,
            message: e.message,
            availableModels: liveModels,
          );
        }
        if (_isModelUnavailableError(e.message, statusCode: e.statusCode) ||
            _isQuotaError(e.message, statusCode: e.statusCode)) {
          continue;
        }
        return ApiTestResult(
          ok: false,
          message: e.message,
          availableModels: liveModels,
        );
      } catch (e) {
        lastError = 'Connection error: $e';
      }
    }

    return ApiTestResult(
      ok: false,
      message: lastError,
      availableModels: liveModels,
    );
  }

  Future<List<String>> _safeFetchModels(AiProviderConfig config) async {
    try {
      return await fetchAvailableModels(config);
    } catch (_) {
      return const [];
    }
  }

  Future<String> _invokeChat({
    required AiProviderConfig config,
    required String systemPrompt,
    required String userPrompt,
    required bool jsonMode,
    required Duration timeout,
  }) {
    if (config.id == AiProviderType.gemini) {
      return _callGemini(
        config: config,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        jsonMode: jsonMode,
        timeout: timeout,
      );
    }
    return _callOpenAiCompatible(
      config: config,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      timeout: timeout,
    );
  }

  Future<String> _callGemini({
    required AiProviderConfig config,
    required String systemPrompt,
    required String userPrompt,
    required bool jsonMode,
    required Duration timeout,
  }) async {
    final model = config.model.trim();
    final isGemma = model.toLowerCase().startsWith('gemma');
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    final body = <String, dynamic>{
      if (!isGemma)
        'system_instruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': isGemma ? '$systemPrompt\n\n$userPrompt' : userPrompt,
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        if (jsonMode && !isGemma) 'responseMimeType': 'application/json',
      },
    };

    final response = await _sendRequest(
      () => _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': config.apiKey.trim(),
        },
        body: jsonEncode(body),
      ),
      timeout: timeout,
    );

    final decoded = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errMsg = (decoded?['error'] as Map<String, dynamic>?)?['message']
          ?.toString();
      throw AiParserException(
        errMsg ?? 'Gemini API error (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final candidates = decoded?['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const AiParserException('Gemini returned no candidates.');
    }
    final first = candidates.first as Map<String, dynamic>;
    final content = first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final text = parts
            ?.whereType<Map<String, dynamic>>()
            .map((p) => p['text']?.toString() ?? '')
            .join() ??
        '';
    if (text.trim().isEmpty) {
      throw const AiParserException('Gemini returned an empty reply.');
    }
    return text;
  }

  Map<String, String> _openAiHeaders(AiProviderConfig config) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey.trim()}',
        if (config.id == AiProviderType.openRouter) ...{
          'HTTP-Referer': 'https://htodo.ai',
          'X-Title': 'H-TODO AI',
        },
      };

  Uri? _deriveOpenAiModelsUri(AiProviderConfig config) {
    switch (config.id) {
      case AiProviderType.groq:
        return Uri.parse('https://api.groq.com/openai/v1/models');
      case AiProviderType.grok:
        return Uri.parse('https://api.x.ai/v1/models');
      case AiProviderType.openRouter:
        return Uri.parse('https://openrouter.ai/api/v1/models');
      case AiProviderType.custom:
        final trimmed = config.baseUrl.trim();
        if (trimmed.isEmpty) return null;
        if (trimmed.endsWith('/chat/completions')) {
          return Uri.tryParse(
            trimmed.replaceFirst(RegExp(r'/chat/completions$'), '/models'),
          );
        }
        return Uri.tryParse('${trimmed.replaceAll(RegExp(r'/+$'), '')}/models');
      case AiProviderType.gemini:
        return null;
    }
  }

  Future<String> _callOpenAiCompatible({
    required AiProviderConfig config,
    required String systemPrompt,
    required String userPrompt,
    required Duration timeout,
  }) async {
    final uri = Uri.tryParse(config.baseUrl.trim());
    if (uri == null || !uri.hasScheme) {
      throw const AiParserException('Invalid provider endpoint URL.');
    }

    final body = jsonEncode({
      'model': config.model.trim(),
      'temperature': 0.2,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
    });

    final response = await _sendRequest(
      () => _client.post(uri, headers: _openAiHeaders(config), body: body),
      timeout: timeout,
    );

    final decoded = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final err = decoded?['error'];
      final errMsg = err is Map<String, dynamic>
          ? err['message']?.toString()
          : err?.toString();
      throw AiParserException(
        errMsg ?? '${config.displayName} error (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final choices = decoded?['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw AiParserException('${config.displayName} returned no choices.');
    }
    final first = choices.first as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>?;
    final content = message?['content']?.toString() ?? '';
    if (content.trim().isEmpty) {
      throw AiParserException('${config.displayName} returned an empty reply.');
    }
    return content;
  }

  Future<http.Response> _sendRequest(
    Future<http.Response> Function() requestFn, {
    required Duration timeout,
  }) async {
    try {
      return await requestFn().timeout(timeout);
    } on TimeoutException {
      throw const AiParserException(
        'Request timed out. Check your internet connection or try again.',
      );
    } catch (e) {
      throw AiParserException('Network error: $e');
    }
  }

  static bool _isNonTextModel(String id) {
    final lower = id.toLowerCase();
    const blocked = [
      'embedding',
      'imagen',
      'veo',
      'whisper',
      'tts',
      'playai',
      'guard',
      'safeguard',
      'moderation',
      'aqa',
      'robotics',
      'computer-use',
      'native-audio',
      'imagine',
      'dall-e',
      'flux',
      'voice',
      'audio',
      'video',
      'lyria',
      'deep-research',
    ];
    return blocked.any(lower.contains);
  }

  static int _compareGeminiModels(String a, String b) {
    return _geminiScore(b).compareTo(_geminiScore(a));
  }

  static int _geminiScore(String id) {
    final lower = id.toLowerCase();
    var score = 0;
    if (lower.contains('flash')) score += 1000;
    if (lower.contains('flash-lite') || lower.contains('lite')) score -= 50;
    if (lower.startsWith('gemini')) score += 500;
    if (lower.startsWith('gemma')) score += 100;
    if (lower.contains('pro')) score += 200;
    if (lower.contains('preview') || lower.contains('exp')) score -= 120;
    if (lower.contains('latest')) score += 40;

    final versionMatch = RegExp(r'(\d+)(?:\.(\d+))?').firstMatch(lower);
    if (versionMatch != null) {
      final major = int.tryParse(versionMatch.group(1) ?? '0') ?? 0;
      final minor = int.tryParse(versionMatch.group(2) ?? '0') ?? 0;
      score += major * 40 + minor * 4;
    }
    return score;
  }

  static int _compareOpenAiModels(AiProviderType type, String a, String b) {
    return _openAiScore(type, b).compareTo(_openAiScore(type, a));
  }

  static int _openAiScore(AiProviderType type, String id) {
    final lower = id.toLowerCase();
    var score = 0;
    switch (type) {
      case AiProviderType.openRouter:
        if (lower == 'openrouter/free') score += 2000;
        if (lower.endsWith(':free')) score += 1000;
        if (lower.contains('llama') || lower.contains('gemma')) score += 200;
      case AiProviderType.groq:
        if (lower.contains('llama-3.3')) score += 1200;
        if (lower.contains('llama-3.1-8b')) score += 1000;
        if (lower.contains('gpt-oss')) score += 800;
        if (lower.contains('qwen')) score += 700;
        if (lower.contains('llama')) score += 500;
      case AiProviderType.grok:
        if (lower.startsWith('grok-4')) score += 1000;
        if (lower.contains('non-reasoning')) score += 200;
        if (lower.contains('latest')) score += 100;
      case AiProviderType.custom:
      case AiProviderType.gemini:
        break;
    }
    return score;
  }

  static bool _isModelUnavailableError(String message, {int? statusCode}) {
    if (statusCode == 404) return true;
    final lower = message.toLowerCase();
    return lower.contains('no longer available') ||
        lower.contains('not found') ||
        lower.contains('decommissioned') ||
        lower.contains('deprecated') ||
        lower.contains('not supported') ||
        lower.contains('invalid model') ||
        lower.contains('does not exist') ||
        lower.contains('model_not_found');
  }

  static bool _isAuthError(String message, {int? statusCode}) {
    if (statusCode == 401 || statusCode == 403) return true;
    final lower = message.toLowerCase();
    return lower.contains('api key not valid') ||
        lower.contains('invalid api key') ||
        lower.contains('unauthorized') ||
        lower.contains('invalid_api_key') ||
        lower.contains('permission denied');
  }

  static bool _isQuotaError(String message, {int? statusCode}) {
    if (statusCode == 429) return true;
    final lower = message.toLowerCase();
    return lower.contains('quota') ||
        lower.contains('rate limit') ||
        lower.contains('resource_exhausted');
  }

  static Map<String, dynamic>? _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static String _buildSystemPrompt(
    DateTime now, {
    List<TaskItem> existingTasks = const [],
  }) {
    final today = DateFormat('yyyy-MM-dd (EEEE)').format(now);
    final pendingExisting =
        existingTasks.where((t) => !t.isCompleted).take(25).toList();
    final existingBlock = pendingExisting.isEmpty
        ? ''
        : '''

Existing pending tasks already saved by the user:
${pendingExisting.map((t) => '- ${t.title} | ${t.courseOrCategory} | ${t.dateKey} | ${t.formattedDueTime ?? 'No specific time'}').join('\n')}
If the user repeats or adds details to one of the existing tasks above (same task on the same date/time), keep the exact same "title" and "courseOrCategory" so the app can merge updates without duplicating it.
''';
    return '''
You are H-TODO AI, an academic and personal schedule extraction assistant.
Current local date: $today.

Extract EVERY actionable task, assignment, class test, exam, lab, or deadline from the user's message.
The user may write in Bengali (বাংলা), English, or Banglish, and may include Bengali numerals (০-৯) or Bengali dates (e.g. ২১ নভেম্বর ২০২৬).$existingBlock

Rules:
1. Convert all dates (including Bengali numerals/months or relative dates like tomorrow/next Sunday) into strict "YYYY-MM-DD" format.
2. Extract dueTime in 24-hour "HH:mm" format if explicitly mentioned (e.g. "11:59 PM" -> "23:59"), otherwise null.
3. Preserve the course or category clearly in "courseOrCategory" (e.g. "IRE 415 – Computer Vision").
4. Split syllabus bullets, sub-topics, or checklist items into "subtasks" as clean, readable strings in their original language (Bengali/English). Do not omit sub-points.
5. Keep full extra context or instructions in "notes".
6. Choose "type" from: "assignment", "classTest", "exam", "lab", "meeting", "task".
7. Choose "priority" from: "high", "medium", "low".
8. Write a concise 1-2 sentence "summary" in the same primary language as the user's message.

Respond with ONLY a valid JSON object (no markdown fences, no commentary) matching this exact schema:
{
  "summary": "string",
  "tasks": [
    {
      "title": "string",
      "courseOrCategory": "string",
      "type": "assignment|classTest|exam|lab|meeting|task",
      "dueDate": "YYYY-MM-DD",
      "dueTime": "HH:mm or null",
      "priority": "high|medium|low",
      "notes": "string",
      "subtasks": ["string"]
    }
  ]
}
''';
  }

  /// Parses raw model output (optionally wrapped in markdown code fences) into [AiParseResult].
  static AiParseResult parseJsonResponse(
    String rawText, {
    required DateTime fallbackDate,
  }) {
    final jsonString = _extractJsonObject(rawText);
    if (jsonString == null) {
      throw const AiParserException(
        'AI response did not contain a valid JSON schedule.',
      );
    }

    final Map<String, dynamic> root;
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw const AiParserException('AI response root is not a JSON object.');
      }
      root = decoded;
    } catch (e) {
      throw AiParserException('Could not parse AI JSON response: $e');
    }

    final rawTasks = root['tasks'];
    if (rawTasks is! List || rawTasks.isEmpty) {
      throw const AiParserException(
        'No tasks or dates could be found in that message. Try adding a clearer date or task.',
      );
    }

    final now = DateTime.now();
    final tasks = <TaskItem>[];

    for (final item in rawTasks) {
      if (item is! Map<String, dynamic>) continue;
      final title = (item['title']?.toString() ?? '').trim();
      if (title.isEmpty) continue;

      final parsedDate = _parseDate(
            item['dueDate']?.toString(),
            fallbackDate: fallbackDate,
          ) ??
          DateTime(fallbackDate.year, fallbackDate.month, fallbackDate.day);

      final parsedTime = _parseTime(item['dueTime']?.toString());

      final rawSubtasks = item['subtasks'] as List<dynamic>? ?? const [];
      final subtasks = rawSubtasks
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .map((s) => SubTaskItem(id: _uuid.v4(), title: s))
          .toList();

      final taskId = _uuid.v4();
      tasks.add(
        TaskItem(
          id: taskId,
          notificationBaseId: TaskItem.stableBaseIdFromUuid(taskId),
          title: title,
          courseOrCategory: (item['courseOrCategory']?.toString() ?? '').trim(),
          type: TaskType.fromString(item['type']?.toString()),
          priority: TaskPriority.fromString(item['priority']?.toString()),
          dueDate: parsedDate,
          dueHour: parsedTime?.$1,
          dueMinute: parsedTime?.$2,
          notes: (item['notes']?.toString() ?? '').trim(),
          subtasks: subtasks,
          createdAt: now,
        ),
      );
    }

    if (tasks.isEmpty) {
      throw const AiParserException(
        'AI returned empty task titles. Please try rephrasing the schedule.',
      );
    }

    final summary = (root['summary']?.toString() ?? '').trim();
    return AiParseResult(
      summary: summary.isNotEmpty
          ? summary
          : 'Added ${tasks.length} scheduled task(s).',
      tasks: tasks,
    );
  }

  static String? _extractJsonObject(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    return cleaned.substring(start, end + 1);
  }

  static String _normalizeDigits(String input) {
    const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    var out = input;
    for (var i = 0; i < bn.length; i++) {
      out = out.replaceAll(bn[i], '$i');
    }
    return out;
  }

  static DateTime? _parseDate(
    String? raw, {
    required DateTime fallbackDate,
  }) {
    if (raw == null || raw.trim().isEmpty) return null;
    final norm = _normalizeDigits(raw.trim());

    final iso = DateTime.tryParse(norm);
    if (iso != null) {
      return DateTime(iso.year, iso.month, iso.day);
    }

    final dmyMatch = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$')
        .firstMatch(norm);
    if (dmyMatch != null) {
      final d = int.tryParse(dmyMatch.group(1)!);
      final m = int.tryParse(dmyMatch.group(2)!);
      final y = int.tryParse(dmyMatch.group(3)!);
      if (d != null && m != null && y != null) {
        return DateTime(y, m, d);
      }
    }

    return DateTime(fallbackDate.year, fallbackDate.month, fallbackDate.day);
  }

  static (int, int)? _parseTime(String? raw) {
    if (raw == null) return null;
    final norm = _normalizeDigits(raw.trim()).toLowerCase();
    if (norm.isEmpty || norm == 'null') return null;

    final match = RegExp(r'^(\d{1,2}):(\d{2})(?:\s*(am|pm))?$').firstMatch(norm);
    if (match == null) return null;

    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final meridiem = match.group(3);
    if (hour == null || minute == null || minute < 0 || minute > 59) {
      return null;
    }

    if (meridiem == 'pm' && hour < 12) hour += 12;
    if (meridiem == 'am' && hour == 12) hour = 0;
    if (hour < 0 || hour > 23) return null;

    return (hour, minute);
  }
}
