import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/cloud_backup_payload.dart';

/// Thrown when Google Drive rejects an expired or revoked OAuth token (HTTP 401).
class DriveAuthExpiredException implements Exception {
  const DriveAuthExpiredException([
    this.message = 'Google Drive authorization expired.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Domain error thrown for Google Drive REST API failures.
class DriveBackupException implements Exception {
  const DriveBackupException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Pure REST v3 client storing one hidden backup file in the user's own `appDataFolder`.
class GoogleDriveBackupClient {
  GoogleDriveBackupClient({http.Client? client})
      : _client = client ?? http.Client();

  static const String appDataScope =
      'https://www.googleapis.com/auth/drive.appdata';
  static const String backupFileName = 'htodo_ai_backup.json';

  static const Duration _timeout = Duration(seconds: 25);

  final http.Client _client;

  Future<List<String>> listBackupFileIds(Map<String, String> authHeaders) async {
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'spaces': 'appDataFolder',
      'q': "name='$backupFileName' and trashed=false",
      'fields': 'files(id,name,modifiedTime)',
      'orderBy': 'modifiedTime desc',
      'pageSize': '10',
    });

    final response =
        await _client.get(uri, headers: authHeaders).timeout(_timeout);
    _checkAuth(response.statusCode);
    if (response.statusCode != 200) {
      throw DriveBackupException(
        'Could not list Google Drive backups (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final files = decoded['files'] as List<dynamic>? ?? const [];
    return files
        .whereType<Map>()
        .map((f) => f['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  /// Downloads the newest `htodo_ai_backup.json` from `appDataFolder` and
  /// cleans up any accidental duplicate files silently.
  Future<({CloudBackupPayload? payload, String? fileId})> downloadBackup(
    Map<String, String> authHeaders,
  ) async {
    final ids = await listBackupFileIds(authHeaders);
    if (ids.isEmpty) {
      return (payload: null, fileId: null);
    }

    final primaryId = ids.first;
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files/$primaryId', {
      'alt': 'media',
    });
    final response =
        await _client.get(uri, headers: authHeaders).timeout(_timeout);
    _checkAuth(response.statusCode);
    if (response.statusCode == 404) {
      return (payload: null, fileId: null);
    }
    if (response.statusCode != 200) {
      throw DriveBackupException(
        'Could not download Google Drive backup (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final raw = utf8.decode(response.bodyBytes);
    final payload = CloudBackupPayload.fromJsonString(raw);

    if (ids.length > 1) {
      await _deleteDuplicateFiles(authHeaders, ids.skip(1));
    }

    return (payload: payload, fileId: primaryId);
  }

  /// Replaces the existing single backup file in `appDataFolder` via `PATCH`,
  /// creating it with `POST multipart` only when none exists yet.
  Future<String> uploadBackup(
    Map<String, String> authHeaders,
    CloudBackupPayload payload, {
    String? knownFileId,
  }) async {
    final bytes = utf8.encode(payload.toJsonString(includeApiKeys: true));

    if (knownFileId != null && knownFileId.isNotEmpty) {
      final patched = await _patchMedia(authHeaders, knownFileId, bytes);
      if (patched) {
        return knownFileId;
      }
    }

    final existingIds = await listBackupFileIds(authHeaders);
    if (existingIds.isNotEmpty) {
      final targetId = existingIds.first;
      final patched = await _patchMedia(authHeaders, targetId, bytes);
      if (patched) {
        if (existingIds.length > 1) {
          await _deleteDuplicateFiles(authHeaders, existingIds.skip(1));
        }
        return targetId;
      }
    }

    return _createMultipart(authHeaders, utf8.decode(bytes));
  }

  Future<bool> _patchMedia(
    Map<String, String> authHeaders,
    String fileId,
    List<int> bodyBytes,
  ) async {
    final uri = Uri.https(
      'www.googleapis.com',
      '/upload/drive/v3/files/$fileId',
      {'uploadType': 'media', 'fields': 'id'},
    );
    final headers = <String, String>{
      ...authHeaders,
      'Content-Type': 'application/json; charset=UTF-8',
    };
    final response = await _client
        .patch(uri, headers: headers, body: bodyBytes)
        .timeout(_timeout);
    _checkAuth(response.statusCode);
    if (response.statusCode == 404) {
      return false;
    }
    if (response.statusCode != 200) {
      throw DriveBackupException(
        'Could not update Google Drive backup (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return true;
  }

  Future<String> _createMultipart(
    Map<String, String> authHeaders,
    String contentJson,
  ) async {
    const boundary = 'htodo_drive_backup_boundary_v1';
    final metadataJson = jsonEncode({
      'name': backupFileName,
      'parents': ['appDataFolder'],
      'mimeType': 'application/json',
    });

    final multipartBody = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadataJson\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$contentJson\r\n'
        '--$boundary--\r\n';

    final uri = Uri.https(
      'www.googleapis.com',
      '/upload/drive/v3/files',
      {'uploadType': 'multipart', 'fields': 'id'},
    );
    final headers = <String, String>{
      ...authHeaders,
      'Content-Type': 'multipart/related; boundary=$boundary',
    };
    final response = await _client
        .post(uri, headers: headers, body: utf8.encode(multipartBody))
        .timeout(_timeout);
    _checkAuth(response.statusCode);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw DriveBackupException(
        'Could not create Google Drive backup (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final createdId = decoded['id']?.toString() ?? '';
    if (createdId.isEmpty) {
      throw const DriveBackupException(
        'Google Drive did not return a backup file ID.',
      );
    }
    return createdId;
  }

  Future<void> _deleteDuplicateFiles(
    Map<String, String> authHeaders,
    Iterable<String> fileIds,
  ) async {
    for (final id in fileIds) {
      try {
        final uri = Uri.https('www.googleapis.com', '/drive/v3/files/$id');
        await _client.delete(uri, headers: authHeaders).timeout(_timeout);
      } catch (_) {
        // Best-effort duplicate cleanup; primary backup already succeeded.
      }
    }
  }

  static void _checkAuth(int statusCode) {
    if (statusCode == 401) {
      throw const DriveAuthExpiredException();
    }
  }
}
