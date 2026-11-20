import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/glass_surface.dart';
import 'ai_chat_screen.dart';
import 'overview_screen.dart';
import 'settings_screen.dart';
import 'tasks_screen.dart';

/// Top-level glassmorphic navigation shell with animated page transitions & floating dock.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.notifications});

  final NotificationService notifications;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  Widget _buildActivePage() {
    switch (_selectedIndex) {
      case 0:
        return OverviewScreen(
          key: const ValueKey(0),
          onGoToPlan: () => _selectTab(1),
          onGoToAiChat: () => _selectTab(2),
          onGoToProfile: () => _selectTab(3),
        );
      case 1:
        return TasksScreen(
          key: const ValueKey(1),
          onGoToAiChat: () => _selectTab(2),
          onGoToSettings: () => _selectTab(3),
        );
      case 2:
        return AiChatScreen(
          key: const ValueKey(2),
          onGoToSettings: () => _selectTab(3),
        );
      default:
        return SettingsScreen(
          key: const ValueKey(3),
          notifications: widget.notifications,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.railBreakpoint;
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    final colors = context.appColors;

    final pageView = AnimatedSwitcher(
      duration:
          disableAnim ? Duration.zero : const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.02, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _buildActivePage(),
    );

    if (wide) {
      return Scaffold(
        body: GlassBackdrop(
          child: Row(
            children: [
              GlassContainer(
                borderRadius: 0,
                blur: 14,
                child: NavigationRail(
                  backgroundColor: Colors.transparent,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectTab,
                  labelType: NavigationRailLabelType.all,
                  indicatorColor: colors.primarySoft,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: Text('Overview'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.assignment_outlined),
                      selectedIcon: Icon(Icons.assignment_rounded),
                      label: Text('Plan'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.auto_awesome_outlined),
                      selectedIcon: Icon(Icons.auto_awesome_rounded),
                      label: Text('AI Chat'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: Text('Profile'),
                    ),
                  ],
                ),
              ),
              Expanded(child: pageView),
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
            Positioned.fill(child: pageView),
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
                      child: _FloatingGlassNav(
                        selectedIndex: _selectedIndex,
                        onSelect: _selectTab,
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
    required this.onSelect,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GlassContainer(
      borderRadius: 36,
      blur: 18,
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
  });

  final IconData icon;
  final IconData activeIcon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

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
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? colors.primary : Colors.transparent,
            ),
            child: Icon(
              selected ? activeIcon : icon,
              size: 23,
              color: selected ? colors.onPrimary : colors.textPrimary,
            ),
          ),
        ),
      ),
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
            duration: const Duration(milliseconds: 220),
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
