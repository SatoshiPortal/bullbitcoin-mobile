import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_backup_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:get_it/get_it.dart';

class TestWalletBackupLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<LoadWalletsForNetworkUsecase>(
      () => LoadWalletsForNetworkUsecase(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerLazySingleton<GetMnemonicFromFingerprintUsecase>(
      () => GetMnemonicFromFingerprintUsecase(
        seedRepository: locator<SeedRepository>(),
      ),
    );
    locator.registerFactory<CheckBackupUsecase>(
      () => CheckBackupUsecase(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }
}
