import 'package:bb_mobile/core/recoverbull/domain/usecases/complete_cloud_backup_verification_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_preview_wallets_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_backup_from_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_all_google_drive_backups_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_google_drive_backup_content_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:bb_mobile/locator.dart';

class OnboardingLocator {
  static void setup() {
    // Blocs
    locator.registerFactory<OnboardingBloc>(
      () => OnboardingBloc(
        createDefaultWalletsUsecase: locator<CreateDefaultWalletsUsecase>(),
        createPreviewWalletsUsecase: locator<CreatePreviewWalletsUsecase>(),
        fetchBackupFromFileSystemUsecase:
            locator<FetchBackupFromFileSystemUsecase>(),
        selectFileFromPathUsecase: locator<SelectFileFromPathUsecase>(),
        connectToGoogleDriveUsecase: locator<ConnectToGoogleDriveUsecase>(),
        restoreEncryptedVaultFromBackupKeyUsecase:
            locator<RestoreEncryptedVaultFromBackupKeyUsecase>(),
        fetchAllGoogleDriveBackupsUsecase:
            locator<FetchAllGoogleDriveBackupsUsecase>(),
        fetchGoogleDriveBackupContentUsecase:
            locator<FetchGoogleDriveBackupContentUsecase>(),
        completePhysicalBackupVerificationUsecase:
            locator<CompletePhysicalBackupVerificationUsecase>(),
        completeCloudBackupVerificationUsecase:
            locator<CompleteCloudBackupVerificationUsecase>(),
      ),
    );
    locator.registerFactory<FetchAllGoogleDriveBackupsUsecase>(
      () => FetchAllGoogleDriveBackupsUsecase(locator()),
    );
  }
}
