import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_backup_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/locator.dart';

class TestWalletBackupLocator {
  static void setup() {
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
    // Blocs
    locator.registerFactory<TestWalletBackupBloc>(
      () => TestWalletBackupBloc(
        loadWalletsForNetworkUsecase: locator<LoadWalletsForNetworkUsecase>(),
        getMnemonicFromFingerprintUsecase:
            locator<GetMnemonicFromFingerprintUsecase>(),
        completePhysicalBackupVerificationUsecase:
            locator<CompletePhysicalBackupVerificationUsecase>(),
      ),
    );
  }
}
