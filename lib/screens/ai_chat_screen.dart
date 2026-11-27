import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../models/task_item.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/task_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/glass_surface.dart';
import '../widgets/task_card.dart';
import '../widgets/task_detail_sheet.dart';
import 'api_keys_screen.dart';

/// Frosted conversational schedule parser backed by the active AI provider.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, required this.onGoToSettings});

  final VoidCallback onGoToSettings;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  static const _exampleNotice = '''
১. IRE 415 – Computer Vision

● ASSIGNMENT 03:
- জমা দেওয়ার শেষ তারিখ: ২১ নভেম্বর ২০২৬ (শনিবার)। (21.11.2026, 11:59 PM)

● CLASS TEST:
- তারিখ: ২২ নভেম্বর ২০২৬ (22.11.2026) (রবিবার)।
- SYLLABUS:
  1. Image Enhancement
  2. Filtering (Basic Techniques, Use Cases, Gaussian & Median Filter, Limitations)
  3. Morphological Operations (Erosion, Dilation, Opening, Closing)''';

  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<TaskItem> _pendingUndoTasks = const [];
  Timer? _undoBannerTimer;

  @override
  void dispose() {
    _undoBannerTimer?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _showUndoBanner(List<TaskItem> deletedTasks) {
    _undoBannerTimer?.cancel();
    setState(() => _pendingUndoTasks = deletedTasks);
    _undoBannerTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() => _pendingUndoTasks = const []);
      }
    });
  }

  void _dismissUndoBanner() {
    _undoBannerTimer?.cancel();
    _undoBannerTimer = null;
    if (_pendingUndoTasks.isNotEmpty) {
      setState(() => _pendingUndoTasks = const []);
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    final taskProvider = context.read<TaskProvider>();
    final aiSettings = context.read<AiSettingsProvider>();
    final activeProvider = aiSettings.activeProvider;

    _inputCtrl.clear();
    final deletedTasks = await chatProvider.sendScheduleMessage(
      text,
      activeProvider: activeProvider,
      taskProvider: taskProvider,
      onModelResolved: (newModel) => aiSettings.updateProviderConfig(
        activeProvider.copyWith(model: newModel),
      ),
      onReminderSettingsAction: (action) async {
        final cur = aiSettings.reminderSettings;
        final next = cur.copyWith(
          enabled: action.remindersEnabled ?? cur.enabled,
          dayBeforeHour: action.newDayBeforeTime?.$1 ?? cur.dayBeforeHour,
          dayBeforeMinute: action.newDayBeforeTime?.$2 ?? cur.dayBeforeMinute,
          endOfDayHour: action.newEndOfDayTime?.$1 ?? cur.endOfDayHour,
          endOfDayMinute: action.newEndOfDayTime?.$2 ?? cur.endOfDayMinute,
        );
        await aiSettings.updateReminderSettings(
          next,
          onReschedule: taskProvider.rescheduleAllNotifications,
        );
      },
    );

    if (deletedTasks.isNotEmpty && mounted) {
      _showUndoBanner(deletedTasks);
    }

    if (mounted && _scrollCtrl.hasClients) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (_scrollCtrl.hasClients) {
        await _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiSettings = context.watch<AiSettingsProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.railBreakpoint;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'AI Auto-Plan',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    GlassPillButton(
                      icon: Icons.check_circle_rounded,
                      iconColor: colors.primary,
                      label:
                          '${aiSettings.activeProvider.displayName.split(' ').first} • Active',
                      selected: true,
                      onTap: () => ApiKeysScreen.open(context),
                    ),
                    if (chatProvider.messages.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      GlassCircleButton(
                        icon: Icons.delete_sweep_outlined,
                        tooltip: 'Clear chat history',
                        onTap: chatProvider.clearHistory,
                      ),
                    ],
                  ],
                ),
              ),
              if (!aiSettings.hasActiveApiKey)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: GlassContainer(
                    borderRadius: AppRadius.md,
                    blur: 0,
                    borderColor: colors.warning,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(
                          Icons.key_outlined,
                          color: colors.warning,
                          size: AppIconSize.md,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Paste a free Gemini, Groq, or Grok API key in Profile to parse schedules.',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        TextButton(
                          onPressed: () => ApiKeysScreen.open(context),
                          child: const Text('Configure'),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: chatProvider.messages.isEmpty
                    ? _ChatEmptyState(
                        onInsertExample: () {
                          _inputCtrl.text = _exampleNotice;
                        },
                      )
                    : ListView.separated(
                        controller: _scrollCtrl,
                        reverse: true,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: chatProvider.messages.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final reversedIndex =
                              chatProvider.messages.length - 1 - index;
                          final msg = chatProvider.messages[reversedIndex];
                          return _ChatBubble(
                            message: msg,
                            taskProvider: taskProvider,
                          );
                        },
                      ),
              ),
              if (chatProvider.isSending)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Organizing tasks, dates & reminders...',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  wide ? AppSpacing.lg : AppLayout.navClearance,
                ),
                child: GlassContainer(
                  borderRadius: AppRadius.xl,
                  blur: 0,
                  elevated: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.xs,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText:
                                'Add a schedule, complete, reschedule, or remove tasks...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.md,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Semantics(
                        label: 'Send schedule to AI',
                        button: true,
                        child: FilledButton(
                          onPressed: chatProvider.isSending ? null : _send,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Icon(Icons.arrow_upward_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: AppSpacing.xs,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: IgnorePointer(
              ignoring: _pendingUndoTasks.isEmpty,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.25),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: _pendingUndoTasks.isEmpty
                    ? const SizedBox.shrink()
                    : Center(
                        key: const ValueKey('top-undo-popup'),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: _TopUndoPopup(
                            tasks: _pendingUndoTasks,
                            onUndo: () async {
                              final restore =
                                  List<TaskItem>.from(_pendingUndoTasks);
                              _dismissUndoBanner();
                              await taskProvider.restoreDeletedTasks(restore);
                            },
                            onOk: _dismissUndoBanner,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
  );
  }
}

class _TopUndoPopup extends StatelessWidget {
  const _TopUndoPopup({
    required this.tasks,
    required this.onUndo,
    required this.onOk,
  });

  final List<TaskItem> tasks;
  final VoidCallback onUndo;
  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final message = tasks.length == 1
        ? 'Removed "${tasks.first.title}"'
        : 'Removed ${tasks.length} tasks';

    return GlassContainer(
      borderRadius: AppRadius.lg,
      blur: 10,
      elevated: true,
      borderColor: colors.glassBorder,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          TextButton(
            onPressed: onUndo,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(48, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Undo'),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: onOk,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(44, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({required this.onInsertExample});

  final VoidCallback onInsertExample;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: GlassContainer(
          borderRadius: AppRadius.xl,
          blur: 0,
          elevated: true,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 28,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Manage schedules & tasks in any language',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Paste notices to add tasks, or chat naturally to mark tasks done, reschedule deadlines, update syllabi, or remove items.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              GlassPillButton(
                icon: Icons.text_snippet_outlined,
                label: 'Try Example Notice',
                onTap: onInsertExample,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.taskProvider,
  });

  final ChatMessage message;
  final TaskProvider taskProvider;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final isUser = message.role == ChatRole.user;

    final createdTasks = message.createdTaskIds
        .map(taskProvider.findById)
        .whereType<TaskItem>()
        .toList();

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: GlassContainer(
          borderRadius: AppRadius.lg,
          blur: 0,
          elevated: !isUser,
          fillColor: isUser ? colors.primarySoft : null,
          borderColor: message.isError ? colors.danger : colors.glassBorder,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isUser
                          ? 'You'
                          : (message.providerName ?? 'H-TODO AI'),
                      style: textTheme.labelSmall?.copyWith(
                        color: message.isError
                            ? colors.danger
                            : colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.content_copy_rounded,
                        size: 15,
                        color: colors.textSecondary,
                      ),
                      tooltip: 'Copy message',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: message.text),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Message copied'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              SelectionArea(
                child: Text(
                  message.text,
                  style: textTheme.bodyMedium?.copyWith(
                    color: message.isError ? colors.danger : colors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ),
              if (createdTasks.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                for (var i = 0;
                    i < (createdTasks.length > 5 ? 5 : createdTasks.length);
                    i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  TaskCard(
                    task: createdTasks[i],
                    compact: true,
                    onToggleComplete: () =>
                        taskProvider.toggleTaskComplete(createdTasks[i].id),
                    onTap: () =>
                        TaskDetailSheet.show(context, createdTasks[i].id),
                  ),
                ],
                if (createdTasks.length > 5) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '+ ${createdTasks.length - 5} more tasks in Plan',
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
