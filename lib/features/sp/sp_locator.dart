import 'dart:async';

import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/sp/data/bwk_sp_account_repository.dart';
import 'package:bb_mobile/features/sp/data/bwk_sp_recipient_address_validator.dart';
import 'package:bb_mobile/features/sp/data/datasources/bwk_sp_account_datasource.dart';
import 'package:bb_mobile/features/sp/data/datasources/sp_account_files_datasource.dart';
import 'package:bb_mobile/features/sp/data/sp_account_files_repository.dart';
import 'package:bb_mobile/features/sp/data/key_value_sp_auto_scan_repository.dart';
import 'package:bb_mobile/features/sp/data/key_value_sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_auto_scan_repository.dart';
import 'package:bb_mobile/features/sp/data/bwk_sp_backend_probe.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_backend_probe_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_payments_port.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_scan_control_port.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_scan_port.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_recipient_address_validator_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';
import 'package:bb_mobile/features/sp/domain/usecases/check_sp_wallet_setup_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/clear_sp_scan_state_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/create_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/generate_taproot_address_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_auto_scan_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_balance_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_network_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/is_sp_scanning_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/is_sp_set_up_now_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_backend_config_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/prepare_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/recreate_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/resync_sp_listener_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/scan_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/send_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/set_sp_auto_scan_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/stop_sp_scan_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/sync_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/validate_sp_amount_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/validate_sp_recipient_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_notification_log_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_notifications_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_updates_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_settings_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_cubit.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:bb_mobile/features/sp/watchers/sp_header_retry_watcher.dart';
import 'package:bb_mobile/features/sp/watchers/sp_notifications_watcher.dart';
import 'package:bb_mobile/features/sp/watchers/sp_tip_watcher.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:get_it/get_it.dart';

/// DI wiring for the Silent Payments feature:
/// adapter (single live session) -> use cases -> facade -> presentation.
///
/// Must be registered BEFORE the wallet/settings locators, whose own use
/// cases resolve `locator<SpFacade>()`.
class SpLocator {
  static void setup(GetIt locator) {
    _registerAdapters(locator);
    _registerUseCases(locator);
    _registerFacade(locator);
    _registerPresentation(locator);
    _startTipWatcher(locator);
    _loadAutoScanSetting(locator);
  }

  // The choice persists, so seed the in-memory value at startup. Deferred to a
  // microtask rather than resolved here: setup is still registering, and a
  // caller that swaps an outbound port right after (the tests do) must get its
  // own. A read failure must not break startup; enabled is the shipped
  // behaviour.
  static void _loadAutoScanSetting(GetIt locator) {
    scheduleMicrotask(() async {
      try {
        await locator<SpAutoScanRepository>().warmUp();
      } catch (e) {
        log.warning('SpLocator: auto scan setting load failed: $e');
      }
    });
  }

  // Wire the SP electrum-listener resync into the core sync coordinator here,
  // so core never imports the SP feature (rule #7). The coordinator is
  // foreground-only, so it may be absent (e.g. the background isolate).
  // The sync tick usually runs before the header store reports a tip, so the
  // scan policy has to be re-judged once it lands. Foreground-only, like the
  // coordinator wiring above.
  static void _startTipWatcher(GetIt locator) {
    if (!locator.isRegistered<SyncCoordinator>()) return;
    locator<SpTipWatcher>().start();
  }

