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
    this.isCustomTime = false,
  });

  final int id;
  final DateTime scheduledAt;
  final String title;
  final String body;
  final bool isDayBefore;
  final bool isCustomTime;
}

/// Pure, deterministic reminder calculator (testable without platform plugins).
abstract final class NotificationScheduleCalculator {
  static DateTime? _effectiveFutureTime(DateTime target, DateTime refNow) {
    if (target.isAfter(refNow)) return target;
    final elapsed = refNow.difference(target);
    if (!elapsed.isNegative &&
        elapsed.inSeconds < 60 &&
        target.year == refNow.year &&
        target.month == refNow.month &&
        target.day == refNow.day &&
        target.hour == refNow.hour &&
        target.minute == refNow.minute) {
      return refNow.add(const Duration(seconds: 5));
    }
    return null;
  }

  static int _slotOrder(ScheduledReminder r) {
    if (r.isDayBefore) return 0;
    if (r.isCustomTime) return 1;
    return 2;
  }

  static List<ScheduledReminder> compute(
    TaskItem task,
    ReminderSettings settings, {
    DateTime? now,
  }) {
    if (!settings.enabled || task.isCompleted) {
      return const [];
    }

    final refNow = now ?? DateTime.now();
    final today = DateTime(refNow.year, refNow.month, refNow.day);
    final safeBase = task.notificationBaseId & 0x0FFFFFFF;
    final todayExtraBase = 0x40000000 + safeBase * 3;
    final dueDay = DateTime(
      task.dueDate.year,
      task.dueDate.month,
      task.dueDate.day,
    );
    final dayBeforeDate = dueDay.subtract(const Duration(days: 1));
    final primaryDayBeforeDate =
        dayBeforeDate.isBefore(today) ? today : dayBeforeDate;
    final primaryDueDate = dueDay.isBefore(today) ? today : dueDay;

    final coursePrefix = task.courseOrCategory.trim().isNotEmpty
        ? '${task.courseOrCategory.trim()} • '
        : '';
    final dueTimeSuffix = task.formattedDueTime != null
        ? ' at ${task.formattedDueTime}'
        : '';

    final reminders = <ScheduledReminder>[];

    // 1. Day-Before / Advance Reminder.
    if (primaryDayBeforeDate.isAfter(today)) {
      final todayAdvanceTarget = DateTime(
        today.year,
        today.month,
        today.day,
        settings.dayBeforeHour,
        settings.dayBeforeMinute,
      );
      final effectiveTodayAdvance =
          _effectiveFutureTime(todayAdvanceTarget, refNow);
      if (effectiveTodayAdvance != null) {
        reminders.add(
          ScheduledReminder(
            id: todayExtraBase,
            scheduledAt: effectiveTodayAdvance,
            title: 'Upcoming: ${task.title}',
            body: '${coursePrefix}Scheduled reminder$dueTimeSuffix.',
            isDayBefore: true,
          ),
        );
      }
    }

    final dayBeforeTarget = DateTime(
      primaryDayBeforeDate.year,
      primaryDayBeforeDate.month,
      primaryDayBeforeDate.day,
      settings.dayBeforeHour,
      settings.dayBeforeMinute,
    );
    final effectiveDayBefore = _effectiveFutureTime(dayBeforeTarget, refNow);
    if (effectiveDayBefore != null) {
      final isTodayOrOverdue =
          primaryDayBeforeDate == today && !dueDay.isAfter(today);
      reminders.add(
        ScheduledReminder(
          id: safeBase * 3,
          scheduledAt: effectiveDayBefore,
          title: isTodayOrOverdue
              ? 'Upcoming today: ${task.title}'
              : 'Upcoming tomorrow: ${task.title}',
          body: isTodayOrOverdue
              ? '${coursePrefix}Due today$dueTimeSuffix.'
              : '${coursePrefix}Due tomorrow$dueTimeSuffix.',
          isDayBefore: true,
        ),
      );
    }

    // 2. Custom Task Time Reminder (never skipped even if matching endOfDay).
    if (task.hasDueTime) {
      if (primaryDueDate.isAfter(today)) {
        final todayTaskTarget = DateTime(
          today.year,
          today.month,
          today.day,
          task.dueHour!,
          task.dueMinute!,
        );
        final effectiveTodayTaskTime =
            _effectiveFutureTime(todayTaskTarget, refNow);
        if (effectiveTodayTaskTime != null) {
          reminders.add(
            ScheduledReminder(
              id: todayExtraBase + 2,
              scheduledAt: effectiveTodayTaskTime,
              title: 'Reminder: ${task.title}',
              body: '${coursePrefix}Scheduled for ${task.formattedDueTime}.',
              isDayBefore: false,
              isCustomTime: true,
            ),
          );
        }
      }

      final taskTimeTarget = DateTime(
        primaryDueDate.year,
        primaryDueDate.month,
        primaryDueDate.day,
        task.dueHour!,
        task.dueMinute!,
      );
      final effectiveTaskTime = _effectiveFutureTime(taskTimeTarget, refNow);
      if (effectiveTaskTime != null) {
        reminders.add(
          ScheduledReminder(
            id: safeBase * 3 + 2,
            scheduledAt: effectiveTaskTime,
            title: 'Reminder: ${task.title}',
            body: '${coursePrefix}Scheduled for ${task.formattedDueTime}.',
            isDayBefore: false,
            isCustomTime: true,
          ),
        );
      }
    }

    // 3. End-of-Day Check-In.
    if (primaryDueDate.isAfter(today)) {
      final todayEndTarget = DateTime(
        today.year,
        today.month,
        today.day,
        settings.endOfDayHour,
        settings.endOfDayMinute,
      );
      final effectiveTodayEnd = _effectiveFutureTime(todayEndTarget, refNow);
      if (effectiveTodayEnd != null) {
        reminders.add(
          ScheduledReminder(
            id: todayExtraBase + 1,
            scheduledAt: effectiveTodayEnd,
            title: 'Mark task complete: ${task.title}',
            body:
                '${coursePrefix}End-of-day check-in — tap to cross off if done.',
            isDayBefore: false,
          ),
        );
      }
    }

    final endOfDayTarget = DateTime(
      primaryDueDate.year,
      primaryDueDate.month,
      primaryDueDate.day,
      settings.endOfDayHour,
      settings.endOfDayMinute,
    );
    final effectiveEndOfDay = _effectiveFutureTime(endOfDayTarget, refNow);
    if (effectiveEndOfDay != null) {
      reminders.add(
        ScheduledReminder(
          id: safeBase * 3 + 1,
          scheduledAt: effectiveEndOfDay,
          title: 'Mark task complete: ${task.title}',
          body:
              '${coursePrefix}End-of-day check-in — tap to cross off if done.',
          isDayBefore: false,
        ),
      );
    }

    reminders.sort((a, b) {
      final timeCmp = a.scheduledAt.compareTo(b.scheduledAt);
      if (timeCmp != 0) return timeCmp;
      return _slotOrder(a).compareTo(_slotOrder(b));
    });

    return reminders;
  }
}

