import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:h_todo_ai/app.dart';
import 'package:h_todo_ai/models/ai_provider_config.dart';
import 'package:h_todo_ai/models/chat_message.dart';
import 'package:h_todo_ai/models/google_account_profile.dart';
import 'package:h_todo_ai/models/security_settings.dart';
import 'package:h_todo_ai/models/task_item.dart';
import 'package:h_todo_ai/services/cloud_backup_service.dart';
import 'package:h_todo_ai/services/notification_service.dart';
import 'package:h_todo_ai/services/security_service.dart';
import 'package:h_todo_ai/services/storage_service.dart';
import 'package:h_todo_ai/providers/task_provider.dart';
import 'package:h_todo_ai/widgets/notifications_sheet.dart';
import 'package:h_todo_ai/widgets/task_card.dart';
import 'package:h_todo_ai/widgets/task_detail_sheet.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('navigates 4 tabs, expands drop-down subtasks, and crosses out done tasks', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sampleTask = TaskItem(
      id: 't-1',
      notificationBaseId: 101,
      title: 'Assignment 03',
      courseOrCategory: 'IRE 415 – Computer Vision',
      type: TaskType.assignment,
      dueDate: today,
      dueHour: 23,
      dueMinute: 59,
      subtasks: const [
        SubTaskItem(id: 'sub-1', title: 'Gaussian Filter Notes'),
      ],
      createdAt: today,
    );

    SharedPreferences.setMockInitialValues({
      'htodo_tasks_v1': jsonEncode([sampleTask.toJson()]),
    });

    final storage = StorageService();
    final notifications = NotificationService();

    await tester.pumpWidget(
      HTodoApp(
        storage: storage,
        notifications: notifications,
        cloudBackup: CloudBackupService.disabled(),
        securityService: SecurityService.disabled(),
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    // Screen 1: Overview
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Assignment 03'), findsWidgets);

    // Expand drop-down details on task card.
    final expandBtn = find.bySemanticsLabel('Expand Assignment 03 details').first;
    await tester.ensureVisible(expandBtn);
    await tester.tap(expandBtn);
    await tester.pumpAndSettle();
    expect(find.text('Gaussian Filter Notes'), findsOneWidget);

    // Switch to Plan Your Day tab and toggle completion -> strikethrough.
    await tester.tap(find.bySemanticsLabel('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Plan Your Day'), findsOneWidget);

    final initialTitle = tester.widget<Text>(find.text('Assignment 03').first);
    expect(initialTitle.style?.decoration, TextDecoration.none);

    final checkBtn =
        find.bySemanticsLabel('Mark Assignment 03 as complete').first;
    await tester.ensureVisible(checkBtn);
    await tester.tap(checkBtn);
    await tester.pumpAndSettle();

    final completedTitle = tester.widget<Text>(find.text('Assignment 03').first);
    expect(completedTitle.style?.decoration, TextDecoration.lineThrough);
    expect(find.text('Done'), findsOneWidget);

    // Switch to AI Auto-Plan tab.
    await tester.tap(find.bySemanticsLabel('AI Auto-Plan').first);
    await tester.pumpAndSettle();
    expect(find.text('AI Auto-Plan'), findsOneWidget);
  });

  testWidgets('Profile opens dedicated AI API Keys page and switches Active badge', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final notifications = NotificationService();

    await tester.pumpWidget(
      HTodoApp(
        storage: storage,
        notifications: notifications,
        cloudBackup: CloudBackupService.disabled(),
        securityService: SecurityService.disabled(),
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('AI API Keys'), findsOneWidget);
    expect(find.text('Privacy & App Lock'), findsOneWidget);

    await tester.tap(find.text('AI API Keys'));
    await tester.pumpAndSettle();

    // Verify dedicated ApiKeysScreen opened with Back button & API Key Guidebook.
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    expect(find.text('API Key Guidebook'), findsOneWidget);

    await tester.ensureVisible(find.text('Google Gemini (Free)'));
    expect(find.text('Google Gemini (Free)'), findsOneWidget);
    await tester.ensureVisible(find.text('Groq (Free)'));
    expect(find.text('Groq (Free)'), findsOneWidget);
    expect(find.text('Recommended • Fast'), findsOneWidget);
    await tester.ensureVisible(find.text('xAI Grok'));
    expect(find.text('xAI Grok'), findsOneWidget);
    await tester.ensureVisible(find.text('OpenRouter (Free)'));
    expect(find.text('OpenRouter (Free)'), findsOneWidget);

    await tester.ensureVisible(find.text('Google Gemini (Free)'));
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    final setActiveBtn = find.text('Set Active').first;
    await tester.ensureVisible(setActiveBtn);
    await tester.tap(setActiveBtn);
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    expect(await storage.loadActiveProviderType(), AiProviderType.groq);

    // Navigate back cleanly to Profile.
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('AppLockScreen blocks wrong PIN and unlocks with correct PIN', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final salt = SecurityService.generateSalt();
    final hash = SecurityService.hashPin('1234', salt);
    final sec = SecuritySettings(
      pinEnabled: true,
      pinSalt: salt,
      pinHash: hash,
    );

    SharedPreferences.setMockInitialValues({
      'htodo_security_v1': jsonEncode(sec.toJson()),
    });

    final storage = StorageService();
    final notifications = NotificationService();

    await tester.pumpWidget(
      HTodoApp(
        storage: storage,
        notifications: notifications,
        cloudBackup: CloudBackupService.disabled(),
        securityService: SecurityService.disabled(),
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Enter your 4-digit pass lock'), findsOneWidget);

    // Wrong PIN -> error and stays locked.
    for (final d in ['9', '9', '9', '9']) {
      await tester.tap(find.text(d));
    }
    await tester.pumpAndSettle();
    expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);
    expect(find.text('Enter your 4-digit pass lock'), findsOneWidget);

    // Correct PIN -> unlocks into Overview.
    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.text(d));
    }
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);
  });

  testWidgets(
      'Overview theme toggle & notifications sheet, Chat reverse+copy, and Profile About/Developer work at 390x844',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final threeDaysLater = today.add(const Duration(days: 3));
    final todayTask = TaskItem(
      id: 't-notif-today',
      notificationBaseId: 504,
      title: 'Today Quiz 01',
      courseOrCategory: 'EEE 201',
      type: TaskType.classTest,
      dueDate: today,
      dueHour: 23,
      dueMinute: 59,
      createdAt: now,
    );
    final tomorrowTask = TaskItem(
      id: 't-notif-1',
      notificationBaseId: 505,
      title: 'Class Test 01',
      courseOrCategory: 'CSE 401',
      type: TaskType.classTest,
      dueDate: tomorrow,
      dueHour: 10,
      dueMinute: 30,
      createdAt: now,
    );
    final futureTask = TaskItem(
      id: 't-notif-later',
      notificationBaseId: 506,
      title: 'Later Exam 01',
      courseOrCategory: 'CSE 405',
      type: TaskType.exam,
      dueDate: threeDaysLater,
      dueHour: 14,
      dueMinute: 0,
      createdAt: now,
    );
    final olderMsg = ChatMessage(
      id: 'm-1',
      role: ChatRole.user,
      text: 'Older notice text',
      timestamp: now.subtract(const Duration(minutes: 10)),
    );
    final newerMsg = ChatMessage(
      id: 'm-2',
      role: ChatRole.assistant,
      text: 'Latest parsed summary',
      timestamp: now,
      providerName: 'Google Gemini (Free)',
    );

    SharedPreferences.setMockInitialValues({
      'htodo_tasks_v1': jsonEncode([
        todayTask.toJson(),
        tomorrowTask.toJson(),
        futureTask.toJson(),
      ]),
      'htodo_chat_v1': jsonEncode([olderMsg.toJson(), newerMsg.toJson()]),
    });

    await tester.pumpWidget(
      HTodoApp(
        storage: StorageService(),
        notifications: NotificationService(),
        cloudBackup: CloudBackupService.disabled(),
        securityService: SecurityService.disabled(),
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    // Bell badge strictly counts only Today's remaining tasks (not Tomorrow or later).
    final bellFinder = find.byTooltip('Notifications');
    expect(
      find.descendant(of: bellFinder, matching: find.text('1')),
      findsOneWidget,
    );

    // Overview Theme Toggle beside Notification Bell.
    final toDarkBtn = find.byTooltip('Switch to Dark theme');
    expect(toDarkBtn, findsOneWidget);
    await tester.tap(toDarkBtn);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Switch to Light theme'), findsOneWidget);

    // Tapping Notifications bell opens NotificationsSheet with Today & Tomorrow panels.
    await tester.tap(bellFinder);
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Plan Your Day'), findsNothing);
    expect(find.text('Today (1)'), findsOneWidget);
    expect(find.text('Tomorrow (1)'), findsOneWidget);

    final sheetFinder = find.byType(NotificationsSheet);
    expect(sheetFinder, findsOneWidget);

    // Today panel displays Today's task only (no Tomorrow or future tasks).
    expect(
      find.descendant(of: sheetFinder, matching: find.text('Today Quiz 01')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheetFinder, matching: find.text('Class Test 01')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheetFinder, matching: find.text('Later Exam 01')),
      findsNothing,
    );

    // Tapping left icon or card on Today panel stays read-only.
    await tester.tap(
      find
          .descendant(
            of: sheetFinder,
            matching: find.byIcon(taskTypeIcon(TaskType.classTest)),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(sheetFinder, findsOneWidget);
    expect(find.byType(TaskDetailSheet), findsNothing);
    await tester.tap(
      find.descendant(of: sheetFinder, matching: find.text('Today Quiz 01')),
    );
    await tester.pumpAndSettle();
    expect(sheetFinder, findsOneWidget);
    expect(find.byType(TaskDetailSheet), findsNothing);

    // Switch to Tomorrow panel: displays Tomorrow's task only.
    await tester.tap(find.text('Tomorrow (1)'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: sheetFinder, matching: find.text('Class Test 01')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheetFinder, matching: find.text('Today Quiz 01')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheetFinder, matching: find.text('Later Exam 01')),
      findsNothing,
    );

    // Completing Tomorrow task auto-removes it from Tomorrow panel; uncompleting restores it.
    final taskProvider = Provider.of<TaskProvider>(
      tester.element(sheetFinder),
      listen: false,
    );
    await taskProvider.toggleTaskComplete('t-notif-1');
    await tester.pumpAndSettle();
    expect(find.text('Nothing for tomorrow'), findsOneWidget);
    expect(
      find.descendant(of: sheetFinder, matching: find.text('Class Test 01')),
      findsNothing,
    );

    await taskProvider.toggleTaskComplete('t-notif-1');
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: sheetFinder, matching: find.text('Class Test 01')),
      findsOneWidget,
    );

    // Switch back to Today panel and test live completion removal + bell count update.
    await tester.tap(find.text('Today (1)'));
    await tester.pumpAndSettle();
    await taskProvider.toggleTaskComplete('t-notif-today');
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsOneWidget);
    expect(
      find.descendant(of: sheetFinder, matching: find.text('Today Quiz 01')),
      findsNothing,
    );

    await taskProvider.toggleTaskComplete('t-notif-today');
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: sheetFinder, matching: find.text('Today Quiz 01')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // AI Chat opens with newest message anchored at the bottom + Copy button.
    // Test font (Ahem) renders wide glyphs that wrap the no-key banner heavily,
    // so give the chat a taller viewport to fit both seeded bubbles.
    tester.view.physicalSize = const Size(390, 1600);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('AI Auto-Plan').first);
    await tester.pumpAndSettle();
    expect(
      find.text('AI Auto-Plan'),
      findsOneWidget,
      reason: 'Expected AI Chat tab to be active after tapping center orb',
    );
    expect(
      find.text('Manage schedules & tasks in any language'),
      findsNothing,
      reason: 'Expected pre-seeded htodo_chat_v1 messages to load',
    );
    expect(
      find.text('Google Gemini (Free)'),
      findsOneWidget,
      reason: 'Expected assistant bubble header to render inside reverse ListView',
    );
    final olderFinder = find.text('Older notice text');
    final newerFinder = find.text('Latest parsed summary');
    expect(olderFinder, findsOneWidget);
    expect(newerFinder, findsOneWidget);
    expect(
      tester.getTopLeft(newerFinder).dy,
      greaterThan(tester.getTopLeft(olderFinder).dy),
    );
    expect(find.byTooltip('Copy message'), findsNWidgets(2));

    // Profile displays About, Check for Updates, and Developer card.
    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Check for Updates'), findsOneWidget);
    expect(find.text('MD Naimur Rashid'), findsOneWidget);
    expect(find.text('naimurrashid.dev'), findsOneWidget);
    expect(find.text('github.com/naimurhamim'), findsOneWidget);
    expect(find.text('md-naimur-rashid'), findsOneWidget);
  });

  testWidgets(
      'Profile shows cached Google Name/Gmail and expands Drive Export/Import at 390x844',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const cachedProfile = GoogleAccountProfile(
      id: 'g-123',
      email: 'student.demo@gmail.com',
      displayName: 'Test Student',
    );
    SharedPreferences.setMockInitialValues({
      'htodo_google_profile_v1': jsonEncode(cachedProfile.toJson()),
    });

    await tester.pumpWidget(
      HTodoApp(
        storage: StorageService(),
        notifications: NotificationService(),
        cloudBackup: CloudBackupService.disabled(),
        securityService: SecurityService.disabled(),
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Test Student'), findsOneWidget);
    expect(find.text('student.demo@gmail.com'), findsOneWidget);

    final backupTile = find.text('Google Drive & Data Backup');
    await tester.ensureVisible(backupTile);
    await tester.tap(backupTile);
    await tester.pumpAndSettle();

    expect(find.text('Export JSON'), findsOneWidget);
    expect(find.text('Import JSON'), findsOneWidget);
  });

  testWidgets(
      'Overview Upcoming Tasks switches to Tomorrow short list when today clears, and Plan week strip swipes horizontally',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeekSameWeekday = today.add(const Duration(days: 7));

    final todayTask = TaskItem(
      id: 't-up-today',
      notificationBaseId: 701,
      title: 'Today Task Alpha',
      type: TaskType.assignment,
      dueDate: today,
      dueHour: 23,
      dueMinute: 59,
      createdAt: now,
    );
    final tmrTask1 = TaskItem(
      id: 't-up-tmr-1',
      notificationBaseId: 702,
      title: 'Tomorrow Quiz Beta',
      type: TaskType.classTest,
      dueDate: tomorrow,
      dueHour: 10,
      dueMinute: 0,
      createdAt: now,
    );
    final tmrTask2 = TaskItem(
      id: 't-up-tmr-2',
      notificationBaseId: 703,
      title: 'Tomorrow Lab Gamma',
      type: TaskType.exam,
      dueDate: tomorrow,
      dueHour: 14,
      dueMinute: 30,
      createdAt: now,
    );

    SharedPreferences.setMockInitialValues({
      'htodo_tasks_v1': jsonEncode([
        todayTask.toJson(),
        tmrTask1.toJson(),
        tmrTask2.toJson(),
      ]),
    });

    await tester.pumpWidget(
      HTodoApp(
        storage: StorageService(),
        notifications: NotificationService(),
        cloudBackup: CloudBackupService.disabled(),
        securityService: SecurityService.disabled(),
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upcoming Tasks'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Today Task Alpha'), findsWidgets);

    // Complete today's remaining task -> card automatically displays Tomorrow's short list.
    final taskProvider = Provider.of<TaskProvider>(
      tester.element(find.text('Overview')),
      listen: false,
    );
    await taskProvider.toggleTaskComplete('t-up-today');
    await tester.pumpAndSettle();

    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('Tomorrow Quiz Beta'), findsWidgets);
    expect(find.text('Tomorrow Lab Gamma'), findsWidgets);

    // Plan Your Day horizontal week swipe changes selected date by +7 days.
    await tester.tap(find.bySemanticsLabel('Plan'));
    await tester.pumpAndSettle();
    expect(find.text(DateFormat('d MMMM, yyyy').format(today)), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(
      find.text(DateFormat('d MMMM, yyyy').format(nextWeekSameWeekday)),
      findsOneWidget,
    );
  });

  testWidgets(
      'Auto-update check detects release, shows bell/top banners, persists single notification, and opens Check for Updates dialog',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'tag_name': 'v9.9.9',
          'body': '## Highlights\n- Smooth 120Hz scrolling',
          'html_url': 'https://github.com/naimurhamim/h-todo-ai/releases/tag/v9.9.9',
          'assets': [
            {
              'name': 'H-TODO-AI-v9.9.9.apk',
              'browser_download_url':
                  'https://github.com/naimurhamim/h-todo-ai/releases/download/v9.9.9/H-TODO-AI-v9.9.9.apk',
            },
          ],
        }),
        200,
      );
    });

    await tester.pumpWidget(
      HTodoApp(
        storage: storage,
        notifications: NotificationService(),
        cloudBackup: CloudBackupService.disabled(),
        securityService: SecurityService.disabled(),
        updateHttpClient: mockClient,
        currentVersionOverride: '1.1.0',
        autoCheckUpdates: true,
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update v9.9.9 available'), findsOneWidget);
    final bellFinder = find.byTooltip('Notifications');
    expect(
      find.descendant(of: bellFinder, matching: find.text('1')),
      findsOneWidget,
    );
    expect(await storage.loadLastNotifiedUpdateVersion(), '9.9.9');

    await tester.tap(bellFinder);
    await tester.pumpAndSettle();
    expect(find.text('Update Available • v9.9.9'), findsOneWidget);

    await tester.tap(find.text('Update Available • v9.9.9'));
    await tester.pumpAndSettle();

    expect(find.text('Update Available'), findsOneWidget);
    expect(find.text('Installed: v1.1.0  •  Latest: v9.9.9'), findsOneWidget);
    expect(find.text('Smooth 120Hz scrolling'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets(
      'Auto-update check stays silent when installed version matches latest release',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'tag_name': 'v1.1.0',
          'body': 'Current build',
          'html_url': 'https://github.com/naimurhamim/h-todo-ai/releases/latest',
        }),
        200,
      );
    });

    await tester.pumpWidget(
      HTodoApp(
        storage: storage,
        notifications: NotificationService(),
        cloudBackup: CloudBackupService.disabled(),
        securityService: SecurityService.disabled(),
        updateHttpClient: mockClient,
        currentVersionOverride: '1.1.0',
        autoCheckUpdates: true,
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update v1.1.0 available'), findsNothing);
    expect(
      find.descendant(
        of: find.byTooltip('Notifications'),
        matching: find.text('1'),
      ),
      findsNothing,
    );
    expect(await storage.loadLastNotifiedUpdateVersion(), isNull);
  });

  testWidgets(
      'AI Auto-Plan quick presets run offline Q&A and templates with zero API keys',
      (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Test font (Ahem) renders wide square glyphs that wrap the no-key banner and hint heavily,
    // so give the chat a taller viewport matching Test 4 to leave space for message bubbles.
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final now = DateTime.now();
    await storage.saveTasks([
      TaskItem(
        id: 'widget_today_1',
        notificationBaseId: 101,
        title: 'Widget Today Task',
        dueDate: DateTime(now.year, now.month, now.day),
        dueHour: 15,
        dueMinute: 0,
        createdAt: now,
      ),
    ]);

    await tester.pumpWidget(
      HTodoApp(
        storage: storage,
        notifications: NotificationService(),
        cloudBackup: CloudBackupService.disabled(),
        securityService: SecurityService.disabled(),
        autoCheckUpdates: false,
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('AI Auto-Plan').first);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Quick presets work offline (0 tokens). Add a free API key in Profile for long notices.',
      ),
      findsOneWidget,
    );
    expect(find.text('Today'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    expect(find.text('What is due today?'), findsOneWidget);
    expect(find.text('Local • Instant'), findsOneWidget);
    expect(find.textContaining('1 task due today:'), findsOneWidget);
    expect(find.textContaining('Widget Today Task'), findsNWidgets(2));

    final quickTaskFinder = find.text('Quick Task');
    if (quickTaskFinder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        quickTaskFinder,
        150,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
        ),
      );
      await tester.pumpAndSettle();
    }

    await tester.ensureVisible(quickTaskFinder);
    await tester.pumpAndSettle();
    await tester.tap(quickTaskFinder);
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.controller?.text, 'Tomorrow 10:00 AM ');

    await tester.tap(find.byTooltip('Hide quick presets'));
    await tester.pumpAndSettle();

    expect(find.text('Quick Task'), findsNothing);
    expect(find.byTooltip('Show quick presets'), findsOneWidget);
  });

  testWidgets(
      'All Scheduled opens directly anchored at Today with past tasks scrollable upward and Today jump button',
      (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final seeded = <TaskItem>[
      for (var d = 12; d >= 1; d--)
        TaskItem(
          id: 'past-$d',
          notificationBaseId: 200 + d,
          title: 'Past Task Day -$d',
          dueDate: today.subtract(Duration(days: d)),
          createdAt: today.subtract(Duration(days: d + 1)),
        ),
      TaskItem(
        id: 'today-anchor',
        notificationBaseId: 301,
        title: 'Anchored Today Task',
        dueDate: today,
        createdAt: today,
      ),
      TaskItem(
        id: 'future-anchor',
        notificationBaseId: 302,
        title: 'Anchored Tomorrow Task',
        dueDate: today.add(const Duration(days: 1)),
        createdAt: today,
      ),
    ];
    await storage.saveTasks(seeded);

    await tester.pumpWidget(
      HTodoApp(
        storage: storage,
        notifications: NotificationService(),
        cloudBackup: CloudBackupService.disabled(),
        securityService: SecurityService.disabled(),
        autoCheckUpdates: false,
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Plan').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Full Timeline View'));
    await tester.pumpAndSettle();

    expect(find.text('All Scheduled'), findsOneWidget);
    expect(find.text('Anchored Today Task'), findsOneWidget);
    expect(find.text('Anchored Tomorrow Task'), findsOneWidget);
    // Oldest past date sits far above Today's anchor and is outside the initial viewport.
    expect(find.text('Past Task Day -12'), findsNothing);

    final timelineFinder = find.byWidgetPredicate(
      (w) => w is CustomScrollView && w.center != null,
    );
    expect(timelineFinder, findsOneWidget);

    await tester.drag(timelineFinder, const Offset(0, 450));
    await tester.pumpAndSettle();
    expect(find.text('Past Task Day -1'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('Anchored Today Task'), findsOneWidget);
  });

  testWidgets(
      'TaskEditorSheet shows expanded built-in types and creates a custom type with chosen icon',
      (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();

    await tester.pumpWidget(
      HTodoApp(
        storage: storage,
        notifications: NotificationService(),
        cloudBackup: CloudBackupService.disabled(),
        securityService: SecurityService.disabled(),
        autoCheckUpdates: false,
        skipSplash: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Plan').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Mail'), findsOneWidget);
    expect(find.text('Travel'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('Institution'), findsOneWidget);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    expect(find.text('New Custom Task Type'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Type Name *'),
      'Tuition',
    );
    await tester.tap(find.byTooltip('Study').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Tuition'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Task Title *'),
      'Math Batch',
    );
    await tester.tap(find.text('Create Task'));
    await tester.pumpAndSettle();

    expect(find.text('Math Batch'), findsOneWidget);
    expect(find.text('Tuition'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsWidgets);
  });
}
