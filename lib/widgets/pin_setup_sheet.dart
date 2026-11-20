import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/security_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/glass_surface.dart';

/// Operation modes for [PinSetupSheet].
enum PinSetupMode { create, change, disable }

/// Frosted modal sheet for creating, changing, or disabling the 4-digit pass lock.
class PinSetupSheet extends StatefulWidget {
  const PinSetupSheet({super.key, required this.mode});

  final PinSetupMode mode;

  static Future<bool?> show(BuildContext context, PinSetupMode mode) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PinSetupSheet(mode: mode),
    );
  }

  @override
  State<PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<PinSetupSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.mode) {
      case PinSetupMode.create:
        return 'Set 4-Digit Pass Lock';
      case PinSetupMode.change:
        return 'Change Pass Lock PIN';
      case PinSetupMode.disable:
        return 'Disable Pass Lock';
    }
  }

  Future<void> _submit() async {
    final sec = context.read<SecurityProvider>();
    final currentPin = _currentCtrl.text.trim();
    final newPin = _newCtrl.text.trim();
    final confirmPin = _confirmCtrl.text.trim();

    if (widget.mode != PinSetupMode.create && currentPin.length != 4) {
      setState(() => _error = 'Enter your current 4-digit PIN.');
      return;
    }

    if (widget.mode != PinSetupMode.disable) {
      if (!RegExp(r'^\d{4}$').hasMatch(newPin)) {
        setState(() => _error = 'New PIN must be exactly 4 digits.');
        return;
      }
      if (newPin != confirmPin) {
        setState(() => _error = 'PINs do not match.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    bool ok = false;
    switch (widget.mode) {
      case PinSetupMode.create:
        await sec.enablePin(newPin);
        ok = true;
      case PinSetupMode.change:
        ok = await sec.changePin(currentPin, newPin);
      case PinSetupMode.disable:
        ok = await sec.disablePin(currentPin);
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok) {
      setState(() => _error = 'Current PIN is incorrect.');
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: GlassContainer(
        borderRadius: AppRadius.xl,
        blur: 18,
        elevated: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GlassCircleButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (widget.mode != PinSetupMode.create) ...[
                _PinInputField(
                  controller: _currentCtrl,
                  label: 'Current 4-Digit PIN',
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (widget.mode != PinSetupMode.disable) ...[
                _PinInputField(
                  controller: _newCtrl,
                  label: 'New 4-Digit PIN',
                ),
                const SizedBox(height: AppSpacing.md),
                _PinInputField(
                  controller: _confirmCtrl,
                  label: 'Confirm 4-Digit PIN',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(
                    widget.mode == PinSetupMode.disable
                        ? 'Disable Pass Lock'
                        : 'Save Pass Lock',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinInputField extends StatelessWidget {
  const _PinInputField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 4,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
      ),
    );
  }
}
