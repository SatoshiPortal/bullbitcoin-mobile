import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/backup_settings/data/backup_reminder_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/backup_reminder_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/manage_backup_reminders_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_reminder_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_words_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/wallet_recovery_settings_cubit.dart';
import 'package:bb_mobile/features/backup_settings/data/file_picker_wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/backup_wallet_now_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/delete_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/export_private_descriptor_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/export_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/fetch_remote_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_recovery_status_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/import_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/publish_vault_descriptor_backups_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vault_from_bip138_file_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_from_backup_words_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_from_cosigner_key_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/retry_wallet_backup_recovery_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/reveal_backup_words_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/set_wallet_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/set_wallet_backup_server_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/watch_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/backup_settings/data/vault_backup_test_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/vault_backup_test_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/verify_vault_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_backup_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_destinations_cubit.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_cubit.dart';
import 'package:bb_mobile/features/wizard/public/wizard_facade.dart';
import 'package:bb_mobile/features/backup_settings/presentation/data_backup_setup_banner_cubit.dart';
import 'package:bb_mobile/features/backup_settings/data/vault_recovery_kit_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/vault_recovery_kit_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/create_vault_recovery_kit_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/vault_recovery_kit_cubit.dart';

class BackupSettingsLocator {
  static void setup(GetIt locator) {
    final walletBackup = locator<WalletBackupFacade>();
    final files = FilePickerWalletBackupFileRepository();
    locator.registerLazySingleton<VaultRecoveryKitRepository>(
      VaultRecoveryKitRepositoryImpl.new,
    );
    locator.registerFactory<CreateVaultRecoveryKitUsecase>(
      () => CreateVaultRecoveryKitUsecase(locator()),
    );
    locator.registerFactory<VaultRecoveryKitCubit>(
      () => VaultRecoveryKitCubit(locator()),
    );
    locator.registerLazySingleton<VaultBackupTestRepository>(
      VaultBackupTestRepositoryImpl.new,
    );
    locator.registerFactory<VerifyVaultDescriptorBackupUsecase>(
      () => VerifyVaultDescriptorBackupUsecase(
        locator<BullVaultFacade>(),
        walletBackup,
        locator<BitcoinDescriptorPort>(),
        locator<VaultBackupTestRepository>(),
        files,
      ),
    );
    locator.registerFactory<PublishVaultDescriptorBackupsUsecase>(
      () => PublishVaultDescriptorBackupsUsecase(
        locator<BullVaultFacade>(),
        walletBackup,
      ),
    );
    locator.registerFactory<RecoverVaultFromBip138FileUsecase>(
      () => RecoverVaultFromBip138FileUsecase(
        locator<BullVaultFacade>(),
        locator<BitcoinDescriptorPort>(),
        files,
      ),
    );
    locator.registerFactory<RecoverVaultsFromCosignerKeyUsecase>(
      () => RecoverVaultsFromCosignerKeyUsecase(walletBackup, locator()),
    );
    locator.registerFactory<RecoverVaultsFromBackupWordsUsecase>(
      () => RecoverVaultsFromBackupWordsUsecase(
        walletBackup,
        locator<BullVaultFacade>(),
        locator<NostrIdentityFacade>(),
        locator(),
      ),
    );
    locator.registerFactory<VaultRecoveryCubit>(
      () => VaultRecoveryCubit(locator(), locator(), locator()),
    );
    locator.registerFactory<BackupWordsCubit>(
      () => BackupWordsCubit(
        RevealBackupWordsUsecase(locator<NostrIdentityFacade>()),
      ),
    );
    locator.registerFactory<ExportPrivateDescriptorFileUsecase>(
      () =>
          ExportPrivateDescriptorFileUsecase(locator<BullVaultFacade>(), files),
    );
    locator.registerFactoryParam<VaultDestinationsCubit, String, void>(
      (walletId, _) => VaultDestinationsCubit(
        locator(),
        WatchWalletBackupUsecase(walletBackup),
        walletId,
      ),
    );
    locator.registerFactoryParam<VaultBackupCubit, String, void>(
      (walletId, _) => VaultBackupCubit(locator(), locator(), walletId),
    );
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
    locator.registerFactory<DataBackupSetupBannerCubit>(
      () => DataBackupSetupBannerCubit(
        hasPendingChoices: locator<WizardFacade>().hasPendingChoices,
        applyPendingChoices: locator<WizardFacade>().applyPendingChoices,
        watchState: walletBackup.watchState,
      ),
    );
    locator.registerFactory<BackupSettingsCubit>(
      () => BackupSettingsCubit(
        watchWalletBackup: WatchWalletBackupUsecase(walletBackup),
        setWalletBackupEnabled: SetWalletBackupEnabledUsecase(walletBackup),
        setWalletBackupServer: SetWalletBackupServerUsecase(walletBackup),
        backupWalletNow: BackupWalletNowUsecase(walletBackup),
        deleteWalletBackup: DeleteWalletBackupUsecase(walletBackup),
        getContents: GetWalletBackupContentsUsecase(walletBackup),
        fetchRemoteContents: FetchRemoteWalletBackupContentsUsecase(
          walletBackup,
        ),
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
