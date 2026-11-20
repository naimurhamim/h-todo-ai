import 'package:flutter/material.dart';

/// Consistent spacing scale (4/8dp rhythm).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Consistent corner radii tokens matching soft glassmorphic surfaces.
abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;
}

/// Consistent vector icon size tokens.
abstract final class AppIconSize {
  static const double sm = 18;
  static const double md = 20;
  static const double lg = 24;
}

/// Shared layout bounds for phone, tablet, and desktop.
abstract final class AppLayout {
  static const double maxContentWidth = 720;
  static const double railBreakpoint = 720;
  static const double navClearance = 104;
}

/// Semantic color + glassmorphism tokens for Light and Dark modes.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.bgGradientTop,
    required this.bgGradientBottom,
    required this.orbPrimary,
    required this.orbAccent,
    required this.glassFill,
    required this.glassFillElevated,
    required this.glassBorder,
    required this.glassShadow,
    required this.surface,
    required this.surfaceSubtle,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color bg;
  final Color bgGradientTop;
  final Color bgGradientBottom;
  final Color orbPrimary;
  final Color orbAccent;
  final Color glassFill;
  final Color glassFillElevated;
  final Color glassBorder;
  final Color glassShadow;
  final Color surface;
  final Color surfaceSubtle;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color success;
  final Color warning;
  final Color danger;

  static const AppColors light = AppColors(
    bg: Color(0xFFECEFF4),
    bgGradientTop: Color(0xFFE8ECF2),
    bgGradientBottom: Color(0xFFE2E6EE),
    orbPrimary: Color(0xFFCBD5E1),
    orbAccent: Color(0xFFFDBA74),
    glassFill: Color(0xBAFFFFFF),
    glassFillElevated: Color(0xE0FFFFFF),
    glassBorder: Color(0xE6FFFFFF),
    glassShadow: Color(0x120F172A),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xB8E6EAF0),
    primary: Color(0xFFEA6A15),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0x1FEA6A15),
    textPrimary: Color(0xFF14171F),
    textSecondary: Color(0xFF666E7D),
    border: Color(0xB8D6DCE6),
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    danger: Color(0xFFDC2626),
  );

  static const AppColors dark = AppColors(
    bg: Color(0xFF0B0E14),
    bgGradientTop: Color(0xFF0E121B),
    bgGradientBottom: Color(0xFF090C11),
    orbPrimary: Color(0xFF334155),
    orbAccent: Color(0xFFEA6A15),
    glassFill: Color(0xB3171D29),
    glassFillElevated: Color(0xD91E2534),
    glassBorder: Color(0x26FFFFFF),
    glassShadow: Color(0x4A000000),
    surface: Color(0xFF151A25),
    surfaceSubtle: Color(0x99232B3C),
    primary: Color(0xFFF47B25),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0x28F47B25),
    textPrimary: Color(0xFFF4F6FA),
    textSecondary: Color(0xFF949BA8),
    border: Color(0x24FFFFFF),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? bgGradientTop,
    Color? bgGradientBottom,
    Color? orbPrimary,
    Color? orbAccent,
    Color? glassFill,
    Color? glassFillElevated,
    Color? glassBorder,
    Color? glassShadow,
    Color? surface,
    Color? surfaceSubtle,
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      bgGradientTop: bgGradientTop ?? this.bgGradientTop,
      bgGradientBottom: bgGradientBottom ?? this.bgGradientBottom,
      orbPrimary: orbPrimary ?? this.orbPrimary,
      orbAccent: orbAccent ?? this.orbAccent,
      glassFill: glassFill ?? this.glassFill,
      glassFillElevated: glassFillElevated ?? this.glassFillElevated,
      glassBorder: glassBorder ?? this.glassBorder,
      glassShadow: glassShadow ?? this.glassShadow,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySoft: primarySoft ?? this.primarySoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      bgGradientTop: Color.lerp(bgGradientTop, other.bgGradientTop, t)!,
      bgGradientBottom:
          Color.lerp(bgGradientBottom, other.bgGradientBottom, t)!,
      orbPrimary: Color.lerp(orbPrimary, other.orbPrimary, t)!,
      orbAccent: Color.lerp(orbAccent, other.orbAccent, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassFillElevated:
          Color.lerp(glassFillElevated, other.glassFillElevated, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Shorthand accessor for semantic glass colors.
extension AppColorsContext on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
