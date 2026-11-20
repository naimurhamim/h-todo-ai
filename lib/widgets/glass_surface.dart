import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Soft gradient + ambient orb backdrop shared across all screens and overlays.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.bgGradientTop,
                      colors.bg,
                      colors.bgGradientBottom,
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -90,
                left: -70,
                child: _AmbientOrb(
                  size: 280,
                  color:
                      colors.orbPrimary.withValues(alpha: dark ? 0.32 : 0.48),
                ),
              ),
              Positioned(
                top: 150,
                right: -100,
                child: _AmbientOrb(
                  size: 300,
                  color: colors.orbAccent.withValues(alpha: dark ? 0.14 : 0.22),
                ),
              ),
              Positioned(
                bottom: -110,
                left: 30,
                child: _AmbientOrb(
                  size: 290,
                  color:
                      colors.orbPrimary.withValues(alpha: dark ? 0.28 : 0.42),
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Frosted translucent glass card container with optional tap feedback.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = AppRadius.lg,
    this.blur = 0,
    this.elevated = false,
    this.borderColor,
    this.fillColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blur;
  final bool elevated;
  final Color? borderColor;
  final Color? fillColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final radius = BorderRadius.circular(borderRadius);
    final effectiveFill =
        fillColor ?? (elevated ? colors.glassFillElevated : colors.glassFill);
    final effectiveBorder = borderColor ?? colors.glassBorder;
    final useGradient = blur <= 0 && fillColor == null;

    final inner = Container(
      decoration: BoxDecoration(
        color: useGradient ? null : effectiveFill,
        gradient: useGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  effectiveFill,
                  colors.glassFill,
                ],
              )
            : null,
        borderRadius: radius,
        border: Border.all(color: effectiveBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: colors.glassShadow,
            blurRadius: blur > 0 ? 18 : 12,
            offset: Offset(0, blur > 0 ? 6 : 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );

    if (blur <= 0) {
      return inner;
    }

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: inner,
      ),
    );
  }
}

/// Circular frosted glass button (44-48dp) with optional numeric badge dot.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.badgeCount = 0,
    this.size = 46,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final int badgeCount;
  final double size;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      label: tooltip,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GlassContainer(
              borderRadius: AppRadius.pill,
              blur: 0,
              elevated: true,
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  icon,
                  size: AppIconSize.md,
                  color: iconColor ?? colors.textPrimary,
                ),
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: colors.surface, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact frosted pill button for actions such as "+ Add" and "Auto-Plan".
class GlassPillButton extends StatelessWidget {
  const GlassPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GlassContainer(
      borderRadius: AppRadius.pill,
      blur: 0,
      elevated: selected,
      borderColor: selected ? colors.primary : colors.glassBorder,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: iconColor ??
                  (selected ? colors.primary : colors.textPrimary),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the custom app logo mark with a crisp vector painter fallback.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.glassFillElevated,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: colors.glassBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: colors.glassShadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/app_logo.png',
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => CustomPaint(
          painter: _FallbackLogoPainter(accent: colors.primary),
        ),
      ),
    );
  }
}

class _FallbackLogoPainter extends CustomPainter {
  const _FallbackLogoPainter({required this.accent});
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.26, size.height * 0.54)
      ..lineTo(size.width * 0.44, size.height * 0.70)
      ..lineTo(size.width * 0.74, size.height * 0.34);
    canvas.drawPath(path, paint);

    final starPaint = Paint()..color = accent;
    final cx = size.width * 0.72;
    final cy = size.height * 0.26;
    final r = size.width * 0.08;
    final star = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r * 0.3, cy - r * 0.3)
      ..lineTo(cx + r, cy)
      ..lineTo(cx + r * 0.3, cy + r * 0.3)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r * 0.3, cy + r * 0.3)
      ..lineTo(cx - r, cy)
      ..lineTo(cx - r * 0.3, cy - r * 0.3)
      ..close();
    canvas.drawPath(star, starPaint);
  }

  @override
  bool shouldRepaint(covariant _FallbackLogoPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
