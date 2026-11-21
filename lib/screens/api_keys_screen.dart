import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/ai_settings_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/glass_surface.dart';
import '../widgets/provider_api_card.dart';

/// Dedicated frosted glass page for pasting, testing, discovering models, and activating AI API keys.
class ApiKeysScreen extends StatelessWidget {
  const ApiKeysScreen({super.key});

  /// Navigates to [ApiKeysScreen] with a smooth fade+slide transition.
  static Future<void> open(BuildContext context) {
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration:
            disableAnim ? Duration.zero : const Duration(milliseconds: 240),
        reverseTransitionDuration:
            disableAnim ? Duration.zero : const Duration(milliseconds: 200),
        pageBuilder: (_, _, _) => const ApiKeysScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiSettings = context.watch<AiSettingsProvider>();
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: GlassBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.maxContentWidth,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        GlassCircleButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          tooltip: 'Back',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'AI API Keys',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        GlassContainer(
                          borderRadius: AppRadius.pill,
                          blur: 0,
                          elevated: true,
                          borderColor: colors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${aiSettings.activeProvider.displayName.split(' ').first} • Active',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _ApiGuidebookCard(),
                          const SizedBox(height: AppSpacing.md),
                          for (var i = 0;
                              i < aiSettings.providerList.length;
                              i++) ...[
                            if (i > 0) const SizedBox(height: AppSpacing.md),
                            ProviderApiCard(
                              config: aiSettings.providerList[i],
                              modelOptions: aiSettings.modelsForProvider(
                                aiSettings.providerList[i].id,
                              ),
                              isActive: aiSettings.providerList[i].id ==
                                  aiSettings.activeProviderType,
                              onSetActive: () => aiSettings.setActiveProvider(
                                aiSettings.providerList[i].id,
                              ),
                              onSave: aiSettings.updateProviderConfig,
                              onTest: () => aiSettings.testProvider(
                                aiSettings.providerList[i].id,
                              ),
                              onLoadModels: () => aiSettings.loadLiveModels(
                                aiSettings.providerList[i].id,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ApiGuidebookCard extends StatefulWidget {
  const _ApiGuidebookCard();

  @override
  State<_ApiGuidebookCard> createState() => _ApiGuidebookCardState();
}

class _ApiGuidebookCardState extends State<_ApiGuidebookCard> {
  bool _expanded = false;

  Future<void> _openConsole(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open browser')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return GlassContainer(
      borderRadius: AppRadius.md,
      blur: 0,
      elevated: true,
      borderColor: colors.glassBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 20,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'API Key Guidebook',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Step-by-step instructions to get a free key (Groq recommended)',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '1. Sign in to one of the free AI consoles below (no credit card needed for Groq, Gemini, or OpenRouter).\n'
                    '2. Tap Create API Key and copy the key.\n'
                    '3. Return here, tap Paste on that provider card, tap Test API, and tap Set Active.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _GuideLinkRow(
                    title: 'Groq Console (Recommended • Fastest Free)',
                    urlLabel: 'console.groq.com/keys',
                    onTap: () => _openConsole('https://console.groq.com/keys'),
                  ),
                  const Divider(height: 1),
                  _GuideLinkRow(
                    title: 'Google AI Studio (Gemini Free)',
                    urlLabel: 'aistudio.google.com/app/apikey',
                    onTap: () =>
                        _openConsole('https://aistudio.google.com/app/apikey'),
                  ),
                  const Divider(height: 1),
                  _GuideLinkRow(
                    title: 'OpenRouter (Free Models)',
                    urlLabel: 'openrouter.ai/keys',
                    onTap: () => _openConsole('https://openrouter.ai/keys'),
                  ),
                  const Divider(height: 1),
                  _GuideLinkRow(
                    title: 'xAI Console (Grok)',
                    urlLabel: 'console.x.ai',
                    onTap: () => _openConsole('https://console.x.ai/'),
                  ),
                ],
              ),
            ),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

class _GuideLinkRow extends StatelessWidget {
  const _GuideLinkRow({
    required this.title,
    required this.urlLabel,
    required this.onTap,
  });

  final String title;
  final String urlLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    urlLabel,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: colors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
