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
        'schedules day-before, custom task due-time, and end-of-day alerts for tasks with dueTime',
        () {
      final reminders = NotificationScheduleCalculator.compute(
        taskWithDueTime,
        settings,
        now: DateTime(2026, 11, 20, 19, 0),
      );

      expect(reminders.length, 3);
      expect(reminders[0].id, 1500);
      expect(reminders[0].isDayBefore, isTrue);
      expect(reminders[0].scheduledAt, DateTime(2026, 11, 21, 20, 0));
      expect(reminders[0].title, contains('Upcoming tomorrow'));

      expect(reminders[1].id, 1502);
      expect(reminders[1].isCustomTime, isTrue);
      expect(reminders[1].scheduledAt, DateTime(2026, 11, 22, 10, 0));
      expect(reminders[1].title, contains('Reminder: Class Test'));

      expect(reminders[2].id, 1501);
      expect(reminders[2].isDayBefore, isFalse);
      expect(reminders[2].scheduledAt, DateTime(2026, 11, 22, 21, 0));
      expect(reminders[2].title, contains('Mark task complete'));
    });

    test('schedules 2 alerts when task has no custom dueTime', () {
      final reminders = NotificationScheduleCalculator.compute(
        taskNoDueTime,
        settings,
        now: DateTime(2026, 11, 20, 19, 0),
      );

      expect(reminders.length, 2);
      expect(reminders[0].scheduledAt, DateTime(2026, 11, 21, 20, 0));
      expect(reminders[1].scheduledAt, DateTime(2026, 11, 22, 21, 0));
    });

    test('skips past day-before window and fires current-minute reminder in 5s',
        () {
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
        now: DateTime(2026, 11, 22, 17, 58, 20),
      );

      expect(reminders.length, 2);
      expect(reminders[0].isCustomTime, isTrue);
      expect(reminders[0].scheduledAt, DateTime(2026, 11, 22, 17, 58, 25));
      expect(reminders[1].scheduledAt, DateTime(2026, 11, 22, 22, 0));
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
        now: DateTime(2026, 11, 20, 19, 0),
      );

      expect(reminders.length, 2);
      expect(reminders[0].scheduledAt, DateTime(2026, 11, 21, 16, 0));
      expect(reminders[1].scheduledAt, DateTime(2026, 11, 22, 22, 0));
    });
  });
}
