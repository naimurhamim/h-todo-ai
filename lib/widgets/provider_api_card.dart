import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ai_provider_config.dart';
import '../services/ai_parser_service.dart';
import '../theme/app_tokens.dart';
import 'glass_surface.dart';

/// Card for pasting, saving, discovering live models, testing, and activating an AI provider.
class ProviderApiCard extends StatefulWidget {
  const ProviderApiCard({
    super.key,
    required this.config,
    required this.modelOptions,
    required this.isActive,
    required this.onSetActive,
    required this.onSave,
    required this.onTest,
    required this.onLoadModels,
  });

  final AiProviderConfig config;
  final List<String> modelOptions;
  final bool isActive;
  final VoidCallback onSetActive;
  final Future<void> Function(AiProviderConfig updated) onSave;
  final Future<ApiTestResult> Function() onTest;
  final Future<List<String>> Function() onLoadModels;

  @override
  State<ProviderApiCard> createState() => _ProviderApiCardState();
}

class _ProviderApiCardState extends State<ProviderApiCard> {
  late final TextEditingController _keyCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _baseUrlCtrl;

  bool _obscureKey = true;
  bool _dirty = false;
  bool _testing = false;
  bool _loadingModels = false;
  ApiTestResult? _testResult;
  String? _modelStatusText;
  bool _modelStatusError = false;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: widget.config.apiKey);
    _modelCtrl = TextEditingController(text: widget.config.model);
    _baseUrlCtrl = TextEditingController(text: widget.config.baseUrl);
  }

  @override
  void didUpdateWidget(covariant ProviderApiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.model != widget.config.model &&
        _modelCtrl.text != widget.config.model) {
      _modelCtrl.text = widget.config.model;
      _dirty = false;
    }
    if (!_dirty && oldWidget.config != widget.config) {
      if (_keyCtrl.text != widget.config.apiKey) {
        _keyCtrl.text = widget.config.apiKey;
      }
      if (_baseUrlCtrl.text != widget.config.baseUrl) {
        _baseUrlCtrl.text = widget.config.baseUrl;
      }
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCurrent({bool showFeedback = true}) async {
    final updated = widget.config.copyWith(
      apiKey: _keyCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      baseUrl: _baseUrlCtrl.text.trim(),
    );
    await widget.onSave(updated);
    if (mounted) {
      setState(() => _dirty = false);
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.config.displayName} saved.')),
        );
      }
    }
  }

  Future<void> _pasteKey() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasted = data?.text?.trim() ?? '';
    if (pasted.isEmpty) return;
    setState(() {
      _keyCtrl.text = pasted;
      _dirty = true;
      _testResult = null;
      _modelStatusText = null;
    });
    await _saveCurrent();
  }

  Future<void> _runLoadModels() async {
    if (_dirty) {
      await _saveCurrent(showFeedback: false);
    }
    setState(() {
      _loadingModels = true;
      _modelStatusText = null;
      _modelStatusError = false;
    });
    try {
      final list = await widget.onLoadModels();
      if (mounted) {
        setState(() {
          _loadingModels = false;
          _modelStatusError = list.isEmpty;
          _modelStatusText = list.isEmpty
              ? 'No compatible chat models returned.'
              : 'Loaded ${list.length} live models.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingModels = false;
          _modelStatusError = true;
          _modelStatusText = e.toString();
        });
      }
    }
  }

  Future<void> _runTest() async {
    if (_dirty) {
      await _saveCurrent(showFeedback: false);
    }
    setState(() {
      _testing = true;
      _testResult = null;
      _modelStatusText = null;
    });
    final res = await widget.onTest();
    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final active = widget.isActive;
    final hasKey = _keyCtrl.text.trim().isNotEmpty;

    return GlassContainer(
      borderRadius: AppRadius.md,
      blur: 0,
      elevated: active,
      borderColor: active ? colors.primary : colors.glassBorder,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.config.displayName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.config.subtitle,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (active)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: colors.onPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Active',
                        style: textTheme.labelMedium?.copyWith(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton(
                  onPressed: widget.onSetActive,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(88, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  child: const Text('Set Active'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _keyCtrl,
            obscureText: _obscureKey,
            onChanged: (_) => setState(() {
              _dirty = true;
              _testResult = null;
              _modelStatusText = null;
            }),
            decoration: InputDecoration(
              labelText: 'API Key',
              hintText: widget.config.hintText,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _obscureKey ? 'Show API key' : 'Hide API key',
                    onPressed: () =>
                        setState(() => _obscureKey = !_obscureKey),
                    icon: Icon(
                      _obscureKey
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: AppIconSize.md,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Paste from clipboard',
                    onPressed: _pasteKey,
                    icon: const Icon(
                      Icons.content_paste_rounded,
                      size: AppIconSize.md,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _modelCtrl,
            onChanged: (_) => setState(() => _dirty = true),
            decoration: InputDecoration(
              labelText: 'Model',
              hintText: 'e.g. gemini-3.8-flash or tap Load Models',
              suffixIcon: IconButton(
                tooltip: 'Load live models from API',
                onPressed: (_loadingModels || !hasKey) ? null : _runLoadModels,
                icon: _loadingModels
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: AppIconSize.md),
              ),
            ),
          ),
          if (widget.modelOptions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: widget.modelOptions.map((modelName) {
                final selected = _modelCtrl.text.trim() == modelName;
                return ChoiceChip(
                  label: Text(modelName),
                  selected: selected,
                  onSelected: (_) async {
                    setState(() {
                      _modelCtrl.text = modelName;
                      _dirty = true;
                    });
                    await _saveCurrent(showFeedback: false);
                  },
                );
              }).toList(),
            ),
          ],
          if (widget.config.id == AiProviderType.custom) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _baseUrlCtrl,
              onChanged: (_) => setState(() => _dirty = true),
              decoration: const InputDecoration(
                labelText: 'Base Endpoint URL',
                hintText: 'https://api.example.com/v1/chat/completions',
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _dirty ? () => _saveCurrent() : null,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(_dirty ? 'Save' : 'Saved'),
              ),
              OutlinedButton.icon(
                onPressed: (_testing || !hasKey) ? null : _runTest,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bolt_rounded, size: 18),
                label: Text(_testing ? 'Testing...' : 'Test API'),
              ),
              OutlinedButton.icon(
                onPressed: (_loadingModels || !hasKey) ? null : _runLoadModels,
                icon: _loadingModels
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 18),
                label: Text(_loadingModels ? 'Loading...' : 'Load Models'),
              ),
              if (!active && hasKey)
                TextButton(
                  onPressed: widget.onSetActive,
                  child: const Text('Use Now'),
                ),
            ],
          ),
          if (_modelStatusText != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  _modelStatusError
                      ? Icons.error_outline_rounded
                      : Icons.info_outline_rounded,
                  size: AppIconSize.sm,
                  color: _modelStatusError ? colors.danger : colors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _modelStatusText!,
                    style: textTheme.bodySmall?.copyWith(
                      color: _modelStatusError
                          ? colors.danger
                          : colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_testResult != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  _testResult!.ok
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  size: AppIconSize.sm,
                  color: _testResult!.ok ? colors.success : colors.danger,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _testResult!.message,
                    style: textTheme.bodySmall?.copyWith(
                      color: _testResult!.ok ? colors.success : colors.danger,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
