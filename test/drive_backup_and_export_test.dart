import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:h_todo_ai/models/ai_provider_config.dart';
import 'package:h_todo_ai/models/chat_message.dart';
import 'package:h_todo_ai/models/cloud_backup_payload.dart';
import 'package:h_todo_ai/models/google_account_profile.dart';
import 'package:h_todo_ai/models/reminder_settings.dart';
import 'package:h_todo_ai/models/task_item.dart';
import 'package:h_todo_ai/providers/ai_settings_provider.dart';
import 'package:h_todo_ai/providers/chat_provider.dart';
import 'package:h_todo_ai/providers/cloud_sync_provider.dart';
import 'package:h_todo_ai/providers/task_provider.dart';
import 'package:h_todo_ai/services/cloud_backup_service.dart';
import 'package:h_todo_ai/services/google_drive_backup_client.dart';
import 'package:h_todo_ai/services/notification_service.dart';
import 'package:h_todo_ai/services/storage_service.dart';

void main() {
  CloudBackupPayload buildSamplePayload({
    String geminiKey = 'AIza-test-key-123',
    List<TaskItem>? tasks,
    DateTime? updatedAt,
  }) {
    final providers = Map<AiProviderType, AiProviderConfig>.from(
      AiProviderConfig.defaults(),
    );
    providers[AiProviderType.gemini] = providers[AiProviderType.gemini]!
        .copyWith(apiKey: geminiKey);

    return CloudBackupPayload(
      updatedAt: updatedAt ?? DateTime(2026, 11, 21, 10, 0),
      activeProviderType: AiProviderType.gemini,
      providers: providers,
      reminderSettings: const ReminderSettings(),
      tasks: tasks ??
          [
            TaskItem(
              id: 't-1',
              notificationBaseId: 101,
              title: 'Assignment 01',
              courseOrCategory: 'CSE 415',
              type: TaskType.assignment,
              dueDate: DateTime(2026, 11, 25),
              createdAt: DateTime(2026, 11, 20),
            ),
          ],
      chatMessages: [
        ChatMessage(
          id: 'm-1',
          role: ChatRole.user,
          text: 'CSE 415 Assignment 01 due 25 Nov',
          timestamp: DateTime(2026, 11, 20),
        ),
      ],
    );
  }

  group('GoogleDriveBackupClient', () {
    const authHeaders = {'Authorization': 'Bearer fake-token'};

    test('creates once with POST multipart then overwrites in-place with PATCH',
        () async {
      final calls = <String>[];
      var uploadCount = 0;

      final mockClient = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}?${request.url.query}');
        if (request.method == 'GET' && request.url.path == '/drive/v3/files') {
          return http.Response(jsonEncode({'files': []}), 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/upload/drive/v3/files') {
          uploadCount++;
          expect(request.body, contains('appDataFolder'));
          expect(request.body, contains('htodo_ai_backup.json'));
          return http.Response(jsonEncode({'id': 'drive-file-1'}), 200);
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/upload/drive/v3/files/drive-file-1') {
          uploadCount++;
          final decoded = jsonDecode(request.body) as Map<String, dynamic>;
          expect(decoded['app'], CloudBackupPayload.backupAppId);
          return http.Response(jsonEncode({'id': 'drive-file-1'}), 200);
        }
        return http.Response('Not found', 404);
      });

      final client = GoogleDriveBackupClient(client: mockClient);
      final payload = buildSamplePayload();

      final fileId1 = await client.uploadBackup(authHeaders, payload);
      expect(fileId1, 'drive-file-1');

      final fileId2 = await client.uploadBackup(
        authHeaders,
        payload,
        knownFileId: fileId1,
      );
      expect(fileId2, 'drive-file-1');
      expect(uploadCount, 2);
      expect(calls.any((c) => c.startsWith('POST /upload/drive/v3/files')), isTrue);
      expect(
        calls.where((c) => c.startsWith('PATCH /upload/drive/v3/files/drive-file-1')),
        hasLength(1),
      );
    });

    test('downloadBackup parses newest file and deletes duplicate copies',
        () async {
      final payload = buildSamplePayload();
      final deletedIds = <String>[];

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files') {
          return http.Response(
            jsonEncode({
              'files': [
                {'id': 'newest-id', 'name': 'htodo_ai_backup.json'},
                {'id': 'stale-dup-id', 'name': 'htodo_ai_backup.json'},
              ],
            }),
            200,
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/drive/v3/files/newest-id') {
          return http.Response(payload.toJsonString(), 200);
        }
        if (request.method == 'DELETE') {
          deletedIds.add(request.url.pathSegments.last);
          return http.Response('', 204);
        }
        return http.Response('Error', 500);
      });

      final client = GoogleDriveBackupClient(client: mockClient);
      final res = await client.downloadBackup(authHeaders);

      expect(res.fileId, 'newest-id');
      expect(res.payload?.tasks, hasLength(1));
      expect(res.payload?.tasks.first.title, 'Assignment 01');
      expect(deletedIds, ['stale-dup-id']);
    });

    test('throws DriveAuthExpiredException on HTTP 401', () async {
      final mockClient = MockClient(
        (_) async => http.Response('Unauthorized', 401),
      );
      final client = GoogleDriveBackupClient(client: mockClient);

      await expectLater(
        client.downloadBackup(authHeaders),
        throwsA(isA<DriveAuthExpiredException>()),
      );
    });
  });

  group('CloudBackupPayload JSON Export/Import & Fingerprinting', () {
    test('includeApiKeys flag controls key serialization & envelope detection',
        () {
      final full = buildSamplePayload(geminiKey: 'secret-key-999');

      final withKeysRaw = full.toJsonString(includeApiKeys: true, pretty: true);
      final withKeysEnv = CloudBackupPayload.parseBackupEnvelope(withKeysRaw);
      expect(withKeysEnv.includesApiKeys, isTrue);
      expect(
        withKeysEnv.payload.providers[AiProviderType.gemini]?.apiKey,
        'secret-key-999',
      );

      final withoutKeysRaw =
          full.toJsonString(includeApiKeys: false, pretty: true);
      final withoutKeysEnv =
          CloudBackupPayload.parseBackupEnvelope(withoutKeysRaw);
      expect(withoutKeysEnv.includesApiKeys, isFalse);
      expect(
        withoutKeysEnv.payload.providers[AiProviderType.gemini]?.apiKey,
        isEmpty,
      );
      expect(withoutKeysEnv.payload.tasks.first.title, 'Assignment 01');
    });

    test('rejects unrelated or invalid JSON files', () {
      expect(
        () => CloudBackupPayload.fromJsonString(
          jsonEncode({'app': 'other_app', 'tasks': []}),
        ),
        throwsFormatException,
      );
      expect(
        () => CloudBackupPayload.fromJsonString(jsonEncode({'hello': 'world'})),
        throwsFormatException,
      );
    });

    test('content fingerprint ignores updatedAt but detects task edits', () {
      final p1 = buildSamplePayload(updatedAt: DateTime(2026, 11, 20, 8, 0));
      final p2 = buildSamplePayload(updatedAt: DateTime(2026, 11, 21, 14, 30));
      final p3 = buildSamplePayload(
        tasks: [
          TaskItem(
            id: 't-1',
            notificationBaseId: 101,
            title: 'Updated Title',
            dueDate: DateTime(2026, 11, 25),
            createdAt: DateTime(2026, 11, 20),
          ),
        ],
      );

      expect(p1.computeContentFingerprint(), p2.computeContentFingerprint());
      expect(
        p1.computeContentFingerprint(),
        isNot(p3.computeContentFingerprint()),
      );
    });
  });

  group('StorageService profile cache & CloudSyncProvider import', () {
    test('persists cached Google Name, Gmail, driveFileId and clears cleanly',
        () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();

      expect(await storage.loadGoogleProfile(), isNull);

      final saved = GoogleAccountProfile(
        id: 'acc-1',
        email: 'user.test@gmail.com',
        displayName: 'User Test',
        photoUrl: 'https://example.com/a.jpg',
        driveFileId: 'drv-1',
        lastSyncedAt: DateTime(2026, 11, 21, 9, 30),
        migratedFromFirebase: true,
      );
      await storage.saveGoogleProfile(saved);

      final loaded = await storage.loadGoogleProfile();
      expect(loaded, isNotNull);
      expect(loaded!.email, 'user.test@gmail.com');
      expect(loaded.displayName, 'User Test');
      expect(loaded.driveFileId, 'drv-1');
      expect(loaded.migratedFromFirebase, isTrue);

      await storage.saveGoogleProfile(null);
      expect(await storage.loadGoogleProfile(), isNull);
    });

    test(
        'applyImportedBackup merges without duplicates and preserves keys when replacing key-less export',
        () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      final aiSettings = AiSettingsProvider(storage: storage);
      final notifications = NotificationService();
      final taskProvider = TaskProvider(
        storage: storage,
        notifications: notifications,
        readReminderSettings: () => aiSettings.reminderSettings,
      );
      final chatProvider = ChatProvider(storage: storage);

      await aiSettings.load();
      await taskProvider.load();
      await chatProvider.load();

      await aiSettings.updateProviderConfig(
        aiSettings.providers[AiProviderType.gemini]!
            .copyWith(apiKey: 'local-user-key'),
      );
      await taskProvider.addTask(
        TaskItem(
          id: 'local-1',
          notificationBaseId: 10,
          title: 'Local Task',
          dueDate: DateTime(2026, 11, 22),
          createdAt: DateTime(2026, 11, 20),
        ),
      );

      final sync = CloudSyncProvider(
        service: CloudBackupService.disabled(),
        storage: storage,
        aiSettings: aiSettings,
        tasks: taskProvider,
        chat: chatProvider,
      );

      final importedKeyless = buildSamplePayload(geminiKey: '');

      // Merge mode keeps existing local task + adds imported task + preserves API key.
      await sync.applyImportedBackup(
        importedKeyless,
        merge: true,
        includesApiKeys: false,
      );
      expect(taskProvider.tasks.map((t) => t.title),
          containsAll(['Local Task', 'Assignment 01']));
      expect(
        aiSettings.providers[AiProviderType.gemini]?.apiKey,
        'local-user-key',
      );

      // Replace mode with key-less export replaces tasks cleanly while keeping local keys.
      await sync.applyImportedBackup(
        importedKeyless,
        merge: false,
        includesApiKeys: false,
      );
      expect(taskProvider.tasks.map((t) => t.title), ['Assignment 01']);
      expect(
        aiSettings.providers[AiProviderType.gemini]?.apiKey,
        'local-user-key',
      );
    });

    test(
        'mergeWithLocal preserves newer local reminderSettings and custom task time even when cloud has API keys',
        () {
      final providersWithKey = Map<AiProviderType, AiProviderConfig>.from(
        AiProviderConfig.defaults(),
      );
      providersWithKey[AiProviderType.groq] =
          providersWithKey[AiProviderType.groq]!
              .copyWith(apiKey: 'gsk-cloud-key');

      final olderCloud = CloudBackupPayload(
        updatedAt: DateTime(2026, 11, 21, 18, 0),
        activeProviderType: AiProviderType.gemini,
        providers: providersWithKey,
        reminderSettings: const ReminderSettings(),
        tasks: [
          TaskItem(
            id: 'shared-task-1',
            notificationBaseId: 500,
            title: 'Class Test',
            dueDate: DateTime(2026, 11, 22),
            dueHour: null,
            dueMinute: null,
            createdAt: DateTime(2026, 11, 20),
          ),
        ],
        chatMessages: const [],
      );

      final newerLocal = CloudBackupPayload(
        updatedAt: DateTime(2026, 11, 21, 19, 30),
        activeProviderType: AiProviderType.groq,
        providers: providersWithKey,
        reminderSettings: const ReminderSettings(
          dayBeforeHour: 19,
          dayBeforeMinute: 45,
          endOfDayHour: 23,
          endOfDayMinute: 15,
        ),
        tasks: [
          TaskItem(
            id: 'shared-task-1',
            notificationBaseId: 500,
            title: 'Class Test',
            dueDate: DateTime(2026, 11, 22),
            dueHour: 19,
            dueMinute: 50,
            notes: 'Bring calculator',
            createdAt: DateTime(2026, 11, 20),
          ),
        ],
        chatMessages: const [],
      );

      final merged = olderCloud.mergeWithLocal(newerLocal);
      expect(merged.activeProviderType, AiProviderType.groq);
      expect(merged.reminderSettings.dayBeforeHour, 19);
      expect(merged.reminderSettings.dayBeforeMinute, 45);
      expect(merged.reminderSettings.endOfDayHour, 23);
      expect(merged.reminderSettings.endOfDayMinute, 15);
      expect(merged.tasks, hasLength(1));
      expect(merged.tasks.first.dueHour, 19);
      expect(merged.tasks.first.dueMinute, 50);
      expect(merged.tasks.first.notes, 'Bring calculator');
    });

    test(
        'mergeWithLocal preserves custom local reminderSettings over default cloud reminderSettings even if cloud is newer',
        () {
      final providersWithKey = Map<AiProviderType, AiProviderConfig>.from(
        AiProviderConfig.defaults(),
      );
      providersWithKey[AiProviderType.groq] =
          providersWithKey[AiProviderType.groq]!
              .copyWith(apiKey: 'gsk-cloud-key');

      final newerCloudWithDefaults = CloudBackupPayload(
        updatedAt: DateTime(2026, 11, 21, 20, 0),
        activeProviderType: AiProviderType.groq,
        providers: providersWithKey,
        reminderSettings: const ReminderSettings(),
        tasks: const [],
        chatMessages: const [],
      );

      final localCustomized = CloudBackupPayload(
        updatedAt: DateTime(2026, 11, 21, 18, 0),
        activeProviderType: AiProviderType.groq,
        providers: providersWithKey,
        reminderSettings: const ReminderSettings(
          dayBeforeHour: 17,
          dayBeforeMinute: 15,
          endOfDayHour: 21,
          endOfDayMinute: 45,
        ),
        tasks: [
          TaskItem(
            id: 'local-only',
            notificationBaseId: 510,
            title: 'Quiz',
            dueDate: DateTime(2026, 11, 22),
            createdAt: DateTime(2026, 11, 21),
          ),
        ],
        chatMessages: const [],
      );

      final merged = newerCloudWithDefaults.mergeWithLocal(localCustomized);
      expect(merged.reminderSettings.dayBeforeHour, 17);
      expect(merged.reminderSettings.dayBeforeMinute, 15);
      expect(merged.reminderSettings.endOfDayHour, 21);
      expect(merged.reminderSettings.endOfDayMinute, 45);
    });

    test('StorageService persists lastUpdatedAt when saving reminder settings',
        () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      expect(await storage.loadLastUpdatedAt(), isNull);

      await storage.saveReminderSettings(
        const ReminderSettings(dayBeforeHour: 18, dayBeforeMinute: 30),
      );
      final recorded = await storage.loadLastUpdatedAt();
      expect(recorded, isNotNull);

      final customTs = DateTime(2026, 11, 21, 12, 0);
      await storage.saveLastUpdatedAt(customTs);
      expect(await storage.loadLastUpdatedAt(), customTs);
    });

    test(
        'deletedTaskIds tombstones serialize cleanly and prevent deleted tasks from resurrecting in mergeWithLocal',
        () {
      final tKeep = TaskItem(
        id: 't-keep',
        notificationBaseId: 101,
        title: 'Keep Task',
        dueDate: DateTime(2026, 11, 25),
        createdAt: DateTime(2026, 11, 20),
      );
      final tDeletedLocally = TaskItem(
        id: 't-del-offline',
        notificationBaseId: 102,
        title: 'Offline Deleted Series Item',
        dueDate: DateTime(2026, 11, 26),
        createdAt: DateTime(2026, 11, 20),
      );

      final olderCloud = CloudBackupPayload(
        updatedAt: DateTime(2026, 11, 22, 10, 0),
        activeProviderType: AiProviderType.groq,
        providers: AiProviderConfig.defaults(),
        reminderSettings: const ReminderSettings(),
        tasks: [tKeep, tDeletedLocally],
        chatMessages: const [],
      );

      final localWithTombstone = CloudBackupPayload(
        updatedAt: DateTime(2026, 11, 22, 12, 0),
        activeProviderType: AiProviderType.groq,
        providers: AiProviderConfig.defaults(),
        reminderSettings: const ReminderSettings(),
        tasks: [tKeep],
        chatMessages: const [],
        deletedTaskIds: const ['t-del-offline'],
      );

      final roundTrip = CloudBackupPayload.fromJsonString(
        localWithTombstone.toJsonString(),
      );
      expect(roundTrip.deletedTaskIds, ['t-del-offline']);
      expect(
        localWithTombstone.computeContentFingerprint(),
        isNot(olderCloud.computeContentFingerprint()),
      );

      final merged = olderCloud.mergeWithLocal(localWithTombstone);
      expect(merged.tasks.map((t) => t.id), ['t-keep']);
      expect(merged.deletedTaskIds, ['t-del-offline']);
    });
  });
}
