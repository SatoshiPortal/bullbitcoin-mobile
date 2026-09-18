import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/data/backup_reminder_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_reminder_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_recovery_status_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:get_it/get_it.dart';

class BackupSettingsLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<BackupReminderRepository>(
      BackupReminderRepositoryImpl.new,
    );
    locator.registerFactory(
      () => GetWalletRecoveryStatusUsecase(locator<GetWalletsUsecase>()),
    );
    locator.registerFactory(
      () => LoadBackupReminderPreferencesUsecase(
        locator<BackupReminderRepository>(),
      ),
    );
    locator.registerFactory(
      () => SelectBackupReminderUsecase(locator<BackupReminderRepository>()),
    );
    locator.registerFactory(
      () => DismissBackupReminderUsecase(locator<BackupReminderRepository>()),
    );
    locator.registerFactory(
      () => SetBackupRemindersDisabledUsecase(
        locator<BackupReminderRepository>(),
      ),
    );
    locator.registerFactory(
      () => BackupReminderCubit(
        loadPreferences: locator<LoadBackupReminderPreferencesUsecase>(),
        selectReminder: locator<SelectBackupReminderUsecase>(),
        dismissReminder: locator<DismissBackupReminderUsecase>(),
        setDisabled: locator<SetBackupRemindersDisabledUsecase>(),
      ),
    );
    locator.registerFactory<BackupSettingsCubit>(
      () => BackupSettingsCubit(
        getStatus: locator<GetWalletRecoveryStatusUsecase>(),
      ),
    );
  }
}
