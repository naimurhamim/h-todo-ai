import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/cloud_sync_provider.dart';
import '../theme/app_tokens.dart';
import 'glass_surface.dart';

/// Card for Google Sign-In cloud backup, auto-replace status, and manual backup/restore.
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
                      'Cloud Backup (Google)',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cloud.isSignedIn
                          ? 'Auto-syncs tasks, chats, API keys & settings'
                          : 'Sign in with Google to back up & restore across devices',
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
              'Cloud backup activates automatically on Android & iOS builds.',
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
                                'Signed in and synced with Firebase.',
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
                  cloud.isBusy ? 'Signing in...' : 'Sign in with Google',
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
                          cloud.userEmail ?? 'Signed in',
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
                                content: Text('Cloud backup replaced.'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Firebase?'),
        content: const Text(
          'Replace current local tasks, chats, API keys, and reminder settings with your saved cloud backup?',
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
      final ok = await cloud.restoreFromCloud();
      if (ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restored from Firebase backup.')),
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
