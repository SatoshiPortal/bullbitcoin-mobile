import 'package:bb_mobile/_core/domain/repositories/file_system_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/google_drive_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/_core/domain/usecases/get_default_wallet_use_case.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/disconnect_google_drive_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/fetch_latest_backup_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/pick_file_use_case.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/create_encrypted_backup_usecase.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/save_key_to_server_usecase.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/save_to_file_system_usecase.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/save_to_google_drive_usecase.dart';
import 'package:bb_mobile/backup_wallet/presentation/bloc/backup_wallet_bloc.dart';
import 'package:bb_mobile/locator.dart';

class BackupWalletLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<CreateEncryptedBackupUsecase>(
      () => CreateEncryptedBackupUsecase(
        seedRepository: locator<SeedRepository>(),
        walletMetadataRepository: locator<WalletMetadataRepository>(),
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );
    locator.registerFactory<SaveToFileSystemUseCase>(
      () => SaveToFileSystemUseCase(
        locator<FileSystemRepository>(),
      ),
    );
    locator.registerFactory<SaveToGoogleDriveUseCase>(
      () => SaveToGoogleDriveUseCase(
        locator<GoogleDriveRepository>(),
      ),
    );
    locator.registerFactory<SaveBackupKeyToServerUsecase>(
      () => SaveBackupKeyToServerUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );

    // Blocs
    locator.registerFactory<BackupWalletBloc>(
      () => BackupWalletBloc(
        createEncryptedBackupUsecase: locator<CreateEncryptedBackupUsecase>(),
        selectFilePathUseCase: locator<SelectFilePathUseCase>(),
        saveToFileSystemUseCase: locator<SaveToFileSystemUseCase>(),
        getDefaultWalletUseCase: locator<GetDefaultWalletUseCase>(),
        saveBackupKeyToServerUsecase: locator<SaveBackupKeyToServerUsecase>(),
        fetchLatestBackupUsecase: locator<FetchLatestBackupUsecase>(),
        connectToGoogleDriveUseCase: locator<ConnectToGoogleDriveUseCase>(),
        disconnectFromGoogleDriveUseCase:
            locator<DisconnectFromGoogleDriveUseCase>(),
        saveToGoogleDriveUseCase: locator<SaveToGoogleDriveUseCase>(),
      ),
    );
  }
}
