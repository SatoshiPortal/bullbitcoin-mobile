import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/pick_file_content_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/onboarding/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_backup_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_encrypted_vault_verification_usecase.dart.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/locator.dart';

class TestWalletBackupLocator {
  static void setup() {
    // Usecases
    locator.registerLazySingleton<CompleteEncryptedVaultVerificationUsecase>(
      () => CompleteEncryptedVaultVerificationUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );

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
        completeEncryptedVaultVerificationUsecase:
            locator<CompleteEncryptedVaultVerificationUsecase>(),
        completePhysicalBackupVerificationUsecase:
            locator<CompletePhysicalBackupVerificationUsecase>(),
        selectFileFromPathUsecase: locator<PickFileContentUsecase>(),
        connectToGoogleDriveUsecase: locator<ConnectToGoogleDriveUsecase>(),
        restoreEncryptedVaultFromBackupKeyUsecase:
            locator<RestoreEncryptedVaultFromVaultKeyUsecase>(),
        fetchLatestGoogleDriveBackupUsecase:
            locator<FetchLatestGoogleDriveVaultUsecase>(),
      ),
    );
  }
}
