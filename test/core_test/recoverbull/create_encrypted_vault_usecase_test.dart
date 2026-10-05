import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecoverBullRepository extends Mock
    implements RecoverBullRepository {}

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

/// The backup path. A wallet read that fails must not be reported as "no
/// default Bitcoin wallet found": an onboarded install always has a default
/// bitcoin and a default liquid wallet, so that message would tell a user with
/// a perfectly good wallet that there is nothing to back up (#1895).
void main() {
  late _MockRecoverBullRepository recoverBullRepository;
  late _MockSeedRepository seedRepository;
  late _MockWalletRepository walletRepository;
  late CreateEncryptedVaultUsecase usecase;

  setUp(() {
    recoverBullRepository = _MockRecoverBullRepository();
    seedRepository = _MockSeedRepository();
    walletRepository = _MockWalletRepository();
    usecase = CreateEncryptedVaultUsecase(
      recoverBullRepository: recoverBullRepository,
      seedRepository: seedRepository,
      walletRepository: walletRepository,
    );
  });

  void stubWallets(Result<List<Wallet>, WalletFailure> result) {
    when(
      () => walletRepository.getWallets(
        onlyBitcoin: any(named: 'onlyBitcoin'),
        onlyDefaults: any(named: 'onlyDefaults'),
        onlyLiquid: any(named: 'onlyLiquid'),
        environment: any(named: 'environment'),
        sync: any(named: 'sync'),
      ),
    ).thenAnswer((_) async => result);
  }

  test(
    'an unreadable wallet store is not "no default Bitcoin wallet"',
    () async {
      stubWallets(
        const Err(
          WalletStorageFailure('SqliteException(11): disk image is malformed'),
        ),
      );

      final result = await usecase.execute();

      final failure = (result as Err).failure as RecoverBullCoreFailure;
      expect(failure, isA<RecoverBullUnexpectedCoreFailure>());
      // This family has a single unexpected variant, so the TYPE cannot tell
      // the two causes apart — the message is the only signal, and it must not
      // claim the user has no wallet.
      expect(failure.logMessage, isNot(contains('No default Bitcoin wallet')));
      // The wallet layer's raw reason stays in the log.
      expect(failure.logMessage, isNot(contains('disk image is malformed')));
      // Nothing was backed up, so the vault was never touched.
      verifyZeroInteractions(recoverBullRepository);
      verifyZeroInteractions(seedRepository);
    },
  );

  test(
    'an genuinely empty default set still reports no default wallet',
    () async {
      stubWallets(const Ok([]));

      final result = await usecase.execute();

      final failure = (result as Err).failure as RecoverBullCoreFailure;
      expect(failure, isA<RecoverBullUnexpectedCoreFailure>());
      expect(failure.logMessage, contains('No default Bitcoin wallet'));
      verifyZeroInteractions(recoverBullRepository);
    },
  );
}
