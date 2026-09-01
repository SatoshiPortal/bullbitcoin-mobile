import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/key_server_attempts.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_vault_key_with_status_from_server_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/record_local_attempt_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/trash_vault_key_usecase.dart';
import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'dart:io';

import 'package:bull_tor/tor.dart';
import 'package:convert/convert.dart' as convert;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:recoverbull/recoverbull.dart' as sdk;

class _Repository extends Mock implements RecoverBullRepository {}

class _Session extends Mock implements EnsureRecoverBullTorSessionUsecase {}

void main() {
  setUpAll(() {
    registerFallbackValue(TorProxyEndpoint(host: '127.0.0.1', port: 19050));
    registerFallbackValue(
      RecoverBullTorRoute(
        TorRoute(
          source: TorSource.embedded,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
          evidence: TorReadinessEvidence.embeddedBootstrap,
        ),
        () async {},
        HttpClient(),
      ),
    );
  });

  test('status-aware fetch and trash record returned attempt status', () async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState();
    final store = RecoverBullAttemptMonitoringStore(database);
    final backup = sdk.RecoverBull.createBackup(
      secret: [1, 2, 3],
      backupKey: List<int>.filled(32, 9),
    );
    final vault = EncryptedVault(file: backup.toJson());
    await store.registerBackup(convert.hex.decode(vault.id));
    final repository = _Repository();
    final session = _Session();
    final route = RecoverBullTorRoute(
      TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
        evidence: TorReadinessEvidence.embeddedBootstrap,
        transport: TorTransport.direct,
      ),
      () async {},
      HttpClient(),
    );
    final status = KeyServerAttemptStatus(
      totalAttempts: 1,
      failedAttempts: 0,
      remainingAttempts: 2,
      windowStartedAt: DateTime.utc(2026),
      previousAttemptAt: null,
      resetsAt: DateTime.utc(2026, 1, 2),
    );
    when(() => session.execute()).thenAnswer((_) async => Ok(route));
    when(
      () => repository.fetchVaultKeyWithStatus(any(), any(), any(), any()),
    ).thenAnswer(
      (_) async =>
          Ok(VaultKeyFetchResult(vaultKey: 'aabb', attemptStatus: status)),
    );
    when(
      () => repository.trashVaultKeyWithStatus(any(), any(), any(), any()),
    ).thenAnswer(
      (_) async =>
          Ok(VaultKeyFetchResult(vaultKey: 'aabb', attemptStatus: status)),
    );

    final record = RecordLocalAttemptUsecase(store);
    await FetchVaultKeyWithStatusFromServerUsecase(
      repository,
      session,
      record,
    ).execute(vault: vault, password: 'password');
    await TrashVaultKeyUsecase(
      repository,
      session,
      record,
    ).execute(vault: vault, password: 'password');

    expect(
      (await store.monitoredBackups())
          .single
          .expectedServerDistinctCandidateTotal,
      1,
    );
    await database.close();
  });
}
