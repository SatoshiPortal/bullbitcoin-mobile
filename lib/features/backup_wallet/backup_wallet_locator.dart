import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/disconnect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/save_file_to_system_usecase.dart';
import 'package:bb_mobile/features/backup_wallet/domain/usecases/save_to_google_drive_usecase.dart';
import 'package:bb_mobile/features/backup_wallet/presentation/bloc/backup_wallet_bloc.dart';
import 'package:bb_mobile/locator.dart';

class BackupWalletLocator {
  static void setup() {
    // Use cases

    locator.registerFactory<SaveToGoogleDriveUsecase>(
      () => SaveToGoogleDriveUsecase(locator<GoogleDriveRepository>()),
    );
    locator.registerFactory<FetchLatestGoogleDriveVaultUsecase>(
      () => FetchLatestGoogleDriveVaultUsecase(),
    );
    // Blocs
    locator.registerFactory<BackupWalletBloc>(
      () => BackupWalletBloc(
        createEncryptedVaultUsecase: locator<CreateEncryptedVaultUsecase>(),
        fetchLatestBackupUsecase: locator<FetchLatestGoogleDriveVaultUsecase>(),
        connectToGoogleDriveUsecase: locator<ConnectToGoogleDriveUsecase>(),
        disconnectFromGoogleDriveUsecase:
            locator<DisconnectFromGoogleDriveUsecase>(),
        saveFileToSystemUsecase: locator<SaveFileToSystemUsecase>(),
        saveToGoogleDriveUsecase: locator<SaveToGoogleDriveUsecase>(),
      ),
    );
  }
}
