import 'package:flutter_test/flutter_test.dart';

import 'package:h_todo_ai/models/reminder_settings.dart';
import 'package:h_todo_ai/models/task_item.dart';
import 'package:h_todo_ai/services/notification_service.dart';

void main() {
  group('NotificationScheduleCalculator.compute', () {
    final taskWithDueTime = TaskItem(
      id: 'task-1',
      notificationBaseId: 500,
      title: 'Class Test',
      courseOrCategory: 'IRE 415 – Computer Vision',
      type: TaskType.classTest,
      dueDate: DateTime(2026, 11, 22),
      dueHour: 10,
      dueMinute: 0,
      createdAt: DateTime(2026, 11, 20),
    );

    final taskNoDueTime = TaskItem(
      id: 'task-2',
      notificationBaseId: 501,
      title: 'Assignment 01',
      courseOrCategory: 'IRE 415',
      type: TaskType.assignment,
      dueDate: DateTime(2026, 11, 22),
      createdAt: DateTime(2026, 11, 20),
    );

    const settings = ReminderSettings(
      enabled: true,
      dayBeforeHour: 20,
      dayBeforeMinute: 0,
      endOfDayHour: 21,
      endOfDayMinute: 0,
    );

    test(
        'schedules day-before, custom task due-time, end-of-day alerts, and today active reminders when upcoming today',
        () {
      final reminders = NotificationScheduleCalculator.compute(
        taskWithDueTime,
        settings,
        now: DateTime(2026, 11, 20, 19, 0),
      );

      expect(reminders.length, 5);

      expect(reminders[0].id, 0x40000000 + 1500);
      expect(reminders[0].isDayBefore, isTrue);
      expect(reminders[0].scheduledAt, DateTime(2026, 11, 20, 20, 0));
      expect(reminders[0].title, 'Upcoming: Class Test');

      expect(reminders[1].id, 0x40000000 + 1501);
      expect(reminders[1].isDayBefore, isFalse);
      expect(reminders[1].isCustomTime, isFalse);
      expect(reminders[1].scheduledAt, DateTime(2026, 11, 20, 21, 0));

      expect(reminders[2].id, 1500);
      expect(reminders[2].isDayBefore, isTrue);
      expect(reminders[2].scheduledAt, DateTime(2026, 11, 21, 20, 0));
      expect(reminders[2].title, contains('Upcoming tomorrow'));

      expect(reminders[3].id, 1502);
      expect(reminders[3].isCustomTime, isTrue);
      expect(reminders[3].scheduledAt, DateTime(2026, 11, 22, 10, 0));
      expect(reminders[3].title, contains('Reminder: Class Test'));

      expect(reminders[4].id, 1501);
      expect(reminders[4].isDayBefore, isFalse);
      expect(reminders[4].scheduledAt, DateTime(2026, 11, 22, 21, 0));
      expect(reminders[4].title, contains('Mark task complete'));
    });

    test('schedules 2 future alerts when today reminder windows have passed', () {
      final reminders = NotificationScheduleCalculator.compute(
        taskNoDueTime,
        settings,
        now: DateTime(2026, 11, 20, 22, 0),
      );

      expect(reminders.length, 2);
      expect(reminders[0].scheduledAt, DateTime(2026, 11, 21, 20, 0));
      expect(reminders[1].scheduledAt, DateTime(2026, 11, 22, 21, 0));
    });

    test(
        'fires Day-Before Reminder today for tasks due today when set to an upcoming time today',
        () {
      final todayTask = TaskItem(
        id: 'task-due-today',
        notificationBaseId: 503,
        title: 'Lab Report',
        dueDate: DateTime(2026, 11, 21),
        createdAt: DateTime(2026, 11, 21),
      );
      const customTodaySettings = ReminderSettings(
        enabled: true,
        dayBeforeHour: 19,
        dayBeforeMinute: 35,
        endOfDayHour: 22,
        endOfDayMinute: 0,
      );

      final reminders = NotificationScheduleCalculator.compute(
        todayTask,
        customTodaySettings,
        now: DateTime(2026, 11, 21, 19, 33),
      );

      expect(reminders.length, 2);
      expect(reminders[0].isDayBefore, isTrue);
      expect(reminders[0].scheduledAt, DateTime(2026, 11, 21, 19, 35));
      expect(reminders[0].title, 'Upcoming today: Lab Report');
      expect(reminders[0].body, contains('Due today'));
      expect(reminders[1].scheduledAt, DateTime(2026, 11, 21, 22, 0));
    });

    test(
        'fires Custom reminder time and End-of-Day Check-In today for tomorrow task when set to upcoming times today',
        () {
      final tomorrowTask = TaskItem(
        id: 'task-tomorrow',
        notificationBaseId: 504,
        title: 'Class Test',
        dueDate: DateTime(2026, 11, 22),
        dueHour: 19,
        dueMinute: 35,
        createdAt: DateTime(2026, 11, 21),
      );
      const upcomingTodaySettings = ReminderSettings(
        enabled: true,
        dayBeforeHour: 16,
        dayBeforeMinute: 0,
        endOfDayHour: 19,
        endOfDayMinute: 36,
      );

      final reminders = NotificationScheduleCalculator.compute(
        tomorrowTask,
        upcomingTodaySettings,
        now: DateTime(2026, 11, 21, 19, 33),
      );

      expect(
        reminders.where((r) => r.scheduledAt.day == 21 && r.isCustomTime),
        hasLength(1),
      );
      expect(
        reminders
            .where((r) => r.scheduledAt == DateTime(2026, 11, 21, 19, 36))
            .single
            .title,
        'Mark task complete: Class Test',
      );
      expect(
        reminders.where((r) => r.scheduledAt.day == 22),
        hasLength(2),
      );
    });

    test('schedules reminders today for overdue uncompleted tasks', () {
      final overdueTask = TaskItem(
        id: 'task-overdue',
        notificationBaseId: 505,
        title: 'Overdue Assignment',
        dueDate: DateTime(2026, 11, 19),
        dueHour: 19,
        dueMinute: 45,
        createdAt: DateTime(2026, 11, 18),
      );

      final reminders = NotificationScheduleCalculator.compute(
        overdueTask,
        settings,
        now: DateTime(2026, 11, 21, 19, 30),
      );

      expect(reminders.length, 3);
      expect(reminders[0].scheduledAt, DateTime(2026, 11, 21, 19, 45));
      expect(reminders[0].isCustomTime, isTrue);
      expect(reminders[1].scheduledAt, DateTime(2026, 11, 21, 20, 0));
      expect(reminders[1].isDayBefore, isTrue);
      expect(reminders[2].scheduledAt, DateTime(2026, 11, 21, 21, 0));
    });

    test(
        'never skips custom task reminder when dueTime matches End-of-Day Check-In',
        () {
      final matchingTask = TaskItem(
        id: 'task-matching-time',
        notificationBaseId: 506,
        title: 'Submit Project',
        dueDate: DateTime(2026, 11, 22),
        dueHour: 22,
        dueMinute: 0,
        createdAt: DateTime(2026, 11, 21),
      );

      final reminders = NotificationScheduleCalculator.compute(
        matchingTask,
        const ReminderSettings(),
        now: DateTime(2026, 11, 22, 18, 0),
      );

      expect(reminders.length, 2);
      expect(reminders[0].isCustomTime, isTrue);
      expect(reminders[0].id, 506 * 3 + 2);
      expect(reminders[0].scheduledAt, DateTime(2026, 11, 22, 22, 0));
      expect(reminders[1].isCustomTime, isFalse);
      expect(reminders[1].isDayBefore, isFalse);
      expect(reminders[1].id, 506 * 3 + 1);
      expect(reminders[1].scheduledAt, DateTime(2026, 11, 22, 22, 0));
    });

    test('fires current-minute reminder in 5s across full 0-59s window', () {
      final todayTask = TaskItem(
        id: 'task-today',
        notificationBaseId: 502,
        title: 'Quick Test',
        dueDate: DateTime(2026, 11, 22),
        dueHour: 17,
        dueMinute: 58,
        createdAt: DateTime(2026, 11, 22),
      );

      final reminders = NotificationScheduleCalculator.compute(
        todayTask,
        const ReminderSettings(),
        now: DateTime(2026, 11, 22, 17, 58, 58),
      );

      expect(reminders.length, 2);
      expect(reminders[0].isCustomTime, isTrue);
      expect(reminders[0].scheduledAt, DateTime(2026, 11, 22, 17, 59, 3));
      expect(reminders[1].scheduledAt, DateTime(2026, 11, 22, 22, 0));
    });

    test('derived notification IDs always remain positive 31-bit Android IDs',
        () {
      final maxMaskTask = TaskItem(
        id: 'max-id-test',
        notificationBaseId: 0x0FFFFFFF,
        title: 'ID Bounds',
        dueDate: DateTime(2026, 11, 25),
        dueHour: 23,
        dueMinute: 0,
        createdAt: DateTime(2026, 11, 20),
      );
      final reminders = NotificationScheduleCalculator.compute(
        maxMaskTask,
        const ReminderSettings(),
        now: DateTime(2026, 11, 20, 10, 0),
      );

      for (final r in reminders) {
        expect(r.id, greaterThan(0));
        expect(r.id, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });

    test('returns no reminders when task is completed or disabled', () {
      final completed = taskWithDueTime.copyWith(isCompleted: true);
      expect(
        NotificationScheduleCalculator.compute(
          completed,
          settings,
          now: DateTime(2026, 11, 20, 19, 0),
        ),
        isEmpty,
      );

      expect(
        NotificationScheduleCalculator.compute(
          taskWithDueTime,
          settings.copyWith(enabled: false),
          now: DateTime(2026, 11, 20, 19, 0),
        ),
        isEmpty,
      );
    });

    test('default settings use 4:00 PM day-before and 10:00 PM due-day', () {
      const defaults = ReminderSettings();
      expect(defaults.dayBeforeHour, 16);
      expect(defaults.dayBeforeMinute, 0);
      expect(defaults.endOfDayHour, 22);
      expect(defaults.endOfDayMinute, 0);

      final reminders = NotificationScheduleCalculator.compute(
        taskNoDueTime,
        defaults,
        now: DateTime(2026, 11, 21, 10, 0),
      );

      expect(reminders.length, 3);
      expect(reminders[0].scheduledAt, DateTime(2026, 11, 21, 16, 0));
      expect(reminders[1].scheduledAt, DateTime(2026, 11, 21, 22, 0));
      expect(reminders[2].scheduledAt, DateTime(2026, 11, 22, 22, 0));
    });
  });
}
