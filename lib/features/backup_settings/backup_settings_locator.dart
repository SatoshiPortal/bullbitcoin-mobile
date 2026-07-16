import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/backup_wallet_metadata_now_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/delete_remote_wallet_metadata_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/load_backup_settings_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/set_wallet_metadata_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/public/wallet_metadata_backup_facade.dart';
import 'package:get_it/get_it.dart';

class BackupSettingsLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<LoadBackupSettingsUsecase>(
      () => LoadBackupSettingsUsecase(
        locator<GetWalletsUsecase>(),
        locator<SettingsRepository>(),
        locator<WalletMetadataBackupFacade>(),
      ),
    );
    locator.registerFactory<SetWalletMetadataBackupEnabledUsecase>(
      () => SetWalletMetadataBackupEnabledUsecase(
        locator<WalletMetadataBackupFacade>(),
      ),
    );
    locator.registerFactory<BackupWalletMetadataNowUsecase>(
      () =>
          BackupWalletMetadataNowUsecase(locator<WalletMetadataBackupFacade>()),
    );
    locator.registerFactory<DeleteRemoteWalletMetadataBackupUsecase>(
      () => DeleteRemoteWalletMetadataBackupUsecase(
        locator<WalletMetadataBackupFacade>(),
      ),
    );
    locator.registerFactory<BackupSettingsCubit>(
      () => BackupSettingsCubit(
        loadSettings: locator<LoadBackupSettingsUsecase>(),
        setMetadataBackupEnabled:
            locator<SetWalletMetadataBackupEnabledUsecase>(),
        backupMetadataNow: locator<BackupWalletMetadataNowUsecase>(),
        deleteRemoteMetadata:
            locator<DeleteRemoteWalletMetadataBackupUsecase>(),
      ),
    );
  }
}
