import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/_core/domain/usecases/fetch_backup_from_file_system_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/find_mnemonic_words_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/onboarding/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/recover_wallet/domain/usecases/recover_wallet_use_case.dart';
import 'package:bb_mobile/recover_wallet/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:bb_mobile/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';

class RecoverWalletLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<RecoverOrCreateWalletUsecase>(
      () => RecoverOrCreateWalletUsecase(
        settingsRepository: locator<SettingsRepository>(),
        mnemonicSeedFactory: locator<MnemonicSeedFactory>(),
        walletManager: locator<WalletManagerService>(),
      ),
    );

    // Blocs
    locator.registerFactory<RecoverWalletBloc>(
      () => RecoverWalletBloc(
        findMnemonicWordsUsecase: locator<FindMnemonicWordsUsecase>(),
        createDefaultWalletsUsecase: locator<CreateDefaultWalletsUsecase>(),
        selectFilePathUsecase: locator<SelectFileFromPathUsecase>(),
        connectToGoogleDriveUsecase: locator<ConnectToGoogleDriveUsecase>(),
        recoverOrCreateWalletUsecase: locator<RecoverOrCreateWalletUsecase>(),
        fetchLatestGoogleDriveBackupUsecase:
            locator<FetchLatestGoogleDriveBackupUsecase>(),
        fetchBackupFromFileSystemUsecase:
            locator<FetchBackupFromFileSystemUsecase>(),
        restoreEncryptedVaultFromBackupKeyUsecase:
            locator<RestoreEncryptedVaultFromBackupKeyUsecase>(),
      ),
    );
  }
}
