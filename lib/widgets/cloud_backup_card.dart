import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/cloud_sync_provider.dart';
import '../theme/app_tokens.dart';
import 'glass_surface.dart';

/// Card for per-user private Google Drive (`appDataFolder`) auto-backup
/// and portable offline JSON Export/Import.
class CloudBackupCard extends StatelessWidget {
  const CloudBackupCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<CloudSyncProvider>();
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return GlassContainer(
      borderRadius: AppRadius.md,
      blur: 0,
      elevated: cloud.isSignedIn,
      borderColor: cloud.isSignedIn ? colors.primary : colors.glassBorder,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cloud.isSignedIn
                      ? colors.primarySoft
                      : colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  cloud.isSignedIn
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_outlined,
                  color:
                      cloud.isSignedIn ? colors.primary : colors.textSecondary,
                  size: AppIconSize.lg,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Private Google Drive',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cloud.isSignedIn
                          ? 'Auto-syncs to your own Drive appDataFolder on every change'
                          : 'Back up privately to your own Google Drive (only you have access)',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (cloud.isSignedIn) ...[
                const SizedBox(width: AppSpacing.sm),
                _SyncStatusBadge(
                  isSyncing: cloud.isSyncing,
                  colors: colors,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!cloud.isAvailable)
            Text(
              'Google Drive auto-sync activates on Android & iOS. Use JSON Export/Import below anytime.',
              style: textTheme.bodySmall,
            )
          else if (!cloud.isSignedIn)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: cloud.isBusy
                    ? null
                    : () async {
                        final ok = await cloud.signInWithGoogle();
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Connected and synced with your Google Drive.',
                              ),
                            ),
                          );
                        }
                      },
                icon: cloud.isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded, size: 18),
                label: Text(
                  cloud.isBusy ? 'Connecting...' : 'Sign in with Google',
                ),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colors.primary,
                    backgroundImage: (cloud.userPhotoUrl != null &&
                            cloud.userPhotoUrl!.isNotEmpty)
                        ? NetworkImage(cloud.userPhotoUrl!)
                        : null,
                    child: (cloud.userPhotoUrl == null ||
                            cloud.userPhotoUrl!.isEmpty)
                        ? Text(
                            _initial(cloud.userName, cloud.userEmail),
                            style: textTheme.labelLarge?.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cloud.userName != null &&
                            cloud.userName!.trim().isNotEmpty)
                          Text(
                            cloud.userName!,
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        Text(
                          cloud.userEmail ?? 'Connected',
                          style: textTheme.bodySmall,
                        ),
                        if (cloud.lastSyncedAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Last backup: ${DateFormat('d MMM, h:mm a').format(cloud.lastSyncedAt!)}',
                            style: textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (cloud.migrationNotice != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: colors.glassBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        cloud.migrationNotice!,
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: cloud.isBusy
                      ? null
                      : () async {
                          final ok = await cloud.backupNow();
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Google Drive backup updated.',
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text('Backup Now'),
                ),
                OutlinedButton.icon(
                  onPressed: cloud.isBusy
                      ? null
                      : () => _confirmRestore(context, cloud),
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  label: const Text('Restore'),
                ),
                TextButton.icon(
                  onPressed: cloud.isBusy ? null : cloud.signOut,
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign Out'),
                ),
              ],
            ),
          ],
          const Divider(height: AppSpacing.xl),
          Text(
            'Local Data Export & Import',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'Save an offline JSON copy of your schedules and chats or restore from any exported file.',
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: cloud.isBusy
                    ? null
                    : () => _openExportDialog(context, cloud),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export JSON'),
              ),
              OutlinedButton.icon(
                onPressed: cloud.isBusy
                    ? null
                    : () => _openImportFlow(context, cloud),
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('Import JSON'),
              ),
            ],
          ),
          if (cloud.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: AppIconSize.sm,
                  color: colors.danger,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    cloud.errorMessage!,
                    style: textTheme.bodySmall?.copyWith(color: colors.danger),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _initial(String? name, String? email) {
    final src = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : (email ?? 'U');
    return src.substring(0, 1).toUpperCase();
  }

  Future<void> _confirmRestore(
    BuildContext context,
    CloudSyncProvider cloud,
  ) async {
    final colors = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colors.glassBorder),
        ),
        title: const Text('Restore from Google Drive?'),
        content: const Text(
          'Replace current local tasks, chats, API keys, and reminder settings with the backup in your private Google Drive?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final ok = await cloud.restoreFromDrive();
      if (ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restored from Google Drive.')),
        );
      }
    }
  }

  Future<void> _openExportDialog(
    BuildContext context,
    CloudSyncProvider cloud,
  ) async {
    final colors = context.appColors;
    var includeApiKeys = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: colors.glassBorder),
          ),
          title: const Text('Export Backup JSON'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Creates a portable JSON backup file of your tasks, syllabus checklists, chat history, and reminder settings.',
              ),
              const SizedBox(height: AppSpacing.md),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: includeApiKeys,
                onChanged: (v) =>
                    setDialogState(() => includeApiKeys = v ?? true),
                title: const Text('Include API Keys'),
                subtitle: const Text(
                  'Uncheck before sharing this file with someone else',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Export & Share'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await cloud.exportBackupToFile(includeApiKeys: includeApiKeys);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup JSON ready.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _openImportFlow(
    BuildContext context,
    CloudSyncProvider cloud,
  ) async {
    try {
      final parsed = await cloud.pickAndParseImportFile();
      if (parsed == null || !context.mounted) return;

      final colors = context.appColors;
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: colors.glassBorder),
          ),
          title: const Text('Import Backup File'),
          content: Text(
            'Found ${parsed.payload.tasks.length} tasks and '
            '${parsed.payload.chatMessages.length} chat messages'
            '${parsed.includesApiKeys ? ' (includes API keys)' : ' (tasks & chats only)'}.\n\n'
            'Merge adds missing items without duplicates. Replace overwrites local tasks and chats.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop('replace'),
              child: const Text('Replace'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('merge'),
              child: const Text('Merge'),
            ),
          ],
        ),
      );

      if (choice == null || !context.mounted) return;
      await cloud.applyImportedBackup(
        parsed.payload,
        merge: choice == 'merge',
        includesApiKeys: parsed.includesApiKeys,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              choice == 'merge'
                  ? 'Backup merged without duplicates.'
                  : 'Backup restored from file.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }
}

class _SyncStatusBadge extends StatelessWidget {
  const _SyncStatusBadge({
    required this.isSyncing,
    required this.colors,
  });

  final bool isSyncing;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSyncing)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.check_rounded, size: 14, color: colors.success),
          const SizedBox(width: 5),
          Text(
            isSyncing ? 'Syncing...' : 'Synced',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isSyncing ? colors.primary : colors.success,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
