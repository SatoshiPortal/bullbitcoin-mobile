import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecoverBullRepository extends Mock
    implements RecoverBullRepository {}

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  test('looks up the default wallet in the active environment', () async {
    final recoverBullRepository = _MockRecoverBullRepository();
    final seedRepository = _MockSeedRepository();
    final settingsRepository = _MockSettingsRepository();
    final walletRepository = _MockWalletRepository();
    final usecase = CreateEncryptedVaultUsecase(
      recoverBullRepository: recoverBullRepository,
      seedRepository: seedRepository,
      settingsRepository: settingsRepository,
      walletRepository: walletRepository,
    );
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(
      () => walletRepository.getWallets(
        onlyBitcoin: true,
        onlyDefaults: true,
        environment: Environment.testnet,
      ),
    ).thenAnswer((_) async => []);

    final result = await usecase.execute();

    expect(result, isA<Err<dynamic, RecoverBullCoreFailure>>());
    verify(
      () => walletRepository.getWallets(
        onlyBitcoin: true,
        onlyDefaults: true,
        environment: Environment.testnet,
      ),
    ).called(1);
  });
}
