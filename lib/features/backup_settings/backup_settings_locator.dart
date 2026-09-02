import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/backup_settings/data/backup_reminder_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_reminder_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/wallet_recovery_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/data/file_picker_wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/backup_wallet_now_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/delete_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/export_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_recovery_status_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/import_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/retry_wallet_backup_recovery_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/set_wallet_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/set_wallet_backup_server_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/watch_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:get_it/get_it.dart';

class BackupSettingsLocator {
  static void setup(GetIt locator) {
    final walletBackup = locator<WalletBackupFacade>();
    final files = FilePickerWalletBackupFileRepository();
    locator.registerLazySingleton<BackupReminderRepository>(
      BackupReminderRepositoryImpl.new,
    );
    locator.registerLazySingleton<BackupReminderCubit>(() {
      final repository = locator<BackupReminderRepository>();
      return BackupReminderCubit(
        LoadBackupReminderPreferencesUsecase(repository),
        SelectBackupReminderUsecase(repository),
        DismissBackupReminderUsecase(repository),
        SetBackupRemindersDismissedUsecase(repository),
      );
    });
    locator.registerFactory<BackupSettingsCubit>(
      () => BackupSettingsCubit(
        watchWalletBackup: WatchWalletBackupUsecase(walletBackup),
        setWalletBackupEnabled: SetWalletBackupEnabledUsecase(walletBackup),
        setWalletBackupServer: SetWalletBackupServerUsecase(walletBackup),
        backupWalletNow: BackupWalletNowUsecase(walletBackup),
        deleteWalletBackup: DeleteWalletBackupUsecase(walletBackup),
        getContents: GetWalletBackupContentsUsecase(walletBackup),
        retryRecovery: RetryWalletBackupRecoveryUsecase(walletBackup),
        exportFile: ExportWalletBackupFileUsecase(walletBackup, files),
        importFile: ImportWalletBackupFileUsecase(walletBackup, files),
        resumeFileImport: ResumeWalletBackupFileImportUsecase(walletBackup),
        recoverSelectedFile: RecoverSelectedWalletBackupFileUsecase(
          walletBackup,
        ),
      ),
    );
    locator.registerFactory<WalletRecoverySettingsCubit>(
      () => WalletRecoverySettingsCubit(
        GetWalletRecoveryStatusUsecase(
          () async => (await locator<SettingsRepository>().fetch()).environment,
          (environment) => locator<WalletRepository>()
              .getDefaultBitcoinWalletBackupStatuses(environment: environment),
        ),
      ),
    );
  }
}
