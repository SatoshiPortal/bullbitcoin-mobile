import 'package:bb_mobile/features/bullvault/presentation/bullvault_recovery_notice_cubit.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/pick_bullvault_recovery_file_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_records_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/import_bullvault_cosigner_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_cosigner_cubit.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/decode_bullvault_recovery_package_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/get_bitcoin_chain_tip_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_menu_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/inspect_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_settings_cubit.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/ensure_canonical_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bip48_account_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_ownership_port.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/reserve_bip48_account_usecase.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_metadata_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_record_mapper.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_recovery_package_codec.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_descriptor_service.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/check_bullvault_mobile_backups_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/can_delete_bullvault_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/cancel_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/activate_initial_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/create_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/create_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/encode_bullvault_recovery_package_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/activate_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_details_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/get_bullvault_funded_predecessor_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/prepare_bullvault_time_reference_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/renew_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/resume_bullvault_onboarding_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/resume_bullvault_renewal_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_setup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/verify_bullvault_descriptor_backup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_registration_name_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/watch_bullvault_migration_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/watch_bullvault_details_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_onboarding_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_home_alert_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_renewal_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_restore_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_wallet_settings_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_experimental_disclaimer.dart';
import 'package:bb_mobile/features/recoverbull/public/recoverbull_facade.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

