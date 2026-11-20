import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_tokens.dart';

/// Checks GitHub Releases for newer builds of H-TODO AI and opens downloads.
class UpdateService {
  static const String repoOwner = 'naimurhamim';
  static const String repoName = 'h-todo-ai';
  static const String releasesUrl =
      'https://github.com/$repoOwner/$repoName/releases';
  static const String latestApiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  /// Compares two semantic version strings (e.g. "v1.2.0" vs "1.0.1+2").
  static bool isNewerVersion(String latestRaw, String currentRaw) {
    final latestParts = _parseVersionParts(latestRaw);
    final currentParts = _parseVersionParts(currentRaw);
    final maxLen = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (var i = 0; i < maxLen; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static List<int> _parseVersionParts(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1);
    }
    cleaned = cleaned.split('+').first.split('-').first;
    if (cleaned.isEmpty) return const [0];
    return cleaned
        .split('.')
        .map((segment) => int.tryParse(segment.trim()) ?? 0)
        .toList();
  }

  static Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.trim().isNotEmpty) {
        return info.version.trim();
      }
    } catch (_) {
      // Fallback when platform channel is unavailable (e.g., widget tests).
    }
    return '1.0.0';
  }

  static Future<void> checkForUpdate(
    BuildContext context, {
    http.Client? client,
  }) async {
    final colors = context.appColors;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colors.glassBorder),
        ),
        content: const Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Checking for updates...')),
          ],
        ),
      ),
    );

    final ownedClient = client == null;
    final httpClient = client ?? http.Client();
    final currentVersion = await getCurrentVersion();

    try {
      final response = await httpClient
          .get(
            Uri.parse(latestApiUrl),
            headers: const {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 15));

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawTag = (data['tag_name'] ?? '0.0.0').toString();
        final latestVersion = rawTag.replaceFirst(RegExp(r'^[vV]'), '');
        final releaseNotes =
            (data['body'] ?? 'New improvements and fixes included.').toString();
        final releasePageUrl =
            (data['html_url'] ?? releasesUrl).toString();

        var downloadUrl = releasePageUrl;
        final assets = data['assets'];
        if (assets is List) {
          for (final asset in assets) {
            if (asset is Map<String, dynamic>) {
              final url = asset['browser_download_url']?.toString() ?? '';
              if (url.toLowerCase().endsWith('.apk')) {
                downloadUrl = url;
                break;
              }
            }
          }
        }

        if (isNewerVersion(latestVersion, currentVersion)) {
          await _showUpdateAvailableDialog(
            context,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            notes: releaseNotes,
            downloadUrl: downloadUrl,
          );
        } else {
          await _showInfoDialog(
            context,
            title: 'Up to Date',
            message:
                'You are running the latest version of H-TODO AI (v$currentVersion).',
            icon: Icons.verified_rounded,
          );
        }
      } else if (response.statusCode == 404) {
        await _showInfoDialog(
          context,
          title: 'Up to Date',
          message:
              'You are running H-TODO AI v$currentVersion. No GitHub releases have been published yet.',
          icon: Icons.verified_outlined,
        );
      } else {
        await _showInfoDialog(
          context,
          title: 'Update Check Failed',
          message:
              'Could not reach GitHub Releases (HTTP ${response.statusCode}).',
          icon: Icons.cloud_off_rounded,
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await _showInfoDialog(
        context,
        title: 'Network Error',
        message:
            'Unable to check for updates right now. Please check your internet connection.',
        icon: Icons.wifi_off_rounded,
      );
    } finally {
      if (ownedClient) {
        httpClient.close();
      }
    }
  }

  static Future<void> _showUpdateAvailableDialog(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    required String notes,
    required String downloadUrl,
  }) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colors.glassBorder),
        ),
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: colors.primary),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('Update Available')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Installed: v$currentVersion  •  Latest: v$latestVersion',
                style: textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Release Notes',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                notes,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final uri = Uri.tryParse(downloadUrl);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }

  static Future<void> _showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
  }) {
    final colors = context.appColors;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colors.glassBorder),
        ),
        title: Row(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
