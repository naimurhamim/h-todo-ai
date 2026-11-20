import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/security_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/glass_surface.dart';

/// Frosted glass privacy lock overlay with 4-digit PIN keypad & fingerprint unlock.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  String _enteredPin = '';
  String? _errorText;
  bool _triggeredAutoBio = false;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _triggeredAutoBio) return;
      _triggeredAutoBio = true;
      final sec = context.read<SecurityProvider>();
      if (sec.biometricEnabled) {
        sec.tryBiometricUnlock();
      }
    });
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _enteredPin += digit;
      _errorText = null;
    });

    if (_enteredPin.length == 4) {
      final sec = context.read<SecurityProvider>();
      final ok = sec.verifyAndUnlock(_enteredPin);
      if (!ok) {
        _shakeCtrl.forward(from: 0);
        setState(() {
          _enteredPin = '';
          _errorText = 'Incorrect PIN. Try again.';
        });
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sec = context.watch<SecurityProvider>();
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: GlassBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLogoMark(size: 72),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'H-TODO AI',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter your 4-digit pass lock',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AnimatedBuilder(
                      animation: _shakeCtrl,
                      builder: (context, child) {
                        final offset =
                            math.sin(_shakeCtrl.value * math.pi * 4) * 10;
                        return Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          final filled = i < _enteredPin.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled
                                  ? colors.primary
                                  : colors.glassFill,
                              border: Border.all(
                                color: filled
                                    ? colors.primary
                                    : colors.textSecondary,
                                width: 1.5,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 20,
                      child: _errorText != null
                          ? Text(
                              _errorText!,
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _PinKeypadGrid(
                      showBiometric: sec.biometricEnabled,
                      onDigit: _onDigit,
                      onBackspace: _onBackspace,
                      onBiometric: sec.tryBiometricUnlock,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinKeypadGrid extends StatelessWidget {
  const _PinKeypadGrid({
    required this.showBiometric,
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
  });

  final bool showBiometric;
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    Widget digitButton(String d) => _KeypadCircle(
          label: d,
          onTap: () => onDigit(d),
        );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [digitButton('1'), digitButton('2'), digitButton('3')],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [digitButton('4'), digitButton('5'), digitButton('6')],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [digitButton('7'), digitButton('8'), digitButton('9')],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (showBiometric)
              _KeypadIconCircle(
                icon: Icons.fingerprint_rounded,
                tooltip: 'Unlock with fingerprint',
                onTap: onBiometric,
                accent: true,
              )
            else
              const SizedBox(width: 72, height: 72),
            digitButton('0'),
            _KeypadIconCircle(
              icon: Icons.backspace_outlined,
              tooltip: 'Delete digit',
              onTap: onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadCircle extends StatelessWidget {
  const _KeypadCircle({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: AppRadius.pill,
      blur: 12,
      elevated: true,
      onTap: onTap,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

class _KeypadIconCircle extends StatelessWidget {
  const _KeypadIconCircle({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      label: tooltip,
      button: true,
      child: GlassContainer(
        borderRadius: AppRadius.pill,
        blur: 12,
        elevated: true,
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Icon(
            icon,
            size: 26,
            color: accent ? colors.primary : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
