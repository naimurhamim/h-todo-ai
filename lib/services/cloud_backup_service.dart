import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/cloud_backup_payload.dart';
import '../models/google_account_profile.dart';
import 'google_drive_backup_client.dart';

/// Manages Google Sign-In, per-user private Google Drive (`appDataFolder`)
/// backup/restore, and one-time legacy Firebase Firestore migration.
class CloudBackupService {
  CloudBackupService({
    GoogleDriveBackupClient? driveClient,
    bool forceDisabled = false,
  })  : _driveClient = driveClient ?? GoogleDriveBackupClient(),
        _forceDisabled = forceDisabled;

  /// Creates an inert instance for headless widget/unit tests.
  CloudBackupService.disabled()
      : _driveClient = GoogleDriveBackupClient(),
        _forceDisabled = true;

  /// Web OAuth 2.0 client ID from `google-services.json` (`client_type: 3`).
  static const String webServerClientId =
      '865261282040-e92e3oearm8am9onpd434ri6n2vet4si.apps.googleusercontent.com';

  final GoogleDriveBackupClient _driveClient;
  final bool _forceDisabled;

  bool _googleInitialized = false;
  GoogleSignInAccount? _currentAccount;

  bool get isAvailable {
    if (_forceDisabled || kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get isSignedInSessionActive => _currentAccount != null;

  GoogleAccountProfile? get currentProfile {
    final account = _currentAccount;
    if (account == null) return null;
    return _profileFromAccount(account);
  }

  static GoogleAccountProfile _profileFromAccount(GoogleSignInAccount account) {
    return GoogleAccountProfile(
      id: account.id,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
    );
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: webServerClientId,
    );
    _googleInitialized = true;
  }

  /// Signs in interactively with Google and authorizes the private
  /// `drive.appdata` scope so backups stay inside the user's own Google Drive.
  /// Returns `null` if the user cancels.
  Future<GoogleAccountProfile?> signInWithGoogle() async {
    if (!isAvailable) {
      throw StateError(
        'Google Drive Backup requires an Android or iOS build.',
      );
    }

    await _ensureGoogleInitialized();

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(
        scopeHint: const [GoogleDriveBackupClient.appDataScope],
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      rethrow;
    }

    final headers = await account.authorizationClient.authorizationHeaders(
      const [GoogleDriveBackupClient.appDataScope],
      promptIfNecessary: true,
    );
    if (headers == null || headers.isEmpty) {
      throw StateError(
        'Google Drive appDataFolder permission was not granted.',
      );
    }

    _currentAccount = account;
    return _profileFromAccount(account);
  }

  /// Attempts to silently restore a previously authenticated Google session
  /// on app startup without displaying interactive UI.
  Future<GoogleAccountProfile?> restoreSilentSession() async {
    if (!isAvailable) return null;
    try {
      await _ensureGoogleInitialized();
      final attempt = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (attempt == null) return null;
      final account = await attempt;
      if (account == null) return null;
      _currentAccount = account;
      return _profileFromAccount(account);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _requireDriveHeaders({
    required bool promptIfNecessary,
  }) async {
    final account = _currentAccount;
    if (account == null) {
      throw const DriveAuthExpiredException(
        'Google session inactive. Tap Sign in / Reconnect to sync.',
      );
    }

    final headers = await account.authorizationClient.authorizationHeaders(
      const [GoogleDriveBackupClient.appDataScope],
      promptIfNecessary: promptIfNecessary,
    );
    if (headers == null || headers.isEmpty) {
      throw const DriveAuthExpiredException(
        'Google Drive permission missing. Tap Sign in / Reconnect.',
      );
    }
    return headers;
  }

  Future<T> _withDriveAuth<T>(
    Future<T> Function(Map<String, String> headers) action, {
    required bool promptIfNecessary,
  }) async {
    var headers = await _requireDriveHeaders(
      promptIfNecessary: promptIfNecessary,
    );
    try {
      return await action(headers);
    } on DriveAuthExpiredException {
      final account = _currentAccount;
      if (account == null) rethrow;
      final bearer = headers['Authorization'] ?? '';
      if (bearer.startsWith('Bearer ')) {
        final expiredToken = bearer.substring(7).trim();
        if (expiredToken.isNotEmpty) {
          try {
            await account.authorizationClient.clearAuthorizationToken(
              accessToken: expiredToken,
            );
          } catch (_) {}
        }
      }
      headers = await _requireDriveHeaders(
        promptIfNecessary: promptIfNecessary,
      );
      return await action(headers);
    }
  }

  Future<({CloudBackupPayload? payload, String? fileId})> fetchDriveBackup({
    bool promptIfNecessary = false,
  }) {
    return _withDriveAuth(
      (headers) => _driveClient.downloadBackup(headers),
      promptIfNecessary: promptIfNecessary,
    );
  }

  Future<String> saveDriveBackup(
    CloudBackupPayload payload, {
    String? knownFileId,
    bool promptIfNecessary = false,
  }) {
    return _withDriveAuth(
      (headers) => _driveClient.uploadBackup(
        headers,
        payload,
        knownFileId: knownFileId,
      ),
      promptIfNecessary: promptIfNecessary,
    );
  }

  DocumentReference<Map<String, dynamic>> _legacyFirebaseDoc(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('backup')
        .doc('state');
  }

  /// Reads any legacy v1.0.0 Firebase Firestore backup once during Drive migration.
  /// Never writes to Firestore. Returns `null` when unavailable or empty.
  Future<CloudBackupPayload?> fetchLegacyFirebaseBackup() async {
    if (!isAvailable || Firebase.apps.isEmpty) return null;
    try {
      var user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        final idToken = _currentAccount?.authentication.idToken;
        if (idToken == null || idToken.isEmpty) return null;
        final cred = GoogleAuthProvider.credential(idToken: idToken);
        final res = await FirebaseAuth.instance.signInWithCredential(cred);
        user = res.user;
      }
      if (user == null) return null;

      final snap = await _legacyFirebaseDoc(user.uid).get();
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return CloudBackupPayload.fromFirestoreMap(data);
    } catch (_) {
      return null;
    }
  }

  /// Removes the old Firebase Firestore backup document after verified Drive upload.
  Future<void> deleteLegacyFirebaseBackup() async {
    if (!isAvailable || Firebase.apps.isEmpty) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _legacyFirebaseDoc(user.uid).delete();
      }
    } catch (_) {
      // Best-effort cleanup; user's data is already safely in Drive.
    }
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  Future<void> signOut() async {
    _currentAccount = null;
    if (!isAvailable) return;
    try {
      await _ensureGoogleInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
  }
}
