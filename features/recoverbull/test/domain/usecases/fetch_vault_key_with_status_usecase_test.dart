import 'dart:io';

import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/key_server_attempts.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_vault_key_with_status_from_server_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/record_local_attempt_usecase.dart';
import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:drift/native.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import '../../support/log_sink.dart';

final class _Repository extends Mock implements RecoverBullRepository {}

final class _Ensure extends Mock
    implements EnsureRecoverBullTorSessionUsecase {}

final class _Vault extends Mock implements EncryptedVault {}

final class _MonitoringRemote
    implements RecoverBullAttemptMonitoringRemotePort {
  final RecoverBullAttemptsSnapshot snapshot;

  const _MonitoringRemote(this.snapshot);

  @override
  Future<RecoverBullAttemptsSnapshot?> poll({
    required String? etag,
    required List<String> backupDigests,
  }) async => snapshot;
}

RecoverBullTorRoute _route(void Function() onClose) => RecoverBullTorRoute(
  TorRoute(
    source: TorSource.embedded,
    endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
    evidence: TorReadinessEvidence.embeddedBootstrap,
  ),
  () async => onClose(),
  HttpClient(),
);

void main() {
  late _Repository repository;
  late _Ensure ensure;
  late _Vault vault;
  late RecoverBullTorRoute route;
  var closeCount = 0;

  setUpAll(() {
    registerFallbackValue(_route(() {}));
  });

  setUp(() {
    repository = _Repository();
    ensure = _Ensure();
    vault = _Vault();
    closeCount = 0;
    route = _route(() => closeCount++);
    when(() => vault.id).thenReturn('00');
    when(() => vault.salt).thenReturn('00');
    when(() => ensure.execute()).thenAnswer((_) async => Ok(route));
  });

  test('closes the owned route after a successful fetch', () async {
    when(
      () => repository.fetchVaultKeyWithStatus(any(), any(), any(), any()),
    ).thenAnswer(
      (_) async =>
          const Ok(VaultKeyFetchResult(vaultKey: 'aabb', attemptStatus: null)),
    );

    final result = await FetchVaultKeyWithStatusFromServerUsecase(
      repository: repository,
      ensureSession: ensure,
      log: const TestLogSink(),
    ).execute(vault: vault, password: 'password');

    expect(result, isA<Ok<VaultKeyFetchResult, RecoverBullFailure>>());
    expect(closeCount, 1);
  });

  test('closes the owned route after a failed fetch', () async {
    when(
      () => repository.fetchVaultKeyWithStatus(any(), any(), any(), any()),
    ).thenAnswer((_) async => const Err(KeyServerUnavailableFailure()));

    final result = await FetchVaultKeyWithStatusFromServerUsecase(
      repository: repository,
      ensureSession: ensure,
      log: const TestLogSink(),
    ).execute(vault: vault, password: 'password');

    expect(result, isA<Err<VaultKeyFetchResult, RecoverBullFailure>>());
    expect(closeCount, 1);
  });

  test(
    'records a successful fetch when the server omits attempt status',
    () async {
      final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
      await database.ensureState();
      final store = RecoverBullAttemptMonitoringStore(database);
      final identifier = [0];
      await store.registerBackup(identifier);
      final digest = store.digestFor(identifier);
      final window = DateTime.utc(2026, 8, 5, 14);
      final record = RecordLocalAttemptUsecase(
        store,
        remote: _MonitoringRemote(
          RecoverBullAttemptsSnapshot(
            collectionStartedAt: window,
            totalAttempts: {digest: 4},
            windowStartedAt: {digest: window},
          ),
        ),
      );
      when(
        () => repository.fetchVaultKeyWithStatus(any(), any(), any(), any()),
      ).thenAnswer(
        (_) async => const Ok(
          VaultKeyFetchResult(vaultKey: 'aabb', attemptStatus: null),
        ),
      );

      final result = await FetchVaultKeyWithStatusFromServerUsecase(
        repository: repository,
        ensureSession: ensure,
        recordAttempt: record,
        log: const TestLogSink(),
      ).execute(vault: vault, password: 'password');

      expect(result, isA<Ok<VaultKeyFetchResult, RecoverBullFailure>>());
      expect(
        (await store.monitoredBackups())
            .single
            .expectedServerDistinctCandidateTotal,
        4,
      );
      await database.close();
    },
  );
}
