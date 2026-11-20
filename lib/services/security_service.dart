import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Handles salted SHA-256 PIN hashing and biometric fingerprint authentication.
class SecurityService {
  SecurityService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication(),
        _forceDisabled = false;

  /// Inert instance for headless tests without native platform biometric channels.
  SecurityService.disabled()
      : _auth = null,
        _forceDisabled = true;

  final LocalAuthentication? _auth;
  final bool _forceDisabled;

  bool get _supportsBiometricsPlatform {
    if (_forceDisabled || kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Generates a random 16-byte hex salt for PIN hashing.
  static String generateSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Computes salted SHA-256 digest of [pin].
  static String hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  /// Constant-time-style equality check for a candidate [pin].
  static bool verifyPin(String pin, String salt, String expectedHash) {
    final actual = hashPin(pin, salt);
    if (actual.length != expectedHash.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<bool> canUseBiometrics() async {
    if (!_supportsBiometricsPlatform || _auth == null) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric({
    String reason = 'Verify fingerprint to unlock H-TODO AI',
  }) async {
    if (!_supportsBiometricsPlatform || _auth == null) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
