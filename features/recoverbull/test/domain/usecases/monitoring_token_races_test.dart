import 'package:bull_recoverbull/src/domain/usecases/register_monitored_backup_usecase.dart';
import 'package:bull_recoverbull/src/domain/entities/monitored_backup.dart';
import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'package:bull_recoverbull/src/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/domain/entities/key_server_attempts.dart';
import 'package:bull_recoverbull/src/domain/usecases/check_backup_attempt_monitoring_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/record_local_attempt_usecase.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/monitoring_repository.dart';

final class _Remote implements RecoverBullAttemptMonitoringRemotePort {
  final Future<RecoverBullAttemptsSnapshot?> Function() response;
  const _Remote(this.response);
  @override
  Future<RecoverBullAttemptsSnapshot?> poll({
    required String? etag,
    required List<String> backupDigests,
  }) => response();
}

void main() {
  late RecoverBullDatabase db;
  late RecoverBullAttemptMonitoringStore store;
  late RecoverbullSettingsDatasource settings;
  final now = DateTime.utc(2026, 10, 13);
  const identifier = [1, 2, 3];

  setUp(() async {
    db = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await db.ensureState();
    store = RecoverBullAttemptMonitoringStore(db);
    settings = RecoverbullSettingsDatasource(database: db);
  });
  tearDown(() => db.close());

  test(
    'disabled monitoring neither polls nor restores created or adopted tracking',
    () async {
      await store.setEnabled(false);
      var polls = 0;
      final record = RecordLocalAttemptUsecase(
        monitoringRepository(store),
        remote: _Remote(() async {
          polls++;
          return null;
        }),
      );
      expect(await record.execute(backupIdHex: '010203').requireOk(), isNull);
      expect(
        await record.recordTargetedLockout(backupIdHex: '010203').requireOk(),
        isNull,
      );
      await store.registerBackup(identifier);
      await store.registerBackup(
        identifier,
        origin: MonitoredBackupOrigin.adopted,
      );
      await store.replaceBackup(
        AttemptMonitoringBackupState(
          serverUrl: '',
          backupIdHash: store
              .digestFor(identifier)
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(),
          expectedTotalAttempts: 9,
        ),
      );
      expect(await store.monitoredBackups(), isEmpty);
      expect(polls, 0);
      // Revoked tracking remains advisory and cannot reject a completed backup.
      expect(
        await RegisterMonitoredBackupUsecase(
          monitoringRepository(store),
        ).execute(backupIdHex: '010203').requireOk(),
        isNull,
      );
      expect(await store.monitoredBackups(), isEmpty);
    },
  );

  for (final unsupported in [false, true]) {
    test(
      'disabling monitoring during local ${unsupported ? '404' : 'success'} prevents every delayed write',
      () async {
        await store.registerBackup(identifier);
        final record = RecordLocalAttemptUsecase(
          monitoringRepository(store),
          clock: () => now,
          remote: _Remote(() async {
            await store.setEnabled(false);
            return RecoverBullAttemptsSnapshot(
              collectionStartedAt: now,
              totalAttempts: {store.digestFor(identifier): 7},
              serverUnsupported: unsupported,
            );
          }),
        );
        expect(await record.execute(backupIdHex: '010203').requireOk(), isNull);
        expect((await store.state()).attemptMonitoringEnabled, isFalse);
        expect((await store.state()).attemptsUnsupportedUntil, isNull);
        expect(await store.monitoredBackups(), isEmpty);
      },
    );
  }

  test(
    'old server 404 cannot mark the newly selected server unsupported',
    () async {
      await store.registerBackup(identifier);
      final check = CheckBackupAttemptMonitoringUsecase(
        store: monitoringRepository(store),
        clock: () => now,
        remote: _Remote(() async {
          await settings.store(Uri.parse('http://new-server.onion'));
          return RecoverBullAttemptsSnapshot(
            collectionStartedAt: now,
            totalAttempts: const {},
            serverUnsupported: true,
          );
        }),
      );
      expect(await check.execute(forceRefresh: true).requireOk(), isEmpty);
      expect((await store.state()).attemptsUnsupportedUntil, isNull);
    },
  );

  for (final notModified in [false, true]) {
    test(
      'old ${notModified ? '304' : 'success'} cannot clear a newer unsupported marker',
      () async {
        await store.registerBackup(identifier);
        final until = now.add(const Duration(days: 1));
        final check = CheckBackupAttemptMonitoringUsecase(
          store: monitoringRepository(store),
          clock: () => now,
          remote: _Remote(() async {
            await store.recordAttemptsUnsupported(until: until);
            return RecoverBullAttemptsSnapshot(
              collectionStartedAt: now,
              totalAttempts: {store.digestFor(identifier): 99},
              notModified: notModified,
            );
          }),
        );
        expect(await check.execute(forceRefresh: true).requireOk(), isEmpty);
        expect((await store.state()).attemptsUnsupportedUntil, until);
        expect((await store.state()).lastSuccessfulCheckAt, isNull);
      },
    );
  }

  for (final unsupported in [false, true]) {
    test(
      'local baseline old ${unsupported ? '404' : 'success'} cannot mutate a new server',
      () async {
        await store.registerBackup(identifier);
        final record = RecordLocalAttemptUsecase(
          monitoringRepository(store),
          clock: () => now,
          remote: _Remote(() async {
            await settings.store(Uri.parse('http://new-server.onion'));
            return RecoverBullAttemptsSnapshot(
              collectionStartedAt: now,
              totalAttempts: {store.digestFor(identifier): 7},
              serverUnsupported: unsupported,
            );
          }),
        );
        expect(await record.execute(backupIdHex: '010203').requireOk(), isNull);
        final row = (await store.monitoredBackups()).single;
        expect(row.expectedServerDistinctCandidateTotal, 0);
        expect(row.awaitsBaseline, isTrue);
        expect((await store.state()).attemptsUnsupportedUntil, isNull);
      },
    );
  }

  test(
    'local baseline cannot overwrite a newer own attempt in the same window',
    () async {
      await store.registerBackup(identifier);
      final record = RecordLocalAttemptUsecase(
        monitoringRepository(store),
        clock: () => now,
        remote: _Remote(() async {
          await store.recordOwnAttempt(
            identifier,
            serverTotalAttempts: 8,
            window: now,
          );
          return RecoverBullAttemptsSnapshot(
            collectionStartedAt: now,
            totalAttempts: {store.digestFor(identifier): 7},
          );
        }),
      );
      expect(await record.execute(backupIdHex: '010203').requireOk(), isNull);
      final row = (await store.monitoredBackups()).single;
      expect(row.expectedServerDistinctCandidateTotal, 8);
      expect(row.currentWindow, attemptWindowIdentity(now));
    },
  );
}