/// Coordinates exact Android/iOS local notifications for day-before, custom task time, and end-of-day reminders.
class NotificationService {
  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'htodo_reminders_v2';
  static const _channelName = 'Schedule Reminders';
  static const _channelDescription =
      'Day-before alerts, task deadline alerts, and end-of-day check-ins';
  static const int _testScheduledId = 999998;
  static const int _testInstantId = 999999;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _tzInitialized = false;
  bool _platformReady = false;
  Future<void>? _initFuture;
  bool _permissionRequestInFlight = false;

  bool get _supportsPlatformScheduling {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> init() {
    if (_initialized) return Future.value();
    return _initFuture ??= _performInit();
  }

  Future<void> _performInit() async {
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
      _platformReady = true;
    } catch (e) {
      _platformReady = false;
      debugPrint('NotificationService.init warning: $e');
    } finally {
      _initialized = true;
    }

    if (!_platformReady || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    } catch (e) {
      debugPrint('NotificationService channel warning: $e');
    }

    await _requestAndroidPermissions(requestExactAlarm: false);
  }

  Future<void> _requestAndroidPermissions({
    required bool requestExactAlarm,
  }) async {
    if (!_platformReady ||
        defaultTargetPlatform != TargetPlatform.android ||
        _permissionRequestInFlight) {
      return;
    }
    _permissionRequestInFlight = true;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl == null) return;
      await androidImpl.requestNotificationsPermission();
      if (requestExactAlarm) {
        final canExact = await androidImpl.canScheduleExactNotifications();
        if (canExact == false) {
          await androidImpl.requestExactAlarmsPermission();
        }
      }
    } catch (e) {
      debugPrint('NotificationService permission warning: $e');
    } finally {
      _permissionRequestInFlight = false;
    }
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
    for (final entry in tz.timeZoneDatabase.locations.entries) {
      final zoneOffset = entry.value.currentTimeZone.offset;
      if (zoneOffset == offsetMs) {
        return entry.value;
      }
    }
    return tz.UTC;
  }

  tz.TZDateTime _toLocalTz(DateTime dt) {
    return tz.TZDateTime(
      tz.local,
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
    );
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        icon: '@mipmap/ic_launcher',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<AndroidScheduleMode> _resolveScheduleMode({
    bool promptIfDenied = false,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl == null) return AndroidScheduleMode.exactAllowWhileIdle;
      var canExact = await androidImpl.canScheduleExactNotifications();
      if (canExact != true && promptIfDenied) {
        await _requestAndroidPermissions(requestExactAlarm: true);
        canExact = await androidImpl.canScheduleExactNotifications();
      }
      if (canExact == true) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {}
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> _zonedScheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime tzDate,
    required AndroidScheduleMode preferredMode,
    String? payload,
  }) async {
    final modes = <AndroidScheduleMode>[
      preferredMode,
      if (preferredMode != AndroidScheduleMode.exactAllowWhileIdle)
        AndroidScheduleMode.exactAllowWhileIdle,
      if (preferredMode != AndroidScheduleMode.alarmClock)
        AndroidScheduleMode.alarmClock,
      if (preferredMode != AndroidScheduleMode.inexactAllowWhileIdle)
        AndroidScheduleMode.inexactAllowWhileIdle,
    ];

    for (final mode in modes) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tzDate,
          _notificationDetails(),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: mode,
          payload: payload,
        );
        return;
      } catch (e) {
        debugPrint('zonedSchedule failed for mode $mode (id=$id): $e');
      }
    }
  }

  Future<void> _scheduleTaskReminders(
    TaskItem task,
    ReminderSettings settings, {
    required AndroidScheduleMode mode,
  }) async {
    final reminders = NotificationScheduleCalculator.compute(task, settings);
    if (reminders.isEmpty) return;

    for (final r in reminders) {
      final tzDate = _toLocalTz(r.scheduledAt);
      await _zonedScheduleWithFallback(
        id: r.id,
        title: r.title,
        body: r.body,
        tzDate: tzDate,
        preferredMode: mode,
        payload: task.id,
      );
    }
  }

  Future<void> scheduleForTask(
    TaskItem task,
    ReminderSettings settings,
  ) async {
    await init();
    await cancelForTask(task);

    if (!_supportsPlatformScheduling || !_platformReady) return;

    final mode = await _resolveScheduleMode(promptIfDenied: false);
    await _scheduleTaskReminders(task, settings, mode: mode);
  }

  Future<void> cancelForTask(TaskItem task) async {
    if (!_supportsPlatformScheduling || !_platformReady) return;
    final safeBase = task.notificationBaseId & 0x0FFFFFFF;
    final todayExtraBase = 0x40000000 + safeBase * 3;
    final legacyBase = task.notificationBaseId;
    final idsToCancel = <int>{
      safeBase * 3,
      safeBase * 3 + 1,
      safeBase * 3 + 2,
      todayExtraBase,
      todayExtraBase + 1,
      todayExtraBase + 2,
      legacyBase * 2,
      legacyBase * 2 + 1,
    };
    for (final id in idsToCancel) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
  }

  Future<void> rescheduleAll(
    List<TaskItem> tasks,
    ReminderSettings settings,
  ) async {
    await init();
    if (!_supportsPlatformScheduling || !_platformReady) return;

    try {
      await _plugin.cancelAll();
    } catch (_) {}

    if (!settings.enabled) return;

    final mode = await _resolveScheduleMode(promptIfDenied: false);
    for (final task in tasks) {
      if (!task.isCompleted) {
        await _scheduleTaskReminders(task, settings, mode: mode);
      }
    }
  }

  Future<String> showTestNotification() async {
    await init();
    if (!_supportsPlatformScheduling || !_platformReady) {
      return 'Reminders are scheduled on Android/iOS devices (not supported in this desktop/web preview).';
    }
    try {
      await _plugin.show(
        _testInstantId,
        'H-TODO AI Reminder Active',
        'Immediate test alert — a timed exact alarm will also fire in 10 seconds.',
        _notificationDetails(),
      );

      final mode = await _resolveScheduleMode(promptIfDenied: true);
      final scheduledAt =
          tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
      await _zonedScheduleWithFallback(
        id: _testScheduledId,
        title: 'H-TODO AI Timed Alarm Test',
        body: 'Exact background alarm verified — task reminders are working.',
        tzDate: scheduledAt,
        preferredMode: mode,
      );

      final pending = await _plugin.pendingNotificationRequests();
      final count = pending.length;
      return 'Test alert sent + 10s scheduled alarm queued ($count active alarm${count == 1 ? '' : 's'} on device).';
    } catch (e) {
      return 'Could not show notification: $e';
    }
  }
}
