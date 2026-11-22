import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_chat_action.dart';
import '../models/ai_provider_config.dart';
import '../models/chat_message.dart';
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

  /// Processes any natural-language To-Do command (add, complete, delete,
  /// reschedule, update syllabus/notes, subtask toggle, or task query) in
  /// any language while declining non-To-Do ChatGPT prompts.
  Future<AiAssistantResponse> processChatCommand(
    String userMessage,
    AiProviderConfig config, {
    DateTime? now,
    List<TaskItem> existingTasks = const [],
    List<ChatMessage> recentMessages = const [],
  }) async {
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) {
      throw const AiParserException('Please enter a message or task command.');
    }
    if (!config.hasKey) {
      throw AiParserException(
        '${config.displayName} API key is empty. Add and save a key in Profile.',
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
    final systemPrompt = _buildAssistantSystemPrompt(
      referenceNow,
      existingTasks: existingTasks,
      recentMessages: recentMessages,
    );

    try {
      final rawReply = await _invokeChat(
        config: config,
        systemPrompt: systemPrompt,
        userPrompt: trimmed,
        jsonMode: true,
        timeout: _requestTimeout,
      );
      return parseAssistantResponse(rawReply, fallbackDate: referenceNow);
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
      final parsed = parseAssistantResponse(
        rawReply,
        fallbackDate: referenceNow,
      );
      return AiAssistantResponse(
        reply: parsed.reply,
        actions: parsed.actions,
        referencedTaskIds: parsed.referencedTaskIds,
        offTopic: parsed.offTopic,
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

  static String _buildAssistantSystemPrompt(
    DateTime now, {
    List<TaskItem> existingTasks = const [],
    List<ChatMessage> recentMessages = const [],
  }) {
    final today = DateFormat('yyyy-MM-dd (EEEE), HH:mm').format(now);

    final seriesGroups = <String, List<TaskItem>>{};
    final standaloneTasks = <TaskItem>[];
    for (final t in existingTasks) {
      final sid = t.seriesId?.trim();
      if (sid != null && sid.isNotEmpty) {
        seriesGroups.putIfAbsent(sid, () => []).add(t);
      } else {
        standaloneTasks.add(t);
      }
    }

    final seriesLines = <String>[];
    for (final entry in seriesGroups.entries) {
      if (entry.value.length < 2) {
        standaloneTasks.addAll(entry.value);
        continue;
      }
      final group = List<TaskItem>.from(entry.value)
        ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
      final first = group.first;
      final last = group.last;
      final pendingCount = group.where((t) => !t.isCompleted).length;
      final doneCount = group.length - pendingCount;
      final timesSet = group
          .where((t) => t.hasDueTime)
          .map(
            (t) =>
                '${t.dueHour!.toString().padLeft(2, '0')}:${t.dueMinute!.toString().padLeft(2, '0')}',
          )
          .toSet()
          .toList()
        ..sort();
      final timesLabel = timesSet.isEmpty ? 'default' : timesSet.join(', ');
      seriesLines.add(
        '- SERIES seriesId=${entry.key} | title="${first.title}" | '
        'course="${first.courseOrCategory}" | type=${first.type.name} | '
        'times=[$timesLabel] | pending=$pendingCount done=$doneCount | '
        'dates=${first.dateKey}..${last.dateKey}',
      );
    }

    final pendingFirst = [
      ...standaloneTasks.where((t) => !t.isCompleted),
      ...standaloneTasks.where((t) => t.isCompleted).take(10),
    ].take(40).toList();

    final standaloneLines = pendingFirst.map((t) {
      final subs = t.subtasks.isEmpty
          ? 'none'
          : t.subtasks
              .map((s) => '${s.isCompleted ? "[x]" : "[ ]"} ${s.title}')
              .join('; ');
      final dueTime = t.formattedDueTime ?? 'none';
      return '- id=${t.id} | status=${t.isCompleted ? "DONE" : "PENDING"} | '
          'title="${t.title}" | course="${t.courseOrCategory}" | '
          'type=${t.type.name} | due=${t.dateKey} $dueTime | '
          'priority=${t.priority.name} | subtasks=[$subs]';
    }).toList();

    final allLines = [...seriesLines, ...standaloneLines];
    final tasksBlock =
        allLines.isEmpty ? 'No saved tasks yet.' : allLines.join('\n');

    final historyList =
        recentMessages.where((m) => !m.isError).toList();
    final recentSlice = historyList.length <= 6
        ? historyList
        : historyList.sublist(historyList.length - 6);
    final historyBlock = recentSlice.isEmpty
        ? ''
        : '''

Recent chat context (oldest to newest, for resolving pronouns like "it", "that", "eta", "এটা"):
${recentSlice.map((m) {
            final roleLabel = m.role == ChatRole.user ? 'User' : 'Assistant';
            final snippet = m.text.replaceAll('\n', ' ').trim();
            final short = snippet.length > 220
                ? '${snippet.substring(0, 220)}...'
                : snippet;
            return '$roleLabel: $short';
          }).join('\n')}
''';

    return '''
You are H-TODO AI, a dedicated To-Do, Academic Schedule, Reminder, and Syllabus Assistant.
Current local date & time: $today.

STRICT DOMAIN BOUNDARY:
- You ONLY manage the user's tasks, assignments, class tests, exams, labs, meetings, syllabi/checklists, deadlines, and reminders, or answer questions about their saved task list.
- If the user asks anything unrelated (general ChatGPT trivia, programming help, stories, math homework, weather, chitchat), DO NOT answer that request. Set "offTopic": true, "actions": [], "referencedTaskIds": [], and write a polite 1-sentence refusal in the user's language stating that you only manage H-TODO AI tasks and schedules.

MULTILINGUAL RULES:
- Understand the user's message in ANY language (English, Bengali / বাংলা, Banglish, Hindi, Arabic, Spanish, etc.), including non-Latin digits (e.g. ০-৯) and relative dates (tomorrow, next Monday, 2 days later, কাল, আগামী শুক্রবার).
- ALWAYS write "reply" clearly and concisely (1-3 sentences, no markdown code blocks) in the SAME primary language the user wrote in.
- Convert all dates to "YYYY-MM-DD" and times to 24-hour "HH:mm" (or null).

ACTIONS YOU CAN PERFORM:
- "add": Create 1 to 5 individual non-repeating tasks from notices or commands. If an identical existing task already exists on the same date/time and the user is repeating a notice, reuse its exact title & courseOrCategory so duplicate protection can merge updates cleanly.
- "add_recurring": ALWAYS use 1 single "add_recurring" action (NEVER emit >5 individual "add" actions) for ANY repeating, daily, every-N-days, weekly, or monthly schedule (e.g., next 40 days, next 1 year, twice a day, every Mon/Wed/Fri, 1st of every month). Set "title", "courseOrCategory", "taskType", "priority", "notes", "addSubtasks", "frequency" ("daily"|"every_n_days"|"weekly"|"monthly"), "interval" (default 1), "startDate" ("YYYY-MM-DD"), "endDate" (optional), "durationDays" (optional int, e.g. 40), "durationMonths" (optional int, e.g. 6 or 12 for 1 year), "maxOccurrences" (optional int), "weekdays" (optional [1..7], 1=Mon..7=Sun), "dayOfMonth" (optional 1..31), "times" (array of 24h "HH:mm", e.g. ["08:00", "20:00"], or [] for default alerts).
- "complete" / "uncomplete": Mark a single existing task completed or pending.
- "delete": Remove/delete a single existing task.
- "reschedule": Change due date and/or due time of a single existing task. Leave "dueTime" omitted if user only moves the date, or set "clearDueTime": true if removing time.
- "update": Change a single task's "title", "courseOrCategory", "type", "priority", "notes", or "addSubtasks".
- "bulk_delete", "bulk_reschedule", "bulk_update", "bulk_complete", "bulk_uncomplete": ALWAYS use 1 single bulk action when deleting, cancelling, completing, rescheduling, or updating a SERIES, a MONTH or DATE RANGE ("this month", "December", "next 7 days"), or ALL matching tasks! Include "filter": { "seriesId": "string or null", "titleQuery": "string or null", "courseQuery": "string or null", "taskType": "enum or null", "dateFrom": "YYYY-MM-DD or null", "dateTo": "YYYY-MM-DD or null", "matchTime": "HH:mm or null", "completedOnly": false, "pendingOnly": false, "confirmAll": false } (include only relevant filters). For "bulk_reschedule"/"bulk_update", also pass "shiftDays" (int, e.g. 2 to postpone 2 days) and/or "dueDate", "dueTime", "clearDueTime", "title", "courseOrCategory", "taskType", "priority", "notes", "addSubtasks". Only set "confirmAll": true if user explicitly confirms removing/updating ALL tasks.
- "complete_subtask" / "uncomplete_subtask": Check or uncheck a syllabus item ("subtaskTitle") inside an existing task.
- "update_reminder_settings": Only when the user asks to change the global default reminder schedule (defaults are 16:00 day-before & 22:00 due-day) or pause/enable notifications globally. Provide "dayBeforeTime" ("HH:mm"), "endOfDayTime" ("HH:mm"), and/or "remindersEnabled" (true/false).
- Queries ("What is due tomorrow?", "Which tasks are pending?", "কাল কী আছে?"): Set "actions": [], put matching IDs in "referencedTaskIds", and summarize concisely in "reply".

AMBIGUITY SAFETY:
- Match existing tasks using exact "taskId", or series using exact "seriesId" from the list below.
- If a single-task delete/complete/reschedule could refer to 2+ unrelated tasks and user did NOT ask for bulk action, set "actions": [] and ask a short clarifying question.

Current saved tasks & repeating series:
$tasksBlock$historyBlock

Respond with ONLY a valid JSON object matching this schema:
{
  "reply": "string in the user's language",
  "offTopic": false,
  "referencedTaskIds": ["existing-task-id"],
  "actions": [
    {
      "type": "add|add_recurring|complete|uncomplete|delete|reschedule|update|bulk_delete|bulk_reschedule|bulk_update|bulk_complete|bulk_uncomplete|complete_subtask|uncomplete_subtask|update_reminder_settings",
      "taskId": "exact existing id or null",
      "taskQuery": "task title fallback if needed",
      "subtaskTitle": "subtask name for subtask actions",
      "dueDate": "YYYY-MM-DD",
      "dueTime": "HH:mm or null",
      "clearDueTime": false,
      "title": "string",
      "courseOrCategory": "string",
      "taskType": "assignment|classTest|exam|lab|meeting|task",
      "priority": "high|medium|low",
      "notes": "string",
      "addSubtasks": ["string"],
      "dayBeforeTime": "HH:mm",
      "endOfDayTime": "HH:mm",
      "remindersEnabled": true,
      "frequency": "daily|every_n_days|weekly|monthly",
      "interval": 1,
      "startDate": "YYYY-MM-DD",
      "endDate": "YYYY-MM-DD",
      "durationDays": 40,
      "durationMonths": 12,
      "maxOccurrences": 80,
      "weekdays": [1, 3, 5],
      "dayOfMonth": 1,
      "times": ["08:00", "20:00"],
      "shiftDays": 0,
      "filter": {
        "seriesId": "exact seriesId or null",
        "titleQuery": "string or null",
        "courseQuery": "string or null",
        "taskType": "assignment|classTest|exam|lab|meeting|task or null",
        "dateFrom": "YYYY-MM-DD or null",
        "dateTo": "YYYY-MM-DD or null",
        "matchTime": "HH:mm or null",
        "completedOnly": false,
        "pendingOnly": false,
        "confirmAll": false
      }
    }
  ]
}
''';
  }

  /// Parses raw model output (single or multi-action JSON) into [AiAssistantResponse].
  static AiAssistantResponse parseAssistantResponse(
    String rawText, {
    required DateTime fallbackDate,
  }) {
    final jsonString = _extractJsonObject(rawText);
    if (jsonString == null) {
      throw const AiParserException(
        'AI response did not contain a valid JSON command.',
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

    final offTopic = root['offTopic'] == true;
    var reply = (root['reply'] ?? root['summary'] ?? '').toString().trim();

    final referencedIds = (root['referencedTaskIds'] as List<dynamic>? ?? const [])
        .map((e) => e.toString().trim())
        .where((id) => id.isNotEmpty)
        .toList();

    final parsedActions = <AiTaskAction>[];
    final rawActions = root['actions'];
    final now = DateTime.now();

    if (rawActions is List && rawActions.isNotEmpty) {
      for (final rawItem in rawActions) {
        if (rawItem is! Map) continue;
        final item = Map<String, dynamic>.from(rawItem);
        final actionType = AiActionType.fromString(item['type']?.toString());
        if (actionType == null) continue;

        if (actionType == AiActionType.add) {
          final taskMap = item['task'] is Map
              ? Map<String, dynamic>.from(item['task'] as Map)
              : item;
          final title = (taskMap['title']?.toString() ?? '').trim();
          if (title.isEmpty) continue;

          final parsedDate = _parseDate(
                taskMap['dueDate']?.toString(),
                fallbackDate: fallbackDate,
              ) ??
              DateTime(fallbackDate.year, fallbackDate.month, fallbackDate.day);
          final parsedTime = _parseTime(taskMap['dueTime']?.toString());
          final rawSubs = (taskMap['subtasks'] ??
                  taskMap['addSubtasks'] ??
                  const <dynamic>[]) as List<dynamic>? ??
              const [];
          final subtasks = rawSubs
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .map((s) => SubTaskItem(id: _uuid.v4(), title: s))
              .toList();

          final taskId = _uuid.v4();
          final newTask = TaskItem(
            id: taskId,
            notificationBaseId: TaskItem.stableBaseIdFromUuid(taskId),
            title: title,
            courseOrCategory:
                (taskMap['courseOrCategory']?.toString() ?? '').trim(),
            type: TaskType.fromString(
              (taskMap['taskType'] ?? taskMap['type'])?.toString(),
            ),
            priority: TaskPriority.fromString(taskMap['priority']?.toString()),
            dueDate: parsedDate,
            dueHour: parsedTime?.$1,
            dueMinute: parsedTime?.$2,
            notes: (taskMap['notes']?.toString() ?? '').trim(),
            subtasks: subtasks,
            createdAt: now,
          );
          parsedActions.add(
            AiTaskAction(type: AiActionType.add, newTask: newTask),
          );
        } else if (actionType == AiActionType.addRecurring) {
          final specMap = item['rule'] is Map
              ? Map<String, dynamic>.from(item['rule'] as Map)
              : (item['task'] is Map
                  ? Map<String, dynamic>.from(item['task'] as Map)
                  : item);
          final title = _nullIfBlank(
                (specMap['title'] ?? item['title'])?.toString(),
              ) ??
              '';
          if (title.isEmpty) continue;

          final startDate = _tryParseStrictDate(
                (specMap['startDate'] ?? specMap['dueDate'] ?? item['startDate'])
                    ?.toString(),
              ) ??
              DateTime(fallbackDate.year, fallbackDate.month, fallbackDate.day);
          final endDate = _tryParseStrictDate(
            (specMap['endDate'] ?? item['endDate'])?.toString(),
          );
          final times = _parseTimeList(specMap['times'] ?? item['times']);
          if (times.isEmpty) {
            final singleTime = _parseTime(
              (specMap['dueTime'] ?? specMap['time'] ?? item['dueTime'])
                  ?.toString(),
            );
            if (singleTime != null) {
              times.add(singleTime);
            }
          }
          final rawSubs = (specMap['subtasks'] ??
                  specMap['addSubtasks'] ??
                  item['addSubtasks'] ??
                  const <dynamic>[]) as List<dynamic>? ??
              const [];
          final subtasks = rawSubs
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();

          parsedActions.add(
            AiTaskAction(
              type: AiActionType.addRecurring,
              recurringSpec: RecurringTaskSpec(
                title: title,
                courseOrCategory:
                    _nullIfBlank((specMap['courseOrCategory'] ?? item['courseOrCategory'])?.toString()) ?? '',
                taskType: TaskType.fromString(
                  (specMap['taskType'] ?? item['taskType'])?.toString(),
                ),
                priority: TaskPriority.fromString(
                  (specMap['priority'] ?? item['priority'])?.toString(),
                ),
                notes: _nullIfBlank((specMap['notes'] ?? item['notes'])?.toString()) ?? '',
                subtasks: subtasks,
                frequency: RecurrenceFrequency.fromString(
                  (specMap['frequency'] ?? item['frequency'])?.toString(),
                ),
                interval: _parseInt(specMap['interval'] ?? item['interval']) ?? 1,
                startDate: startDate,
                endDate: endDate,
                durationDays: _parseInt(
                  specMap['durationDays'] ?? item['durationDays'],
                ),
                durationMonths: _parseInt(
                  specMap['durationMonths'] ?? item['durationMonths'],
                ),
                maxOccurrences: _parseInt(
                  specMap['maxOccurrences'] ?? item['maxOccurrences'],
                ),
                weekdays: _parseWeekdays(
                  specMap['weekdays'] ?? item['weekdays'],
                ),
                dayOfMonth: _parseInt(
                  specMap['dayOfMonth'] ?? item['dayOfMonth'],
                ),
                times: times,
              ),
            ),
          );
        } else if (actionType == AiActionType.bulkDelete ||
            actionType == AiActionType.bulkReschedule ||
            actionType == AiActionType.bulkUpdate ||
            actionType == AiActionType.bulkComplete ||
            actionType == AiActionType.bulkUncomplete) {
          final filter = _parseBulkFilter(item);
          final parsedDue = _tryParseStrictDate(
            (item['newDueDate'] ?? item['dueDate'])?.toString(),
          );
          final parsedTime = _parseTime(
            (item['newDueTime'] ?? item['dueTime'])?.toString(),
          );
          final clearDueTime = item['clearDueTime'] == true;
          final rawNewTitle = _nullIfBlank(
            (item['newTitle'] ?? item['title'])?.toString(),
          );
          final rawNewCourse = _nullIfBlank(
            (item['newCourseOrCategory'] ?? item['courseOrCategory'])
                ?.toString(),
          );
          final rawTypeStr = _nullIfBlank(
            (item['newTaskType'] ?? item['taskType'])?.toString(),
          );
          final rawPriorityStr = _nullIfBlank(
            (item['newPriority'] ?? item['priority'])?.toString(),
          );
          final rawNotes = _nullIfBlank(
            (item['newNotes'] ?? item['notes'])?.toString(),
          );
          final rawSubList = (item['addSubtasks'] ??
                  item['subtasks'] ??
                  const <dynamic>[]) as List<dynamic>? ??
              const [];
          final addSubs = rawSubList
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();

          parsedActions.add(
            AiTaskAction(
              type: actionType,
              bulkFilter: filter,
              shiftDays: _parseInt(item['shiftDays']),
              newDueDate: parsedDue,
              newDueHour: parsedTime?.$1,
              newDueMinute: parsedTime?.$2,
              clearDueTime: clearDueTime,
              newTitle: rawNewTitle,
              newCourseOrCategory: rawNewCourse,
              newTaskType:
                  rawTypeStr != null ? TaskType.fromString(rawTypeStr) : null,
              newPriority: rawPriorityStr != null
                  ? TaskPriority.fromString(rawPriorityStr)
                  : null,
              newNotes: rawNotes,
              addSubtasks: addSubs,
            ),
          );
        } else if (actionType == AiActionType.updateReminderSettings) {
          final dayBeforeTime = _parseTime(
            (item['dayBeforeTime'] ?? item['day_before_time'])?.toString(),
          );
          final endOfDayTime = _parseTime(
            (item['endOfDayTime'] ?? item['end_of_day_time'])?.toString(),
          );
          final enabledRaw = item['remindersEnabled'] ?? item['enabled'];
          final enabledBool = enabledRaw is bool ? enabledRaw : null;
          if (dayBeforeTime != null ||
              endOfDayTime != null ||
              enabledBool != null) {
            parsedActions.add(
              AiTaskAction(
                type: AiActionType.updateReminderSettings,
                newDayBeforeTime: dayBeforeTime,
                newEndOfDayTime: endOfDayTime,
                remindersEnabled: enabledBool,
              ),
            );
          }
        } else {
          final targetId = _nullIfBlank(item['taskId']?.toString());
          final query = _nullIfBlank(
            (item['taskQuery'] ?? item['title'])?.toString(),
          );
          final parsedDue = _tryParseStrictDate(
            (item['newDueDate'] ?? item['dueDate'])?.toString(),
          );
          final parsedTime = _parseTime(
            (item['newDueTime'] ?? item['dueTime'])?.toString(),
          );
          final clearDueTime = item['clearDueTime'] == true;
          final rawNewTitle = _nullIfBlank(
            (item['newTitle'] ??
                    (item['taskQuery'] != null ? item['title'] : null))
                ?.toString(),
          );
          final rawNewCourse = _nullIfBlank(
            (item['newCourseOrCategory'] ?? item['courseOrCategory'])
                ?.toString(),
          );
          final rawTypeStr = _nullIfBlank(
            (item['newTaskType'] ?? item['taskType'])?.toString(),
          );
          final rawPriorityStr = _nullIfBlank(
            (item['newPriority'] ?? item['priority'])?.toString(),
          );
          final rawNotes = _nullIfBlank(
            (item['newNotes'] ?? item['notes'])?.toString(),
          );
          final rawSubList = (item['addSubtasks'] ??
                  item['subtasks'] ??
                  const <dynamic>[]) as List<dynamic>? ??
              const [];
          final addSubs = rawSubList
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();
          final subtaskTitle = _nullIfBlank(item['subtaskTitle']?.toString());

          parsedActions.add(
            AiTaskAction(
              type: actionType,
              taskId: targetId,
              taskQuery: query,
              newDueDate: parsedDue,
              newDueHour: parsedTime?.$1,
              newDueMinute: parsedTime?.$2,
              clearDueTime: clearDueTime,
              newTitle: rawNewTitle,
              newCourseOrCategory: rawNewCourse,
              newTaskType:
                  rawTypeStr != null ? TaskType.fromString(rawTypeStr) : null,
              newPriority: rawPriorityStr != null
                  ? TaskPriority.fromString(rawPriorityStr)
                  : null,
              newNotes: rawNotes,
              addSubtasks: addSubs,
              subtaskTitle: subtaskTitle,
            ),
          );
        }
      }
    } else if (root['tasks'] is List && (root['tasks'] as List).isNotEmpty) {
      // Legacy fallback if a model returns the older `tasks`-only schema.
      final legacy = parseJsonResponse(rawText, fallbackDate: fallbackDate);
      for (final task in legacy.tasks) {
        parsedActions.add(AiTaskAction(type: AiActionType.add, newTask: task));
      }
      if (reply.isEmpty) {
        reply = legacy.summary;
      }
    }

    if (reply.isEmpty && parsedActions.isEmpty) {
      throw const AiParserException(
        'Could not understand that command. Try mentioning a task name, date, or action.',
      );
    }

    if (reply.isEmpty && parsedActions.isNotEmpty) {
      reply = 'Updated ${parsedActions.length} task action(s).';
    }

    return AiAssistantResponse(
      reply: reply,
      actions: parsedActions,
      referencedTaskIds: referencedIds,
      offTopic: offTopic,
    );
  }

  static BulkTaskFilter _parseBulkFilter(Map<String, dynamic> item) {
    final filterMap = item['filter'] is Map
        ? Map<String, dynamic>.from(item['filter'] as Map)
        : const <String, dynamic>{};

    final seriesId = _nullIfBlank(
      (filterMap['seriesId'] ?? item['seriesId'])?.toString(),
    );
    final titleQuery = _nullIfBlank(
      (filterMap['titleQuery'] ??
              filterMap['title'] ??
              item['titleQuery'] ??
              item['taskQuery'])
          ?.toString(),
    );
    final courseQuery = _nullIfBlank(
      (filterMap['courseQuery'] ??
              filterMap['courseOrCategory'] ??
              item['courseQuery'])
          ?.toString(),
    );
    final filterTypeStr = _nullIfBlank(
      (filterMap['taskType'] ?? filterMap['type'] ?? item['taskTypeFilter'])
          ?.toString(),
    );
    final dateFrom = _tryParseStrictDate(
      (filterMap['dateFrom'] ?? item['dateFrom'])?.toString(),
    );
    final dateTo = _tryParseStrictDate(
      (filterMap['dateTo'] ?? item['dateTo'])?.toString(),
    );
    final matchTime = _parseTime(
      (filterMap['matchTime'] ?? item['matchTime'])?.toString(),
    );
    final completedOnly =
        filterMap['completedOnly'] == true || item['completedOnly'] == true;
    final pendingOnly =
        filterMap['pendingOnly'] == true || item['pendingOnly'] == true;
    final confirmAll =
        filterMap['confirmAll'] == true || item['confirmAll'] == true;

    return BulkTaskFilter(
      seriesId: seriesId,
      titleQuery: titleQuery,
      courseQuery: courseQuery,
      taskType:
          filterTypeStr != null ? TaskType.fromString(filterTypeStr) : null,
      dateFrom: dateFrom,
      dateTo: dateTo,
      matchTime: matchTime,
      completedOnly: completedOnly,
      pendingOnly: pendingOnly,
      confirmAll: confirmAll,
    );
  }

  static int? _parseInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    final norm = _normalizeDigits(raw.toString().trim());
    return int.tryParse(norm);
  }

  static List<(int, int)> _parseTimeList(dynamic raw) {
    final result = <(int, int)>[];
    if (raw is List) {
      for (final item in raw) {
        final t = _parseTime(item?.toString());
        if (t != null) result.add(t);
      }
    } else if (raw is String) {
      for (final part in raw.split(',')) {
        final t = _parseTime(part);
        if (t != null) result.add(t);
      }
    }
    return result;
  }

  static List<int> _parseWeekdays(dynamic raw) {
    if (raw is! List) return const [];
    final out = <int>[];
    for (final item in raw) {
      final numVal = _parseInt(item);
      if (numVal != null && numVal >= 1 && numVal <= 7) {
        if (!out.contains(numVal)) out.add(numVal);
        continue;
      }
      final name = (item?.toString() ?? '').trim().toLowerCase();
      final mapped = switch (name) {
        'mon' || 'monday' || 'সোম' || 'সোমবার' || 'som' || 'sombar' => 1,
        'tue' ||
        'tuesday' ||
        'মঙ্গল' ||
        'মঙ্গলবার' ||
        'mongol' ||
        'mongolbar' =>
          2,
        'wed' ||
        'wednesday' ||
        'বুধ' ||
        'বুধবার' ||
        'budh' ||
        'budhbar' =>
          3,
        'thu' ||
        'thursday' ||
        'বৃহস্পতি' ||
        'বৃহস্পতিবার' ||
        'brihospoti' =>
          4,
        'fri' ||
        'friday' ||
        'শুক্র' ||
        'শুক্রবার' ||
        'shukro' ||
        'shukrobar' =>
          5,
        'sat' || 'saturday' || 'শনি' || 'শনিবার' || 'shoni' || 'shonibar' => 6,
        'sun' || 'sunday' || 'রবি' || 'রবিবার' || 'robi' || 'robibar' => 7,
        _ => null,
      };
      if (mapped != null && !out.contains(mapped)) {
        out.add(mapped);
      }
    }
    return out;
  }

  static String? _nullIfBlank(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;
    return trimmed;
  }

  static DateTime? _tryParseStrictDate(String? raw) {
    final cleaned = _nullIfBlank(raw);
    if (cleaned == null) return null;
    final norm = _normalizeDigits(cleaned);
    final iso = DateTime.tryParse(norm);
    if (iso != null) {
      return DateTime(iso.year, iso.month, iso.day);
    }
    final dmyMatch =
        RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$').firstMatch(norm);
    if (dmyMatch != null) {
      final d = int.tryParse(dmyMatch.group(1)!);
      final m = int.tryParse(dmyMatch.group(2)!);
      final y = int.tryParse(dmyMatch.group(3)!);
      if (d != null && m != null && y != null) {
        return DateTime(y, m, d);
      }
    }
    return null;
  }
}
