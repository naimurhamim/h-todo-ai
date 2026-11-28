import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_chat_action.dart';
import '../models/reminder_settings.dart';
import '../models/task_item.dart';

enum ChatPresetKind { instantQa, template }

@immutable
class ChatPreset {
  const ChatPreset({
    required this.id,
    required this.label,
    required this.command,
    required this.kind,
  });

  final String id;
  final String label;
  final String command;
  final ChatPresetKind kind;
}

/// Deterministic zero-token local command and Q&A parser with built-in chat presets.
///
/// Always returns `null` when a message is ambiguous, multi-line, contains a syllabus
/// or vague pronoun, or falls outside supported strict patterns so Cloud AI can handle it
/// exclusively with zero overlap or double execution.
abstract final class LocalCommandParser {
  static const _uuid = Uuid();
  static const String localProviderLabel = 'Local • Instant';

  static const List<ChatPreset> presets = [
    ChatPreset(
      id: 'qa_today',
      label: 'Today',
      command: 'What is due today?',
      kind: ChatPresetKind.instantQa,
    ),
    ChatPreset(
      id: 'qa_tomorrow',
      label: 'Tomorrow',
      command: 'What is due tomorrow?',
      kind: ChatPresetKind.instantQa,
    ),
    ChatPreset(
      id: 'qa_week',
      label: 'This Week',
      command: 'Show tasks for this week',
      kind: ChatPresetKind.instantQa,
    ),
    ChatPreset(
      id: 'qa_next',
      label: 'Next Due',
      command: 'What is my next deadline?',
      kind: ChatPresetKind.instantQa,
    ),
    ChatPreset(
      id: 'qa_overdue',
      label: 'Overdue',
      command: 'Show overdue tasks',
      kind: ChatPresetKind.instantQa,
    ),
    ChatPreset(
      id: 'qa_summary',
      label: 'Summary',
      command: 'Show task summary',
      kind: ChatPresetKind.instantQa,
    ),
    ChatPreset(
      id: 'qa_reminders',
      label: 'Reminders',
      command: 'Show reminder settings',
      kind: ChatPresetKind.instantQa,
    ),
    ChatPreset(
      id: 'tpl_quick',
      label: 'Quick Task',
      command: 'Tomorrow 10:00 AM ',
      kind: ChatPresetKind.template,
    ),
    ChatPreset(
      id: 'tpl_daily',
      label: 'Daily Routine',
      command: 'Daily 8:00 AM Study for 30 days',
      kind: ChatPresetKind.template,
    ),
    ChatPreset(
      id: 'tpl_twice',
      label: 'Twice Daily',
      command: 'Daily 8:00 AM & 9:00 PM Revision for 40 days',
      kind: ChatPresetKind.template,
    ),
    ChatPreset(
      id: 'tpl_weekly',
      label: 'Weekly',
      command: 'Every Sun, Tue, Thu 9:00 AM Class for 3 months',
      kind: ChatPresetKind.template,
    ),
    ChatPreset(
      id: 'tpl_monthly',
      label: 'Monthly',
      command: 'Every month on 1st 10:00 AM Bill for 6 months',
      kind: ChatPresetKind.template,
    ),
    ChatPreset(
      id: 'tpl_postpone',
      label: 'Postpone Today',
      command: "Postpone today's tasks by 1 day",
      kind: ChatPresetKind.template,
    ),
    ChatPreset(
      id: 'tpl_clear_done',
      label: 'Clear Done',
      command: 'Delete all completed tasks',
      kind: ChatPresetKind.template,
    ),
    ChatPreset(
      id: 'tpl_pause_alerts',
      label: 'Pause Alerts',
      command: 'Pause reminders',
      kind: ChatPresetKind.template,
    ),
  ];

  static AiAssistantResponse? tryParse(
    String rawMessage, {
    required List<TaskItem> existingTasks,
    required ReminderSettings reminderSettings,
    DateTime? now,
  }) {
    final trimmed = rawMessage.trim();
    if (trimmed.isEmpty) return null;

    // Complex multi-line notices, syllabi, or conversational references go strictly to Cloud AI.
    if (trimmed.contains('\n') || trimmed.length > 140) return null;

    final refNow = now ?? DateTime.now();
    final today = DateTime(refNow.year, refNow.month, refNow.day);
    final isBengali = _containsBengali(trimmed);
    final normalized = _normalizeDigits(trimmed);
    final lower = normalized.toLowerCase().trim();

    if (_hasComplexityMarkers(lower)) {
      return null;
    }

    // 1. Instant Q&A Queries (always safe and read-only).
    final qaResult = _tryParseQuery(
      lower: lower,
      isBengali: isBengali,
      existingTasks: existingTasks,
      reminderSettings: reminderSettings,
      today: today,
    );
    if (qaResult != null) return qaResult;

    // 2. Reminder toggle commands.
    final reminderToggle = _tryParseReminderToggle(
      lower: lower,
      isBengali: isBengali,
    );
    if (reminderToggle != null) return reminderToggle;

    // 3. Safe scoped bulk commands.
    final bulkCmd = _tryParseSafeBulk(
      lower: lower,
      isBengali: isBengali,
      today: today,
    );
    if (bulkCmd != null) return bulkCmd;

    // 4. Structured recurring templates / direct commands.
    final recurring = _tryParseRecurring(
      original: normalized,
      lower: lower,
      isBengali: isBengali,
      today: today,
    );
    if (recurring != null) return recurring;

    // 5. Simple single quick task ("Tomorrow 10:00 AM Physics Quiz", "কাল ১০টায় কুইজ").
    final singleTask = _tryParseSimpleSingleTask(
      original: normalized,
      lower: lower,
      isBengali: isBengali,
      today: today,
      now: refNow,
    );
    if (singleTask != null) return singleTask;

    return null;
  }

