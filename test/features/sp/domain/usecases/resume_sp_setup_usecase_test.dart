import 'package:bb_mobile/core/wallet/domain/wallet_mutation_guard.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';
import 'package:bb_mobile/features/sp/domain/usecases/resume_sp_setup_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../sp_fakes.dart';

class _Configs extends Mock implements SpBackendConfigRepository {}

void main() {
  late MockSpAccountRepository repository;
  late MockGetSpSecretUsecase secrets;
  late _Configs configs;
  late ResumeSpSetupUsecase usecase;

  setUpAll(() {
    registerFallbackValue(BitcoinNetwork.regtest);
    registerFallbackValue(spBackendConfig());
    registerFallbackValue(spSourceBinding);
  });
  setUp(() async {
    final secret = await spSecret();
    registerFallbackValue(secret);
    repository = MockSpAccountRepository();
    secrets = MockGetSpSecretUsecase();
    configs = _Configs();
    when(
      () => configs.hasLegacyConfig(),
    ).thenAnswer((_) async => const Ok(false));
    when(() => configs.fetch()).thenAnswer((_) async => Ok(spBackendConfig()));
    when(
      () => configs.setIsSetUpNow(isSetUp: any(named: 'isSetUp')),
    ).thenReturn(null);
    when(
      () => repository.hasLegacyData(),
    ).thenAnswer((_) async => const Ok(false));
    when(
      () => repository.hasRevokedSentinel(),
    ).thenAnswer((_) async => const Ok(false));
    when(
      () => repository.verifyResumeBackups(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => repository.verifyPendingIdentity(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(() => repository.hasSession).thenReturn(false);
    when(() => repository.beginTeardown()).thenReturn(null);
    when(() => repository.endTeardown()).thenReturn(null);
    when(() => repository.dispose()).thenAnswer((_) async => const Ok(null));
    when(
      () => secrets.resolve(
        any(),
        walletId: any(named: 'walletId'),
        expected: any(named: 'expected'),
      ),
    ).thenAnswer((_) async => Ok((secret: secret, binding: spSourceBinding)));
    when(
      () => repository.createFromSecret(
        network: any(named: 'network'),
        expectedConfig: any(named: 'expectedConfig'),
        secret: any(named: 'secret'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        fetchConcurrencyFactor: any(named: 'fetchConcurrencyFactor'),
        matchConcurrencyFactor: any(named: 'matchConcurrencyFactor'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    usecase = ResumeSpSetupUsecase(
      repository: repository,
      files: repository,
      configs: configs,
      secrets: secrets,
      guard: SpSessionGuard(),
      walletMutationGuard: WalletMutationGuard(),
    );
  });

  test(
    'verifies the same binding and closes retained handle before opening',
    () async {
      when(() => repository.hasSession).thenReturn(true);
      expect(await usecase.execute(), isA<Ok<void, SpFailure>>());
      verifyInOrder([
        () => repository.verifyPendingIdentity(any()),
        () => secrets.resolve(
          BitcoinNetwork.regtest,
          walletId: 'wallet',
          expected: spSourceBinding,
        ),
        () => repository.dispose(),
        () => repository.createFromSecret(
          network: BitcoinNetwork.regtest,
          expectedConfig: any(named: 'expectedConfig'),
          secret: any(named: 'secret'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          fetchConcurrencyFactor: any(named: 'fetchConcurrencyFactor'),
          matchConcurrencyFactor: any(named: 'matchConcurrencyFactor'),
        ),
      ]);
      verifyNever(() => repository.deleteAccountDir());
    },
  );

  test(
    'native retry failure keeps pending data and remains retryable',
    () async {
      when(
        () => repository.createFromSecret(
          network: any(named: 'network'),
          expectedConfig: any(named: 'expectedConfig'),
          secret: any(named: 'secret'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          fetchConcurrencyFactor: any(named: 'fetchConcurrencyFactor'),
          matchConcurrencyFactor: any(named: 'matchConcurrencyFactor'),
        ),
      ).thenAnswer((_) async => const Err(SpUnexpected('open failed')));
      final result = await usecase.execute();
      expect((result as Err).failure, isA<SpRecoveryRequired>());
      verifyNever(() => repository.deleteAccountDir());
      verifyNever(() => configs.delete());
    },
  );

  for (final rejection in [
    'legacy key',
    'legacy files',
    'sentinel',
    'backup',
    'marker',
    'identity',
    'dispose',
  ]) {
    test('$rejection refuses retry without deleting account data', () async {
      switch (rejection) {
        case 'legacy key':
          when(
            () => configs.hasLegacyConfig(),
          ).thenAnswer((_) async => const Ok(true));
        case 'legacy files':
          when(
            () => repository.hasLegacyData(),
          ).thenAnswer((_) async => const Ok(true));
        case 'sentinel':
          when(
            () => repository.hasRevokedSentinel(),
          ).thenAnswer((_) async => const Ok(true));
        case 'backup':
          when(
            () => repository.verifyResumeBackups(any()),
          ).thenAnswer((_) async => const Err(SpRecoveryRequired()));
        case 'marker':
          when(
            () => repository.verifyPendingIdentity(any()),
          ).thenAnswer((_) async => const Err(SpRecoveryRequired()));
        case 'identity':
          when(
            () => secrets.resolve(
              any(),
              walletId: any(named: 'walletId'),
              expected: any(named: 'expected'),
            ),
          ).thenAnswer((_) async => const Err(SpSourceMismatch()));
        case 'dispose':
          when(() => repository.hasSession).thenReturn(true);
          when(
            () => repository.dispose(),
          ).thenAnswer((_) async => const Err(SpSessionBusy()));
      }
      expect(await usecase.execute(), isA<Err<void, SpFailure>>());
      verifyNever(
        () => repository.createFromSecret(
          network: any(named: 'network'),
          expectedConfig: any(named: 'expectedConfig'),
          secret: any(named: 'secret'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          fetchConcurrencyFactor: any(named: 'fetchConcurrencyFactor'),
          matchConcurrencyFactor: any(named: 'matchConcurrencyFactor'),
        ),
      );
      verifyNever(() => repository.deleteAccountDir());
      verifyNever(() => configs.delete());
    });
  }
}
