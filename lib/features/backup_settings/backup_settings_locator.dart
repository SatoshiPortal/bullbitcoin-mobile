import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/reveal_data_recovery_words_usecase.dart';
import 'package:bb_mobile/features/backup_settings/data/backup_reminder_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_reminder_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_recovery_status_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_vault_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_backup_cubit.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_data_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/data_backup_recovery_cubit.dart';

class BackupSettingsLocator {
  static void setup(GetIt locator) {
    locator.registerFactory(() => RecoverVaultsUsecase(locator()));
    locator.registerFactory(() => VaultRecoveryCubit(locator()));
    locator.registerFactory(() => InspectDataBackupUsecase(locator()));
    locator.registerFactory(() => RecoverDataBackupUsecase(locator()));
    locator.registerFactoryParam<
      DataBackupRecoveryCubit,
      WalletBackupInspection?,
      void
    >(
      (inspection, _) =>
          DataBackupRecoveryCubit(locator(), locator(), inspection: inspection),
    );
    locator.registerFactory(
      () => LoadVaultBackupUsecase(locator(), locator(), locator()),
    );
    locator.registerFactory(
      () => CheckVaultServerBackupUsecase(locator(), locator()),
    );
    locator.registerFactory(
      () => VerifyVaultDescriptorBackupUsecase(locator()),
    );
    locator.registerFactory(
      () => VaultBackupCubit(locator(), locator(), locator()),
    );
    locator.registerFactory(
      () => RevealDataRecoveryWordsUsecase(
        locator<GetSettingsUsecase>(),
        locator<GetDefaultSeedUsecase>(),
      ),
    );
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
