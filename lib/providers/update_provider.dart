import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';

/// Coordinates silent app-launch GitHub release checks and one-time update notifications.
class UpdateProvider extends ChangeNotifier {
  UpdateProvider({
    required StorageService storage,
    required NotificationService notifications,
    http.Client? httpClient,
    String? currentVersionOverride,
    bool autoCheckOnStart = true,
  })  : _storage = storage,
        _notifications = notifications,
        _httpClient = httpClient,
        _currentVersionOverride = currentVersionOverride {
    if (autoCheckOnStart) {
      unawaited(checkSilently());
    }
  }

  final StorageService _storage;
  final NotificationService _notifications;
  final http.Client? _httpClient;
  final String? _currentVersionOverride;

  AppUpdateInfo? _availableUpdate;
  bool _showTopBanner = false;
  bool _checking = false;
  bool _hasChecked = false;
  bool _disposed = false;

  AppUpdateInfo? get availableUpdate => _availableUpdate;
  bool get hasUpdate => _availableUpdate != null;
  bool get showTopBanner => _showTopBanner && _availableUpdate != null;
  bool get isChecking => _checking;

  Future<void> checkSilently({bool force = false}) async {
    if (_checking || (_hasChecked && !force) || _disposed) return;
    _checking = true;
    _hasChecked = true;

    try {
      final info = await UpdateService.fetchLatestUpdate(
        client: _httpClient,
        currentVersionOverride: _currentVersionOverride,
      );
      if (_disposed) return;

      if (info == null) {
        final hadUpdate = _availableUpdate != null || _showTopBanner;
        _availableUpdate = null;
        _showTopBanner = false;
        await _notifications.cancelUpdateNotification();
        if (hadUpdate && !_disposed) notifyListeners();
        return;
      }

      _availableUpdate = info;
      _showTopBanner = true;
      notifyListeners();

      final lastNotified = await _storage.loadLastNotifiedUpdateVersion();
      if (_disposed) return;
      if (lastNotified != info.latestVersion) {
        // Record before notifying so repeated launches do not re-alert for the same release.
        await _storage.saveLastNotifiedUpdateVersion(info.latestVersion);
        await _notifications.showUpdateNotification(
          latestVersion: info.latestVersion,
        );
      }
    } finally {
      _checking = false;
    }
  }

  void dismissTopBanner() {
    if (!_showTopBanner) return;
    _showTopBanner = false;
    if (!_disposed) notifyListeners();
  }

  void markUpToDate() {
    if (_availableUpdate == null && !_showTopBanner) return;
    _availableUpdate = null;
    _showTopBanner = false;
    unawaited(_notifications.cancelUpdateNotification());
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
