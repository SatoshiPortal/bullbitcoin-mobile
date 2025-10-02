import 'package:bb_mobile/core/recoverbull/data/datasources/file_storage_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/google_drive_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_vault_key_from_default_seed_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/decrypt_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/disconnect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_all_drive_file_metadata_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_vault_from_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/pick_file_content_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/save_file_to_system_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/tor/data/repository/tor_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/locator.dart';

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
      () => FileStorageDatasource(),
    );
  }

  static Future<void> registerRepositories() async {
    locator.registerLazySingleton<GoogleDriveRepository>(
      () => GoogleDriveRepository(locator<GoogleDriveAppDatasource>()),
    );

    locator.registerLazySingleton<FileSystemRepository>(
      () => FileSystemRepository(),
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

    locator.registerFactory<FetchLatestGoogleDriveVaultUsecase>(
      () =>
          FetchLatestGoogleDriveVaultUsecase(locator<GoogleDriveRepository>()),
    );

    locator.registerFactory<CreateVaultKeyFromDefaultSeedUsecase>(
      () => CreateVaultKeyFromDefaultSeedUsecase(
        seedRepository: locator<SeedRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );

    locator.registerFactory<RestoreEncryptedVaultFromVaultKeyUsecase>(
      () => RestoreEncryptedVaultFromVaultKeyUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
        walletRepository: locator<WalletRepository>(),
        createDefaultWalletsUsecase: locator<CreateDefaultWalletsUsecase>(),
      ),
    );

    locator.registerFactory<PickFileContentUsecase>(
      () => PickFileContentUsecase(),
    );
    locator.registerFactory<SaveFileToSystemUsecase>(
      () => SaveFileToSystemUsecase(),
    );
    locator.registerFactory<FetchAllDriveFileMetadataUsecase>(
      () => FetchAllDriveFileMetadataUsecase(locator<GoogleDriveRepository>()),
    );

    locator.registerFactory<FetchVaultFromDriveUsecase>(
      () => FetchVaultFromDriveUsecase(locator<GoogleDriveRepository>()),
    );

    locator.registerFactory<DecryptVaultUsecase>(
      () => DecryptVaultUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );
    locator.registerFactory<RestoreVaultUsecase>(
      () => RestoreVaultUsecase(
        walletRepository: locator<WalletRepository>(),
        createDefaultWalletsUsecase: locator<CreateDefaultWalletsUsecase>(),
      ),
    );
  }
}
