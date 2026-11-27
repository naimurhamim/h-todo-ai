import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/reminder_settings.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/cloud_sync_provider.dart';
import '../providers/security_provider.dart';
import '../providers/task_provider.dart';
import '../providers/update_provider.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/cloud_backup_card.dart';
import '../widgets/glass_surface.dart';
import '../widgets/pin_setup_sheet.dart';
import 'api_keys_screen.dart';

/// "Profile" screen matching the right glassmorphism reference layout with drop-down controls.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.notifications,
    this.openUpdateSignal = 0,
    this.openCloudSignal = 0,
  });

  final NotificationService notifications;
  final int openUpdateSignal;
  final int openCloudSignal;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _checkUpdatesKey = GlobalKey();
  final GlobalKey _cloudSectionKey = GlobalKey();

  String? _expandedSection;
  String _appVersion = '1.0.0';
  int _handledUpdateSignal = 0;
  int _handledCloudSignal = 0;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _checkNavigationSignals();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkNavigationSignals();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkNavigationSignals() {
    if (widget.openUpdateSignal > _handledUpdateSignal) {
      _handledUpdateSignal = widget.openUpdateSignal;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToKey(_checkUpdatesKey);
        _handleCheckForUpdates();
      });
    }
    if (widget.openCloudSignal > _handledCloudSignal) {
      _handledCloudSignal = widget.openCloudSignal;
      setState(() => _expandedSection = 'cloud');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToKey(_cloudSectionKey);
      });
    }
  }

  void _scrollToKey(GlobalKey key) {
    final targetContext = key.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.35,
      );
    }
  }

  Future<void> _handleCheckForUpdates() async {
    final updateProvider = context.read<UpdateProvider>();
    final available = updateProvider.availableUpdate;
    if (available != null) {
      await UpdateService.showUpdateAvailableDialog(context, available);
      return;
    }
    await UpdateService.checkForUpdate(context);
  }

  Future<void> _loadAppVersion() async {
    final version = await UpdateService.getCurrentVersion();
    if (mounted) {
      setState(() => _appVersion = version);
    }
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  void _toggleSection(String key) {
    setState(() {
      _expandedSection = (_expandedSection == key) ? null : key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final aiSettings = context.watch<AiSettingsProvider>();
    final taskProvider = context.read<TaskProvider>();
    final cloud = context.watch<CloudSyncProvider>();
    final security = context.watch<SecurityProvider>();
    final updateProvider = context.watch<UpdateProvider>();
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final reminder = aiSettings.reminderSettings;
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.railBreakpoint;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              wide ? AppSpacing.xl : AppLayout.navClearance,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Profile',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (security.hasPin)
                    GlassCircleButton(
                      icon: Icons.lock_outline_rounded,
                      tooltip: 'Lock app now',
                      onTap: security.lockNow,
                    )
                  else if (cloud.isSignedIn)
                    GlassCircleButton(
                      icon: Icons.logout_rounded,
                      tooltip: 'Sign out',
                      onTap: cloud.signOut,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              GlassContainer(
                borderRadius: AppRadius.lg,
                blur: 0,
                elevated: true,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ProfileAvatar(
                      photoUrl: cloud.userPhotoUrl,
                      name: cloud.userName ?? cloud.userEmail,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (cloud.userName != null &&
                                    cloud.userName!.trim().isNotEmpty)
                                ? cloud.userName!
                                : 'H-TODO AI',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cloud.isSignedIn
                                ? (cloud.userEmail ?? 'Private Google Drive')
                                : 'Local device profile',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            children: [
                              if (!cloud.isSignedIn)
                                GlassPillButton(
                                  icon: Icons.login_rounded,
                                  label: cloud.isAvailable
                                      ? 'Google Sign-In'
                                      : 'Data Backup',
                                  onTap: () {
                                    if (cloud.isAvailable) {
                                      cloud.signInWithGoogle();
                                    } else {
                                      _toggleSection('cloud');
                                    }
                                  },
                                )
                              else ...[
                                GlassPillButton(
                                  icon: Icons.cloud_upload_outlined,
                                  label: cloud.isSyncing
                                      ? 'Syncing...'
                                      : 'Backup',
                                  onTap: cloud.backupNow,
                                ),
                                GlassPillButton(
                                  icon: Icons.cloud_download_outlined,
                                  label: 'Restore',
                                  onTap: () => _toggleSection('cloud'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GlassContainer(
                borderRadius: AppRadius.lg,
                blur: 0,
                onTap: () => ApiKeysScreen.open(context),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    gradient: LinearGradient(
                      colors: [
                        colors.primarySoft,
                        colors.surfaceSubtle,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.glassFillElevated,
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: colors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active AI: ${aiSettings.activeProvider.displayName}',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                aiSettings.hasActiveApiKey
                                    ? 'Model: ${aiSettings.activeProvider.model}'
                                    : 'Tap to paste a free Gemini or Groq API key',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GlassContainer(
                borderRadius: AppRadius.lg,
                blur: 0,
                elevated: true,
                child: Column(
                  children: [
                    _ProfileNavRow(
                      icon: Icons.key_rounded,
                      title: 'AI API Keys',
                      subtitle: aiSettings.hasActiveApiKey
                          ? '${aiSettings.activeProvider.displayName} • Active'
                          : 'Configure Gemini, Groq, Grok, OpenRouter',
                      onTap: () => ApiKeysScreen.open(context),
                    ),
                    const Divider(height: 1),
                    _ProfileAccordionSection(
                      icon: Icons.lock_outline_rounded,
                      title: 'Privacy & App Lock',
                      subtitle: security.hasPin
                          ? (security.biometricEnabled
                              ? 'PIN + Fingerprint Lock enabled'
                              : '4-digit Pass Lock enabled')
                          : 'Protect tasks & API keys with PIN + Fingerprint',
                      expanded: _expandedSection == 'privacy',
                      onToggle: () => _toggleSection('privacy'),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: _PrivacyLockPanel(security: security),
                      ),
                    ),
                    const Divider(height: 1),
                    _ProfileAccordionSection(
                      icon: Icons.notifications_none_rounded,
                      title: 'Reminders',
                      subtitle: reminder.enabled
                          ? 'Day before ${ReminderSettings.formatHourMinute(reminder.dayBeforeHour, reminder.dayBeforeMinute)} • Due day ${ReminderSettings.formatHourMinute(reminder.endOfDayHour, reminder.endOfDayMinute)}'
                          : 'Notifications paused',
                      expanded: _expandedSection == 'reminders',
                      onToggle: () => _toggleSection('reminders'),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: _RemindersPanel(
                          reminder: reminder,
                          aiSettings: aiSettings,
                          taskProvider: taskProvider,
                          notifications: widget.notifications,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    _ProfileAccordionSection(
                      icon: Icons.palette_outlined,
                      title: 'Appearance',
                      subtitle: _themeLabel(aiSettings.themeMode),
                      expanded: _expandedSection == 'appearance',
                      onToggle: () => _toggleSection('appearance'),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: Icon(Icons.brightness_auto_outlined),
                                label: Text('System'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: Icon(Icons.light_mode_outlined),
                                label: Text('Light'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode_outlined),
                                label: Text('Dark'),
                              ),
                            ],
                            selected: {aiSettings.themeMode},
                            onSelectionChanged: (selected) {
                              aiSettings.setThemeMode(selected.first);
                            },
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    _ProfileAccordionSection(
                      key: _cloudSectionKey,
                      icon: Icons.cloud_outlined,
                      title: 'Google Drive & Data Backup',
                      subtitle: cloud.isSignedIn
                          ? 'Private Drive (${cloud.userEmail ?? 'Connected'})'
                          : 'Private Google Drive sync & JSON Export/Import',
                      expanded: _expandedSection == 'cloud',
                      onToggle: () => _toggleSection('cloud'),
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: CloudBackupCard(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
                child: Text(
                  'About',
                  style: textTheme.titleSmall?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GlassContainer(
                borderRadius: AppRadius.lg,
                blur: 0,
                elevated: true,
                child: Column(
                  children: [
                    _AboutInfoRow(
                      icon: Icons.info_outline_rounded,
                      title: 'H-TODO AI',
                      subtitle: 'Version $_appVersion',
                    ),
                    const Divider(height: 1),
                    _ProfileNavRow(
                      key: _checkUpdatesKey,
                      icon: Icons.system_update_rounded,
                      title: 'Check for Updates',
                      subtitle: updateProvider.hasUpdate
                          ? 'New version v${updateProvider.availableUpdate!.latestVersion} available'
                          : 'Verify latest release on GitHub',
                      trailing: updateProvider.hasUpdate
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: colors.primarySoft,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                'New',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : null,
                      onTap: _handleCheckForUpdates,
                    ),
                    const Divider(height: 1),
                    const _AboutInfoRow(
                      icon: Icons.storage_outlined,
                      title: 'Data Storage',
                      subtitle:
                          'On-device + private Google Drive (appDataFolder)',
                    ),
                    const Divider(height: 1),
                    const _AboutInfoRow(
                      icon: Icons.verified_user_outlined,
                      title: 'Privacy',
                      subtitle:
                          'Backups stay in your own Google Drive; zero server access',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
                child: Text(
                  'Developer',
                  style: textTheme.titleSmall?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GlassContainer(
                borderRadius: AppRadius.lg,
                blur: 0,
                elevated: true,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.glassBorder),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/Naimur_Hamim.jpg',
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const AppLogoMark(size: 56),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MD Naimur Rashid',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Creator',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1),
                    _DeveloperLinkRow(
                      icon: Icons.language_rounded,
                      label: 'Website',
                      value: 'naimurrashid.dev',
                      onTap: () =>
                          _openExternalUrl('https://naimurrashid.dev/'),
                    ),
                    const Divider(height: 1),
                    _DeveloperLinkRow(
                      icon: Icons.code_rounded,
                      label: 'GitHub',
                      value: 'github.com/naimurhamim',
                      onTap: () =>
                          _openExternalUrl('https://github.com/naimurhamim'),
                    ),
                    const Divider(height: 1),
                    _DeveloperLinkRow(
                      icon: Icons.work_outline_rounded,
                      label: 'LinkedIn',
                      value: 'md-naimur-rashid',
                      onTap: () => _openExternalUrl(
                        'https://www.linkedin.com/in/md-naimur-rashid/',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  static String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light Glass';
      case ThemeMode.dark:
        return 'Dark Glass';
      case ThemeMode.system:
        return 'Follow System';
    }
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.photoUrl, required this.name});

  final String? photoUrl;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    if (hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.network(
          photoUrl!,
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const AppLogoMark(size: 68),
        ),
      );
    }
    return const AppLogoMark(size: 68);
  }
}

class _ProfileNavRow extends StatelessWidget {
  const _ProfileNavRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.quarterTurns = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final double quarterTurns;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceSubtle,
              ),
              child: Icon(icon, size: 19, color: colors.textPrimary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            ?trailing,
            AnimatedRotation(
              turns: quarterTurns,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAccordionSection extends StatelessWidget {
  const _ProfileAccordionSection({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProfileNavRow(
          icon: icon,
          title: title,
          subtitle: subtitle,
          onTap: onToggle,
          quarterTurns: expanded ? 0.25 : 0,
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: child,
          crossFadeState:
              expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }
}

class _PrivacyLockPanel extends StatelessWidget {
  const _PrivacyLockPanel({required this.security});

  final SecurityProvider security;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GlassContainer(
      borderRadius: AppRadius.md,
      blur: 0,
      fillColor: colors.surfaceSubtle,
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('4-Digit Pass Lock'),
            subtitle: Text(
              security.hasPin
                  ? 'PIN protection active'
                  : 'Require PIN before opening app',
            ),
            value: security.hasPin,
            onChanged: (next) async {
              if (next) {
                await PinSetupSheet.show(context, PinSetupMode.create);
              } else {
                await PinSetupSheet.show(context, PinSetupMode.disable);
              }
            },
          ),
          if (security.hasPin) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.password_rounded),
              title: const Text('Change Pass Lock PIN'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => PinSetupSheet.show(context, PinSetupMode.change),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Fingerprint Unlock'),
              subtitle: Text(
                security.biometricsAvailable
                    ? 'Unlock quickly using device fingerprint'
                    : 'No biometric sensor/fingerprint enrolled on this device',
              ),
              value: security.biometricEnabled,
              onChanged: security.biometricsAvailable
                  ? (enabled) async {
                      final ok = await security.setBiometricEnabled(enabled);
                      if (!ok && enabled && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fingerprint verification failed.'),
                          ),
                        );
                      }
                    }
                  : null,
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Lock When Minimized'),
              subtitle: const Text('Re-lock automatically on resume'),
              value: security.lockOnResume,
              onChanged: security.setLockOnResume,
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: security.lockNow,
                  icon: const Icon(Icons.lock_outline_rounded, size: 18),
                  label: const Text('Lock Now'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RemindersPanel extends StatelessWidget {
  const _RemindersPanel({
    required this.reminder,
    required this.aiSettings,
    required this.taskProvider,
    required this.notifications,
  });

  final ReminderSettings reminder;
  final AiSettingsProvider aiSettings;
  final TaskProvider taskProvider;
  final NotificationService notifications;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return GlassContainer(
      borderRadius: AppRadius.md,
      blur: 0,
      fillColor: colors.surfaceSubtle,
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Day-before + end-of-day check-in alerts'),
            value: reminder.enabled,
            onChanged: (value) async {
              await aiSettings.updateReminderSettings(
                reminder.copyWith(enabled: value),
                onReschedule: taskProvider.rescheduleAllNotifications,
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Day-Before Reminder'),
            subtitle: const Text('Alert 1 day prior to due date'),
            trailing: Text(
              ReminderSettings.formatHourMinute(
                reminder.dayBeforeHour,
                reminder.dayBeforeMinute,
              ),
              style: textTheme.labelLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            onTap: () => _pickReminderTime(
              context: context,
              initial: reminder.dayBeforeTime,
              onPicked: (picked) => aiSettings.updateReminderSettings(
                reminder.copyWith(
                  dayBeforeHour: picked.hour,
                  dayBeforeMinute: picked.minute,
                ),
                onReschedule: taskProvider.rescheduleAllNotifications,
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.task_alt_rounded),
            title: const Text('End-of-Day Check-In'),
            subtitle: const Text('Prompt on due date to cross off tasks'),
            trailing: Text(
              ReminderSettings.formatHourMinute(
                reminder.endOfDayHour,
                reminder.endOfDayMinute,
              ),
              style: textTheme.labelLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            onTap: () => _pickReminderTime(
              context: context,
              initial: reminder.endOfDayTime,
              onPicked: (picked) => aiSettings.updateReminderSettings(
                reminder.copyWith(
                  endOfDayHour: picked.hour,
                  endOfDayMinute: picked.minute,
                ),
                onReschedule: taskProvider.rescheduleAllNotifications,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final msg = await notifications.showTestNotification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg)),
                    );
                  }
                },
                icon: const Icon(Icons.notifications_outlined, size: 18),
                label: const Text('Send Test Notification'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReminderTime({
    required BuildContext context,
    required TimeOfDay initial,
    required Future<void> Function(TimeOfDay picked) onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      await onPicked(picked);
    }
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.md, color: colors.textPrimary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeveloperLinkRow extends StatelessWidget {
  const _DeveloperLinkRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: AppIconSize.md, color: colors.textPrimary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
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
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
