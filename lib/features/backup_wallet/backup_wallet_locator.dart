import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/disconnect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_folder_path_usecase.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/backup_wallet/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/features/backup_wallet/domain/usecases/save_to_file_system_usecase.dart';
import 'package:bb_mobile/features/backup_wallet/domain/usecases/save_to_google_drive_usecase.dart';
import 'package:bb_mobile/features/backup_wallet/presentation/bloc/backup_wallet_bloc.dart';
import 'package:bb_mobile/locator.dart';

class BackupWalletLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<CreateEncryptedVaultUsecase>(
      () => CreateEncryptedVaultUsecase(
        seedRepository: locator<SeedRepository>(),
        walletRepository: locator<WalletRepository>(),
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );
    locator.registerFactory<SaveToFileSystemUsecase>(
      () => SaveToFileSystemUsecase(locator<FileSystemRepository>()),
    );
    locator.registerFactory<SaveToGoogleDriveUsecase>(
      () => SaveToGoogleDriveUsecase(locator<GoogleDriveRepository>()),
    );

    // Blocs
    locator.registerFactory<BackupWalletBloc>(
      () => BackupWalletBloc(
        createEncryptedBackupUsecase: locator<CreateEncryptedVaultUsecase>(),

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