abstract final class BullVaultLocator {
  static void setup(GetIt locator) {
    locator<SettingsFacade>().registerEntry(
      SettingsEntryContribution(
        id: 'bullvault',
        section: SettingsEntrySection.wallet,
        title: (localization) => localization.bullVaultMenuTitle,
        icon: Icons.security,
        isSuperuser: true,
        open: openBullVaultMenu,
      ),
    );
    locator.registerLazySingleton<BullVaultMetadataDatasource>(
      () => BullVaultMetadataDatasource(locator()),
    );
    locator.registerLazySingleton<BullVaultDescriptorService>(
      () => BullVaultDescriptorService(locator<BitcoinDescriptorPort>()),
    );
    locator.registerLazySingleton<BullVaultRepository>(() {
      final codec = BullVaultRecoveryPackageCodec(
        locator<BullVaultDescriptorService>(),
      );
      return BullVaultRepositoryImpl(
        locator(),
        BullVaultRecordMapper(codec),
        codec,
      );
    });
    locator.registerLazySingleton<CreateBullVaultUsecase>(
      () => CreateBullVaultUsecase(
        locator(),
        locator<BitcoinDescriptorPort>(),
        locator<GetDefaultSeedUsecase>(),
        locator<GetSettingsUsecase>(),
        locator<DeleteWalletUsecase>(),
        locator<Bip48AccountRepository>(),
        locator<PrepareBullVaultTimeReferenceUsecase>(),
      ),
    );
    locator.registerFactory<EncodeBullVaultRecoveryPackageUsecase>(
      () => EncodeBullVaultRecoveryPackageUsecase(locator()),
    );
    locator.registerFactory<RestoreBullVaultUsecase>(
      () => RestoreBullVaultUsecase(
        locator(),
        locator<BitcoinDescriptorPort>(),
        locator<BullVaultDescriptorService>(),
        locator<GetSettingsUsecase>(),
        locator<GetDefaultSeedUsecase>(),
        locator<GetWalletUsecase>(),
        locator<ReserveBip48AccountUsecase>(),
        locator<DeleteWalletUsecase>(),
        locator<WalletSignerOwnershipPort>(),
        locator<GetAllSeedsUsecase>(),
        locator<EnsureCanonicalSeedUsecase>(),
      ),
    );
    locator.registerFactory<PrepareBullVaultTimeReferenceUsecase>(
      () => PrepareBullVaultTimeReferenceUsecase(
        locator<GetBitcoinChainTipUsecase>(),
      ),
    );
    locator.registerFactory<CheckBullVaultMobileBackupsUsecase>(
      () => CheckBullVaultMobileBackupsUsecase(
        locator<TestWalletBackupFacade>(),
        locator<RecoverBullFacade>(),
      ),
    );
    locator.registerFactory<CreateBullVaultOnboardingUsecase>(
      () => CreateBullVaultOnboardingUsecase(locator(), locator()),
    );
    locator.registerFactory<GetBullVaultDetailsUsecase>(
      () => GetBullVaultDetailsUsecase(
        locator(),
        locator<GetWalletUsecase>(),
        locator<GetAddressAtIndexUsecase>(),
      ),
    );
    locator.registerFactory<ResumeBullVaultRenewalUsecase>(
      () =>
          ResumeBullVaultRenewalUsecase(locator(), locator<GetWalletUsecase>()),
    );
    locator.registerLazySingleton<RenewBullVaultUsecase>(
      () => RenewBullVaultUsecase(
        locator(),
        locator<BitcoinDescriptorPort>(),
        locator<GetWalletUsecase>(),
        locator<DeleteWalletUsecase>(),
        locator<ResumeBullVaultRenewalUsecase>(),
        locator<PrepareBullVaultTimeReferenceUsecase>(),
      ),
    );
    locator.registerFactory<ActivateBullVaultRenewalUsecase>(
      () => ActivateBullVaultRenewalUsecase(
        locator(),
        locator<GetWalletUsecase>(),
      ),
    );
    locator.registerFactory<CancelBullVaultRenewalUsecase>(
      () =>
          CancelBullVaultRenewalUsecase(locator(), locator<GetWalletUsecase>()),
    );
    locator.registerFactory<ActivateInitialBullVaultUsecase>(
      () => ActivateInitialBullVaultUsecase(
        locator(),
        locator<GetWalletUsecase>(),
      ),
    );
    locator.registerFactory<ResumeBullVaultOnboardingUsecase>(
      () => ResumeBullVaultOnboardingUsecase(
        locator(),
        locator<GetWalletUsecase>(),
        locator<ReserveBip48AccountUsecase>(),
      ),
    );
    locator.registerFactory<LoadBullVaultOnboardingUsecase>(
      () => LoadBullVaultOnboardingUsecase(locator(), locator(), locator()),
    );
    locator.registerFactory<LoadBullVaultRenewalUsecase>(
      () => LoadBullVaultRenewalUsecase(locator(), locator(), locator()),
    );
    locator.registerLazySingleton<UpdateBullVaultSetupUsecase>(
      () => UpdateBullVaultSetupUsecase(locator(), locator(), locator()),
    );
    locator.registerLazySingleton<VerifyBullVaultDescriptorBackupUsecase>(
      () => VerifyBullVaultDescriptorBackupUsecase(locator(), locator()),
    );
    locator.registerFactory<UpdateBullVaultRegistrationNameUsecase>(
      () => UpdateBullVaultRegistrationNameUsecase(locator()),
    );
    locator.registerFactory<WatchBullVaultMigrationUsecase>(
      () => WatchBullVaultMigrationUsecase(locator<SendFacade>()),
    );
    locator.registerFactory<CanDeleteBullVaultWalletUsecase>(
      () => CanDeleteBullVaultWalletUsecase(locator()),
    );
    locator.registerFactory(() => GetBullVaultRecordsUsecase(locator()));
    locator.registerFactory(() => GetBullVaultRecordUsecase(locator()));
    locator.registerFactory(
      () => LoadBullVaultMenuUsecase(locator(), locator<GetSettingsUsecase>()),
    );
    locator.registerFactory(
      () => InspectBullVaultUsecase(
        locator(),
        locator<GetWalletUsecase>(),
        locator<SeedVerificationPort>(),
      ),
    );
    locator.registerLazySingleton<BullVaultRecoveryNoticeCubit>(
      BullVaultRecoveryNoticeCubit.new,
    );
    locator.registerFactory(() => BullVaultSettingsCubit(locator(), locator()));
    locator.registerFactory(() => WatchBullVaultRecordsUsecase(locator()));
    locator.registerFactory(
      () => DecodeBullVaultRecoveryPackageUsecase(locator()),
    );
    locator.registerFactory<BullVaultFacade>(
      () => BullVaultFacade(
        locator(),
        locator(),
        locator(),
        locator(),
        locator(),
        locator(),
        locator(),
        locator(),
        locator(),
      ),
    );
    locator.registerFactory(() => PickBullVaultRecoveryFileUsecase(locator()));
    locator.registerFactory<BullVaultOnboardingCubit>(
      () => BullVaultOnboardingCubit(
        locator(),
        locator(),
        locator(),
        locator(),
        locator(),
        locator(),
        locator(),
        locator<UpdateBullVaultRegistrationNameUsecase>(),
        pickRecoveryFile: locator(),
      ),
    );
    locator.registerFactory<BullVaultHomeAlertCubit>(
      () => BullVaultHomeAlertCubit(locator()),
    );
    locator.registerFactory<GetBullVaultFundedPredecessorUsecase>(
      () => GetBullVaultFundedPredecessorUsecase(locator(), locator()),
    );
    locator.registerFactory<BullVaultRestoreCubit>(
      () => BullVaultRestoreCubit(locator(), locator()),
    );
    locator.registerFactory(
      () => ImportBullVaultCosignerUsecase(
        locator(),
        locator<GetWalletUsecase>(),
        locator<EnsureCanonicalSeedUsecase>(),
        locator<WalletSignerOwnershipPort>(),
      ),
    );
    locator.registerFactoryParam<BullVaultCosignerCubit, String, void>(
      (walletId, _) => BullVaultCosignerCubit(locator(), walletId: walletId),
    );
    locator.registerFactory<BullVaultWalletSettingsCubit>(
      () => BullVaultWalletSettingsCubit(locator()),
    );
    locator.registerFactoryParam<BullVaultRenewalCubit, String, void>(
      (walletId, _) => BullVaultRenewalCubit(
        locator(),
        locator(),
        locator(),
        locator(),
        locator(),
        locator(),
        locator(),
        locator(),
        walletId: walletId,
        pickRecoveryFile: locator(),
        prepareTimeReferenceUsecase: locator(),
        watchDetailsUsecase: locator(),
      ),
    );
    locator.registerFactory<WatchBullVaultDetailsUsecase>(
      () => WatchBullVaultDetailsUsecase(locator(), locator()),
    );
  }
}
