import 'package:bb_mobile/_core/domain/repositories/file_system_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/google_drive_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/_core/domain/usecases/get_default_wallet_use_case.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/store_backup_key_usecase.dart';
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
    locator.registerFactory<SaveBackupKeyToServerUsecase>(
      () => SaveBackupKeyToServerUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );

    // Blocs
    locator.registerFactory<BackupWalletBloc>(
      () => BackupWalletBloc(
        createEncryptedVaultUsecase: locator<CreateEncryptedVaultUsecase>(),
        getDefaultWalletUsecase: locator<GetDefaultWalletUsecase>(),
      ),
    );
  }
}
