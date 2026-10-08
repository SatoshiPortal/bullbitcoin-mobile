import 'package:bb_mobile/core/recoverbull/recoverbull_locator.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart'
    as settings_contract;
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

/// The backup path. A wallet read that fails must not be reported as "no
/// default Bitcoin wallet found": an onboarded install always has a default
/// bitcoin and a default liquid wallet, so that message would tell a user with
/// a perfectly good wallet that there is nothing to back up (#1895).
void main() {
  late _MockWalletRepository walletRepository;
  late CreateEncryptedVaultUsecase usecase;

  setUp(() {
    FakeSecureStoragePlatform().install();
    walletRepository = _MockWalletRepository();
    final settings = _MockSettingsRepository();
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    usecase = CreateEncryptedVaultUsecase(
      secrets: Secrets(scratchDirectory: () async => '/tmp'),
      walletRepository: walletRepository,
      settingsRepository: settings,
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

  test('vault export selects the active environment', () async {
    final locator = GetIt.asNewInstance();
    final settings = _MockSettingsRepository();
    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    locator.registerSingleton<Secrets>(
      Secrets(scratchDirectory: () async => '/tmp'),
    );
    locator.registerSingleton<WalletRepository>(walletRepository);
    locator.registerSingleton<settings_contract.SettingsRepository>(settings);
    RecoverbullLocator.registerUsecases(locator);
    stubWallets(const Ok([]));

    await locator<CreateEncryptedVaultUsecase>().execute();

    final environment = verify(
      () => walletRepository.getWallets(
        onlyBitcoin: true,
        onlyDefaults: true,
        environment: captureAny(named: 'environment'),
      ),
    ).captured.single;
    expect(environment, Environment.testnet);
    await locator.reset();
  });

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
      // Nothing was backed up, so no backup time was recorded.
      verifyNever(
        () => walletRepository.updateEncryptedBackupTime(
          time: any(named: 'time'),
          walletId: any(named: 'walletId'),
        ),
      );
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
    },
  );
}