  static void _registerAdapters(GetIt locator) {
    // One datasource each, both lazySingletons: the FFI one owns the live
    // session, and the files one carries the recreate backup across calls, so a
    // second instance of either would split state that must stay single.
    locator.registerLazySingleton<BwkSpAccountDatasource>(
      BwkSpAccountDatasource.new,
    );
    locator.registerLazySingleton<SpAccountFilesDatasource>(
      SpAccountFilesDatasource.new,
    );
    // lazySingleton: exactly one owner of the live SpAccount session. Every
    // session interface below resolves to that same instance; the split only
    // narrows what each consumer is handed, notably keeping `scanOnce`
    // (SpScanPort) away from everything but ScanSpWalletUsecase.
    locator.registerLazySingleton<BwkSpAccountRepository>(
      () => BwkSpAccountRepository(
        ffi: locator<BwkSpAccountDatasource>(),
        files: locator<SpAccountFilesDatasource>(),
      ),
    );
    locator.registerLazySingleton<SpAccountRepository>(
      () => locator<BwkSpAccountRepository>(),
    );
    // The account directory is its own adapter: none of it touches the FFI.
    locator.registerLazySingleton<SpAccountFilesPort>(
      () =>
          SpAccountFilesRepository(files: locator<SpAccountFilesDatasource>()),
    );
    locator.registerLazySingleton<SpScanPort>(
      () => locator<BwkSpAccountRepository>(),
    );
    locator.registerLazySingleton<SpScanControlPort>(
      () => locator<BwkSpAccountRepository>(),
    );
    locator.registerLazySingleton<SpPaymentsPort>(
      () => locator<BwkSpAccountRepository>(),
    );
    locator.registerLazySingleton<SpBackendProbePort>(BwkSpBackendProbe.new);
    locator.registerLazySingleton<SpRecipientAddressValidatorPort>(
      BwkSpRecipientAddressValidator.new,
    );
    locator.registerLazySingleton<SpBackendConfigRepository>(
      () => KeyValueSpBackendConfigRepository(
        storage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );
  }

  static void _registerUseCases(GetIt locator) {
    // Singleton: its in-flight guard serializes session establishment so
    // concurrent callers never race two live SpAccount instances.
    locator.registerLazySingleton<EnsureSpSessionUsecase>(
      () => EnsureSpSessionUsecase(
        repository: locator<SpAccountRepository>(),
        files: locator<SpAccountFilesPort>(),
        configRepository: locator<SpBackendConfigRepository>(),
        getDefaultSeedUsecase: locator<GetDefaultSeedUsecase>(),
      ),
    );
    locator.registerFactory<GetSpWalletUsecase>(
      () => GetSpWalletUsecase(
        ensureSpSessionUsecase: locator<EnsureSpSessionUsecase>(),
        getSpFeatureGateUsecase: locator<GetSpFeatureGateUsecase>(),
      ),
    );
    locator.registerLazySingleton<SpAutoScanRepository>(
      () => KeyValueSpAutoScanRepository(
        storage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );
    locator.registerFactory<IsSpSetUpNowUsecase>(
      () =>
          IsSpSetUpNowUsecase(repository: locator<SpBackendConfigRepository>()),
    );
    locator.registerFactory<GetSpAutoScanUsecase>(
      () => GetSpAutoScanUsecase(repository: locator<SpAutoScanRepository>()),
    );
    locator.registerFactory<SetSpAutoScanUsecase>(
      () => SetSpAutoScanUsecase(repository: locator<SpAutoScanRepository>()),
    );
    locator.registerFactory<CheckSpWalletSetupUsecase>(
      () => CheckSpWalletSetupUsecase(
        configRepository: locator<SpBackendConfigRepository>(),
        files: locator<SpAccountFilesPort>(),
      ),
    );
    locator.registerFactory<GetSpFeatureGateUsecase>(
      () => GetSpFeatureGateUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    // Singleton: the two use cases holding it are factories, so the exclusion
    // only works if they share one guard.
    locator.registerLazySingleton<SpSessionGuard>(SpSessionGuard.new);
    locator.registerFactory<RevokeSpWalletUsecase>(
      () => RevokeSpWalletUsecase(
        repository: locator<SpAccountRepository>(),
        files: locator<SpAccountFilesPort>(),
        configRepository: locator<SpBackendConfigRepository>(),
        guard: locator<SpSessionGuard>(),
      ),
    );
    locator.registerLazySingleton<SpTipWatcher>(
      () => SpTipWatcher(
        watchSpUpdatesUsecase: locator<WatchSpUpdatesUsecase>(),
        syncSpWalletUsecase: locator<SyncSpWalletUsecase>(),
      ),
    );
    // Singleton so its in-flight guard covers both callers: SpTipWatcher holds
    // one directly, and the sync coordinator reaches another through SpFacade.
    locator.registerLazySingleton<SyncSpWalletUsecase>(
      () => SyncSpWalletUsecase(
        repository: locator<SpAccountRepository>(),
        getSpWalletUsecase: locator<GetSpWalletUsecase>(),
        isSpScanningUsecase: locator<IsSpScanningUsecase>(),
        resyncSpListenerUsecase: locator<ResyncSpListenerUsecase>(),
        scanSpWalletUsecase: locator<ScanSpWalletUsecase>(),
        getSpAutoScanUsecase: locator<GetSpAutoScanUsecase>(),
      ),
    );
    locator.registerFactory<ScanSpWalletUsecase>(
      () => ScanSpWalletUsecase(repository: locator<SpScanPort>()),
    );
    locator.registerFactory<StopSpScanUsecase>(
      () => StopSpScanUsecase(repository: locator<SpScanControlPort>()),
    );
    locator.registerFactory<ClearSpScanStateUsecase>(
      () => ClearSpScanStateUsecase(repository: locator<SpScanControlPort>()),
    );
    locator.registerFactory<GenerateTaprootAddressUsecase>(
      () =>
          GenerateTaprootAddressUsecase(repository: locator<SpPaymentsPort>()),
    );
    locator.registerFactory<PrepareSpPaymentUsecase>(
      () => PrepareSpPaymentUsecase(repository: locator<SpPaymentsPort>()),
    );
    locator.registerFactory<SendSpPaymentUsecase>(
      () => SendSpPaymentUsecase(repository: locator<SpPaymentsPort>()),
    );
    locator.registerFactory<GetSpNetworkUsecase>(
      () => GetSpNetworkUsecase(repository: locator<SpAccountRepository>()),
    );
    locator.registerFactory<GetSpBalanceUsecase>(
      () => GetSpBalanceUsecase(repository: locator<SpAccountRepository>()),
    );
    locator.registerFactory<ValidateSpRecipientUsecase>(
      () => ValidateSpRecipientUsecase(
        getSpNetworkUsecase: locator<GetSpNetworkUsecase>(),
        validator: locator<SpRecipientAddressValidatorPort>(),
      ),
    );
    locator.registerFactory<ValidateSpAmountUsecase>(
      () => ValidateSpAmountUsecase(
        getSpBalanceUsecase: locator<GetSpBalanceUsecase>(),
      ),
    );
    locator.registerFactory<GetSpBackendDefaultsUsecase>(
      () => GetSpBackendDefaultsUsecase(probe: locator<SpBackendProbePort>()),
    );
    locator.registerFactory<LoadSpBackendConfigUsecase>(
      () => LoadSpBackendConfigUsecase(
        configRepository: locator<SpBackendConfigRepository>(),
      ),
    );
    locator.registerFactory<LoadSpWalletDataUsecase>(
      () => LoadSpWalletDataUsecase(
        repository: locator<SpAccountRepository>(),
        ensureSpSessionUsecase: locator<EnsureSpSessionUsecase>(),
      ),
    );
    locator.registerFactory<WatchSpNotificationsUsecase>(
      () => WatchSpNotificationsUsecase(
        repository: locator<SpAccountRepository>(),
      ),
    );
    locator.registerFactory<SpNotificationsWatcher>(
      () => SpNotificationsWatcher(
        watchSpNotificationsUsecase: locator<WatchSpNotificationsUsecase>(),
        ensureSpSessionUsecase: locator<EnsureSpSessionUsecase>(),
      ),
    );
    locator.registerFactory<IsSpScanningUsecase>(
      () => IsSpScanningUsecase(repository: locator<SpScanControlPort>()),
    );
    locator.registerFactory<CreateSpWalletUsecase>(
      () => CreateSpWalletUsecase(
        getDefaultSeedUsecase: locator<GetDefaultSeedUsecase>(),
        settingsRepository: locator<SettingsRepository>(),
        repository: locator<SpAccountRepository>(),
        files: locator<SpAccountFilesPort>(),
        configRepository: locator<SpBackendConfigRepository>(),
        scanSpWalletUsecase: locator<ScanSpWalletUsecase>(),
      ),
    );
    locator.registerFactory<RecreateSpWalletUsecase>(
      () => RecreateSpWalletUsecase(
        getDefaultSeedUsecase: locator<GetDefaultSeedUsecase>(),
        repository: locator<SpAccountRepository>(),
        files: locator<SpAccountFilesPort>(),
        configRepository: locator<SpBackendConfigRepository>(),
        ensureSpSessionUsecase: locator<EnsureSpSessionUsecase>(),
        guard: locator<SpSessionGuard>(),
      ),
    );
    locator.registerFactory<WatchSpUpdatesUsecase>(
      () => WatchSpUpdatesUsecase(repository: locator<SpAccountRepository>()),
    );
    locator.registerFactory<WatchSpNotificationLogUsecase>(
      () => WatchSpNotificationLogUsecase(
        repository: locator<SpAccountRepository>(),
      ),
    );
    locator.registerFactory<ResyncSpListenerUsecase>(
      () => ResyncSpListenerUsecase(
        repository: locator<SpAccountRepository>(),
        scanControl: locator<SpScanControlPort>(),
      ),
    );
    locator.registerFactory<TestSpBackendUsecase>(
      () => TestSpBackendUsecase(probe: locator<SpBackendProbePort>()),
    );
  }

  static void _registerFacade(GetIt locator) {
    locator.registerLazySingleton<SpFacade>(
      () => SpFacade(
        getSpWalletUsecase: locator<GetSpWalletUsecase>(),
        isSpScanningUsecase: locator<IsSpScanningUsecase>(),
        checkSpWalletSetupUsecase: locator<CheckSpWalletSetupUsecase>(),
        isSpSetUpNowUsecase: locator<IsSpSetUpNowUsecase>(),
        getSpFeatureGateUsecase: locator<GetSpFeatureGateUsecase>(),
        getSpNetworkUsecase: locator<GetSpNetworkUsecase>(),
        revokeSpWalletUsecase: locator<RevokeSpWalletUsecase>(),
        watchSpUpdatesUsecase: locator<WatchSpUpdatesUsecase>(),
        syncSpWalletUsecase: locator<SyncSpWalletUsecase>(),
        validateSpRecipientUsecase: locator<ValidateSpRecipientUsecase>(),
        validateSpAmountUsecase: locator<ValidateSpAmountUsecase>(),
        prepareSpPaymentUsecase: locator<PrepareSpPaymentUsecase>(),
        sendSpPaymentUsecase: locator<SendSpPaymentUsecase>(),
      ),
    );
  }

  static void _registerPresentation(GetIt locator) {
    locator.registerFactory<SpCubit>(
      () => SpCubit(
        loadSpWalletDataUsecase: locator<LoadSpWalletDataUsecase>(),
        spNotificationsWatcher: locator<SpNotificationsWatcher>(),
        scanSpWalletUsecase: locator<ScanSpWalletUsecase>(),
        stopSpScanUsecase: locator<StopSpScanUsecase>(),
        clearSpScanStateUsecase: locator<ClearSpScanStateUsecase>(),
        revokeSpWalletUsecase: locator<RevokeSpWalletUsecase>(),
        generateTaprootAddressUsecase: locator<GenerateTaprootAddressUsecase>(),
        setSpAutoScanUsecase: locator<SetSpAutoScanUsecase>(),
        getSpAutoScanUsecase: locator<GetSpAutoScanUsecase>(),
        headerRetryWatcher: SpHeaderRetryWatcher(
          resyncSpListenerUsecase: locator<ResyncSpListenerUsecase>(),
        ),
      ),
    );
    locator.registerFactory<SpSetupCubit>(
      () => SpSetupCubit(
        createSpWalletUsecase: locator<CreateSpWalletUsecase>(),
        testSpBackendUsecase: locator<TestSpBackendUsecase>(),
        getSpBackendDefaultsUsecase: locator<GetSpBackendDefaultsUsecase>(),
      ),
    );
    locator.registerFactory<SpSettingsCubit>(
      () => SpSettingsCubit(
        recreateSpWalletUsecase: locator<RecreateSpWalletUsecase>(),
        watchNotificationLogUsecase: locator<WatchSpNotificationLogUsecase>(),
        testSpBackendUsecase: locator<TestSpBackendUsecase>(),
        loadSpBackendConfigUsecase: locator<LoadSpBackendConfigUsecase>(),
        getSpBackendDefaultsUsecase: locator<GetSpBackendDefaultsUsecase>(),
      ),
    );
  }
}
