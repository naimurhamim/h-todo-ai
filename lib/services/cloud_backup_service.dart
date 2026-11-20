import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/cloud_backup_payload.dart';

/// Handles Google Sign-In authentication and Firestore snapshot backup/restore.
class CloudBackupService {
  CloudBackupService({bool forceDisabled = false})
      : _forceDisabled = forceDisabled;

  /// Creates an inert instance for headless widget/unit tests.
  CloudBackupService.disabled() : _forceDisabled = true;

  /// Web OAuth 2.0 client ID from `google-services.json` (`client_type: 3`).
  static const String webServerClientId =
      '865261282040-e92e3oearm8am9onpd434ri6n2vet4si.apps.googleusercontent.com';

  final bool _forceDisabled;
  bool _googleInitialized = false;

  bool get isAvailable {
    if (_forceDisabled || kIsWeb) return false;
    final mobilePlatform = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!mobilePlatform) return false;
    return Firebase.apps.isNotEmpty;
  }

  User? get currentUser =>
      isAvailable ? FirebaseAuth.instance.currentUser : null;

  Stream<User?> authStateChanges() {
    if (!isAvailable) return const Stream<User?>.empty();
    return FirebaseAuth.instance.authStateChanges();
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: webServerClientId,
    );
    _googleInitialized = true;
  }

  /// Signs in with Google and authenticates Firebase Auth. Returns `null` if cancelled.
  Future<User?> signInWithGoogle() async {
    if (!isAvailable) {
      throw StateError(
        'Cloud Backup requires an Android or iOS device with Firebase initialized.',
      );
    }

    await _ensureGoogleInitialized();

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google Sign-In did not return an ID token. Check SHA-1 & OAuth setup in Firebase.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    return userCredential.user;
  }

  Future<void> signOut() async {
    if (!isAvailable) return;
    try {
      await _ensureGoogleInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  DocumentReference<Map<String, dynamic>> _backupDoc(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('backup')
        .doc('state');
  }

  /// Replaces the user's entire cloud backup document with [payload].
  Future<void> saveBackup(String uid, CloudBackupPayload payload) async {
    if (!isAvailable) return;
    await _backupDoc(uid).set(payload.toFirestoreMap());
  }

  /// Fetches the user's cloud backup document, or `null` if none exists yet.
  Future<CloudBackupPayload?> fetchBackup(String uid) async {
    if (!isAvailable) return null;
    final snap = await _backupDoc(uid).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return CloudBackupPayload.fromFirestoreMap(data);
  }
}
