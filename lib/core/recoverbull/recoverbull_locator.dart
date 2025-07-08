import 'package:bb_mobile/core/recoverbull/data/datasources/file_storage_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/google_drive_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_backup_key_from_default_seed_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_backup_from_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/disconnect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/save_to_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_folder_path_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/tor/data/repository/tor_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:file_picker/file_picker.dart';

class RecoverbullLocator {
  static Future<void> registerDatasources() async {
    // - Google Drive Datasource
    locator.registerLazySingleton<GoogleDriveAppDatasource>(
      () => GoogleDriveAppDatasource(),
    );

    // - RecoverBullRemoteDatasource
    locator.registerLazySingleton<RecoverBullRemoteDatasource>(
      () => RecoverBullRemoteDatasource(
        address: Uri.parse(ApiServiceConstants.bullBitcoinKeyServerApiUrlPath),
      ),
    );

    // - FileStorageDataSource
    locator.registerLazySingleton<FileStorageDatasource>(
      () => FileStorageDatasource(filePicker: FilePicker.platform),
    );
  }

  static Future<void> registerRepositories() async {
    locator.registerLazySingleton<GoogleDriveRepository>(
      () => GoogleDriveRepository(locator<GoogleDriveAppDatasource>()),
    );

    locator.registerLazySingleton<FileSystemRepository>(
      () => FileSystemRepository(locator<FileStorageDatasource>()),
    );

    locator.registerSingletonWithDependencies<RecoverBullRepository>(
      () => RecoverBullRepository(
        remoteDatasource: locator<RecoverBullRemoteDatasource>(),
        torRepository: locator<TorRepository>(),
      ),
      dependsOn: [TorRepository],
    );
  }

  static void registerUsecases() {
    locator.registerFactory<CreateEncryptedVaultUsecase>(
      () => CreateEncryptedVaultUsecase(
        seedRepository: locator<SeedRepository>(),
        walletRepository: locator<WalletRepository>(),
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );
    locator.registerFactory<ConnectToGoogleDriveUsecase>(
      () => ConnectToGoogleDriveUsecase(locator<GoogleDriveRepository>()),
    );

    locator.registerFactory<DisconnectFromGoogleDriveUsecase>(
      () => DisconnectFromGoogleDriveUsecase(locator<GoogleDriveRepository>()),
    );

    locator.registerFactory<FetchLatestGoogleDriveBackupUsecase>(
      () =>
          FetchLatestGoogleDriveBackupUsecase(locator<GoogleDriveRepository>()),
    );

    locator.registerFactory<CreateBackupKeyFromDefaultSeedUsecase>(
      () => CreateBackupKeyFromDefaultSeedUsecase(
        seedRepository: locator<SeedRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );

    locator.registerFactory<FetchBackupFromFileSystemUsecase>(
      () => FetchBackupFromFileSystemUsecase(),
    );

    locator.registerFactory<RestoreEncryptedVaultFromBackupKeyUsecase>(
      () => RestoreEncryptedVaultFromBackupKeyUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
        walletRepository: locator<WalletRepository>(),
        createDefaultWalletsUsecase: locator<CreateDefaultWalletsUsecase>(),
      ),
    );

    locator.registerFactory<SelectFileFromPathUsecase>(
      () => SelectFileFromPathUsecase(locator<FileSystemRepository>()),
    );

    locator.registerFactory<SelectFolderPathUsecase>(
      () => SelectFolderPathUsecase(locator<FileSystemRepository>()),
    );
    locator.registerFactory<SaveToFileSystemUsecase>(
      () => SaveToFileSystemUsecase(locator<FileSystemRepository>()),
    );
    locator.registerLazySingleton<CompletePhysicalBackupVerificationUsecase>(
      () => CompletePhysicalBackupVerificationUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
  }
}
