import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/sp_session_guard.dart';
import 'package:silent/src/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:silent/src/domain/usecases/is_sp_scanning_usecase.dart';
import 'package:silent/src/domain/usecases/update_sp_backend_config_usecase.dart';

import '../../sp_fakes.dart';

class _Session extends Mock implements EnsureSpSessionUsecase {}

void main() {
  const network = BitcoinNetwork.mainnet;
  const newUrl = 'https://blindbit.new';
  final previous = spBackendConfig(
    network: network,
    blindbitUrl: 'https://blindbit.old',
  );
  late MockSpAccountRepository account;
  late FakeSpBackendConfigRepository configs;
  late _Session session;
  late FakeSpFeatureGateUsecase gate;
  late UpdateSpBackendConfigUsecase update;

  setUp(() async {
    account = MockSpAccountRepository();
    configs = FakeSpBackendConfigRepository();
    await configs.save(previous);
    session = _Session();
    gate = FakeSpFeatureGateUsecase();
    update = UpdateSpBackendConfigUsecase(
      gate: gate,
      account: account,
      files: account,
      configs: configs,
      ensureSession: session,
      isScanning: IsSpScanningUsecase(repository: account),
      guard: SpSessionGuard(),
    );
    when(account.adoptNewestBackup).thenAnswer((_) async => const Ok(false));
    when(account.hasRevokedSentinel).thenAnswer((_) async => const Ok(false));
    when(account.accountDirExists).thenAnswer((_) async => const Ok(true));
    when(() => account.isScanningCached).thenReturn(false);
    when(account.dispose).thenAnswer((_) async => const Ok(null));
  });

  Future<Result<bool, SilentFailure>> change() => update.execute(
    network: network,
    blindbitUrl: newUrl,
    electrumUrl: previous.electrumUrl,
  );

  test('reopens with the new config without replacing wallet files', () async {
    when(() => session.execute(allowDuringTeardown: true))
        .thenAnswer((_) async {
          expect(
            (await configs.fetch()).fold((c) => c?.blindbitUrl, (_) => null),
            newUrl,
          );
          return Ok(spWallet());
        });

    expect(
      await change(),
      isA<Ok<bool, SilentFailure>>().having((r) => r.value, 'value', true),
    );
    verify(account.dispose).called(1);
    verifyNever(account.deleteAccountDir);
  });

  test(
    'restores and reopens the previous config if the new open fails',
    () async {
      const failure = SilentUnexpected('open failed');
      final openedUrls = <String?>[];
      when(() => session.execute(allowDuringTeardown: true))
          .thenAnswer((_) async {
            final url = (await configs.fetch()).fold(
              (c) => c?.blindbitUrl,
              (_) => null,
            );
            openedUrls.add(url);
            return url == newUrl ? const Err(failure) : Ok(spWallet());
          });

      expect(
        await change(),
        isA<Err<bool, SilentFailure>>().having(
          (r) => r.failure,
          'failure',
          failure,
        ),
      );
      expect(openedUrls, [newUrl, previous.blindbitUrl]);
      verifyNever(account.deleteAccountDir);
    },
  );

  test('reopens the old session if saving the new config fails', () async {
    configs.saveShouldFail = true;
    when(() => session.execute(allowDuringTeardown: true))
        .thenAnswer((_) async => Ok(spWallet()));

    expect(await change(), isA<Err<bool, SilentFailure>>());
    expect((await configs.fetch()).fold((c) => c, (_) => null), previous);
    verify(() => session.execute(allowDuringTeardown: true)).called(1);
    verifyNever(account.deleteAccountDir);
  });

  test('reports rollback failure when restoring the config fails', () async {
    when(() => session.execute(allowDuringTeardown: true))
        .thenAnswer((_) async {
          configs.saveShouldFail = true;
          return const Err(SilentUnexpected('open failed'));
        });

    final result = await change();

    expect(
      result,
      isA<Err<bool, SilentFailure>>().having(
        (r) => r.failure.runtimeType.toString(),
        'failure type',
        'SilentBackendRollbackFailed',
      ),
    );
    expect(
      (await configs.fetch()).fold((c) => c?.blindbitUrl, (_) => null),
      newUrl,
    );
  });

  test('does not reopen the old session when the gate closes', () async {
    when(() => session.execute(allowDuringTeardown: true))
        .thenAnswer((_) async {
          gate.allowed = false;
          return const Err(SilentUnsupportedNetwork());
        });

    final result = await change();

    expect(
      result,
      isA<Err<bool, SilentFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<SilentBackendRollbackFailed>(),
      ),
    );
    expect((await configs.fetch()).fold((c) => c, (_) => null), previous);
    verify(() => session.execute(allowDuringTeardown: true)).called(1);
  });

  test(
    'reports rollback failure if the previous session cannot reopen',
    () async {
      when(() => session.execute(allowDuringTeardown: true))
          .thenAnswer((_) async => const Ok(null));

      expect(
        await change(),
        isA<Err<bool, SilentFailure>>().having(
          (r) => r.failure,
          'failure',
          isA<SilentBackendRollbackFailed>(),
        ),
      );
    },
  );

  test('refuses to reconfigure a running scan', () async {
    when(() => account.isScanningCached).thenReturn(true);

    expect(
      await change(),
      isA<Err<bool, SilentFailure>>().having(
        (r) => r.failure,
        'failure',
        isA<SilentScanBusy>(),
      ),
    );
    verifyNever(account.dispose);
  });
}
