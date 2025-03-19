import 'package:bb_mobile/_core/domain/repositories/file_system_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/google_drive_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/_core/domain/usecases/get_default_wallet_use_case.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/disconnect_google_drive_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/fetch_latest_backup_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/recoverbull/domain/usecases/save_to_file_system_usecase.dart';
import 'package:bb_mobile/recoverbull/domain/usecases/save_to_google_drive_usecase.dart';
import 'package:bb_mobile/recoverbull/domain/usecases/store_backup_key_into_server_usecase.dart';
import 'package:bb_mobile/recoverbull/presentation/bloc/backup_wallet_bloc.dart';

class RecoverbullLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<CreateEncryptedVaultUsecase>(
      () => CreateEncryptedVaultUsecase(
        seedRepository: locator<SeedRepository>(),
        walletMetadataRepository: locator<WalletMetadataRepository>(),
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );
    locator.registerFactory<SaveToFileSystemUsecase>(
      () => SaveToFileSystemUsecase(
        locator<FileSystemRepository>(),
      ),
    );
    locator.registerFactory<SaveToGoogleDriveUsecase>(
      () => SaveToGoogleDriveUsecase(
        locator<GoogleDriveRepository>(),
      ),
    );
    locator.registerFactory<StoreBackupKeyIntoServerUsecase>(
      () => StoreBackupKeyIntoServerUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
        seedRepository: locator<SeedRepository>(),
        walletMetadataRepository: locator<WalletMetadataRepository>(),
      ),
    );

    // Blocs
    locator.registerFactory<BackupWalletBloc>(
      () => BackupWalletBloc(
        createEncryptedBackupUsecase: locator<CreateEncryptedVaultUsecase>(),
        storeBackupKeyIntoServerUsecase:
            locator<StoreBackupKeyIntoServerUsecase>(),
        fetchLatestBackupUsecase: locator<FetchLatestBackupUsecase>(),
        connectToGoogleDriveUsecase: locator<ConnectToGoogleDriveUsecase>(),
        disconnectFromGoogleDriveUsecase:
            locator<DisconnectFromGoogleDriveUsecase>(),
        selectFilePathUsecase: locator<SelectFilePathUsecase>(),
        saveToFileSystemUsecase: locator<SaveToFileSystemUsecase>(),
        saveToGoogleDriveUsecase: locator<SaveToGoogleDriveUsecase>(),
      ),
    );
  }
}
