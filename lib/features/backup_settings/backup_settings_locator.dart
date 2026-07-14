import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/data/shared_preferences_backup_health_reminder_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_health_reminder_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/acknowledge_backup_health_reminder_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/evaluate_backup_health_reminder_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/start_backup_health_action_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_health_reminder_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:get_it/get_it.dart';

class BackupSettingsLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<BackupHealthReminderRepository>(
      SharedPreferencesBackupHealthReminderRepository.new,
    );

    locator.registerFactory<EvaluateBackupHealthReminderUsecase>(
      () => EvaluateBackupHealthReminderUsecase(
        locator<BackupHealthReminderRepository>(),
      ),
    );
    locator.registerFactory<AcknowledgeBackupHealthReminderUsecase>(
      () => AcknowledgeBackupHealthReminderUsecase(
        locator<BackupHealthReminderRepository>(),
      ),
    );
    locator.registerFactory<StartBackupHealthActionUsecase>(
      () => StartBackupHealthActionUsecase(
        locator<BackupHealthReminderRepository>(),
      ),
    );

    // Blocs
    locator.registerFactory<BackupHealthReminderCubit>(
      () => BackupHealthReminderCubit(
        locator<EvaluateBackupHealthReminderUsecase>(),
        locator<AcknowledgeBackupHealthReminderUsecase>(),
        locator<StartBackupHealthActionUsecase>(),
      ),
    );
    locator.registerFactory<BackupSettingsCubit>(
      () => BackupSettingsCubit(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }
}
