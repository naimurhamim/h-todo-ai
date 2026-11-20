import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:h_todo_ai/providers/security_provider.dart';
import 'package:h_todo_ai/services/security_service.dart';
import 'package:h_todo_ai/services/storage_service.dart';

void main() {
  group('SecurityService PIN hashing', () {
    test('verifies matching PIN and rejects wrong PIN or salt', () {
      final saltA = SecurityService.generateSalt();
      final saltB = SecurityService.generateSalt();
      expect(saltA, isNot(equals(saltB)));

      final hash = SecurityService.hashPin('2580', saltA);
      expect(SecurityService.verifyPin('2580', saltA, hash), isTrue);
      expect(SecurityService.verifyPin('1234', saltA, hash), isFalse);
      expect(SecurityService.verifyPin('2580', saltB, hash), isFalse);
    });
  });

  group('SecurityProvider lifecycle', () {
    test('enables, verifies, changes, re-locks on resume, and disables PIN', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      final provider = SecurityProvider(
        storage: storage,
        securityService: SecurityService.disabled(),
      );
      await provider.load();

      expect(provider.hasPin, isFalse);
      expect(provider.isLocked, isFalse);

      await provider.enablePin('4321');
      expect(provider.hasPin, isTrue);
      expect(provider.isLocked, isFalse);

      provider.lockNow();
      expect(provider.isLocked, isTrue);
      expect(provider.verifyAndUnlock('0000'), isFalse);
      expect(provider.isLocked, isTrue);
      expect(provider.verifyAndUnlock('4321'), isTrue);
      expect(provider.isLocked, isFalse);

      provider.handleAppLifecycleState(AppLifecycleState.paused);
      provider.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(provider.isLocked, isTrue);
      expect(provider.verifyAndUnlock('4321'), isTrue);

      expect(await provider.changePin('0000', '9876'), isFalse);
      expect(await provider.changePin('4321', '9876'), isTrue);
      provider.lockNow();
      expect(provider.verifyAndUnlock('4321'), isFalse);
      expect(provider.verifyAndUnlock('9876'), isTrue);

      expect(await provider.disablePin('0000'), isFalse);
      expect(await provider.disablePin('9876'), isTrue);
      expect(provider.hasPin, isFalse);
      expect(provider.isLocked, isFalse);
    });
  });
}
