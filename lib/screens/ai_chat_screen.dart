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

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    final taskProvider = context.read<TaskProvider>();
    final aiSettings = context.read<AiSettingsProvider>();
    final activeProvider = aiSettings.activeProvider;

    _inputCtrl.clear();
    await chatProvider.sendScheduleMessage(
      text,
      activeProvider: activeProvider,
      taskProvider: taskProvider,
      onModelResolved: (newModel) => aiSettings.updateProviderConfig(
        activeProvider.copyWith(model: newModel),
      ),
    );

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
          child: Column(
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
                                'Paste notice, assignment, exam date & syllabus...',
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
        ),
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
                'Paste any schedule in Bangla or English',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'AI extracts every deadline, creates structured checklists for your syllabus, and schedules both a day-before alert and an end-of-day completion reminder.',
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
                for (var i = 0; i < createdTasks.length; i++) ...[
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}
