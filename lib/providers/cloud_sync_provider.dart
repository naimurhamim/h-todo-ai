import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/cloud_backup_payload.dart';
import '../models/google_account_profile.dart';
import '../services/cloud_backup_service.dart';
import '../services/local_backup_service.dart';
import '../services/storage_service.dart';
import 'ai_settings_provider.dart';
import 'chat_provider.dart';
import 'task_provider.dart';

/// Coordinates cached Google identity, WhatsApp-style private Google Drive
/// (`appDataFolder`) auto-backup, one-time Firebase migration, and JSON Export/Import.
class CloudSyncProvider extends ChangeNotifier {
  CloudSyncProvider({
    required CloudBackupService service,
    required StorageService storage,
    required AiSettingsProvider aiSettings,
    required TaskProvider tasks,
    required ChatProvider chat,
    LocalBackupService? localBackup,
  })  : _service = service,
        _storage = storage,
        _aiSettings = aiSettings,
        _tasks = tasks,
        _chat = chat,
        _localBackup = localBackup ?? LocalBackupService() {
    _aiSettings.setOnDataChanged(scheduleAutoBackup);
    _tasks.setOnDataChanged(scheduleAutoBackup);
    _chat.setOnDataChanged(scheduleAutoBackup);

    unawaited(_initSession());
  }

  final CloudBackupService _service;
  final StorageService _storage;
  final AiSettingsProvider _aiSettings;
  final TaskProvider _tasks;
  final ChatProvider _chat;
  final LocalBackupService _localBackup;

  Timer? _debounceTimer;
  GoogleAccountProfile? _profile;
  bool _isBusy = false;
  bool _isSyncing = false;
  bool _suppressAutoSync = false;
  bool _uploadInFlight = false;
  bool _queuedUpload = false;
  String? _lastSyncedFingerprint;
  String? _errorMessage;
  String? _migrationNotice;

  bool get isAvailable => _service.isAvailable;
  bool get isSignedIn => _profile != null;
  bool get hasLiveDriveSession => _service.isSignedInSessionActive;
  String? get userEmail => _profile?.email;
  String? get userName => _profile?.displayName;
  String? get userPhotoUrl => _profile?.photoUrl;
  DateTime? get lastSyncedAt => _profile?.lastSyncedAt;
  bool get isBusy => _isBusy;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  String? get migrationNotice => _migrationNotice;

  Future<void> _initSession() async {
    _profile = await _storage.loadGoogleProfile();
    notifyListeners();

    if (!_service.isAvailable) return;
    await _waitForLocalLoads();

    final live = await _service.restoreSilentSession();
    if (live == null) return;

    _profile = _mergeAccountInfo(existing: _profile, fresh: live);
    await _storage.saveGoogleProfile(_profile);
    notifyListeners();

    await _reconcileWithDrive(promptIfNecessary: false);
  }

  GoogleAccountProfile _mergeAccountInfo({
    GoogleAccountProfile? existing,
    required GoogleAccountProfile fresh,
  }) {
    final sameUser = existing != null &&
        existing.email.toLowerCase() == fresh.email.toLowerCase();
    if (!sameUser) {
      return fresh;
    }
    return existing.copyWith(
      id: fresh.id,
      email: fresh.email,
      displayName: fresh.displayName ?? existing.displayName,
      photoUrl: fresh.photoUrl ?? existing.photoUrl,
    );
  }

