import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_provider_config.dart';
import '../models/chat_message.dart';
import '../models/google_account_profile.dart';
import '../models/reminder_settings.dart';
import '../models/security_settings.dart';
import '../models/task_item.dart';

/// Persists tasks, chat history, AI provider configs, Google profile, and settings.
class StorageService {
  StorageService({SharedPreferences? prefs}) : _prefs = prefs;

  static const _tasksKey = 'htodo_tasks_v1';
  static const _chatKey = 'htodo_chat_v1';
  static const _providersKey = 'htodo_providers_v1';
  static const _activeProviderKey = 'htodo_active_provider_v1';
  static const _reminderSettingsKey = 'htodo_reminder_settings_v1';
  static const _securitySettingsKey = 'htodo_security_v1';
  static const _googleProfileKey = 'htodo_google_profile_v1';
  static const _lastUpdatedAtKey = 'htodo_last_updated_at_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<DateTime?> loadLastUpdatedAt() async {
    final prefs = await _instance();
    final raw = prefs.getString(_lastUpdatedAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> saveLastUpdatedAt(DateTime timestamp) async {
    final prefs = await _instance();
    await prefs.setString(_lastUpdatedAtKey, timestamp.toIso8601String());
  }

  Future<List<TaskItem>> loadTasks() async {
    final prefs = await _instance();
    final raw = prefs.getString(_tasksKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(TaskItem.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTasks(List<TaskItem> tasks) async {
    final prefs = await _instance();
    final encoded = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString(_tasksKey, encoded);
    await prefs.setString(_lastUpdatedAtKey, DateTime.now().toIso8601String());
  }

  Future<List<ChatMessage>> loadChatMessages() async {
    final prefs = await _instance();
    final raw = prefs.getString(_chatKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveChatMessages(List<ChatMessage> messages) async {
    final prefs = await _instance();
    final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
    await prefs.setString(_chatKey, encoded);
    await prefs.setString(_lastUpdatedAtKey, DateTime.now().toIso8601String());
  }

  Future<Map<AiProviderType, AiProviderConfig>> loadProviders() async {
    final defaults = Map<AiProviderType, AiProviderConfig>.from(
      AiProviderConfig.defaults(),
    );
    final prefs = await _instance();
    final raw = prefs.getString(_providersKey);
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final type = AiProviderType.fromString(entry.key);
        final base = defaults[type];
        final value = entry.value;
        if (base != null && value is Map<String, dynamic>) {
          defaults[type] = base.mergePersisted(value);
        }
      }
    } catch (_) {
      return defaults;
    }
    return defaults;
  }

  Future<void> saveProviders(
    Map<AiProviderType, AiProviderConfig> providers,
  ) async {
    final prefs = await _instance();
    final map = <String, dynamic>{
      for (final entry in providers.entries) entry.key.name: entry.value.toJson(),
    };
    await prefs.setString(_providersKey, jsonEncode(map));
    await prefs.setString(_lastUpdatedAtKey, DateTime.now().toIso8601String());
  }

  Future<AiProviderType> loadActiveProviderType() async {
    final prefs = await _instance();
    final raw = prefs.getString(_activeProviderKey);
    return AiProviderType.fromString(raw);
  }

  Future<void> saveActiveProviderType(AiProviderType type) async {
    final prefs = await _instance();
    await prefs.setString(_activeProviderKey, type.name);
    await prefs.setString(_lastUpdatedAtKey, DateTime.now().toIso8601String());
  }

  Future<ReminderSettings> loadReminderSettings() async {
    final prefs = await _instance();
    final raw = prefs.getString(_reminderSettingsKey);
    if (raw == null || raw.isEmpty) return const ReminderSettings();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return ReminderSettings.fromJson(decoded);
    } catch (_) {
      return const ReminderSettings();
    }
  }

  Future<void> saveReminderSettings(ReminderSettings settings) async {
    final prefs = await _instance();
    await prefs.setString(_reminderSettingsKey, jsonEncode(settings.toJson()));
    await prefs.setString(_lastUpdatedAtKey, DateTime.now().toIso8601String());
  }

  Future<SecuritySettings> loadSecuritySettings() async {
    final prefs = await _instance();
    final raw = prefs.getString(_securitySettingsKey);
    if (raw == null || raw.isEmpty) return const SecuritySettings();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return SecuritySettings.fromJson(decoded);
    } catch (_) {
      return const SecuritySettings();
    }
  }

  Future<void> saveSecuritySettings(SecuritySettings settings) async {
    final prefs = await _instance();
    await prefs.setString(_securitySettingsKey, jsonEncode(settings.toJson()));
  }

  Future<GoogleAccountProfile?> loadGoogleProfile() async {
    final prefs = await _instance();
    final raw = prefs.getString(_googleProfileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final profile = GoogleAccountProfile.fromJson(decoded);
      if (profile.email.trim().isEmpty) return null;
      return profile;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveGoogleProfile(GoogleAccountProfile? profile) async {
    final prefs = await _instance();
    if (profile == null) {
      await prefs.remove(_googleProfileKey);
    } else {
      await prefs.setString(_googleProfileKey, jsonEncode(profile.toJson()));
    }
  }
}
