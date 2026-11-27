import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cloud_sync_provider.dart';
import '../providers/update_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/glass_surface.dart';
import 'ai_chat_screen.dart';
import 'overview_screen.dart';
import 'settings_screen.dart';
import 'tasks_screen.dart';

/// Top-level glassmorphic navigation shell with state-preserving tabs, floating dock & status banners.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.notifications});

  final NotificationService notifications;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  final Set<int> _visitedTabs = {0};
  int _openUpdateSignal = 0;
  int _openCloudSignal = 0;

  CloudSyncProvider? _cloudProvider;
  Timer? _cloudBannerTimer;
  int? _lastCloudBannerId;

  @override
  void initState() {
    super.initState();
    widget.notifications.setOnNotificationTap(_handleNotificationTap);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextCloud = context.read<CloudSyncProvider>();
    if (_cloudProvider != nextCloud) {
      _cloudProvider?.removeListener(_onCloudSyncChanged);
      _cloudProvider = nextCloud;
      nextCloud.addListener(_onCloudSyncChanged);
      _scheduleBannerDismissIfNeeded(nextCloud.statusBanner);
    }
  }

  @override
  void dispose() {
    _cloudBannerTimer?.cancel();
    _cloudProvider?.removeListener(_onCloudSyncChanged);
    widget.notifications.setOnNotificationTap(null);
    super.dispose();
  }

  void _onCloudSyncChanged() {
    if (!mounted) return;
    _scheduleBannerDismissIfNeeded(_cloudProvider?.statusBanner);
  }

  void _scheduleBannerDismissIfNeeded(SyncStatusBanner? banner) {
    if (banner == null) {
      _cloudBannerTimer?.cancel();
      _cloudBannerTimer = null;
      _lastCloudBannerId = null;
      return;
    }
    if (banner.id == _lastCloudBannerId) return;
    _lastCloudBannerId = banner.id;
    _cloudBannerTimer?.cancel();
    final duration = banner.kind == SyncBannerKind.error
        ? const Duration(seconds: 6)
        : const Duration(milliseconds: 3500);
    _cloudBannerTimer = Timer(duration, () {
      if (mounted) {
        _cloudProvider?.dismissStatusBanner();
      }
    });
  }

  void _handleNotificationTap(String? payload) {
    if (!mounted) return;
    if (payload == NotificationService.updatePayload) {
      _openCheckForUpdates();
    }
  }

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _visitedTabs.add(index);
      _selectedIndex = index;
    });
  }

  void _openCheckForUpdates() {
    context.read<UpdateProvider>().dismissTopBanner();
    setState(() {
      _visitedTabs.add(3);
      _selectedIndex = 3;
      _openUpdateSignal++;
    });
  }

  void _openCloudBackupSettings() {
    _cloudBannerTimer?.cancel();
    context.read<CloudSyncProvider>().dismissStatusBanner();
    setState(() {
      _visitedTabs.add(3);
      _selectedIndex = 3;
      _openCloudSignal++;
    });
  }

  Widget _buildTabSlot(int index) {
    if (!_visitedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    final Widget page;
    switch (index) {
      case 0:
        page = OverviewScreen(
          key: const ValueKey(0),
          onGoToPlan: () => _selectTab(1),
          onGoToAiChat: () => _selectTab(2),
          onGoToProfile: () => _selectTab(3),
          onGoToUpdate: _openCheckForUpdates,
        );
      case 1:
        page = TasksScreen(
          key: const ValueKey(1),
          onGoToAiChat: () => _selectTab(2),
          onGoToSettings: () => _selectTab(3),
        );
      case 2:
        page = AiChatScreen(
          key: const ValueKey(2),
          onGoToSettings: () => _selectTab(3),
        );
      default:
        page = SettingsScreen(
          key: const ValueKey(3),
          notifications: widget.notifications,
          openUpdateSignal: _openUpdateSignal,
          openCloudSignal: _openCloudSignal,
        );
    }
    return RepaintBoundary(child: page);
  }

  Widget _buildTopStatusBanner(
    BuildContext context,
    UpdateProvider updateProvider,
    CloudSyncProvider cloud,
  ) {
    final updateInfo = updateProvider.availableUpdate;
    final showUpdate = updateProvider.showTopBanner && updateInfo != null;
    final syncBanner = cloud.statusBanner;

    final Widget? bannerChild;
    if (showUpdate) {
      bannerChild = _TopStatusBanner(
        key: ValueKey('update-${updateInfo.latestVersion}'),
        icon: Icons.system_update_rounded,
        message: 'Update v${updateInfo.latestVersion} available',
        actionLabel: 'View',
        isError: false,
        onAction: _openCheckForUpdates,
        onDismiss: updateProvider.dismissTopBanner,
      );
    } else if (syncBanner != null) {
      final isError = syncBanner.kind == SyncBannerKind.error;
      final icon = switch (syncBanner.kind) {
        SyncBannerKind.loaded => Icons.cloud_download_outlined,
        SyncBannerKind.saved => Icons.cloud_upload_outlined,
        SyncBannerKind.synced => Icons.cloud_done_outlined,
        SyncBannerKind.error => Icons.cloud_off_rounded,
      };
      bannerChild = _TopStatusBanner(
        key: ValueKey('sync-${syncBanner.id}'),
        icon: icon,
        message: syncBanner.message,
        actionLabel: syncBanner.canRetry ? 'Sync' : null,
        isError: isError,
        onAction: syncBanner.canRetry ? _openCloudBackupSettings : null,
        onDismiss: () {
          _cloudBannerTimer?.cancel();
          cloud.dismissStatusBanner();
        },
      );
    } else {
      bannerChild = null;
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: bannerChild == null
          ? const SizedBox.shrink()
          : SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: bannerChild,
                  ),
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.railBreakpoint;
    final colors = context.appColors;
    final updateProvider = context.watch<UpdateProvider>();
    final cloud = context.watch<CloudSyncProvider>();
    final hasTopBanner =
        (updateProvider.showTopBanner && updateProvider.availableUpdate != null) ||
        cloud.statusBanner != null;

    final pageStack = IndexedStack(
      index: _selectedIndex,
      children: List<Widget>.generate(4, _buildTabSlot),
    );
    final bodyArea = Column(
      children: [
        _buildTopStatusBanner(context, updateProvider, cloud),
        Expanded(
          child: hasTopBanner
              ? MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: pageStack,
                )
              : pageStack,
        ),
      ],
    );

    if (wide) {
      return Scaffold(
        body: GlassBackdrop(
          child: Row(
            children: [
              GlassContainer(
                borderRadius: 0,
                blur: 10,
                child: NavigationRail(
                  backgroundColor: Colors.transparent,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectTab,
                  labelType: NavigationRailLabelType.all,
                  indicatorColor: colors.primarySoft,
                  destinations: [
                    const NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: Text('Overview'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.assignment_outlined),
                      selectedIcon: Icon(Icons.assignment_rounded),
                      label: Text('Plan'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.auto_awesome_outlined),
                      selectedIcon: Icon(Icons.auto_awesome_rounded),
                      label: Text('AI Chat'),
                    ),
                    NavigationRailDestination(
                      icon: _ProfileDotIcon(
                        icon: const Icon(Icons.person_outline_rounded),
                        showDot: updateProvider.hasUpdate,
                      ),
                      selectedIcon: _ProfileDotIcon(
                        icon: const Icon(Icons.person_rounded),
                        showDot: updateProvider.hasUpdate,
                      ),
                      label: const Text('Profile'),
                    ),
                  ],
                ),
              ),
              Expanded(child: bodyArea),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: GlassBackdrop(
        child: Stack(
          children: [
            Positioned.fill(child: bodyArea),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: RepaintBoundary(
                        child: _FloatingGlassNav(
                          selectedIndex: _selectedIndex,
                          hasUpdate: updateProvider.hasUpdate,
                          onSelect: _selectTab,
                        ),
                      ),
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

class _FloatingGlassNav extends StatelessWidget {
  const _FloatingGlassNav({
    required this.selectedIndex,
    required this.hasUpdate,
    required this.onSelect,
  });

  final int selectedIndex;
  final bool hasUpdate;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GlassContainer(
      borderRadius: 36,
      blur: 10,
      elevated: true,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavOrbButton(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            tooltip: 'Overview',
            selected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
          _NavOrbButton(
            icon: Icons.assignment_outlined,
            activeIcon: Icons.assignment_rounded,
            tooltip: 'Plan',
            selected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
          _AiCenterOrbButton(
            selected: selectedIndex == 2,
            onTap: () => onSelect(2),
            colors: colors,
          ),
          _NavOrbButton(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            tooltip: 'Profile',
            selected: selectedIndex == 3,
            showDot: hasUpdate,
            onTap: () => onSelect(3),
          ),
        ],
      ),
    );
  }
}

class _NavOrbButton extends StatelessWidget {
  const _NavOrbButton({
    required this.icon,
    required this.activeIcon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      label: tooltip,
      button: true,
      selected: selected,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? colors.primary : Colors.transparent,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  size: 23,
                  color: selected ? colors.onPrimary : colors.textPrimary,
                ),
                if (showDot && !selected)
                  Positioned(
                    top: 10,
                    right: 11,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileDotIcon extends StatelessWidget {
  const _ProfileDotIcon({required this.icon, required this.showDot});

  final Widget icon;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    if (!showDot) return icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.appColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _AiCenterOrbButton extends StatelessWidget {
  const _AiCenterOrbButton({
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  final bool selected;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AI Auto-Plan',
      button: true,
      selected: selected,
      child: Tooltip(
        message: 'AI Auto-Plan',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: selected
                  ? LinearGradient(
                      colors: [colors.primary, colors.primary],
                    )
                  : RadialGradient(
                      colors: [
                        colors.primary.withValues(alpha: 0.25),
                        colors.glassFillElevated,
                      ],
                    ),
              border: Border.all(
                color: selected ? colors.primary : colors.glassBorder,
                width: 1.2,
              ),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 24,
              color: selected ? colors.onPrimary : colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopStatusBanner extends StatelessWidget {
  const _TopStatusBanner({
    super.key,
    required this.icon,
    required this.message,
    required this.isError,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final bool isError;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final accentColor = isError ? colors.danger : colors.primary;

    return GlassContainer(
      borderRadius: AppRadius.pill,
      blur: 10,
      elevated: true,
      borderColor: accentColor.withValues(alpha: 0.7),
      onTap: onAction,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  actionLabel!,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.xs),
          InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
