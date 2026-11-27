import 'package:flutter/material.dart';

import '../models/ai_provider_config.dart';
import '../models/reminder_settings.dart';
import '../services/ai_parser_service.dart';
import '../services/storage_service.dart';

/// Holds AI provider API keys, active provider selection, and reminder/theme preferences.
class AiSettingsProvider extends ChangeNotifier {
  AiSettingsProvider({
    required StorageService storage,
    AiParserService? parser,
  })  : _storage = storage,
        _parser = parser ?? AiParserService(),
        _providers = Map<AiProviderType, AiProviderConfig>.from(
          AiProviderConfig.defaults(),
        );

  final StorageService _storage;
  final AiParserService _parser;

  Map<AiProviderType, AiProviderConfig> _providers;
  final Map<AiProviderType, List<String>> _liveModels = {};
  AiProviderType _activeProviderType = AiProviderType.gemini;
  ReminderSettings _reminderSettings = const ReminderSettings();
  bool _loaded = false;
  VoidCallback? _onDataChanged;

  void setOnDataChanged(VoidCallback? callback) {
    _onDataChanged = callback;
  }

  Map<AiProviderType, AiProviderConfig> get providers =>
      Map.unmodifiable(_providers);
  List<AiProviderConfig> get providerList =>
      AiProviderType.values.map((t) => _providers[t]!).toList();

  List<String> modelsForProvider(AiProviderType type) {
    final live = _liveModels[type];
    if (live != null && live.isNotEmpty) return live;
    return _providers[type]!.suggestedModels;
  }

  AiProviderType get activeProviderType => _activeProviderType;
  AiProviderConfig get activeProvider => _providers[_activeProviderType]!;
  bool get hasActiveApiKey => activeProvider.hasKey;
  bool get hasAnyApiKey => _providers.values.any((p) => p.hasKey);
  Map<AiProviderType, List<String>> get cachedModelsMap => {
        for (final entry in _providers.entries)
          entry.key: modelsForProvider(entry.key),
      };
  ReminderSettings get reminderSettings => _reminderSettings;
  ThemeMode get themeMode => _reminderSettings.resolvedThemeMode;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _providers = await _storage.loadProviders();
    _activeProviderType = await _storage.loadActiveProviderType();
    _reminderSettings = await _storage.loadReminderSettings();
    _loaded = true;
    notifyListeners();
  }

  Future<void> updateProviderConfig(AiProviderConfig updated) async {
    _providers[updated.id] = updated;
    await _storage.saveProviders(_providers);
    notifyListeners();
    _onDataChanged?.call();
  }

  Future<void> setActiveProvider(AiProviderType type) async {
    if (_activeProviderType == type) return;
    _activeProviderType = type;
    await _storage.saveActiveProviderType(type);
    notifyListeners();
    _onDataChanged?.call();
  }

  Future<List<String>> loadLiveModels(AiProviderType type) async {
    final config = _providers[type]!;
    final models = await _parser.fetchAvailableModels(config);
    if (models.isNotEmpty) {
      _liveModels[type] = models;
      if (config.model.trim().isEmpty || !models.contains(config.model.trim())) {
        await updateProviderConfig(config.copyWith(model: models.first));
      } else {
        notifyListeners();
      }
    }
    return models;
  }

  Future<ApiTestResult> testProvider(AiProviderType type) async {
    final config = _providers[type]!;
    final res = await _parser.testConnection(config);
    if (res.availableModels.isNotEmpty) {
      _liveModels[type] = res.availableModels;
    }
    if (res.ok &&
        res.resolvedModel != null &&
        res.resolvedModel != config.model.trim()) {
      await updateProviderConfig(config.copyWith(model: res.resolvedModel));
    } else if (res.availableModels.isNotEmpty) {
      notifyListeners();
    }
    return res;
  }

  Future<void> updateReminderSettings(
    ReminderSettings updated, {
    Future<void> Function(ReminderSettings settings)? onReschedule,
  }) async {
    _reminderSettings = updated;
    await _storage.saveReminderSettings(updated);
    if (onReschedule != null) {
      await onReschedule(updated);
    }
    notifyListeners();
    _onDataChanged?.call();
  }

  /// Replaces local AI/reminder state from a cloud restore without triggering re-upload.
  Future<void> applyRestoredState({
    required Map<AiProviderType, AiProviderConfig> providers,
    required AiProviderType activeProviderType,
    required ReminderSettings reminderSettings,
  }) async {
    _providers = Map<AiProviderType, AiProviderConfig>.from(providers);
    _activeProviderType = activeProviderType;
    _reminderSettings = reminderSettings;
    _loaded = true;
    await _storage.saveProviders(_providers);
    await _storage.saveActiveProviderType(_activeProviderType);
    await _storage.saveReminderSettings(_reminderSettings);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final str = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await updateReminderSettings(_reminderSettings.copyWith(themeMode: str));
  }
}
