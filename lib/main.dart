import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/cloud_backup_service.dart';
import 'services/notification_service.dart';
import 'services/security_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Keep app usable offline/locally if Firebase init fails.
    }
  }

  final storage = StorageService();
  final notifications = NotificationService();
  await notifications.init();

  runApp(
    HTodoApp(
      storage: storage,
      notifications: notifications,
      cloudBackup: CloudBackupService(),
      securityService: SecurityService(),
    ),
  );
}
