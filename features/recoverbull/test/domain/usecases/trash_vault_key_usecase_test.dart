import 'package:bull_recoverbull/src/data/mappers/encrypted_vault_mapper.dart';
import '../../support/monitoring_repository.dart';
import 'dart:io';
import 'package:convert/convert.dart' show hex;

import 'package:bull_recoverbull/src/domain/entities/key_server_attempts.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/record_local_attempt_usecase.dart';
import 'package:bull_recoverbull/src/domain/entities/attempt_alert.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_attempt_alert_port.dart';
import 'package:bull_recoverbull/src/data/recoverbull_attempt_monitoring_store.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:drift/native.dart';
import '../../support/log_sink.dart';
import 'package:bull_recoverbull/src/domain/usecases/trash_vault_key_usecase.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:recoverbull/recoverbull.dart' as sdk;

class _Repository extends Mock implements RecoverBullRepository {}

class _Ensure extends Mock implements EnsureRecoverBullTorSessionUsecase {}

RecoverBullTorRoute _route({Future<void> Function()? onClose}) =>
    RecoverBullTorRoute(
      TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
        evidence: TorReadinessEvidence.embeddedBootstrap,
      ),
      onClose ?? () async {},
      HttpClient(),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_route());
  });

  test(
    'successful deletion forgets the backup without publishing an alert',
    () async {
      final repository = _Repository();
      final ensure = _Ensure();
      final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await database.ensureState();
      final store = RecoverBullAttemptMonitoringStore(database);
      final recordAttempt = RecordLocalAttemptUsecase(
        monitoringRepository(store),
      );
      final alerts = _AlertPort();
      final backup = sdk.RecoverBull.createBackup(
        secret: [1],
        backupKey: List<int>.filled(32, 1),
      );
      final vault = EncryptedVaultMapper.parse(backup.toJson());
      final window = DateTime.utc(2026, 10, 1);
      final status = KeyServerAttemptStatus(
        totalAttempts: 3,
        failedAttempts: 2,
        remainingAttempts: 7,
        windowStartedAt: window,
        previousAttemptAt: null,
        resetsAt: window.add(const Duration(days: 1)),
      );
      await store.registerBackup(
        hex.decode(vault.id),
        observedTotal: 1,
        window: attemptWindowIdentity(window),
      );
      when(() => ensure.execute()).thenAnswer((_) async => Ok(_route()));
      when(
        () => repository.trashVaultKeyWithStatus(any(), any(), any(), any()),
      ).thenAnswer(
        (_) async =>
            Ok(VaultKeyFetchResult(vaultKey: 'key', attemptStatus: status)),
      );
      final result = await TrashVaultKeyUsecase(
        repository: repository,
        ensureSession: ensure,
        recordAttempt: recordAttempt,
        alertPort: alerts,
        log: const TestLogSink(),
      ).execute(vault: vault, password: 'password');
      expect(result, isA<Ok<VaultKeyFetchResult, RecoverBullFailure>>());
      expect(await store.monitoredBackups(), isEmpty);
      expect(alerts.published, isEmpty);
    },
  );

  test('trash preserves Ok when owned route teardown throws', () async {
    var closed = false;
    final route = _route(
      onClose: () async {
        closed = true;
        throw Exception('teardown');
      },
    );
    final repository = _Repository();
    final ensure = _Ensure();
    final backup = sdk.RecoverBull.createBackup(
      secret: [1],
      backupKey: List<int>.filled(32, 1),
    );
    final vault = EncryptedVaultMapper.parse(backup.toJson());
    when(() => ensure.execute()).thenAnswer((_) async => Ok(route));
    when(
      () => repository.trashVaultKeyWithStatus(any(), any(), any(), any()),
    ).thenAnswer(
      (_) async =>
          const Ok(VaultKeyFetchResult(vaultKey: 'key', attemptStatus: null)),
    );

    final result = await TrashVaultKeyUsecase(
      repository: repository,
      ensureSession: ensure,
      log: const TestLogSink(),
    ).execute(vault: vault, password: 'password');

    expect(result, isA<Ok<VaultKeyFetchResult, RecoverBullFailure>>());
    expect(closed, isTrue);
  });

  test('trash closes its owned route when repository throws', () async {
    var closed = false;
    final route = _route(onClose: () async => closed = true);
    final repository = _Repository();
    final ensure = _Ensure();
    final backup = sdk.RecoverBull.createBackup(
      secret: [1],
      backupKey: List<int>.filled(32, 1),
    );
    final vault = EncryptedVaultMapper.parse(backup.toJson());
    when(() => ensure.execute()).thenAnswer((_) async => Ok(route));
    when(
      () => repository.trashVaultKeyWithStatus(any(), any(), any(), any()),
    ).thenThrow(StateError('repository'));

    await expectLater(
      () => TrashVaultKeyUsecase(
        repository: repository,
        ensureSession: ensure,
        log: const TestLogSink(),
      ).execute(vault: vault, password: 'password'),
      throwsStateError,
    );
    expect(closed, isTrue);
  });

  test(
    'trash records and publishes a targeted lockout while returning Err',
    () async {
      var closed = false;
      final route = _route(onClose: () async => closed = true);
      final repository = _Repository();
      final ensure = _Ensure();
      final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
      await database.ensureState();
      final recordAttempt = RecordLocalAttemptUsecase(
        monitoringRepository(RecoverBullAttemptMonitoringStore(database)),
      );
      final alertPort = _AlertPort();
      final backup = sdk.RecoverBull.createBackup(
        secret: [1],
        backupKey: List<int>.filled(32, 1),
      );
      final vault = EncryptedVaultMapper.parse(backup.toJson());
      const failure = KeyServerRateLimitedFailure();
      when(() => ensure.execute()).thenAnswer((_) async => Ok(route));
      when(
        () => repository.trashVaultKeyWithStatus(any(), any(), any(), any()),
      ).thenAnswer((_) async => const Err(failure));
      final result = await TrashVaultKeyUsecase(
        repository: repository,
        ensureSession: ensure,
        recordAttempt: recordAttempt,
        alertPort: alertPort,
        log: const TestLogSink(),
      ).execute(vault: vault, password: 'password');

      expect(result, isA<Err<VaultKeyFetchResult, RecoverBullFailure>>());
      expect(
        (await recordAttempt.store.monitoredBackups().requireOk()),
        hasLength(1),
      );
      expect(alertPort.published, hasLength(1));
      expect(closed, isTrue);
      await database.close();
    },
  );

  test(
    'trash stays Ok when forgetting the monitored backup fails afterwards',
    () async {
      final repository = _Repository();
      final ensure = _Ensure();
      final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
      await database.ensureState();
      final recordAttempt = RecordLocalAttemptUsecase(
        monitoringRepository(RecoverBullAttemptMonitoringStore(database)),
      );
      // A missing table models a recoverable storage failure after server deletion.
      addTearDown(database.close);
      await database.customStatement('DROP TABLE recoverbull_monitored_backup');
      final log = TestLogSink.recording();
      final backup = sdk.RecoverBull.createBackup(
        secret: [1],
        backupKey: List<int>.filled(32, 1),
      );
      final vault = EncryptedVaultMapper.parse(backup.toJson());
      when(() => ensure.execute()).thenAnswer((_) async => Ok(_route()));
      when(
        () => repository.trashVaultKeyWithStatus(any(), any(), any(), any()),
      ).thenAnswer(
        (_) async => const Ok(
          VaultKeyFetchResult(vaultKey: 'secret-key', attemptStatus: null),
        ),
      );

      final result = await TrashVaultKeyUsecase(
        repository: repository,
        ensureSession: ensure,
        recordAttempt: recordAttempt,
        log: log,
      ).execute(vault: vault, password: 'secret-password');

      expect(result, isA<Ok<VaultKeyFetchResult, RecoverBullFailure>>());
      final messages = log.entries.map((entry) => entry.message).join('\n');
      expect(
        messages,
        contains('recoverbull.attempts.monitoring.remove.failed'),
      );
      expect(messages, isNot(contains('secret-key')));
      expect(messages, isNot(contains('secret-password')));
      expect(messages, isNot(contains(vault.id)));
    },
  );
}

final class _AlertPort implements RecoverBullAttemptAlertPort {
  final published = <AttemptAlert>[];

  @override
  void publish(AttemptAlert alert) => published.add(alert);
}
