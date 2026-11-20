import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/cloud_backup_payload.dart';
import '../services/cloud_backup_service.dart';
import 'ai_settings_provider.dart';
import 'chat_provider.dart';
import 'task_provider.dart';

/// Coordinates Google Sign-In and debounced full-replace Firestore backup/restore.
class CloudSyncProvider extends ChangeNotifier {
  CloudSyncProvider({
    required CloudBackupService service,
    required AiSettingsProvider aiSettings,
    required TaskProvider tasks,
    required ChatProvider chat,
  })  : _service = service,
        _aiSettings = aiSettings,
        _tasks = tasks,
        _chat = chat {
    _aiSettings.setOnDataChanged(scheduleAutoBackup);
    _tasks.setOnDataChanged(scheduleAutoBackup);
    _chat.setOnDataChanged(scheduleAutoBackup);

    if (_service.isAvailable) {
      _user = _service.currentUser;
      _authSub = _service.authStateChanges().listen(_handleAuthChanged);
      if (_user != null) {
        unawaited(_syncInitialSession(_user!.uid));
      }
    }
  }

  final CloudBackupService _service;
  final AiSettingsProvider _aiSettings;
  final TaskProvider _tasks;
  final ChatProvider _chat;

  StreamSubscription<User?>? _authSub;
  Timer? _debounceTimer;

  User? _user;
  bool _isBusy = false;
  bool _isSyncing = false;
  bool _suppressAutoSync = false;
  DateTime? _lastSyncedAt;
  String? _errorMessage;

  bool get isAvailable => _service.isAvailable;
  bool get isSignedIn => _user != null;
  String? get userEmail => _user?.email;
  String? get userName => _user?.displayName;
  String? get userPhotoUrl => _user?.photoURL;
  bool get isBusy => _isBusy;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get errorMessage => _errorMessage;

  void _handleAuthChanged(User? nextUser) {
    _user = nextUser;
    if (nextUser == null) {
      _debounceTimer?.cancel();
      _lastSyncedAt = null;
    }
    notifyListeners();
  }

  Future<void> _waitForLocalLoads() async {
    var attempts = 0;
    while ((!_aiSettings.isLoaded || !_tasks.isLoaded || !_chat.isLoaded) &&
        attempts < 40) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      attempts++;
    }
  }

  Future<void> _syncInitialSession(String uid) async {
    await _waitForLocalLoads();
    await _reconcileWithCloud(uid);
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

  Future<void> _reconcileWithCloud(String uid) async {
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final cloud = await _service.fetchBackup(uid);
      final local = _buildCurrentPayload();

      if (cloud != null) {
        if (local.isMeaningfullyEmpty) {
          await _applyPayloadLocally(cloud);
        } else {
          final merged = cloud.mergeWithLocal(local);
          await _applyPayloadLocally(merged);
          await _service.saveBackup(uid, merged);
        }
      } else {
        await _service.saveBackup(uid, local);
      }
      _lastSyncedAt = DateTime.now();
    } catch (e) {
      _errorMessage = 'Cloud sync failed: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    if (_isBusy || !isAvailable) return false;
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _service.signInWithGoogle();
      if (user == null) {
        return false;
      }
      _user = user;
      await _waitForLocalLoads();
      await _reconcileWithCloud(user.uid);
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
    notifyListeners();

    try {
      await _service.signOut();
      _user = null;
      _lastSyncedAt = null;
    } catch (e) {
      _errorMessage = 'Sign-out failed: $e';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Debounces and replaces the cloud backup document whenever any local data changes.
  void scheduleAutoBackup() {
    if (!isAvailable || _user == null || _suppressAutoSync) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      unawaited(backupNow(silent: true));
    });
  }

  Future<bool> backupNow({bool silent = false}) async {
    final uid = _user?.uid;
    if (!isAvailable || uid == null) return false;

    if (!silent) {
      _isBusy = true;
    }
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = _buildCurrentPayload();
      await _service.saveBackup(uid, payload);
      _lastSyncedAt = DateTime.now();
      return true;
    } catch (e) {
      _errorMessage = 'Backup failed: $e';
      return false;
    } finally {
      if (!silent) {
        _isBusy = false;
      }
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<bool> restoreFromCloud() async {
    final uid = _user?.uid;
    if (!isAvailable || uid == null || _isBusy) return false;

    _isBusy = true;
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final cloud = await _service.fetchBackup(uid);
      if (cloud == null) {
        _errorMessage = 'No cloud backup found for this Google account yet.';
        return false;
      }
      await _applyPayloadLocally(cloud);
      _lastSyncedAt = DateTime.now();
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

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _authSub?.cancel();
    _aiSettings.setOnDataChanged(null);
    _tasks.setOnDataChanged(null);
    _chat.setOnDataChanged(null);
    super.dispose();
  }
}
