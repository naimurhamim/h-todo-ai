import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'providers/ai_settings_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/cloud_sync_provider.dart';
import 'providers/security_provider.dart';
import 'providers/task_provider.dart';
import 'providers/update_provider.dart';
import 'screens/app_lock_screen.dart';
import 'screens/home_shell.dart';
import 'screens/splash_screen.dart';
import 'services/ai_parser_service.dart';
import 'services/cloud_backup_service.dart';
import 'services/notification_service.dart';
import 'services/security_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

/// Root H-TODO AI application wiring providers, glass themes, privacy lock & splash.
class HTodoApp extends StatelessWidget {
  const HTodoApp({
    super.key,
    required this.storage,
    required this.notifications,
    this.parser,
    this.cloudBackup,
    this.securityService,
    this.updateHttpClient,
    this.currentVersionOverride,
    this.autoCheckUpdates,
    this.skipSplash = false,
  });

  final StorageService storage;
  final NotificationService notifications;
  final AiParserService? parser;
  final CloudBackupService? cloudBackup;
  final SecurityService? securityService;
  final http.Client? updateHttpClient;
  final String? currentVersionOverride;
  final bool? autoCheckUpdates;
  final bool skipSplash;

  @override
  Widget build(BuildContext context) {
    final aiParser = parser ?? AiParserService();
    final backupService = cloudBackup ?? CloudBackupService();
    final secService = securityService ?? SecurityService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AiSettingsProvider>(
          create: (_) => AiSettingsProvider(
            storage: storage,
            parser: aiParser,
          )..load(),
        ),
        ChangeNotifierProvider<TaskProvider>(
          create: (ctx) => TaskProvider(
            storage: storage,
            notifications: notifications,
            readReminderSettings: () =>
                ctx.read<AiSettingsProvider>().reminderSettings,
          )..load(),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(
            storage: storage,
            parser: aiParser,
          )..load(),
        ),
        ChangeNotifierProvider<SecurityProvider>(
          lazy: false,
          create: (_) => SecurityProvider(
            storage: storage,
            securityService: secService,
          )..load(),
        ),
        ChangeNotifierProvider<CloudSyncProvider>(
          lazy: false,
          create: (ctx) => CloudSyncProvider(
            service: backupService,
            storage: storage,
            aiSettings: ctx.read<AiSettingsProvider>(),
            tasks: ctx.read<TaskProvider>(),
            chat: ctx.read<ChatProvider>(),
          ),
        ),
        ChangeNotifierProvider<UpdateProvider>(
          lazy: false,
          create: (_) => UpdateProvider(
            storage: storage,
            notifications: notifications,
            httpClient: updateHttpClient,
            currentVersionOverride: currentVersionOverride,
            autoCheckOnStart: autoCheckUpdates ?? backupService.isAvailable,
          ),
        ),
      ],
      child: Consumer<AiSettingsProvider>(
        builder: (context, aiSettings, _) {
          return MaterialApp(
            title: 'H-TODO AI',
            debugShowCheckedModeBanner: false,
            themeMode: aiSettings.themeMode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: _EntryGate(
              notifications: notifications,
              skipSplash: skipSplash,
            ),
          );
        },
      ),
    );
  }
}

class _EntryGate extends StatefulWidget {
  const _EntryGate({
    required this.notifications,
    required this.skipSplash,
  });

  final NotificationService notifications;
  final bool skipSplash;

  @override
  State<_EntryGate> createState() => _EntryGateState();
}

class _EntryGateState extends State<_EntryGate> with WidgetsBindingObserver {
  late bool _showingSplash;

  @override
  void initState() {
    super.initState();
    _showingSplash = !widget.skipSplash;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    context.read<SecurityProvider>().handleAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(
        context.read<TaskProvider>().refreshRollingNotifications(
              context.read<AiSettingsProvider>().reminderSettings,
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = context.watch<SecurityProvider>();
    final disableAnim = MediaQuery.disableAnimationsOf(context);

    final Widget child;
    if (_showingSplash) {
      child = SplashScreen(
        key: const ValueKey('splash'),
        onFinished: () {
          if (mounted) setState(() => _showingSplash = false);
        },
      );
    } else if (security.isLocked) {
      child = const AppLockScreen(key: ValueKey('lock'));
    } else {
      child = HomeShell(
        key: const ValueKey('home'),
        notifications: widget.notifications,
      );
    }

    return AnimatedSwitcher(
      duration:
          disableAnim ? Duration.zero : const Duration(milliseconds: 320),
      child: child,
    );
  }
}
