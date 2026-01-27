import 'package:bb_mobile/core/recoverbull/data/datasources/file_storage_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/google_drive_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/allow_permission_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/decrypt_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_permission_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_recoverbull_url_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_vault_key_from_server_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/delete_drive_file_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/export_drive_file_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_all_drive_file_metadata_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_vault_from_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/save_to_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/save_file_to_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/store_recoverbull_url_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/store_vault_key_into_server_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/update_latest_encrypted_backup_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/tor/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/core/tor/domain/ports/tor_config_port.dart';
import 'package:bb_mobile/core/tor/infrastructure/services/tor_connectivity_service.dart';
import 'package:bb_mobile/core/tor/interface_adapters/adapters/tor_config_adapter.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:get_it/get_it.dart';

class RecoverbullLocator {
  static Future<void> registerDatasources(GetIt locator) async {
    locator.registerLazySingleton<GoogleDriveAppDatasource>(
      () => GoogleDriveAppDatasource(),
    );

    locator.registerLazySingleton<RecoverbullSettingsDatasource>(
      () => RecoverbullSettingsDatasource(sqlite: locator<SqliteDatabase>()),
    );

    locator.registerSingletonWithDependencies<RecoverBullRemoteDatasource>(
      () => RecoverBullRemoteDatasource(
        recoverbullSettingsDatasource: locator<RecoverbullSettingsDatasource>(),
        torDatasource: locator<TorDatasource>(),
      ),
      dependsOn: [TorDatasource],
    );

    locator.registerLazySingleton<FileStorageDatasource>(
      () => FileStorageDatasource(),
    );

    await locator.isReady<RecoverBullRemoteDatasource>();
  }

  static Future<void> registerRepositories(GetIt locator) async {
    locator.registerLazySingleton<GoogleDriveRepository>(
      () => GoogleDriveRepository(),
    );

    locator.registerLazySingleton<FileSystemRepository>(
      () => FileSystemRepository(),
    );

    locator.registerLazySingleton<TorConfigPort>(
      () => TorConfigAdapter(
        settingsRepository: locator<SettingsRepository>(),
        torConnectivityService: locator<TorConnectivityService>(),
      ),
    );

    locator.registerSingletonWithDependencies<RecoverBullRepository>(
      () => RecoverBullRepository(
        remoteDatasource: locator<RecoverBullRemoteDatasource>(),
        recoverbullSettingsDatasource: locator<RecoverbullSettingsDatasource>(),
        torConfigPort: locator<TorConfigPort>(),
      ),
      dependsOn: [RecoverBullRemoteDatasource],
    );

    await locator.isReady<RecoverBullRepository>();
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<CreateEncryptedVaultUsecase>(
      () => CreateEncryptedVaultUsecase(
        seedRepository: locator<SeedRepository>(),
        walletRepository: locator<WalletRepository>(),
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );
    locator.registerFactory<ConnectToGoogleDriveUsecase>(
      () => ConnectToGoogleDriveUsecase(
        driveRepository: locator<GoogleDriveRepository>(),
      ),
    );

    locator.registerFactory<FetchLatestGoogleDriveVaultUsecase>(
      () => FetchLatestGoogleDriveVaultUsecase(
        driveRepository: locator<GoogleDriveRepository>(),
      ),
    );

    locator.registerFactory<SaveFileToSystemUsecase>(
      () => SaveFileToSystemUsecase(),
    );

    locator.registerFactory<FetchAllDriveFileMetadataUsecase>(
      () => FetchAllDriveFileMetadataUsecase(
        driveRepository: locator<GoogleDriveRepository>(),
      ),
    );

    locator.registerFactory<FetchVaultFromDriveUsecase>(
      () => FetchVaultFromDriveUsecase(
        driveRepository: locator<GoogleDriveRepository>(),
      ),
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

    locator.registerFactory<StoreVaultKeyIntoServerUsecase>(
      () => StoreVaultKeyIntoServerUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );

    locator.registerFactory<CheckServerConnectionUsecase>(
      () => CheckServerConnectionUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );

    locator.registerFactory<FetchVaultKeyFromServerUsecase>(
      () => FetchVaultKeyFromServerUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );
    locator.registerFactory<SaveVaultToGoogleDriveUsecase>(
      () => SaveVaultToGoogleDriveUsecase(
        driveRepository: locator<GoogleDriveRepository>(),
      ),
    );
    locator.registerFactory<DeleteDriveFileUsecase>(
      () => DeleteDriveFileUsecase(
        driveRepository: locator<GoogleDriveRepository>(),
      ),
    );
    locator.registerFactory<ExportDriveFileUsecase>(
      () => ExportDriveFileUsecase(
        driveRepository: locator<GoogleDriveRepository>(),
      ),
    );
    locator.registerFactory<UpdateLatestEncryptedVaultTestUsecase>(
      () => UpdateLatestEncryptedVaultTestUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<FetchRecoverbullUrlUsecase>(
      () => FetchRecoverbullUrlUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );
    locator.registerFactory<StoreRecoverbullUrlUsecase>(
      () => StoreRecoverbullUrlUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );
    locator.registerFactory<AllowPermissionUsecase>(
      () => AllowPermissionUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );
    locator.registerFactory<FetchPermissionUsecase>(
      () => FetchPermissionUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );
  }
}
