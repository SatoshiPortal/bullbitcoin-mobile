import 'package:bb_mobile/features/backup_settings/data/backup_reminder_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_reminder_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:get_it/get_it.dart';

class BackupSettingsLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<BackupReminderRepository>(
      BackupReminderRepositoryImpl.new,
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
    // Blocs
    locator.registerFactory<BackupSettingsCubit>(
      () => BackupSettingsCubit(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }
}
