import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_backup_from_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_encrypted_vault_verification_usecase.dart.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_default_mnemonic_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart';
import 'package:bb_mobile/locator.dart';

class TestWalletBackupLocator {
  static void setup() {
    // Usecases
    locator.registerLazySingleton<CompleteEncryptedVaultVerificationUsecase>(
      () => CompleteEncryptedVaultVerificationUsecase(
        walletMetadataRepository: locator<WalletMetadataRepository>(),
      ),
    );
    locator.registerLazySingleton<CompletePhysicalBackupVerificationUsecase>(
      () => CompletePhysicalBackupVerificationUsecase(
        walletMetadataRepository: locator<WalletMetadataRepository>(),
      ),
    );
    locator.registerLazySingleton<LoadDefaultMnemonicUsecase>(
      () => LoadDefaultMnemonicUsecase(
        walletMetadataRepository: locator<WalletMetadataRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );
    // Blocs
    locator.registerFactory<TestWalletBackupBloc>(
      () => TestWalletBackupBloc(
        fetchBackupFromFileSystemUsecase:
            locator<FetchBackupFromFileSystemUsecase>(),
        loadDefaultMnemonicUsecase: locator<LoadDefaultMnemonicUsecase>(),
        completeEncryptedVaultVerificationUsecase:
            locator<CompleteEncryptedVaultVerificationUsecase>(),
        completePhysicalBackupVerificationUsecase:
            locator<CompletePhysicalBackupVerificationUsecase>(),
        selectFileFromPathUsecase: locator<SelectFileFromPathUsecase>(),
        connectToGoogleDriveUsecase: locator<ConnectToGoogleDriveUsecase>(),
        restoreEncryptedVaultFromBackupKeyUsecase:
            locator<RestoreEncryptedVaultFromBackupKeyUsecase>(),
        fetchLatestGoogleDriveBackupUsecase:
            locator<FetchLatestGoogleDriveBackupUsecase>(),
      ),
    );
  }
}
