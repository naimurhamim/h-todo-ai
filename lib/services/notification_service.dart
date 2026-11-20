import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder_settings.dart';
import '../models/task_item.dart';

/// Immutable description of one scheduled reminder for a task.
@immutable
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.isDayBefore,
  });

  final int id;
  final DateTime scheduledAt;
  final String title;
  final String body;
  final bool isDayBefore;
}

/// Pure, deterministic reminder calculator (testable without platform plugins).
abstract final class NotificationScheduleCalculator {
  static List<ScheduledReminder> compute(
    TaskItem task,
    ReminderSettings settings, {
    DateTime? now,
  }) {
    if (!settings.enabled || task.isCompleted) {
      return const [];
    }

    final refNow = now ?? DateTime.now();
    final dueDay = DateTime(
      task.dueDate.year,
      task.dueDate.month,
      task.dueDate.day,
    );
    final dayBeforeDate = dueDay.subtract(const Duration(days: 1));

    final dayBeforeAt = DateTime(
      dayBeforeDate.year,
      dayBeforeDate.month,
      dayBeforeDate.day,
      settings.dayBeforeHour,
      settings.dayBeforeMinute,
    );

    final endOfDayAt = DateTime(
      dueDay.year,
      dueDay.month,
      dueDay.day,
      settings.endOfDayHour,
      settings.endOfDayMinute,
    );

    final coursePrefix = task.courseOrCategory.trim().isNotEmpty
        ? '${task.courseOrCategory.trim()} • '
        : '';
    final dueTimeSuffix = task.formattedDueTime != null
        ? ' at ${task.formattedDueTime}'
        : '';

    final reminders = <ScheduledReminder>[];

    if (dayBeforeAt.isAfter(refNow)) {
      reminders.add(
        ScheduledReminder(
          id: task.notificationBaseId * 2,
          scheduledAt: dayBeforeAt,
          title: 'Upcoming tomorrow: ${task.title}',
          body: '${coursePrefix}Due tomorrow$dueTimeSuffix.',
          isDayBefore: true,
        ),
      );
    }

    if (endOfDayAt.isAfter(refNow)) {
      reminders.add(
        ScheduledReminder(
          id: task.notificationBaseId * 2 + 1,
          scheduledAt: endOfDayAt,
          title: 'Mark task complete: ${task.title}',
          body:
              '${coursePrefix}End-of-day check-in — tap to cross off if done.',
          isDayBefore: false,
        ),
      );
    }

    return reminders;
  }
}

/// Coordinates local notifications for day-before & end-of-day reminders.
class NotificationService {
  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'htodo_reminders';
  static const _channelName = 'Schedule Reminders';
  static const _channelDescription =
      'Day-before alerts and end-of-day completion check-ins';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _tzInitialized = false;

  bool get _supportsPlatformScheduling {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initTimezone();

    if (!_supportsPlatformScheduling) {
      _initialized = true;
      return;
    }

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _plugin.initialize(settings);

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.requestNotificationsPermission();
      }
    } catch (_) {
      // Ignore plugin startup issues on headless/unsupported runners.
    }

    _initialized = true;
  }

  void _initTimezone() {
    if (_tzInitialized) return;
    tz_data.initializeTimeZones();
    final localLocation = _resolveLocalLocation(DateTime.now());
    tz.setLocalLocation(localLocation);
    _tzInitialized = true;
  }

  tz.Location _resolveLocalLocation(DateTime now) {
    final offsetMs = now.timeZoneOffset.inMilliseconds;
    // Check common matching zone first (e.g., Asia/Dhaka for +06:00).
    if (offsetMs == const Duration(hours: 6).inMilliseconds &&
        tz.timeZoneDatabase.locations.containsKey('Asia/Dhaka')) {
      return tz.getLocation('Asia/Dhaka');
    }

    for (final entry in tz.timeZoneDatabase.locations.entries) {
      final zoneOffset = entry.value.currentTimeZone.offset;
      if (zoneOffset == offsetMs && !entry.key.startsWith('Etc/')) {
        return entry.value;
      }
    }
    return tz.UTC;
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
  }

  Future<void> scheduleForTask(
    TaskItem task,
    ReminderSettings settings,
  ) async {
    await init();
    await cancelForTask(task);

    if (!_supportsPlatformScheduling) return;

    final reminders = NotificationScheduleCalculator.compute(task, settings);
    if (reminders.isEmpty) return;

    for (final r in reminders) {
      try {
        final tzDate = tz.TZDateTime.from(r.scheduledAt, tz.local);
        await _plugin.zonedSchedule(
          r.id,
          r.title,
          r.body,
          tzDate,
          _notificationDetails(),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: task.id,
        );
      } catch (_) {
        // Safely continue if OS denies exact/background scheduling.
      }
    }
  }

  Future<void> cancelForTask(TaskItem task) async {
    if (!_supportsPlatformScheduling) return;
    try {
      await _plugin.cancel(task.notificationBaseId * 2);
      await _plugin.cancel(task.notificationBaseId * 2 + 1);
    } catch (_) {
      // Safely ignore in headless or unsupported environments.
    }
  }

  Future<void> rescheduleAll(
    List<TaskItem> tasks,
    ReminderSettings settings,
  ) async {
    await init();
    if (!_supportsPlatformScheduling) return;

    try {
      await _plugin.cancelAll();
    } catch (_) {}

    if (!settings.enabled) return;

    for (final task in tasks) {
      if (!task.isCompleted) {
        await scheduleForTask(task, settings);
      }
    }
  }

  Future<String> showTestNotification() async {
    await init();
    if (!_supportsPlatformScheduling) {
      return 'Reminders are scheduled on Android/iOS devices (not supported in this desktop/web preview).';
    }
    try {
      await _plugin.show(
        999999,
        'H-TODO AI Reminder Active',
        'You will be notified the day before and at end-of-day for each task.',
        _notificationDetails(),
      );
      return 'Test notification sent.';
    } catch (e) {
      return 'Could not show notification: $e';
    }
  }
}
