import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Handles temporary JSON backup export (auto-cleaned) and file import via system picker.
class LocalBackupService {
  static const String _exportSubdir = 'htodo_exports';

  /// Writes [jsonContent] to a timestamped temp `.json` file (cleaning obsolete prior exports)
  /// and opens the OS share sheet so the user saves or shares only where they choose.
  Future<String> exportJsonFile(
    String jsonContent, {
    String? suggestedFileName,
  }) async {
    final now = DateTime.now();
    final stamp = '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}-'
        '${now.minute.toString().padLeft(2, '0')}';
    final fileName = suggestedFileName ?? 'htodo_ai_backup_$stamp.json';

    final tempRoot = await getTemporaryDirectory();
    final exportDir = Directory('${tempRoot.path}/$_exportSubdir');
    if (await exportDir.exists()) {
      await _cleanOldTempExports(exportDir);
    } else {
      await exportDir.create(recursive: true);
    }

    final file = File('${exportDir.path}/$fileName');
    await file.writeAsString(jsonContent, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'H-TODO AI Backup',
      ),
    );
    return file.path;
  }

  Future<void> _cleanOldTempExports(Directory dir) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Opens a system file picker filtered to `.json` and returns its UTF-8 text,
  /// or `null` if the user cancels.
  Future<String?> pickJsonFileContent() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final picked = result.files.single;
    if (picked.bytes != null && picked.bytes!.isNotEmpty) {
      return utf8.decode(picked.bytes!);
    }
    final path = picked.path;
    if (path != null && path.isNotEmpty) {
      return File(path).readAsString();
    }
    return null;
  }
}
