import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:h_todo_ai/models/custom_task_type.dart';
import 'package:h_todo_ai/models/reminder_settings.dart';
import 'package:h_todo_ai/models/task_item.dart';
import 'package:h_todo_ai/providers/task_provider.dart';
import 'package:h_todo_ai/services/local_command_parser.dart';
import 'package:h_todo_ai/services/notification_service.dart';
import 'package:h_todo_ai/services/storage_service.dart';
import 'package:h_todo_ai/widgets/task_type_icons.dart';

void main() {
  group('Expanded built-in & custom task types', () {
    test('TaskType.fromString resolves all 21 types and common synonyms', () {
      expect(TaskType.fromString('mail'), TaskType.mail);
      expect(TaskType.fromString('email'), TaskType.mail);
      expect(TaskType.fromString('travel'), TaskType.travel);
      expect(TaskType.fromString('flight'), TaskType.travel);
      expect(TaskType.fromString('bank'), TaskType.bank);
      expect(TaskType.fromString('finance'), TaskType.bank);
      expect(TaskType.fromString('institution'), TaskType.institution);
      expect(TaskType.fromString('university'), TaskType.institution);
      expect(TaskType.fromString('call'), TaskType.call);
      expect(TaskType.fromString('phone'), TaskType.call);
      expect(TaskType.fromString('work'), TaskType.work);
      expect(TaskType.fromString('study'), TaskType.study);
      expect(TaskType.fromString('bill'), TaskType.bill);
      expect(TaskType.fromString('rent'), TaskType.bill);
      expect(TaskType.fromString('shopping'), TaskType.shopping);
      expect(TaskType.fromString('grocery'), TaskType.shopping);
      expect(TaskType.fromString('health'), TaskType.health);
      expect(TaskType.fromString('doctor'), TaskType.health);
      expect(TaskType.fromString('fitness'), TaskType.fitness);
      expect(TaskType.fromString('gym'), TaskType.fitness);
      expect(TaskType.fromString('event'), TaskType.event);
      expect(TaskType.fromString('family'), TaskType.family);
      expect(TaskType.fromString('document'), TaskType.document);
      expect(TaskType.fromString('passport'), TaskType.document);
      expect(TaskType.fromString('personal'), TaskType.personal);
    });

    test('LocalCommandParser infers expanded EN/BN task categories', () {
      const reminders = ReminderSettings();
      final fixedNow = DateTime(2026, 11, 28, 9, 0);

      TaskType infer(String input) {
        final res = LocalCommandParser.tryParse(
          input,
          existingTasks: const [],
          reminderSettings: reminders,
          now: fixedNow,
        );
        expect(res, isNotNull, reason: 'Expected local parse for: $input');
        return res!.actions.single.newTask!.type;
      }

      expect(infer('Tomorrow 10:00 AM Send Mail to HR'), TaskType.mail);
      expect(infer('Tomorrow 8:00 AM Dhaka Travel plan'), TaskType.travel);
      expect(infer('Today 2:00 PM Bank visit'), TaskType.bank);
      expect(infer('Tomorrow 11:00 AM Institution registration'), TaskType.institution);
      expect(infer('Today 5:00 PM Call Advisor'), TaskType.call);
      expect(infer('Tomorrow 6:00 PM Pay Internet Bill'), TaskType.bill);
      expect(infer('Today 4:00 PM Doctor checkup'), TaskType.health);
      expect(infer('Tomorrow 9:00 AM Passport document pickup'), TaskType.document);
      expect(infer('কাল সকাল ১০টায় ব্যাংকে যাওয়া'), TaskType.bank);
      expect(infer('কাল বিকাল ৪টায় মেইল পাঠানো'), TaskType.mail);
    });

    test('customTypeIconByKey and taskIconForItem resolve safely for all icons and snapshots', () {
      for (final opt in kCustomTypeIconOptions) {
        expect(customTypeIconByKey(opt.key), opt.icon);
      }
      expect(taskTypeIcon(TaskType.mail), Icons.mail_outline_rounded);
      expect(taskTypeIcon(TaskType.travel), Icons.flight_takeoff_rounded);
      expect(taskTypeIcon(TaskType.bank), Icons.account_balance_rounded);
      expect(taskTypeIcon(TaskType.institution), Icons.apartment_rounded);

      const liveCustom = CustomTaskType(
        id: 'c-1',
        name: 'Visa Office',
        iconKey: 'institution',
      );
      final task = TaskItem(
        id: 't-1',
        notificationBaseId: 11,
        title: 'Submit application',
        dueDate: DateTime(2026, 11, 28),
        createdAt: DateTime(2026, 11, 28),
        customTypeId: 'c-1',
        customTypeLabel: 'Old Label',
        customTypeIconKey: 'document',
      );

      // Uses live CustomTaskType when present.
      expect(taskIconForItem(task, [liveCustom]), Icons.apartment_rounded);
      expect(taskLabelForItem(task, [liveCustom]), 'Visa Office');

      // Falls back cleanly to snapshot when custom category is deleted.
      expect(taskIconForItem(task, const []), Icons.folder_copy_outlined);
      expect(taskLabelForItem(task, const []), 'Old Label');
    });

    test('TaskProvider persists, updates across tasks, and deletes custom task types', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      final provider = TaskProvider(
        storage: storage,
        notifications: NotificationService(),
      );
      await provider.load();

      final created = await provider.addCustomTaskType(
        name: 'Bank Loan',
        iconKey: 'bank',
      );
      expect(created, isNotNull);
      expect(provider.customTaskTypes, hasLength(1));

      await provider.addTask(
        TaskItem(
          id: 'task-1',
          notificationBaseId: 21,
          title: 'Sign papers',
          dueDate: DateTime(2026, 11, 28),
          createdAt: DateTime(2026, 11, 28),
          customTypeId: created!.id,
          customTypeLabel: created.name,
          customTypeIconKey: created.iconKey,
        ),
      );

      await provider.updateCustomTaskType(
        created.copyWith(name: 'Home Loan', iconKey: 'home'),
      );
      expect(provider.tasks.single.customTypeLabel, 'Home Loan');
      expect(provider.tasks.single.customTypeIconKey, 'home');

      final reloadedStorage = await storage.loadCustomTaskTypes();
      expect(reloadedStorage.single.name, 'Home Loan');
      expect(reloadedStorage.single.iconKey, 'home');

      await provider.deleteCustomTaskType(created.id);
      expect(provider.customTaskTypes, isEmpty);
      // Task snapshot stays intact cleanly.
      expect(provider.tasks.single.displayTypeLabel, 'Home Loan');
    });
  });
}
