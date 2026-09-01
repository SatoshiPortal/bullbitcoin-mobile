import 'dart:io';

import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/key_server_attempts.dart';
import 'package:bull_recoverbull/src/domain/entities/attempt_alert.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import '../../support/log_sink.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_vault_key_from_server_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_vault_key_with_status_from_server_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/record_local_attempt_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/trash_vault_key_usecase.dart';
import 'package:bull_recoverbull/src/public/recoverbull.dart';
import 'package:bull_tor/tor.dart';
import 'package:convert/convert.dart' as convert;
import 'package:drift/native.dart';
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

  test('fetch publishes a suspicious alert from local recording', () async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState();
    final store = RecoverBullAttemptMonitoringStore(database);
    final monitoring = RecoverBullAttemptMonitoring(store);
    await monitoring.setEnabled(true);
    final backup = sdk.RecoverBull.createBackup(
      secret: [1, 2, 3],
      backupKey: List<int>.filled(32, 9),
    );
    final vault = EncryptedVault(file: backup.toJson());
    await store.registerBackup(convert.hex.decode(vault.id));
    final repository = _Repository();
    final ensure = _Ensure();
    final route = _route();
    when(() => ensure.execute()).thenAnswer((_) async => Ok(route));
    var fetchCount = 0;
    when(
      () => repository.fetchVaultKeyWithStatus(any(), any(), any(), any()),
    ).thenAnswer(
      (_) async => Ok(
        VaultKeyFetchResult(
          vaultKey: 'aabb',
          attemptStatus: KeyServerAttemptStatus(
            totalAttempts: 2,
            failedAttempts: 1,
            remainingAttempts: 1,
            windowStartedAt: fetchCount++ == 0
                ? DateTime.utc(2026)
                : DateTime.utc(2026, 1, 2),
            previousAttemptAt: null,
            resetsAt: DateTime.utc(2026, 1, 2),
          ),
        ),
      ),
    );
    when(
      () => repository.trashVaultKeyWithStatus(any(), any(), any(), any()),
    ).thenAnswer(
      (_) async => Ok(
        VaultKeyFetchResult(
          vaultKey: 'aabb',
          attemptStatus: KeyServerAttemptStatus(
            totalAttempts: 2,
            failedAttempts: 1,
            remainingAttempts: 1,
            windowStartedAt: DateTime.utc(2026, 1, 3),
            previousAttemptAt: null,
            resetsAt: DateTime.utc(2026, 1, 4),
          ),
        ),
      ),
    );

    await FetchVaultKeyFromServerUsecase(
      repository: repository,
      ensureTor: ensure,
      recordAttempt: RecordLocalAttemptUsecase(store),
      alertPort: monitoring,
      log: const TestLogSink(),
    ).execute(vault: vault, password: 'password', route: route);
    var alerts = await monitoring.alerts.firstWhere(
      (alerts) => alerts.isNotEmpty,
    );
    expect(alerts.single, isA<RecoverBullAttemptAlert>());
    await monitoring.acknowledge(alerts.single);

    await FetchVaultKeyWithStatusFromServerUsecase(
      repository: repository,
      ensureSession: ensure,
      recordAttempt: RecordLocalAttemptUsecase(store),
      alertPort: monitoring,
      log: const TestLogSink(),
    ).execute(vault: vault, password: 'password');

    alerts = await monitoring.alerts.firstWhere((alerts) => alerts.isNotEmpty);
    expect(alerts.single, isA<RecoverBullAttemptAlert>());
    await monitoring.acknowledge(alerts.single);

    await TrashVaultKeyUsecase(
      repository: repository,
      ensureSession: ensure,
      recordAttempt: RecordLocalAttemptUsecase(store),
      alertPort: monitoring,
      log: const TestLogSink(),
    ).execute(vault: vault, password: 'password', route: route);
    alerts = await monitoring.alerts.firstWhere((alerts) => alerts.isNotEmpty);
    expect(alerts.single, isA<RecoverBullAttemptAlert>());
    await monitoring.acknowledge(alerts.single);
    expect(await monitoring.alerts.first, isEmpty);
    await database.close();
  });

  test(
    'distinct suspicious alerts remain independently acknowledgeable',
    () async {
      final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
      await database.ensureState();
      final monitoring = RecoverBullAttemptMonitoring(
        RecoverBullAttemptMonitoringStore(database),
      );
      monitoring.publish(
        SuspiciousActivityAlert(
          backupIdHash: 'backup-a',
          observedTotal: 3,
          expectedTotal: 1,
          windowStartedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      monitoring.publish(
        SuspiciousActivityAlert(
          backupIdHash: 'backup-b',
          observedTotal: 3,
          expectedTotal: 1,
          windowStartedAt: DateTime.utc(2026, 1, 2),
        ),
      );

      final visible = await monitoring.alerts.firstWhere(
        (alerts) => alerts.length == 2,
      );
      await monitoring.acknowledge(visible.first);
      final remaining = await monitoring.alerts.firstWhere(
        (alerts) => alerts.length == 1,
      );
      expect(remaining.single, same(visible.last));
      await database.close();
    },
  );
}
