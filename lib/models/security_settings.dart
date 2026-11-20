import 'package:flutter/foundation.dart';

/// Device-local privacy lock configuration (4-digit PIN + biometric fingerprint).
@immutable
class SecuritySettings {
  const SecuritySettings({
    this.pinEnabled = false,
    this.pinHash,
    this.pinSalt,
    this.biometricEnabled = false,
    this.lockOnResume = true,
  });

  final bool pinEnabled;
  final String? pinHash;
  final String? pinSalt;
  final bool biometricEnabled;
  final bool lockOnResume;

  bool get hasPin =>
      pinEnabled &&
      (pinHash?.isNotEmpty ?? false) &&
      (pinSalt?.isNotEmpty ?? false);

  SecuritySettings copyWith({
    bool? pinEnabled,
    String? pinHash,
    String? pinSalt,
    bool clearPin = false,
    bool? biometricEnabled,
    bool? lockOnResume,
  }) {
    return SecuritySettings(
      pinEnabled: pinEnabled ?? this.pinEnabled,
      pinHash: clearPin ? null : (pinHash ?? this.pinHash),
      pinSalt: clearPin ? null : (pinSalt ?? this.pinSalt),
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      lockOnResume: lockOnResume ?? this.lockOnResume,
    );
  }

  Map<String, dynamic> toJson() => {
        'pinEnabled': pinEnabled,
        'pinHash': pinHash,
        'pinSalt': pinSalt,
        'biometricEnabled': biometricEnabled,
        'lockOnResume': lockOnResume,
      };

  factory SecuritySettings.fromJson(Map<String, dynamic> json) {
    return SecuritySettings(
      pinEnabled: json['pinEnabled'] == true,
      pinHash: json['pinHash']?.toString(),
      pinSalt: json['pinSalt']?.toString(),
      biometricEnabled: json['biometricEnabled'] == true,
      lockOnResume: json['lockOnResume'] != false,
    );
  }
}
