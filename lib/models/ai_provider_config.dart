import 'package:flutter/foundation.dart';

/// Supported AI schedule-parsing providers.
enum AiProviderType {
  gemini,
  groq,
  grok,
  openRouter,
  custom;

  static AiProviderType fromString(String? raw) {
    return AiProviderType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AiProviderType.gemini,
    );
  }
}

/// Configuration for a single AI provider entry in Settings.
@immutable
class AiProviderConfig {
  const AiProviderConfig({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.apiKey,
    required this.model,
    required this.baseUrl,
    required this.suggestedModels,
    required this.hintText,
  });

  final AiProviderType id;
  final String displayName;
  final String subtitle;
  final String apiKey;
  final String model;
  final String baseUrl;
  final List<String> suggestedModels;
  final String hintText;

  /// Parses one or more backup API keys separated by commas, semicolons, or new lines.
  List<String> get apiKeys {
    final seen = <String>{};
    final out = <String>[];
    for (final part in apiKey.split(RegExp(r'[\n,;]+'))) {
      final k = part.trim();
      if (k.isNotEmpty && seen.add(k)) {
        out.add(k);
      }
    }
    return out;
  }

  String get primaryApiKey {
    final keys = apiKeys;
    return keys.isEmpty ? '' : keys.first;
  }

  bool get hasKey => apiKeys.isNotEmpty;

  AiProviderConfig copyWith({
    String? apiKey,
    String? model,
    String? baseUrl,
  }) {
    return AiProviderConfig(
      id: id,
      displayName: displayName,
      subtitle: subtitle,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      baseUrl: baseUrl ?? this.baseUrl,
      suggestedModels: suggestedModels,
      hintText: hintText,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id.name,
        'apiKey': apiKey,
        'model': model,
        'baseUrl': baseUrl,
      };

  /// Merges persisted user edits onto canonical provider metadata defaults.
  AiProviderConfig mergePersisted(Map<String, dynamic> json) {
    var persistedModel = (json['model']?.toString().trim() ?? '');
    if (persistedModel.isEmpty || _isRetiredDefault(id, persistedModel)) {
      persistedModel = model;
    }
    return copyWith(
      apiKey: json['apiKey']?.toString() ?? apiKey,
      model: persistedModel,
      baseUrl: (json['baseUrl']?.toString().trim().isNotEmpty ?? false)
          ? json['baseUrl'].toString().trim()
          : baseUrl,
    );
  }

  static bool _isRetiredDefault(AiProviderType type, String persisted) {
    const retiredGemini = {
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
    };
    const retiredGrok = {'grok-3-mini', 'grok-3'};
    if (type == AiProviderType.gemini) return retiredGemini.contains(persisted);
    if (type == AiProviderType.grok) return retiredGrok.contains(persisted);
    return false;
  }

  static Map<AiProviderType, AiProviderConfig> defaults() {
    return const {
      AiProviderType.gemini: AiProviderConfig(
        id: AiProviderType.gemini,
        displayName: 'Google Gemini (Free)',
        subtitle: 'Recommended • Great Bengali + English parsing',
        apiKey: '',
        model: 'gemini-3.8-flash',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
        suggestedModels: [
          'gemini-3.8-flash',
          'gemini-3.6-flash',
          'gemini-3.5-flash-lite',
        ],
        hintText: 'Get free key: aistudio.google.com',
      ),
      AiProviderType.groq: AiProviderConfig(
        id: AiProviderType.groq,
        displayName: 'Groq (Free)',
        subtitle: 'Ultra-fast free Llama inference',
        apiKey: '',
        model: 'llama-3.3-70b-versatile',
        baseUrl: 'https://api.groq.com/openai/v1/chat/completions',
        suggestedModels: [
          'llama-3.3-70b-versatile',
          'llama-3.1-8b-instant',
          'openai/gpt-oss-120b',
          'openai/gpt-oss-20b',
          'qwen/qwen3.8-27b',
        ],
        hintText: 'Free API key: console.groq.com',
      ),
      AiProviderType.grok: AiProviderConfig(
        id: AiProviderType.grok,
        displayName: 'xAI Grok',
        subtitle: 'OpenAI-compatible xAI endpoint',
        apiKey: '',
        model: 'grok-4.7',
        baseUrl: 'https://api.x.ai/v1/chat/completions',
        suggestedModels: [
          'grok-4.7',
          'grok-4.6',
          'grok-4.20-non-reasoning',
        ],
        hintText: 'xAI API key: console.x.ai',
      ),
      AiProviderType.openRouter: AiProviderConfig(
        id: AiProviderType.openRouter,
        displayName: 'OpenRouter (Free)',
        subtitle: 'Access free community models with one key',
        apiKey: '',
        model: 'openrouter/free',
        baseUrl: 'https://openrouter.ai/api/v1/chat/completions',
        suggestedModels: [
          'openrouter/free',
          'meta-llama/llama-3.3-70b-instruct:free',
          'google/gemma-3-27b-it:free',
        ],
        hintText: 'Free models: openrouter.ai',
      ),
      AiProviderType.custom: AiProviderConfig(
        id: AiProviderType.custom,
        displayName: 'Custom OpenAI-Compatible',
        subtitle: 'Cerebras, Mistral, DeepSeek, or local proxy',
        apiKey: '',
        model: '',
        baseUrl: 'https://api.cerebras.ai/v1/chat/completions',
        suggestedModels: [],
        hintText: 'Any OpenAI-compatible /chat/completions endpoint',
      ),
    };
  }
}
