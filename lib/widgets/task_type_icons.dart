import 'package:flutter/material.dart';

import '../models/custom_task_type.dart';
import '../models/task_item.dart';

/// Curated const Material icon option selectable for custom task categories.
@immutable
class CustomTypeIconOption {
  const CustomTypeIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

/// Tree-shake-safe catalog of 30 icons users can attach to custom task types.
const List<CustomTypeIconOption> kCustomTypeIconOptions = [
  CustomTypeIconOption(key: 'label', label: 'Tag', icon: Icons.bookmark_border_rounded),
  CustomTypeIconOption(key: 'mail', label: 'Mail', icon: Icons.mail_outline_rounded),
  CustomTypeIconOption(key: 'travel', label: 'Travel', icon: Icons.flight_takeoff_rounded),
  CustomTypeIconOption(key: 'bank', label: 'Bank', icon: Icons.account_balance_rounded),
  CustomTypeIconOption(key: 'institution', label: 'Office', icon: Icons.apartment_rounded),
  CustomTypeIconOption(key: 'call', label: 'Call', icon: Icons.call_outlined),
  CustomTypeIconOption(key: 'shopping', label: 'Shop', icon: Icons.shopping_bag_outlined),
  CustomTypeIconOption(key: 'health', label: 'Health', icon: Icons.medical_services_outlined),
  CustomTypeIconOption(key: 'bill', label: 'Bill', icon: Icons.receipt_long_outlined),
  CustomTypeIconOption(key: 'work', label: 'Work', icon: Icons.work_outline_rounded),
  CustomTypeIconOption(key: 'study', label: 'Study', icon: Icons.menu_book_rounded),
  CustomTypeIconOption(key: 'event', label: 'Event', icon: Icons.celebration_outlined),
  CustomTypeIconOption(key: 'fitness', label: 'Fitness', icon: Icons.fitness_center_rounded),
  CustomTypeIconOption(key: 'family', label: 'Family', icon: Icons.family_restroom_rounded),
  CustomTypeIconOption(key: 'document', label: 'Docs', icon: Icons.folder_copy_outlined),
  CustomTypeIconOption(key: 'home', label: 'Home', icon: Icons.home_outlined),
  CustomTypeIconOption(key: 'car', label: 'Ride', icon: Icons.directions_car_outlined),
  CustomTypeIconOption(key: 'food', label: 'Food', icon: Icons.restaurant_outlined),
  CustomTypeIconOption(key: 'code', label: 'Code', icon: Icons.code_rounded),
  CustomTypeIconOption(key: 'payment', label: 'Pay', icon: Icons.payments_outlined),
  CustomTypeIconOption(key: 'gift', label: 'Gift', icon: Icons.card_giftcard_outlined),
  CustomTypeIconOption(key: 'music', label: 'Music', icon: Icons.music_note_outlined),
  CustomTypeIconOption(key: 'camera', label: 'Photo', icon: Icons.photo_camera_outlined),
  CustomTypeIconOption(key: 'pet', label: 'Pet', icon: Icons.pets_outlined),
  CustomTypeIconOption(key: 'star', label: 'Priority', icon: Icons.star_outline_rounded),
  CustomTypeIconOption(key: 'flag', label: 'Goal', icon: Icons.flag_outlined),
  CustomTypeIconOption(key: 'build', label: 'Fix', icon: Icons.build_outlined),
  CustomTypeIconOption(key: 'volunteer', label: 'Care', icon: Icons.volunteer_activism_outlined),
  CustomTypeIconOption(key: 'mosque', label: 'Prayer', icon: Icons.mosque_outlined),
  CustomTypeIconOption(key: 'idea', label: 'Idea', icon: Icons.lightbulb_outline_rounded),
];

/// Static const switch lookup so Flutter release icon tree-shaking keeps every icon.
IconData customTypeIconByKey(String? key) {
  switch ((key ?? '').trim()) {
    case 'mail':
      return Icons.mail_outline_rounded;
    case 'travel':
      return Icons.flight_takeoff_rounded;
    case 'bank':
      return Icons.account_balance_rounded;
    case 'institution':
      return Icons.apartment_rounded;
    case 'call':
      return Icons.call_outlined;
    case 'shopping':
      return Icons.shopping_bag_outlined;
    case 'health':
      return Icons.medical_services_outlined;
    case 'bill':
      return Icons.receipt_long_outlined;
    case 'work':
      return Icons.work_outline_rounded;
    case 'study':
      return Icons.menu_book_rounded;
    case 'event':
      return Icons.celebration_outlined;
    case 'fitness':
      return Icons.fitness_center_rounded;
    case 'family':
      return Icons.family_restroom_rounded;
    case 'document':
      return Icons.folder_copy_outlined;
    case 'home':
      return Icons.home_outlined;
    case 'car':
      return Icons.directions_car_outlined;
    case 'food':
      return Icons.restaurant_outlined;
    case 'code':
      return Icons.code_rounded;
    case 'payment':
      return Icons.payments_outlined;
    case 'gift':
      return Icons.card_giftcard_outlined;
    case 'music':
      return Icons.music_note_outlined;
    case 'camera':
      return Icons.photo_camera_outlined;
    case 'pet':
      return Icons.pets_outlined;
    case 'star':
      return Icons.star_outline_rounded;
    case 'flag':
      return Icons.flag_outlined;
    case 'build':
      return Icons.build_outlined;
    case 'volunteer':
      return Icons.volunteer_activism_outlined;
    case 'mosque':
      return Icons.mosque_outlined;
    case 'idea':
      return Icons.lightbulb_outline_rounded;
    case 'label':
    default:
      return Icons.bookmark_border_rounded;
  }
}

/// Clean minimalist icon mapping for each built-in task category.
IconData taskTypeIcon(TaskType type) {
  switch (type) {
    case TaskType.assignment:
      return Icons.description_outlined;
    case TaskType.classTest:
      return Icons.edit_note_rounded;
    case TaskType.exam:
      return Icons.school_outlined;
    case TaskType.lab:
      return Icons.science_outlined;
    case TaskType.meeting:
      return Icons.groups_outlined;
    case TaskType.mail:
      return Icons.mail_outline_rounded;
    case TaskType.travel:
      return Icons.flight_takeoff_rounded;
    case TaskType.bank:
      return Icons.account_balance_rounded;
    case TaskType.institution:
      return Icons.apartment_rounded;
    case TaskType.call:
      return Icons.call_outlined;
    case TaskType.work:
      return Icons.work_outline_rounded;
    case TaskType.study:
      return Icons.menu_book_rounded;
    case TaskType.bill:
      return Icons.receipt_long_outlined;
    case TaskType.shopping:
      return Icons.shopping_bag_outlined;
    case TaskType.health:
      return Icons.medical_services_outlined;
    case TaskType.fitness:
      return Icons.fitness_center_rounded;
    case TaskType.event:
      return Icons.celebration_outlined;
    case TaskType.family:
      return Icons.family_restroom_rounded;
    case TaskType.document:
      return Icons.folder_copy_outlined;
    case TaskType.personal:
      return Icons.person_outline_rounded;
    case TaskType.task:
      return Icons.bookmark_border_rounded;
  }
}

/// Resolves the effective display icon for [task], prioritizing live custom categories
/// and saved custom type snapshots before falling back to built-in [TaskType].
IconData taskIconForItem(
  TaskItem task, [
  List<CustomTaskType> customTypes = const [],
]) {
  final customId = task.customTypeId?.trim();
  if (customId != null && customId.isNotEmpty) {
    for (final custom in customTypes) {
      if (custom.id == customId) {
        return customTypeIconByKey(custom.iconKey);
      }
    }
  }
  final customIconKey = task.customTypeIconKey?.trim();
  if (customIconKey != null && customIconKey.isNotEmpty) {
    return customTypeIconByKey(customIconKey);
  }
  return taskTypeIcon(task.type);
}

/// Resolves the display label for [task], using live custom categories when present
/// or falling back to saved custom snapshot label and built-in [TaskType.label].
String taskLabelForItem(
  TaskItem task, [
  List<CustomTaskType> customTypes = const [],
]) {
  final customId = task.customTypeId?.trim();
  if (customId != null && customId.isNotEmpty) {
    for (final custom in customTypes) {
      if (custom.id == customId && custom.name.trim().isNotEmpty) {
        return custom.name.trim();
      }
    }
  }
  return task.displayTypeLabel;
}
