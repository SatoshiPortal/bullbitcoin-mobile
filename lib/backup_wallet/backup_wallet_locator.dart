import 'package:bb_mobile/_core/domain/repositories/file_system_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/google_drive_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/disconnect_google_drive_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/select_folder_path_usecase.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/save_to_file_system_usecase.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/save_to_google_drive_usecase.dart';
import 'package:bb_mobile/backup_wallet/presentation/bloc/backup_wallet_bloc.dart';
import 'package:bb_mobile/locator.dart';

class BackupWalletLocator {
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
    locator.registerFactory<FetchLatestGoogleDriveBackupUsecase>(
      () => FetchLatestGoogleDriveBackupUsecase(
        locator<GoogleDriveRepository>(),
      ),
    );
    // Blocs
    locator.registerFactory<BackupWalletBloc>(
      () => BackupWalletBloc(
        createEncryptedBackupUsecase: locator<CreateEncryptedVaultUsecase>(),
        fetchLatestBackupUsecase:
            locator<FetchLatestGoogleDriveBackupUsecase>(),
        connectToGoogleDriveUsecase: locator<ConnectToGoogleDriveUsecase>(),
        disconnectFromGoogleDriveUsecase:
            locator<DisconnectFromGoogleDriveUsecase>(),
        selectFolderPathUsecase: locator<SelectFolderPathUsecase>(),
        saveToFileSystemUsecase: locator<SaveToFileSystemUsecase>(),
        saveToGoogleDriveUsecase: locator<SaveToGoogleDriveUsecase>(),
      ),
    );
  }
}
