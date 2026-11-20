import 'package:flutter/material.dart';

/// Dual-reminder notification preferences and theme choice.
@immutable
class ReminderSettings {
  const ReminderSettings({
    this.enabled = true,
    this.dayBeforeHour = 16,
    this.dayBeforeMinute = 0,
    this.endOfDayHour = 22,
    this.endOfDayMinute = 0,
    this.themeMode = 'system',
  });

  final bool enabled;
  final int dayBeforeHour;
  final int dayBeforeMinute;
  final int endOfDayHour;
  final int endOfDayMinute;
  final String themeMode;

  TimeOfDay get dayBeforeTime =>
      TimeOfDay(hour: dayBeforeHour, minute: dayBeforeMinute);

  TimeOfDay get endOfDayTime =>
      TimeOfDay(hour: endOfDayHour, minute: endOfDayMinute);

  ThemeMode get resolvedThemeMode {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String formatHourMinute(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:${minute.toString().padLeft(2, '0')} $period';
  }

  ReminderSettings copyWith({
    bool? enabled,
    int? dayBeforeHour,
    int? dayBeforeMinute,
    int? endOfDayHour,
    int? endOfDayMinute,
    String? themeMode,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      dayBeforeHour: dayBeforeHour ?? this.dayBeforeHour,
      dayBeforeMinute: dayBeforeMinute ?? this.dayBeforeMinute,
      endOfDayHour: endOfDayHour ?? this.endOfDayHour,
      endOfDayMinute: endOfDayMinute ?? this.endOfDayMinute,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'dayBeforeHour': dayBeforeHour,
        'dayBeforeMinute': dayBeforeMinute,
        'endOfDayHour': endOfDayHour,
        'endOfDayMinute': endOfDayMinute,
        'themeMode': themeMode,
      };

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    return ReminderSettings(
      enabled: json['enabled'] != false,
      dayBeforeHour: (json['dayBeforeHour'] as int?) ?? 16,
      dayBeforeMinute: (json['dayBeforeMinute'] as int?) ?? 0,
      endOfDayHour: (json['endOfDayHour'] as int?) ?? 22,
      endOfDayMinute: (json['endOfDayMinute'] as int?) ?? 0,
      themeMode: json['themeMode']?.toString() ?? 'system',
    );
  }
}
