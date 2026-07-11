import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/revoke_sp_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSpAccountRepository extends Mock implements SpAccountRepository {}

class MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

// Orchestration-level tests: the on-disk teardown (sentinel-before-dispose,
// delete + partial recovery) lives in BwkSpAccountRepository.revokeOnDisk and
// is covered by its own test. Here we only assert the use case wires the repo
// calls in the right order.
void main() {
  late MockSpAccountRepository accountRepo;
  late MockSpBackendConfigRepository configRepo;
  late RevokeSpWalletUsecase usecase;

  setUp(() {
    accountRepo = MockSpAccountRepository();
    configRepo = MockSpBackendConfigRepository();
    when(() => accountRepo.beginTeardown()).thenReturn(null);
    when(() => accountRepo.endTeardown()).thenReturn(null);
    when(() => accountRepo.notifySetupChanged()).thenReturn(null);
    when(() => accountRepo.revokeOnDisk()).thenAnswer((_) async {});
    when(() => configRepo.delete()).thenAnswer((_) async {});
    usecase = RevokeSpWalletUsecase(
      repository: accountRepo,
      configRepository: configRepo,
    );
  });

  group('RevokeSpWalletUsecase', () {
    test('revokes on disk, drops the config, then notifies, all bracketed by '
        'begin/endTeardown', () async {
      await usecase.execute();

      verifyInOrder([
        () => accountRepo.beginTeardown(),
        () => accountRepo.revokeOnDisk(),
        () => configRepo.delete(),
        () => accountRepo.notifySetupChanged(),
        () => accountRepo.endTeardown(),
      ]);
    });

    test('a config delete failure does not abort the revoke; it still notifies',
        () async {
      when(() => configRepo.delete()).thenThrow(Exception('config gone'));

      await usecase.execute();

      verify(() => accountRepo.notifySetupChanged()).called(1);
      verify(() => accountRepo.endTeardown()).called(1);
    });

    test('when revokeOnDisk fails, the config is NOT dropped, no final notify, '
        'and endTeardown still runs, error returned as Err', () async {
      when(() => accountRepo.revokeOnDisk()).thenThrow(Exception('delete boom'));

      final result = await usecase.execute();

      expect(result, isA<Err<void, SpFailure>>());
      verifyNever(() => configRepo.delete());
      verifyNever(() => accountRepo.notifySetupChanged());
      verify(() => accountRepo.endTeardown()).called(1);
    });
  });
}