  static bool _containsBengali(String text) =>
      RegExp(r'[\u0980-\u09FF]').hasMatch(text);

  static String _normalizeDigits(String input) {
    const bn = '০১২৩৪৫৬৭৮৯';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final buf = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final bi = bn.indexOf(ch);
      if (bi != -1) {
        buf.write(bi);
        continue;
      }
      final ai = ar.indexOf(ch);
      if (ai != -1) {
        buf.write(ai);
        continue;
      }
      buf.write(ch);
    }
    return buf.toString();
  }

  static bool _hasComplexityMarkers(String lower) {
    const blockedWords = [
      'syllabus',
      'chapter',
      'topic',
      ' সিলেবাস',
      'সিলেবাস',
      'reschedule ',
      'edit ',
      'rename ',
      'change ',
      'add subtask',
    ];
    if (lower.contains('●') || lower.contains('•')) return true;
    for (final word in blockedWords) {
      if (lower.contains(word)) return true;
    }
    if (RegExp(r'\b(it|that|this one|these|those|eta|ota|এটা|ওটা)\b')
        .hasMatch(lower)) {
      return true;
    }
    return false;
  }

  static DateTime _dayOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static List<TaskItem> _sortChronological(Iterable<TaskItem> tasks) {
    final list = tasks.toList();
    list.sort((a, b) {
      final d = _dayOnly(a.dueDate).compareTo(_dayOnly(b.dueDate));
      if (d != 0) return d;
      final h = (a.dueHour ?? 23).compareTo(b.dueHour ?? 23);
      if (h != 0) return h;
      final m = (a.dueMinute ?? 59).compareTo(b.dueMinute ?? 59);
      if (m != 0) return m;
      return a.priority.index.compareTo(b.priority.index);
    });
    return list;
  }

  static String _formatTaskLine(TaskItem t, {bool includeDate = false}) {
    final datePart =
        includeDate ? '${DateFormat('EEE d MMM').format(t.dueDate)} • ' : '';
    final timePart = t.formattedDueTime ?? 'No set time';
    return '- ${t.title} ($datePart$timePart)';
  }

  static AiAssistantResponse? _tryParseQuery({
    required String lower,
    required bool isBengali,
    required List<TaskItem> existingTasks,
    required ReminderSettings reminderSettings,
    required DateTime today,
  }) {
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 6));

    // Today Q&A
    if (RegExp(
      r'^(what is due today\??|due today\??|today\??|todays? tasks\??|'
      r"what's due today\??|show today'?s? tasks\??|আজ কী আছে\??|আজকের কাজ\??|আজকে কি আছে\??)$",
    ).hasMatch(lower)) {
      final matches = _sortChronological(
        existingTasks.where((t) => !t.isCompleted && _dayOnly(t.dueDate) == today),
      );
      if (matches.isEmpty) {
        return AiAssistantResponse(
          reply: isBengali
              ? 'আজকের জন্য কোনো বাকি কাজ নেই।'
              : 'No pending tasks due today.',
          handledLocally: true,
          resolvedProviderName: localProviderLabel,
        );
      }
      final lines = matches.take(5).map(_formatTaskLine).join('\n');
      final more = matches.length > 5 ? '\n+${matches.length - 5} more' : '';
      return AiAssistantResponse(
        reply: isBengali
            ? 'আজ ${matches.length}টি কাজ বাকি আছে:\n$lines$more'
            : '${matches.length} task${matches.length == 1 ? '' : 's'} due today:\n$lines$more',
        referencedTaskIds: matches.take(10).map((t) => t.id).toList(),
        handledLocally: true,
        resolvedProviderName: localProviderLabel,
      );
    }

    // Tomorrow Q&A
    if (RegExp(
      r'^(what is due tomorrow\??|due tomorrow\??|tomorrow\??|tomorrows? tasks\??|'
      r"what's due tomorrow\??|show tomorrow'?s? tasks\??|কাল কী আছে\??|আগামীকাল কী আছে\??|কালকের কাজ\??)$",
    ).hasMatch(lower)) {
      final matches = _sortChronological(
        existingTasks
            .where((t) => !t.isCompleted && _dayOnly(t.dueDate) == tomorrow),
      );
      if (matches.isEmpty) {
        return AiAssistantResponse(
          reply: isBengali
              ? 'আগামীকালের জন্য কোনো কাজ নির্ধারিত নেই।'
              : 'Nothing pending for tomorrow.',
          handledLocally: true,
          resolvedProviderName: localProviderLabel,
        );
      }
      final lines = matches.take(5).map(_formatTaskLine).join('\n');
      final more = matches.length > 5 ? '\n+${matches.length - 5} more' : '';
      return AiAssistantResponse(
        reply: isBengali
            ? 'আগামীকাল ${matches.length}টি কাজ রয়েছে:\n$lines$more'
            : '${matches.length} task${matches.length == 1 ? '' : 's'} due tomorrow:\n$lines$more',
        referencedTaskIds: matches.take(10).map((t) => t.id).toList(),
        handledLocally: true,
        resolvedProviderName: localProviderLabel,
      );
    }

    // This Week Q&A
    if (RegExp(
      r'^(show tasks for this week|this week\??|weekly tasks\??|'
      r"what'?s due this week\??|এই সপ্তাহের কাজ\??)$",
    ).hasMatch(lower)) {
      final matches = _sortChronological(
        existingTasks.where((t) {
          if (t.isCompleted) return false;
          final d = _dayOnly(t.dueDate);
          return !d.isBefore(today) && !d.isAfter(weekEnd);
        }),
      );
      if (matches.isEmpty) {
        return AiAssistantResponse(
          reply: isBengali
              ? 'আগামী ৭ দিনে কোনো বাকি কাজ নেই।'
              : 'No pending tasks in the next 7 days.',
          handledLocally: true,
          resolvedProviderName: localProviderLabel,
        );
      }
      final lines = matches
          .take(5)
          .map((t) => _formatTaskLine(t, includeDate: true))
          .join('\n');
      final more = matches.length > 5 ? '\n+${matches.length - 5} more' : '';
      return AiAssistantResponse(
        reply: isBengali
            ? 'আগামী ৭ দিনে ${matches.length}টি কাজ আছে:\n$lines$more'
            : '${matches.length} task${matches.length == 1 ? '' : 's'} in the next 7 days:\n$lines$more',
        referencedTaskIds: matches.take(10).map((t) => t.id).toList(),
        handledLocally: true,
        resolvedProviderName: localProviderLabel,
      );
    }

    // Next Deadline Q&A
    if (RegExp(
      r'^(what is my next deadline\??|next deadline\??|next task\??|next due\??|পরের কাজ কী\??)$',
    ).hasMatch(lower)) {
      final upcoming = _sortChronological(
        existingTasks
            .where((t) => !t.isCompleted && !_dayOnly(t.dueDate).isBefore(today)),
      );
      if (upcoming.isEmpty) {
        return AiAssistantResponse(
          reply: isBengali
              ? 'সামনে কোনো পেন্ডিং ডেডলাইন নেই।'
              : 'No upcoming deadlines right now.',
          handledLocally: true,
          resolvedProviderName: localProviderLabel,
        );
      }
      final next = upcoming.first;
      final dateLabel = _dayOnly(next.dueDate) == today
          ? (isBengali ? 'আজ' : 'Today')
          : _dayOnly(next.dueDate) == tomorrow
              ? (isBengali ? 'আগামীকাল' : 'Tomorrow')
              : DateFormat('EEE, d MMM').format(next.dueDate);
      final timeLabel =
          next.formattedDueTime != null ? ' • ${next.formattedDueTime}' : '';
      return AiAssistantResponse(
        reply: isBengali
            ? 'পরবর্তী ডেডলাইন: ${next.title} ($dateLabel$timeLabel)।'
            : 'Next deadline: ${next.title} ($dateLabel$timeLabel).',
        referencedTaskIds: [next.id],
        handledLocally: true,
        resolvedProviderName: localProviderLabel,
      );
    }

    // Overdue Q&A
    if (RegExp(
      r'^(show overdue tasks|overdue\??|overdue tasks\??|বাকি কাজ\??)$',
    ).hasMatch(lower)) {
      final overdue = _sortChronological(
        existingTasks
            .where((t) => !t.isCompleted && _dayOnly(t.dueDate).isBefore(today)),
      );
      if (overdue.isEmpty) {
        return AiAssistantResponse(
          reply: isBengali
              ? 'কোনো ওভারডিউ বা সময় পার হওয়া কাজ নেই।'
              : 'No overdue tasks. Everything is on track.',
          handledLocally: true,
          resolvedProviderName: localProviderLabel,
        );
      }
      final lines = overdue
          .take(5)
          .map((t) => _formatTaskLine(t, includeDate: true))
          .join('\n');
      return AiAssistantResponse(
        reply: isBengali
            ? '${overdue.length}টি ওভারডিউ কাজ রয়েছে:\n$lines'
            : '${overdue.length} overdue task${overdue.length == 1 ? '' : 's'}:\n$lines',
        referencedTaskIds: overdue.take(10).map((t) => t.id).toList(),
        handledLocally: true,
        resolvedProviderName: localProviderLabel,
      );
    }

    // Summary Q&A
    if (RegExp(
      r'^(show task summary|task summary\??|summary\??|status\??|পেন্ডিং কাজ কয়টা\??)$',
    ).hasMatch(lower)) {
      final total = existingTasks.length;
      final done = existingTasks.where((t) => t.isCompleted).length;
      final pending = total - done;
      final todayCount = existingTasks
          .where((t) => !t.isCompleted && _dayOnly(t.dueDate) == today)
          .length;
      final tmrCount = existingTasks
          .where((t) => !t.isCompleted && _dayOnly(t.dueDate) == tomorrow)
          .length;
      return AiAssistantResponse(
        reply: isBengali
            ? 'মোট $totalটি টাস্ক: আজ বাকি $todayCountটি, আগামীকাল $tmrCountটি, মোট পেন্ডিং $pendingটি ও সম্পন্ন $doneটি।'
            : 'Total $total tasks: $todayCount left today, $tmrCount tomorrow, $pending pending overall, and $done completed.',
        handledLocally: true,
        resolvedProviderName: localProviderLabel,
      );
    }

    // Reminder settings Q&A
    if (RegExp(
      r'^(show reminder settings|reminder settings\??|reminders\??|রিমাইন্ডার সময়\??)$',
    ).hasMatch(lower)) {
      final dayBefore = ReminderSettings.formatHourMinute(
        reminderSettings.dayBeforeHour,
        reminderSettings.dayBeforeMinute,
      );
      final dueDay = ReminderSettings.formatHourMinute(
        reminderSettings.endOfDayHour,
        reminderSettings.endOfDayMinute,
      );
      if (!reminderSettings.enabled) {
        return AiAssistantResponse(
          reply: isBengali
              ? 'রিমাইন্ডার এখন বন্ধ আছে (ডিফল্ট: আগের দিন $dayBefore এবং নির্ধারিত দিন $dueDay)।'
              : 'Reminders are currently paused (defaults: day before $dayBefore, due day $dueDay).',
          handledLocally: true,
          resolvedProviderName: localProviderLabel,
        );
      }
      return AiAssistantResponse(
        reply: isBengali
            ? 'রিমাইন্ডার চালু আছে: আগের দিন $dayBefore ও নির্ধারিত দিন $dueDay (কাস্টম সময় থাকলে শুধু সেটাই বাজবে)।'
            : 'Reminders active: day before at $dayBefore & due day at $dueDay (custom task times override defaults).',
        handledLocally: true,
        resolvedProviderName: localProviderLabel,
      );
    }

    return null;
  }

  static AiAssistantResponse? _tryParseReminderToggle({
    required String lower,
    required bool isBengali,
  }) {
    if (RegExp(
      r'^(pause|disable|turn off|mute|stop) (all )?reminders?$|রিমাইন্ডার বন্ধ করো$',
    ).hasMatch(lower)) {
      return AiAssistantResponse(
        reply: isBengali
            ? 'সব রিমাইন্ডার সাময়িকভাবে বন্ধ করা হয়েছে।'
            : 'All reminders have been paused.',
        actions: const [
          AiTaskAction(
            type: AiActionType.updateReminderSettings,
            remindersEnabled: false,
          ),
        ],
        handledLocally: true,
        resolvedProviderName: localProviderLabel,
      );
    }
    if (RegExp(
      r'^(enable|resume|turn on|start|unmute) (all )?reminders?$|রিমাইন্ডার চালু করো$',
    ).hasMatch(lower)) {
      return AiAssistantResponse(
        reply: isBengali
            ? 'রিমাইন্ডার আবার চালু ও শিডিউল করা হয়েছে।'
            : 'Reminders have been enabled and rescheduled.',
        actions: const [
          AiTaskAction(
            type: AiActionType.updateReminderSettings,
            remindersEnabled: true,
          ),
        ],
        handledLocally: true,
        resolvedProviderName: localProviderLabel,
      );
    }
    return null;
  }

  static AiAssistantResponse? _tryParseSafeBulk({
    required String lower,
    required bool isBengali,
    required DateTime today,
  }) {
    // Delete all completed tasks
    if (RegExp(
      r'^(delete|remove|clear) (all )?(completed|done) tasks?$|'
      r'সব কমপ্লিট( করা)? টাস্ক ডিলিট করো$',
    ).hasMatch(lower)) {
      return AiAssistantResponse(
        reply: isBengali
            ? 'কমপ্লিট করা সব টাস্ক পরিষ্কার করা হচ্ছে।'
            : 'Clearing all completed tasks.',
        actions: const [
          AiTaskAction(
            type: AiActionType.bulkDelete,
            bulkFilter: BulkTaskFilter(completedOnly: true),
          ),
        ],
        handledLocally: true,
        resolvedProviderName: localProviderLabel,
      );
    }

    // Postpone / shift today's pending tasks by N days
    final shiftMatch = RegExp(
      r"^(?:postpone|shift|move)\s+today'?s?\s+(?:tasks?\s+)?by\s+(\d{1,2})\s+days?$",
    ).firstMatch(lower);
    if (shiftMatch != null) {
      final days = int.tryParse(shiftMatch.group(1) ?? '');
      if (days != null && days >= 1 && days <= 30) {
        return AiAssistantResponse(
          reply: isBengali
              ? 'আজকের বাকি টাস্কগুলো $days দিন পেছানো হয়েছে।'
              : "Postponing today's pending tasks by $days day${days == 1 ? '' : 's'}.",
          actions: [
            AiTaskAction(
              type: AiActionType.bulkReschedule,
              shiftDays: days,
              bulkFilter: BulkTaskFilter(
                dateFrom: today,
                dateTo: today,
                pendingOnly: true,
              ),
            ),
          ],
          handledLocally: true,
          resolvedProviderName: localProviderLabel,
        );
      }
    }

    // Delete all tasks in a specific named month
    final monthDelMatch = RegExp(
      r'^(?:delete|remove|cancel|clear)\s+(?:all\s+)?tasks?\s+(?:in|for)\s+([a-z]+)(?:\s+(\d{4}))?$',
    ).firstMatch(lower);
    if (monthDelMatch != null) {
      final monthNum = _parseMonthName(monthDelMatch.group(1) ?? '');
      if (monthNum != null) {
        final explicitYear = int.tryParse(monthDelMatch.group(2) ?? '');
        final year = explicitYear ??
            (monthNum < today.month ? today.year + 1 : today.year);
        final from = DateTime(year, monthNum, 1);
        final to = DateTime(year, monthNum + 1, 0);
        final monthLabel = DateFormat('MMMM yyyy').format(from);
        return AiAssistantResponse(
          reply: isBengali
              ? '$monthLabel মাসের টাস্কগুলো মুছে ফেলা হচ্ছে।'
              : 'Removing scheduled tasks for $monthLabel.',
          actions: [
            AiTaskAction(
              type: AiActionType.bulkDelete,
              bulkFilter: BulkTaskFilter(dateFrom: from, dateTo: to),
            ),
          ],
          handledLocally: true,
          resolvedProviderName: localProviderLabel,
        );
      }
    }

    return null;
  }

  static AiAssistantResponse? _tryParseRecurring({
    required String original,
    required String lower,
    required bool isBengali,
    required DateTime today,
  }) {
    // Pattern A: Daily / Every N days [times] <Title> for <N> <days|weeks|months|years>
    final dailyMatch = RegExp(
      r'^(daily|every\s+day|every\s+(\d{1,2})\s+days)\s+(.+?)\s+for\s+(\d{1,3})\s+(days?|weeks?|months?|years?)$',
      caseSensitive: false,
    ).firstMatch(original);
    if (dailyMatch != null) {
      final everyN = int.tryParse(dailyMatch.group(2) ?? '');
      final body = (dailyMatch.group(3) ?? '').trim();
      final count = int.tryParse(dailyMatch.group(4) ?? '');
      final unit = (dailyMatch.group(5) ?? '').toLowerCase();
      if (count != null && count > 0) {
        final extracted = _extractLeadingTimes(body);
        final title = _cleanTitle(extracted.remaining);
        if (title.isNotEmpty) {
          final (daysCap, monthsCap) = _durationCaps(count, unit);
          final spec = RecurringTaskSpec(
            title: title,
            frequency: everyN != null && everyN > 1
                ? RecurrenceFrequency.everyNDays
                : RecurrenceFrequency.daily,
            interval: everyN ?? 1,
            startDate: today,
            durationDays: daysCap,
            durationMonths: monthsCap,
            times: extracted.times,
          );
          return _buildRecurringResponse(spec, isBengali: isBengali);
        }
      }
    }

    // Pattern B: Every Sun, Tue, Thu [times] <Title> for <N> <days|weeks|months|years>
    final weeklyMatch = RegExp(
      r'^every\s+(.+?)\s+for\s+(\d{1,3})\s+(days?|weeks?|months?|years?)$',
      caseSensitive: false,
    ).firstMatch(original);
    if (weeklyMatch != null) {
      final body = (weeklyMatch.group(1) ?? '').trim();
      final count = int.tryParse(weeklyMatch.group(2) ?? '');
      final unit = (weeklyMatch.group(3) ?? '').toLowerCase();
      final (weekdays, rest) = _extractLeadingWeekdays(body);
      if (weekdays.isNotEmpty && rest.isNotEmpty && count != null && count > 0) {
        final extracted = _extractLeadingTimes(rest);
        final title = _cleanTitle(extracted.remaining);
        if (title.isNotEmpty) {
          final (daysCap, monthsCap) = _durationCaps(count, unit);
          final spec = RecurringTaskSpec(
            title: title,
            frequency: RecurrenceFrequency.weekly,
            startDate: today,
            weekdays: weekdays,
            durationDays: daysCap,
            durationMonths: monthsCap,
            times: extracted.times,
          );
          return _buildRecurringResponse(spec, isBengali: isBengali);
        }
      }
    }

    // Pattern C: Every month on 1st [times] <Title> for <N> <months|years>
    final monthlyMatch = RegExp(
      r'^(?:every\s+month(?:\s+on)?|monthly(?:\s+on)?)\s+(\d{1,2})(?:st|nd|rd|th)?\s+(.+?)\s+for\s+(\d{1,2})\s+(months?|years?)$',
      caseSensitive: false,
    ).firstMatch(original);
    if (monthlyMatch != null) {
      final dom = int.tryParse(monthlyMatch.group(1) ?? '');
      final body = (monthlyMatch.group(2) ?? '').trim();
      final count = int.tryParse(monthlyMatch.group(3) ?? '');
      final unit = (monthlyMatch.group(4) ?? '').toLowerCase();
      if (dom != null && dom >= 1 && dom <= 31 && count != null && count > 0) {
        final extracted = _extractLeadingTimes(body);
        final title = _cleanTitle(extracted.remaining);
        if (title.isNotEmpty) {
          final (daysCap, monthsCap) = _durationCaps(count, unit);
          final spec = RecurringTaskSpec(
            title: title,
            frequency: RecurrenceFrequency.monthly,
            startDate: today,
            dayOfMonth: dom,
            durationDays: daysCap,
            durationMonths: monthsCap,
            times: extracted.times,
          );
          return _buildRecurringResponse(spec, isBengali: isBengali);
        }
      }
    }

    // Pattern D (Bengali): প্রতিদিন [সকাল ৮টায়] <Title> <N> দিন/মাস
    final bnDailyMatch = RegExp(
      r'^প্রতিদিন\s+(.+?)\s+(\d{1,3})\s*(দিন|মাস|সপ্তাহ)(?:\s*(?:ধরে|পর্যন্ত|জন্য))?$',
    ).firstMatch(original);
    if (bnDailyMatch != null) {
      final body = (bnDailyMatch.group(1) ?? '').trim();
      final count = int.tryParse(bnDailyMatch.group(2) ?? '');
      final bnUnit = bnDailyMatch.group(3) ?? '';
      if (count != null && count > 0) {
        final extracted = _extractAnyLeadingTimes(body);
        final title = _cleanTitle(extracted.remaining);
        if (title.isNotEmpty) {
          final unit = bnUnit == 'মাস'
              ? 'months'
              : (bnUnit == 'সপ্তাহ' ? 'weeks' : 'days');
          final (daysCap, monthsCap) = _durationCaps(count, unit);
          final spec = RecurringTaskSpec(
            title: title,
            frequency: RecurrenceFrequency.daily,
            startDate: today,
            durationDays: daysCap,
            durationMonths: monthsCap,
            times: extracted.times,
          );
          return _buildRecurringResponse(spec, isBengali: true);
        }
      }
    }

    return null;
  }

  static AiAssistantResponse _buildRecurringResponse(
    RecurringTaskSpec spec, {
    required bool isBengali,
  }) {
    final preview = RecurringTaskExpander.expand(spec, seriesId: 'preview');
    final total = preview.tasks.length;
    return AiAssistantResponse(
      reply: isBengali
          ? 'লোকাল রুল ইঞ্জিন দিয়ে "$total"টি "${spec.title}" টাস্ক তৈরি করা হয়েছে।'
          : 'Created $total recurring "${spec.title}" task${total == 1 ? '' : 's'} offline (0 tokens).',
      actions: [
        AiTaskAction(
          type: AiActionType.addRecurring,
          recurringSpec: spec,
        ),
      ],
      handledLocally: true,
      resolvedProviderName: localProviderLabel,
    );
  }

  static AiAssistantResponse? _tryParseSimpleSingleTask({
    required String original,
    required String lower,
    required bool isBengali,
    required DateTime today,
    required DateTime now,
  }) {
    DateTime? targetDate;
    String rest = '';

    final enMatch = RegExp(
      r'^(today|tomorrow)\b(.*)$',
      caseSensitive: false,
    ).firstMatch(original);
    if (enMatch != null) {
      final keyword = enMatch.group(1)!.toLowerCase();
      targetDate =
          keyword == 'today' ? today : today.add(const Duration(days: 1));
      rest = (enMatch.group(2) ?? '').trim();
    } else {
      final bnMatch = RegExp(r'^(আজকে?|আগামীকাল|কাল)\s+(.+)$').firstMatch(original);
      if (bnMatch != null) {
        final keyword = bnMatch.group(1)!;
        targetDate =
            keyword.startsWith('আজ') ? today : today.add(const Duration(days: 1));
        rest = (bnMatch.group(2) ?? '').trim();
      }
    }

    if (targetDate == null || rest.isEmpty) return null;

    // If user mentions multiple tasks or "and" with another time, let Cloud AI handle it cleanly.
    if (rest.contains(' & ') || RegExp(r'\band\b', caseSensitive: false).hasMatch(rest)) {
      return null;
    }

    final extracted = _extractAnyLeadingTimes(rest);
    if (extracted.times.length > 1) return null;

    var title = _cleanTitle(extracted.remaining);
    if (title.isEmpty || title.length > 70) return null;

    final slot = extracted.times.isNotEmpty ? extracted.times.first : null;
    final id = _uuid.v4();
    final task = TaskItem(
      id: id,
      notificationBaseId: TaskItem.stableBaseIdFromUuid(id),
      title: title,
      type: _inferType(title.toLowerCase()),
      dueDate: targetDate,
      dueHour: slot?.$1,
      dueMinute: slot?.$2,
      createdAt: now,
    );

    final dayLabel = targetDate == today
        ? (isBengali ? 'আজ' : 'Today')
        : (isBengali ? 'আগামীকাল' : 'Tomorrow');
    final timeStr =
        task.formattedDueTime != null ? ' • ${task.formattedDueTime}' : '';

    return AiAssistantResponse(
      reply: isBengali
          ? '"${task.title}" ($dayLabel$timeStr) অফলাইনে যোগ করা হয়েছে।'
          : 'Added "${task.title}" for $dayLabel$timeStr (0 tokens).',
      actions: [AiTaskAction(type: AiActionType.add, newTask: task)],
      handledLocally: true,
      resolvedProviderName: localProviderLabel,
    );
  }

  static ({List<(int, int)> times, String remaining}) _extractAnyLeadingTimes(
    String input,
  ) {
    final en = _extractLeadingTimes(input);
    if (en.times.isNotEmpty) return en;

    final bnRegex = RegExp(
      r'^(সকাল|ভোর|দুপুর|বিকাল|বিকেল|সন্ধ্যা|রাত)?\s*(\d{1,2})(?::(\d{2}))?\s*(?:টায়|টা|টার দিকে)?\s*',
    );
    final trimmed = input.trim();
    final m = bnRegex.matchAsPrefix(trimmed);
    if (m == null) return en;
    final period = m.group(1) ?? '';
    var hour = int.tryParse(m.group(2) ?? '');
    final minute = int.tryParse(m.group(3) ?? '0') ?? 0;
    if (hour == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return en;
    }
    if ((period == 'দুপুর' ||
            period == 'বিকাল' ||
            period == 'বিকেল' ||
            period == 'সন্ধ্যা' ||
            period == 'রাত') &&
        hour >= 1 &&
        hour < 12) {
      if (!(period == 'রাত' && hour == 12)) {
        hour += 12;
      }
    } else if (period == 'রাত' && hour == 12) {
      hour = 0;
    }
    final rem = trimmed.substring(m.end).trim();
    if (rem.isEmpty) return en;
    return (times: [(hour, minute)], remaining: rem);
  }

  static ({List<(int, int)> times, String remaining}) _extractLeadingTimes(
    String input,
  ) {
    final times = <(int, int)>[];
    var rest = input.trim();

    final timeRegex = RegExp(
      r'^(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b(?:\s*(?:&|and)\s*)?',
      caseSensitive: false,
    );

    while (times.length < 3) {
      final m = timeRegex.matchAsPrefix(rest);
      if (m == null) break;
      var hour = int.tryParse(m.group(1) ?? '');
      final minute = int.tryParse(m.group(2) ?? '0') ?? 0;
      final mer = (m.group(3) ?? '').toLowerCase();
      if (hour == null || hour < 1 || hour > 12 || minute < 0 || minute > 59) {
        break;
      }
      if (mer == 'pm' && hour < 12) hour += 12;
      if (mer == 'am' && hour == 12) hour = 0;
      times.add((hour, minute));
      rest = rest.substring(m.end).trim();
    }

    return (times: times, remaining: rest);
  }

  static String _cleanTitle(String raw) {
    return raw
        .replaceFirst(RegExp(r'^(?:-|–|:|\bat\b)\s*', caseSensitive: false), '')
        .trim();
  }

  static TaskType _inferType(String lowerTitle) {
    if (lowerTitle.contains('exam') ||
        lowerTitle.contains('mid') ||
        lowerTitle.contains('final') ||
        lowerTitle.contains('পরীক্ষা')) {
      return TaskType.exam;
    }
    if (lowerTitle.contains('quiz') ||
        lowerTitle.contains('class test') ||
        RegExp(r'\bct\b').hasMatch(lowerTitle) ||
        lowerTitle.contains('কুইজ')) {
      return TaskType.classTest;
    }
    if (lowerTitle.contains('assignment') ||
        lowerTitle.contains('report') ||
        lowerTitle.contains('submission') ||
        lowerTitle.contains('অ্যাসাইনমেন্ট')) {
      return TaskType.assignment;
    }
    if (RegExp(r'\blab\b').hasMatch(lowerTitle) ||
        lowerTitle.contains('sessional')) {
      return TaskType.lab;
    }
    if (lowerTitle.contains('mail') ||
        lowerTitle.contains('email') ||
        lowerTitle.contains('মেইল')) {
      return TaskType.mail;
    }
    if (lowerTitle.contains('travel') ||
        lowerTitle.contains('trip') ||
        lowerTitle.contains('flight') ||
        lowerTitle.contains('tour') ||
        lowerTitle.contains('ভ্রমণ') ||
        lowerTitle.contains('ট্রিপ')) {
      return TaskType.travel;
    }
    if (lowerTitle.contains('bank') || lowerTitle.contains('ব্যাংক')) {
      return TaskType.bank;
    }
    if (lowerTitle.contains('institution') ||
        lowerTitle.contains('university') ||
        lowerTitle.contains('college') ||
        lowerTitle.contains('office') ||
        lowerTitle.contains('ভার্সিটি') ||
        lowerTitle.contains('অফিস') ||
        lowerTitle.contains('প্রতিষ্ঠান')) {
      return TaskType.institution;
    }
    if (lowerTitle.contains('meeting') || lowerTitle.contains('মিটিং')) {
      return TaskType.meeting;
    }
    if (RegExp(r'\bcall\b').hasMatch(lowerTitle) ||
        lowerTitle.contains('phone') ||
        lowerTitle.contains('ফোন') ||
        lowerTitle.contains('কল')) {
      return TaskType.call;
    }
    if (RegExp(r'\bbill\b').hasMatch(lowerTitle) ||
        lowerTitle.contains('payment') ||
        lowerTitle.contains('rent') ||
        lowerTitle.contains('fee') ||
        lowerTitle.contains('বিল')) {
      return TaskType.bill;
    }
    if (lowerTitle.contains('shopping') ||
        lowerTitle.contains('grocery') ||
        lowerTitle.contains('market') ||
        lowerTitle.contains('বাজার') ||
        lowerTitle.contains('কেনাকাটা')) {
      return TaskType.shopping;
    }
    if (lowerTitle.contains('health') ||
        lowerTitle.contains('doctor') ||
        lowerTitle.contains('medicine') ||
        lowerTitle.contains('hospital') ||
        lowerTitle.contains('ডাক্তার') ||
        lowerTitle.contains('ওষুধ')) {
      return TaskType.health;
    }
    if (lowerTitle.contains('fitness') ||
        RegExp(r'\bgym\b').hasMatch(lowerTitle) ||
        lowerTitle.contains('workout') ||
        lowerTitle.contains('exercise') ||
        lowerTitle.contains('ব্যায়াম')) {
      return TaskType.fitness;
    }
    if (lowerTitle.contains('document') ||
        lowerTitle.contains('passport') ||
        lowerTitle.contains('visa') ||
        lowerTitle.contains('paperwork') ||
        lowerTitle.contains('কাগজপত্র')) {
      return TaskType.document;
    }
    if (lowerTitle.contains('family') ||
        lowerTitle.contains('parents') ||
        lowerTitle.contains('পরিবার')) {
      return TaskType.family;
    }
    if (lowerTitle.contains('event') ||
        lowerTitle.contains('ceremony') ||
        lowerTitle.contains('অনুষ্ঠান')) {
      return TaskType.event;
    }
    if (lowerTitle.contains('study') ||
        lowerTitle.contains('revision') ||
        lowerTitle.contains('পড়া')) {
      return TaskType.study;
    }
    if (lowerTitle.contains('work') ||
        lowerTitle.contains('project') ||
        lowerTitle.contains('প্রজেক্ট')) {
      return TaskType.work;
    }
    if (lowerTitle.contains('personal') || lowerTitle.contains('ব্যক্তিগত')) {
      return TaskType.personal;
    }
    return TaskType.task;
  }

  static (int?, int?) _durationCaps(int count, String unit) {
    if (unit.startsWith('day')) return (count, null);
    if (unit.startsWith('week')) return (count * 7, null);
    if (unit.startsWith('month')) return (null, count);
    if (unit.startsWith('year')) return (null, count * 12);
    return (count, null);
  }

  static int? _weekdayFromToken(String token) {
    return switch (token.toLowerCase()) {
      'mon' || 'monday' => DateTime.monday,
      'tue' || 'tues' || 'tuesday' => DateTime.tuesday,
      'wed' || 'wednesday' => DateTime.wednesday,
      'thu' || 'thur' || 'thurs' || 'thursday' => DateTime.thursday,
      'fri' || 'friday' => DateTime.friday,
      'sat' || 'saturday' => DateTime.saturday,
      'sun' || 'sunday' => DateTime.sunday,
      _ => null,
    };
  }

  /// Peels one or more weekday tokens (`Sun, Tue & Thu`) from the front of [raw].
  static (List<int>, String) _extractLeadingWeekdays(String raw) {
    final weekdays = <int>[];
    var pos = 0;
    final len = raw.length;
    final wordRe = RegExp(r'^[a-zA-Z]+');
    final sepRe = RegExp(r'^[,\s&/]+');

    while (pos < len) {
      var scan = pos;
      if (weekdays.isNotEmpty) {
        final sep = sepRe.firstMatch(raw.substring(scan));
        if (sep == null) break;
        scan += sep.end;
        // Support natural "and" connector only when followed by another weekday.
        final andMatch = RegExp(r'^and\s+', caseSensitive: false)
            .firstMatch(raw.substring(scan));
        if (andMatch != null) {
          final afterAnd = raw.substring(scan + andMatch.end);
          final nextWord = wordRe.firstMatch(afterAnd)?.group(0);
          if (nextWord != null && _weekdayFromToken(nextWord) != null) {
            scan += andMatch.end;
          }
        }
      }
      if (scan >= len) break;
      final wordMatch = wordRe.firstMatch(raw.substring(scan));
      if (wordMatch == null) break;
      final word = wordMatch.group(0)!;
      final iso = _weekdayFromToken(word);
      if (iso == null) break;
      if (!weekdays.contains(iso)) weekdays.add(iso);
      pos = scan + wordMatch.end;
    }

    if (weekdays.isEmpty) return (const [], raw);
    final remainder = raw.substring(pos).replaceFirst(RegExp(r'^[,\s&/]+'), '').trim();
    return (weekdays, remainder);
  }

  static int? _parseMonthName(String token) {
    return switch (token.toLowerCase()) {
      'jan' || 'january' => 1,
      'feb' || 'february' => 2,
      'mar' || 'march' => 3,
      'apr' || 'april' => 4,
      'may' => 5,
      'jun' || 'june' => 6,
      'jul' || 'july' => 7,
      'aug' || 'august' => 8,
      'sep' || 'sept' || 'september' => 9,
      'oct' || 'october' => 10,
      'nov' || 'november' => 11,
      'dec' || 'december' => 12,
      _ => null,
    };
  }
}