  Future<void> _waitForLocalLoads() async {
    var attempts = 0;
    while ((!_aiSettings.isLoaded || !_tasks.isLoaded || !_chat.isLoaded) &&
        attempts < 40) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      attempts++;
    }
  }

  CloudBackupPayload _buildCurrentPayload() {
    return CloudBackupPayload(
      updatedAt: DateTime.now(),
      activeProviderType: _aiSettings.activeProviderType,
      providers: _aiSettings.providers,
      reminderSettings: _aiSettings.reminderSettings,
      tasks: _tasks.tasks,
      chatMessages: _chat.messages,
    );
  }

  Future<void> _applyPayloadLocally(CloudBackupPayload payload) async {
    _suppressAutoSync = true;
    try {
      await _aiSettings.applyRestoredState(
        providers: payload.providers,
        activeProviderType: payload.activeProviderType,
        reminderSettings: payload.reminderSettings,
      );
      await _tasks.applyRestoredState(
        payload.tasks,
        payload.reminderSettings,
      );
      await _chat.applyRestoredState(payload.chatMessages);
    } finally {
      _suppressAutoSync = false;
    }
  }

  Future<void> _reconcileWithDrive({required bool promptIfNecessary}) async {
    if (_profile == null || !_service.isAvailable) return;
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final driveRes = await _service.fetchDriveBackup(
        promptIfNecessary: promptIfNecessary,
      );
      final local = _buildCurrentPayload();

      if (driveRes.payload != null) {
        var finalPayload = driveRes.payload!;

        if (local.isMeaningfullyEmpty) {
          await _applyPayloadLocally(finalPayload);
        } else {
          final merged = driveRes.payload!.mergeWithLocal(local);
          await _applyPayloadLocally(merged);
          finalPayload = merged;
        }

        // Migrate legacy Firebase tasks/keys once if not yet migrated.
        var migratedNow = false;
        if (!(_profile?.migratedFromFirebase ?? false)) {
          final legacy = await _service.fetchLegacyFirebaseBackup();
          if (legacy != null && !legacy.isMeaningfullyEmpty) {
            final withLegacy = legacy.mergeWithLocal(finalPayload);
            await _applyPayloadLocally(withLegacy);
            finalPayload = withLegacy;
            migratedNow = true;
          }
        }

        var fileId = driveRes.fileId;
        if (finalPayload.computeContentFingerprint() !=
            driveRes.payload!.computeContentFingerprint()) {
          fileId = await _service.saveDriveBackup(
            finalPayload,
            knownFileId: fileId,
            promptIfNecessary: promptIfNecessary,
          );
        }

        if (migratedNow) {
          await _service.deleteLegacyFirebaseBackup();
          _migrationNotice =
              'Migrated your old Firebase backup to your private Google Drive.';
        }

        _lastSyncedFingerprint = finalPayload.computeContentFingerprint();
        _profile = _profile!.copyWith(
          driveFileId: fileId,
          lastSyncedAt: DateTime.now(),
          migratedFromFirebase:
              (_profile?.migratedFromFirebase ?? false) || migratedNow,
        );
      } else {
        // First time setting up Drive backup for this Google account.
        CloudBackupPayload? legacy;
        if (!(_profile?.migratedFromFirebase ?? false)) {
          legacy = await _service.fetchLegacyFirebaseBackup();
        }

        var initialPayload = local;
        if (legacy != null && !legacy.isMeaningfullyEmpty) {
          initialPayload = legacy.mergeWithLocal(local);
          await _applyPayloadLocally(initialPayload);
        }

        final createdFileId = await _service.saveDriveBackup(
          initialPayload,
          promptIfNecessary: promptIfNecessary,
        );

        if (legacy != null) {
          await _service.deleteLegacyFirebaseBackup();
          _migrationNotice =
              'Old Firebase backup moved to your private Google Drive and cleared from Firebase.';
        }

        _lastSyncedFingerprint = initialPayload.computeContentFingerprint();
        _profile = _profile!.copyWith(
          driveFileId: createdFileId,
          lastSyncedAt: DateTime.now(),
          migratedFromFirebase: true,
        );
      }

      await _storage.saveGoogleProfile(_profile);
    } catch (e) {
      _errorMessage = 'Google Drive sync failed: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Signs in with Google, caches Name/Email/Photo locally, and syncs Drive.
  Future<bool> signInWithGoogle() async {
    if (_isBusy || !isAvailable) return false;
    _isBusy = true;
    _errorMessage = null;
    _migrationNotice = null;
    notifyListeners();

    try {
      final signed = await _service.signInWithGoogle();
      if (signed == null) return false;

      _profile = _mergeAccountInfo(existing: _profile, fresh: signed);
      await _storage.saveGoogleProfile(_profile);
      notifyListeners();

      await _waitForLocalLoads();
      await _reconcileWithDrive(promptIfNecessary: true);
      return true;
    } catch (e) {
      _errorMessage = 'Sign-in failed: $e';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_isBusy) return;
    _debounceTimer?.cancel();
    _isBusy = true;
    _errorMessage = null;
    _migrationNotice = null;
    notifyListeners();

    try {
      await _service.signOut();
      _profile = null;
      _lastSyncedFingerprint = null;
      await _storage.saveGoogleProfile(null);
    } catch (e) {
      _errorMessage = 'Sign-out failed: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Debounces and replaces the single `htodo_ai_backup.json` file in the user's
  /// own Drive `appDataFolder` whenever local data changes.
  void scheduleAutoBackup() {
    if (!isAvailable || _profile == null || _suppressAutoSync) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      unawaited(_runSingleUpload(silent: true, promptIfNecessary: false));
    });
  }

  Future<bool> _runSingleUpload({
    required bool silent,
    required bool promptIfNecessary,
  }) async {
    if (!isAvailable || _profile == null) return false;

    final initialPayload = _buildCurrentPayload();
    final initialHash = initialPayload.computeContentFingerprint();
    if (silent && initialHash == _lastSyncedFingerprint) {
      return true;
    }

    if (_uploadInFlight) {
      _queuedUpload = true;
      return true;
    }

    _uploadInFlight = true;
    if (!silent) {
      _isBusy = true;
    }
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    var succeeded = true;
    try {
      do {
        _queuedUpload = false;
        if (!_service.isSignedInSessionActive) {
          await _service.restoreSilentSession();
          if (!_service.isSignedInSessionActive && promptIfNecessary) {
            final signed = await _service.signInWithGoogle();
            if (signed != null) {
              _profile = _mergeAccountInfo(existing: _profile, fresh: signed);
            }
          }
        }

        final payload = _buildCurrentPayload();
        final fingerprint = payload.computeContentFingerprint();
        if (silent && fingerprint == _lastSyncedFingerprint) {
          continue;
        }

        final nextId = await _service.saveDriveBackup(
          payload,
          knownFileId: _profile?.driveFileId,
          promptIfNecessary: promptIfNecessary,
        );
        _lastSyncedFingerprint = fingerprint;
        _profile = _profile!.copyWith(
          driveFileId: nextId,
          lastSyncedAt: DateTime.now(),
        );
        await _storage.saveGoogleProfile(_profile);
      } while (_queuedUpload);
    } catch (e) {
      succeeded = false;
      _errorMessage = 'Drive backup failed: $e';
    } finally {
      _uploadInFlight = false;
      if (!silent) {
        _isBusy = false;
      }
      _isSyncing = false;
      notifyListeners();
    }
    return succeeded;
  }

  Future<bool> backupNow({bool silent = false}) {
    return _runSingleUpload(silent: silent, promptIfNecessary: !silent);
  }

  Future<bool> restoreFromDrive() async {
    if (!isAvailable || _profile == null || _isBusy) return false;

    _isBusy = true;
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!_service.isSignedInSessionActive) {
        await _service.restoreSilentSession();
        if (!_service.isSignedInSessionActive) {
          final signed = await _service.signInWithGoogle();
          if (signed == null) return false;
          _profile = _mergeAccountInfo(existing: _profile, fresh: signed);
        }
      }

      final res = await _service.fetchDriveBackup(promptIfNecessary: true);
      if (res.payload == null) {
        _errorMessage = 'No backup found in your Google Drive yet.';
        return false;
      }

      await _applyPayloadLocally(res.payload!);
      _lastSyncedFingerprint = res.payload!.computeContentFingerprint();
      _profile = _profile!.copyWith(
        driveFileId: res.fileId,
        lastSyncedAt: DateTime.now(),
      );
      await _storage.saveGoogleProfile(_profile);
      return true;
    } catch (e) {
      _errorMessage = 'Restore failed: $e';
      return false;
    } finally {
      _isBusy = false;
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Builds pretty-printed JSON suitable for manual offline export.
  String buildExportJson({bool includeApiKeys = true}) {
    return _buildCurrentPayload().toJsonString(
      includeApiKeys: includeApiKeys,
      pretty: true,
    );
  }

  /// Writes a `.json` backup file and opens the OS share sheet.
  Future<String> exportBackupToFile({bool includeApiKeys = true}) async {
    await _waitForLocalLoads();
    final jsonText = buildExportJson(includeApiKeys: includeApiKeys);
    return _localBackup.exportJsonFile(jsonText);
  }

  /// Lets the user choose a `.json` backup file and validates its contents.
  /// Returns `null` if file selection was cancelled.
  Future<({CloudBackupPayload payload, bool includesApiKeys})?>
      pickAndParseImportFile() async {
    final raw = await _localBackup.pickJsonFileContent();
    if (raw == null || raw.trim().isEmpty) return null;
    return CloudBackupPayload.parseBackupEnvelope(raw);
  }

  /// Applies an imported backup locally (merging deduplicated records or replacing),
  /// preserving existing API keys if the imported file excluded keys.
  Future<void> applyImportedBackup(
    CloudBackupPayload imported, {
    required bool merge,
    bool includesApiKeys = true,
  }) async {
    await _waitForLocalLoads();
    final local = _buildCurrentPayload();

    final CloudBackupPayload target;
    if (merge) {
      target = imported.mergeWithLocal(local);
    } else if (includesApiKeys) {
      target = imported;
    } else {
      target = CloudBackupPayload(
        schemaVersion: imported.schemaVersion,
        updatedAt: DateTime.now(),
        activeProviderType: local.activeProviderType,
        providers: local.providers,
        reminderSettings: imported.reminderSettings,
        tasks: imported.tasks,
        chatMessages: imported.chatMessages,
      );
    }

    await _applyPayloadLocally(target);
    notifyListeners();
    scheduleAutoBackup();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _aiSettings.setOnDataChanged(null);
    _tasks.setOnDataChanged(null);
    _chat.setOnDataChanged(null);
    super.dispose();
  }
}
