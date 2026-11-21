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
              _ReleaseNotesView(markdown: notes),
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

  /// Parses GitHub release Markdown notes into clean styled blocks without raw syntax symbols.
  static List<ReleaseNoteBlock> parseReleaseNotes(String markdown) {
    final blocks = <ReleaseNoteBlock>[];
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    var inCodeFence = false;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.startsWith('```')) {
        inCodeFence = !inCodeFence;
        continue;
      }
      if (inCodeFence) {
        if (line.isNotEmpty) {
          blocks.add(
            ReleaseNoteBlock(
              kind: ReleaseNoteKind.paragraph,
              segments: [ReleaseNoteSegment(line, code: true)],
            ),
          );
        }
        continue;
      }
      if (line.isEmpty) continue;
      if (RegExp(r'^[-*_]{3,}$').hasMatch(line)) continue;

      final headingMatch = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(line);
      if (headingMatch != null) {
        final content = headingMatch.group(1)!.trim();
        if (content.isNotEmpty) {
          blocks.add(
            ReleaseNoteBlock(
              kind: ReleaseNoteKind.heading,
              segments: _parseInlineSegments(content),
            ),
          );
        }
        continue;
      }

      final bulletMatch = RegExp(r'^(?:[-*+•])\s+(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        final content = bulletMatch.group(1)!.trim();
        if (content.isNotEmpty) {
          blocks.add(
            ReleaseNoteBlock(
              kind: ReleaseNoteKind.bullet,
              segments: _parseInlineSegments(content),
            ),
          );
        }
        continue;
      }

      final numberedMatch = RegExp(r'^(\d+\.)\s+(.*)$').firstMatch(line);
      if (numberedMatch != null) {
        final marker = numberedMatch.group(1)!;
        final content = numberedMatch.group(2)!.trim();
        if (content.isNotEmpty) {
          blocks.add(
            ReleaseNoteBlock(
              kind: ReleaseNoteKind.numbered,
              marker: marker,
              segments: _parseInlineSegments(content),
            ),
          );
        }
        continue;
      }

      blocks.add(
        ReleaseNoteBlock(
          kind: ReleaseNoteKind.paragraph,
          segments: _parseInlineSegments(line),
        ),
      );
    }

    return blocks;
  }

  static List<ReleaseNoteSegment> _parseInlineSegments(String input) {
    // Convert `[label](url)` Markdown links to clean readable labels first.
    final withLinksCleaned = input.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (m) => m.group(1) ?? '',
    );

    final segments = <ReleaseNoteSegment>[];
    final tokenRegex = RegExp(
      r'(\*\*(.+?)\*\*|__(.+?)__|`([^`]+)`|\*([^*]+?)\*)',
    );
    var cursor = 0;

    for (final match in tokenRegex.allMatches(withLinksCleaned)) {
      if (match.start > cursor) {
        segments.add(
          ReleaseNoteSegment(withLinksCleaned.substring(cursor, match.start)),
        );
      }
      if (match.group(2) != null) {
        segments.add(ReleaseNoteSegment(match.group(2)!, bold: true));
      } else if (match.group(3) != null) {
        segments.add(ReleaseNoteSegment(match.group(3)!, bold: true));
      } else if (match.group(4) != null) {
        segments.add(ReleaseNoteSegment(match.group(4)!, code: true));
      } else if (match.group(5) != null) {
        segments.add(ReleaseNoteSegment(match.group(5)!, italic: true));
      }
      cursor = match.end;
    }

    if (cursor < withLinksCleaned.length) {
      segments.add(ReleaseNoteSegment(withLinksCleaned.substring(cursor)));
    }

    return segments.isEmpty ? [ReleaseNoteSegment(withLinksCleaned)] : segments;
  }
}

enum ReleaseNoteKind { heading, bullet, numbered, paragraph }

@immutable
class ReleaseNoteSegment {
  const ReleaseNoteSegment(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool code;
}

@immutable
class ReleaseNoteBlock {
  const ReleaseNoteBlock({
    required this.kind,
    required this.segments,
    this.marker,
  });

  final ReleaseNoteKind kind;
  final List<ReleaseNoteSegment> segments;
  final String? marker;
}

class _ReleaseNotesView extends StatelessWidget {
  const _ReleaseNotesView({required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final blocks = UpdateService.parseReleaseNotes(markdown);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    if (blocks.isEmpty) {
      return Text(
        'Bug fixes and performance improvements.',
        style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++)
          _buildBlock(blocks[i], colors, textTheme, isFirst: i == 0),
      ],
    );
  }

  Widget _buildBlock(
    ReleaseNoteBlock block,
    AppColors colors,
    TextTheme textTheme, {
    required bool isFirst,
  }) {
    final baseStyle = (block.kind == ReleaseNoteKind.heading
            ? textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              )
            : textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                height: 1.4,
              )) ??
        const TextStyle(fontSize: 13);

    final rich = Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          for (final seg in block.segments)
            TextSpan(
              text: seg.text,
              style: TextStyle(
                fontWeight: seg.bold ? FontWeight.w700 : null,
                fontStyle: seg.italic ? FontStyle.italic : null,
                fontFamily: seg.code ? 'monospace' : null,
                color: (seg.bold || seg.code) ? colors.textPrimary : null,
                backgroundColor: seg.code ? colors.surfaceSubtle : null,
              ),
            ),
        ],
      ),
    );

    if (block.kind == ReleaseNoteKind.heading) {
      return Padding(
        padding: EdgeInsets.only(top: isFirst ? 0 : AppSpacing.sm, bottom: 4),
        child: rich,
      );
    }

    if (block.kind == ReleaseNoteKind.bullet ||
        block.kind == ReleaseNoteKind.numbered) {
      final prefix =
          block.kind == ReleaseNoteKind.bullet ? '•' : (block.marker ?? '•');
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: block.kind == ReleaseNoteKind.bullet ? 14 : 22,
              child: Text(
                prefix,
                style: baseStyle.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(child: rich),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: rich,
    );
  }
}
