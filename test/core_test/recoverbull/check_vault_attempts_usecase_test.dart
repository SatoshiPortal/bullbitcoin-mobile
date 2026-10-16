import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_attempts.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_tor_route.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_vault_attempts_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements RecoverBullRepository {}

class _MockEnsureSession extends Mock
    implements EnsureRecoverBullTorSessionUsecase {}

class _MockEncryptedVault extends Mock implements EncryptedVault {}

void main() {
  late _MockRepository repository;
  late _MockEnsureSession ensureSession;
  late _MockEncryptedVault vault;
  late CheckVaultAttemptsUsecase usecase;
  late List<Duration> waits;
  var sessionsClosed = 0;

  final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 19050);

  setUpAll(() => registerFallbackValue(endpoint));

  setUp(() {
    repository = _MockRepository();
    ensureSession = _MockEnsureSession();
    vault = _MockEncryptedVault();
    waits = [];
    sessionsClosed = 0;
    when(() => vault.id).thenReturn('aa' * 32);
    when(() => ensureSession.execute()).thenAnswer(
      (_) async => Ok(
        RecoverBullTorRoute(
          TorRoute(
            source: TorSource.embedded,
            endpoint: endpoint,
            evidence: TorReadinessEvidence.embeddedBootstrap,
            transport: TorTransport.direct,
          ),
          () async => sessionsClosed++,
        ),
      ),
    );
    usecase = CheckVaultAttemptsUsecase(
      repository,
      ensureSession,
      wait: (duration) async => waits.add(duration),
    );
  });

  void stubAttempts(
    List<Result<VaultAttempts, RecoverBullCoreFailure>> answers,
  ) {
    final queue = [...answers];
    when(
      () => repository.fetchVaultAttempts(any(), any()),
    ).thenAnswer((_) async => queue.removeAt(0));
  }

  test('retries an unreachable server, then reports the attempts', () async {
    stubAttempts([
      const Err(KeyServerUnavailableFailure('socks general failure')),
      const Ok(VaultAttempts(failedAttempts: 3)),
    ]);

    final result = await usecase.execute(vault: vault);

    expect((result as Ok).value.failedAttempts, 3);
    expect(waits, [const Duration(seconds: 1)]);
    verify(() => repository.fetchVaultAttempts('aa' * 32, endpoint)).called(2);
    expect(sessionsClosed, 1);
  });

  test('no Tor route: unknown, the server is never asked', () async {
    when(() => ensureSession.execute()).thenAnswer(
      (_) async => const Err(KeyServerUnavailableFailure('tor down')),
    );

    final result = await usecase.execute(vault: vault);

    expect((result as Err).failure, isA<KeyServerUnavailableFailure>());
    verifyNever(() => repository.fetchVaultAttempts(any(), any()));
  });

  test('gives up after the last attempt and closes the session', () async {
    stubAttempts(
      List.filled(
        CheckVaultAttemptsUsecase.maxAttempts,
        const Err(KeyServerUnavailableFailure('socks general failure')),
      ),
    );

    final result = await usecase.execute(vault: vault);

    expect((result as Err).failure, isA<KeyServerUnavailableFailure>());
    verify(
      () => repository.fetchVaultAttempts(any(), any()),
    ).called(CheckVaultAttemptsUsecase.maxAttempts);
    expect(sessionsClosed, 1);
  });
}
