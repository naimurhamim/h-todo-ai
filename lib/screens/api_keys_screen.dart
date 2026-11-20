import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
                        GlassContainer(
                          borderRadius: AppRadius.md,
                          blur: 0,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(
                            'Paste API keys for Google Gemini, Groq, xAI Grok, OpenRouter, or a custom endpoint. Tap Load Models or Test API to verify live models, and tap Set Active to choose which provider runs.',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
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
