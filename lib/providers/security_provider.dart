import 'package:flutter/material.dart';

import '../models/security_settings.dart';
import '../services/security_service.dart';
import '../services/storage_service.dart';

/// Coordinates PIN pass lock, biometric fingerprint unlock, and auto-lock lifecycle.
class SecurityProvider extends ChangeNotifier {
  SecurityProvider({
    required StorageService storage,
    SecurityService? securityService,
  })  : _storage = storage,
        _service = securityService ?? SecurityService();

  final StorageService _storage;
  final SecurityService _service;

  SecuritySettings _settings = const SecuritySettings();
  bool _isLocked = false;
  bool _biometricsAvailable = false;
  bool _loaded = false;
  bool _wasBackgrounded = false;
  bool _authenticatingBiometric = false;

  SecuritySettings get settings => _settings;
  bool get isLocked => _isLocked;
  bool get hasPin => _settings.hasPin;
  bool get biometricEnabled => _settings.biometricEnabled && _settings.hasPin;
  bool get lockOnResume => _settings.lockOnResume;
  bool get biometricsAvailable => _biometricsAvailable;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _settings = await _storage.loadSecuritySettings();
    _biometricsAvailable = await _service.canUseBiometrics();
    _isLocked = _settings.hasPin;
    _loaded = true;
    notifyListeners();
  }

  Future<void> refreshBiometricAvailability() async {
    _biometricsAvailable = await _service.canUseBiometrics();
    notifyListeners();
  }

  Future<void> enablePin(String pin) async {
    final salt = SecurityService.generateSalt();
    final hash = SecurityService.hashPin(pin, salt);
    _settings = _settings.copyWith(
      pinEnabled: true,
      pinSalt: salt,
      pinHash: hash,
    );
    await _storage.saveSecuritySettings(_settings);
    _isLocked = false;
    notifyListeners();
  }

  Future<bool> changePin(String currentPin, String newPin) async {
    if (!verifyPinOnly(currentPin)) return false;
    await enablePin(newPin);
    return true;
  }

  Future<bool> disablePin(String currentPin) async {
    if (!verifyPinOnly(currentPin)) return false;
    _settings = _settings.copyWith(
      pinEnabled: false,
      clearPin: true,
      biometricEnabled: false,
    );
    await _storage.saveSecuritySettings(_settings);
    _isLocked = false;
    notifyListeners();
    return true;
  }

  Future<bool> setBiometricEnabled(bool enabled) async {
    if (!_settings.hasPin) return false;
    if (enabled) {
      _authenticatingBiometric = true;
      final ok = await _service.authenticateBiometric(
        reason: 'Verify fingerprint to enable biometric unlock',
      );
      _authenticatingBiometric = false;
      if (!ok) return false;
    }
    _settings = _settings.copyWith(biometricEnabled: enabled);
    await _storage.saveSecuritySettings(_settings);
    notifyListeners();
    return true;
  }

  Future<void> setLockOnResume(bool enabled) async {
    _settings = _settings.copyWith(lockOnResume: enabled);
    await _storage.saveSecuritySettings(_settings);
    notifyListeners();
  }

  bool verifyPinOnly(String pin) {
    if (!_settings.hasPin) return false;
    return SecurityService.verifyPin(
      pin,
      _settings.pinSalt!,
      _settings.pinHash!,
    );
  }

  bool verifyAndUnlock(String pin) {
    if (!verifyPinOnly(pin)) return false;
    _isLocked = false;
    notifyListeners();
    return true;
  }

  Future<bool> tryBiometricUnlock() async {
    if (!biometricEnabled || _authenticatingBiometric) return false;
    _authenticatingBiometric = true;
    final ok = await _service.authenticateBiometric();
    _authenticatingBiometric = false;
    if (ok) {
      _isLocked = false;
      notifyListeners();
    }
    return ok;
  }

  void lockNow() {
    if (!_settings.hasPin) return;
    _isLocked = true;
    notifyListeners();
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    if (!_settings.hasPin || !_settings.lockOnResume) return;
    if (_authenticatingBiometric) return;

    if (state == AppLifecycleState.paused) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      if (!_isLocked) {
        _isLocked = true;
        notifyListeners();
      }
    }
  }
}
