import 'package:flutter_test/flutter_test.dart';

import 'package:h_todo_ai/models/reminder_settings.dart';
import 'package:h_todo_ai/models/task_item.dart';
import 'package:h_todo_ai/services/notification_service.dart';

void main() {
  group('NotificationScheduleCalculator.compute', () {
    final taskWithCustomTime = TaskItem(
      id: 'task-1',
      notificationBaseId: 500,
      title: 'Class Test',
      courseOrCategory: 'IRE 415 – Computer Vision',
      type: TaskType.classTest,
      dueDate: DateTime(2026, 11, 25),
      dueHour: 10,
      dueMinute: 0,
      createdAt: DateTime(2026, 11, 20),
    );

    final taskNoCustomTime = TaskItem(
      id: 'task-2',
      notificationBaseId: 501,
      title: 'Assignment 01',
      courseOrCategory: 'IRE 415',
      type: TaskType.assignment,
      dueDate: DateTime(2026, 11, 25),
      createdAt: DateTime(2026, 11, 20),
    );

    const settings = ReminderSettings(
      enabled: true,
      dayBeforeHour: 17,
      dayBeforeMinute: 0,
      endOfDayHour: 22,
      endOfDayMinute: 0,
    );

    test(
        'task WITH custom time schedules ONLY 1 alert on dueDate and disables defaults',
        () {
      final reminders = NotificationScheduleCalculator.compute(
        taskWithCustomTime,
        settings,
        now: DateTime(2026, 11, 22, 16, 55),
      );

      expect(reminders, hasLength(1));
      expect(reminders.first.id, 500 * 3 + 2);
      expect(reminders.first.isCustomTime, isTrue);
      expect(reminders.first.isDayBefore, isFalse);
      expect(reminders.first.scheduledAt, DateTime(2026, 11, 25, 10, 0));
      expect(reminders.first.title, 'Reminder: Class Test');
    });

    test(
        'task WITHOUT custom time schedules Day-Before ONLY on D-1 and End-of-Day ONLY on D (never today for future dates)',
        () {
      // On Nov 22 at 16:55, a MID Exam due on Nov 25 must NOT fire at 17:00 today.
      final remindersFromEarlierDay = NotificationScheduleCalculator.compute(
        taskNoCustomTime,
        settings,
        now: DateTime(2026, 11, 22, 16, 55),
      );

      expect(remindersFromEarlierDay, hasLength(2));
      expect(
        remindersFromEarlierDay.any((r) => r.scheduledAt.day == 22),
        isFalse,
      );
      expect(remindersFromEarlierDay[0].id, 501 * 3);
      expect(remindersFromEarlierDay[0].isDayBefore, isTrue);
      expect(
        remindersFromEarlierDay[0].scheduledAt,
        DateTime(2026, 11, 24, 17, 0),
      );
      expect(remindersFromEarlierDay[0].title, 'Upcoming tomorrow: Assignment 01');

      expect(remindersFromEarlierDay[1].id, 501 * 3 + 1);
      expect(remindersFromEarlierDay[1].isDayBefore, isFalse);
      expect(
        remindersFromEarlierDay[1].scheduledAt,
        DateTime(2026, 11, 25, 22, 0),
      );
      expect(
        remindersFromEarlierDay[1].title,
        'Mark task complete: Assignment 01',
      );
    });

    test(
        'task due today without custom time skips past yesterday Day-Before and schedules ONLY today End-of-Day',
        () {
      final todayTask = TaskItem(
        id: 'task-today',
        notificationBaseId: 503,
        title: 'Lab Report',
        dueDate: DateTime(2026, 11, 22),
        createdAt: DateTime(2026, 11, 20),
      );

      final reminders = NotificationScheduleCalculator.compute(
        todayTask,
        settings,
        now: DateTime(2026, 11, 22, 16, 55),
      );

      expect(reminders, hasLength(1));
      expect(reminders.first.id, 503 * 3 + 1);
      expect(reminders.first.isDayBefore, isFalse);
      expect(reminders.first.isCustomTime, isFalse);
      expect(reminders.first.scheduledAt, DateTime(2026, 11, 22, 22, 0));
    });

    test(
        'task due today with custom time in current minute (0-59s) fires 1 custom alert 5s ahead and no defaults',
        () {
      final todayCustom = TaskItem(
        id: 'task-custom-now',
        notificationBaseId: 504,
        title: 'Quick Test',
        dueDate: DateTime(2026, 11, 22),
        dueHour: 17,
        dueMinute: 58,
        createdAt: DateTime(2026, 11, 22),
      );

      final reminders = NotificationScheduleCalculator.compute(
        todayCustom,
        const ReminderSettings(),
        now: DateTime(2026, 11, 22, 17, 58, 58),
      );

      expect(reminders, hasLength(1));
      expect(reminders.first.isCustomTime, isTrue);
      expect(reminders.first.id, 504 * 3 + 2);
      expect(reminders.first.scheduledAt, DateTime(2026, 11, 22, 17, 59, 3));
    });

    test('overdue uncompleted, completed, and disabled tasks return empty list',
        () {
      final overdueDefault = TaskItem(
        id: 'overdue-1',
        notificationBaseId: 505,
        title: 'Overdue Quiz',
        dueDate: DateTime(2026, 11, 20),
        createdAt: DateTime(2026, 11, 18),
      );
      final overdueCustom = overdueDefault.copyWith(
        dueHour: 20,
        dueMinute: 0,
      );

      expect(
        NotificationScheduleCalculator.compute(
          overdueDefault,
          settings,
          now: DateTime(2026, 11, 22, 10, 0),
        ),
        isEmpty,
      );
      expect(
        NotificationScheduleCalculator.compute(
          overdueCustom,
          settings,
          now: DateTime(2026, 11, 22, 10, 0),
        ),
        isEmpty,
      );

      final completed = taskNoCustomTime.copyWith(isCompleted: true);
      expect(
        NotificationScheduleCalculator.compute(
          completed,
          settings,
          now: DateTime(2026, 11, 22, 10, 0),
        ),
        isEmpty,
      );

      expect(
        NotificationScheduleCalculator.compute(
          taskNoCustomTime,
          settings.copyWith(enabled: false),
          now: DateTime(2026, 11, 22, 10, 0),
        ),
        isEmpty,
      );
    });

    test('derived notification IDs always remain positive 31-bit Android IDs',
        () {
      final maxMaskTask = TaskItem(
        id: 'max-id-test',
        notificationBaseId: 0x0FFFFFFF,
        title: 'ID Bounds',
        dueDate: DateTime(2026, 11, 25),
        createdAt: DateTime(2026, 11, 20),
      );
      final reminders = NotificationScheduleCalculator.compute(
        maxMaskTask,
        const ReminderSettings(),
        now: DateTime(2026, 11, 20, 10, 0),
      );

      expect(reminders, hasLength(2));
      for (final r in reminders) {
        expect(r.id, greaterThan(0));
        expect(r.id, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });

    test('default settings use 4:00 PM day-before and 10:00 PM due-day', () {
      const defaults = ReminderSettings();
      expect(defaults.dayBeforeHour, 16);
      expect(defaults.dayBeforeMinute, 0);
      expect(defaults.endOfDayHour, 22);
      expect(defaults.endOfDayMinute, 0);

      final reminders = NotificationScheduleCalculator.compute(
        taskNoCustomTime,
        defaults,
        now: DateTime(2026, 11, 22, 10, 0),
      );

      expect(reminders, hasLength(2));
      expect(reminders[0].scheduledAt, DateTime(2026, 11, 24, 16, 0));
      expect(reminders[1].scheduledAt, DateTime(2026, 11, 25, 22, 0));
    });
  });

  group('NotificationScheduleCalculator.computeRollingWindow', () {
    test(
        'caps active alarms at 99, prioritizes soonest alerts including urgent tomorrow task, and rolls forward',
        () {
      // Create 120 daily tasks with default reminders (= 240 potential alarms).
      final baseDay = DateTime(2026, 11, 22);
      final tasks = List.generate(120, (i) {
        final d = DateTime(baseDay.year, baseDay.month, baseDay.day + i + 2);
        return TaskItem(
          id: 'series-$i',
          notificationBaseId: 1000 + i,
          title: 'Daily Habit #$i',
          dueDate: d,
          createdAt: baseDay,
        );
      });

      // Add an urgent task for tomorrow morning AFTER the series list.
      final urgentTomorrow = TaskItem(
        id: 'urgent-ct',
        notificationBaseId: 9999,
        title: 'Urgent Class Test',
        dueDate: DateTime(2026, 11, 23),
        dueHour: 8,
        dueMinute: 30,
        createdAt: baseDay,
      );
      final allTasks = [...tasks, urgentTomorrow];

      final windowNow = NotificationScheduleCalculator.computeRollingWindow(
        allTasks,
        const ReminderSettings(),
        now: DateTime(2026, 11, 22, 18, 0),
      );

      expect(windowNow, hasLength(99));
      expect(windowNow.first.taskId, 'urgent-ct');
      expect(
        windowNow.first.reminder.scheduledAt,
        DateTime(2026, 11, 23, 8, 30),
      );
      expect(
        windowNow.any((e) => e.taskId == 'series-119'),
        isFalse,
      );

      // Roll clock forward 75 days: old tasks pass out, tail tasks (series-119) roll in!
      final windowLater = NotificationScheduleCalculator.computeRollingWindow(
        allTasks,
        const ReminderSettings(),
        now: DateTime(2027, 2, 5, 10, 0),
      );
      expect(windowLater, isNotEmpty);
      expect(windowLater.length, lessThanOrEqualTo(99));
      expect(
        windowLater.any((e) => e.taskId == 'series-119'),
        isTrue,
      );
    });
  });
}
