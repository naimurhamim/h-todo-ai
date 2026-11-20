import 'package:flutter_test/flutter_test.dart';

import 'package:h_todo_ai/models/reminder_settings.dart';
import 'package:h_todo_ai/models/task_item.dart';
import 'package:h_todo_ai/services/notification_service.dart';

void main() {
  group('NotificationScheduleCalculator.compute', () {
    final task = TaskItem(
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

    const settings = ReminderSettings(
      enabled: true,
      dayBeforeHour: 20,
      dayBeforeMinute: 0,
      endOfDayHour: 21,
      endOfDayMinute: 0,
    );

    test('schedules both day-before and end-of-day alerts for future tasks', () {
      final reminders = NotificationScheduleCalculator.compute(
        task,
        settings,
        now: DateTime(2026, 11, 20, 19, 0),
      );

      expect(reminders.length, 2);
      expect(reminders[0].id, 1000);
      expect(reminders[0].isDayBefore, isTrue);
      expect(reminders[0].scheduledAt, DateTime(2026, 11, 21, 20, 0));
      expect(reminders[0].title, contains('Upcoming tomorrow'));

      expect(reminders[1].id, 1001);
      expect(reminders[1].isDayBefore, isFalse);
      expect(reminders[1].scheduledAt, DateTime(2026, 11, 22, 21, 0));
      expect(reminders[1].title, contains('Mark task complete'));
    });

    test('schedules only end-of-day when day-before window has passed', () {
      final reminders = NotificationScheduleCalculator.compute(
        task,
        settings,
        now: DateTime(2026, 11, 22, 9, 0),
      );

      expect(reminders.length, 1);
      expect(reminders.single.isDayBefore, isFalse);
      expect(reminders.single.scheduledAt, DateTime(2026, 11, 22, 21, 0));
    });

    test('returns no reminders when task is completed or disabled', () {
      final completed = task.copyWith(isCompleted: true);
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
          task,
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
        task,
        defaults,
        now: DateTime(2026, 11, 20, 19, 0),
      );

      expect(reminders.length, 2);
      expect(reminders[0].scheduledAt, DateTime(2026, 11, 21, 16, 0));
      expect(reminders[1].scheduledAt, DateTime(2026, 11, 22, 22, 0));
    });
  });
}
