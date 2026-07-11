import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/sp/data/bwk_sp_account_repository.dart';
import 'package:bb_mobile/features/sp/data/key_value_sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/check_sp_wallet_setup_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/create_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/generate_taproot_address_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_balance_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_network_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_backend_config_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/prepare_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/refresh_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/recreate_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/resync_sp_listener_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/scan_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/send_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/stop_sp_scan_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_notification_log_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_notifications_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_updates_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_send_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_settings_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_cubit.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
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
    _wireSyncListener(locator);
  }

  // Wire the SP electrum-listener resync into the core sync coordinator here,
  // so core never imports the SP feature (rule #7). The coordinator is
  // foreground-only, so it may be absent (e.g. the background isolate).
  static void _wireSyncListener(GetIt locator) {
    if (!locator.isRegistered<SyncCoordinator>()) return;
    locator<SyncCoordinator>().resyncSpListener = () =>
        locator<SpFacade>().resyncListener();
  }

  static void _registerAdapters(GetIt locator) {
    // lazySingleton: exactly one owner of the live SpAccount session.
    locator.registerLazySingleton<SpAccountRepository>(
      BwkSpAccountRepository.new,
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
        configRepository: locator<SpBackendConfigRepository>(),
        getDefaultSeedUsecase: locator<GetDefaultSeedUsecase>(),
      ),
    );
    locator.registerFactory<GetSpWalletUsecase>(
      () => GetSpWalletUsecase(
        ensureSpSessionUsecase: locator<EnsureSpSessionUsecase>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<CheckSpWalletSetupUsecase>(
      () => CheckSpWalletSetupUsecase(
        configRepository: locator<SpBackendConfigRepository>(),
        accountRepository: locator<SpAccountRepository>(),
      ),
    );
    locator.registerFactory<GetSpFeatureGateUsecase>(
      () => GetSpFeatureGateUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<RevokeSpWalletUsecase>(
      () => RevokeSpWalletUsecase(
        repository: locator<SpAccountRepository>(),
        configRepository: locator<SpBackendConfigRepository>(),
      ),
    );
    locator.registerFactory<ScanSpWalletUsecase>(
      () => ScanSpWalletUsecase(repository: locator<SpAccountRepository>()),
    );
    locator.registerFactory<StopSpScanUsecase>(
      () => StopSpScanUsecase(repository: locator<SpAccountRepository>()),
    );
    locator.registerFactory<GenerateTaprootAddressUsecase>(
      () => GenerateTaprootAddressUsecase(
        repository: locator<SpAccountRepository>(),
      ),
    );
    locator.registerFactory<PrepareSpPaymentUsecase>(
      () => PrepareSpPaymentUsecase(repository: locator<SpAccountRepository>()),
    );
    locator.registerFactory<SendSpPaymentUsecase>(
      () => SendSpPaymentUsecase(repository: locator<SpAccountRepository>()),
    );
    locator.registerFactory<GetSpNetworkUsecase>(
      () => GetSpNetworkUsecase(repository: locator<SpAccountRepository>()),
    );
    locator.registerFactory<GetSpBalanceUsecase>(
      () => GetSpBalanceUsecase(repository: locator<SpAccountRepository>()),
    );
    locator.registerFactory<GetSpBackendDefaultsUsecase>(
      () => GetSpBackendDefaultsUsecase(
        configRepository: locator<SpBackendConfigRepository>(),
      ),
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
    locator.registerFactory<RefreshSpWalletUsecase>(
      () => RefreshSpWalletUsecase(
        repository: locator<SpAccountRepository>(),
        getSpWalletUsecase: locator<GetSpWalletUsecase>(),
      ),
    );
    locator.registerFactory<CreateSpWalletUsecase>(
      () => CreateSpWalletUsecase(
        getDefaultSeedUsecase: locator<GetDefaultSeedUsecase>(),
        settingsRepository: locator<SettingsRepository>(),
        repository: locator<SpAccountRepository>(),
        configRepository: locator<SpBackendConfigRepository>(),
      ),
    );
    locator.registerFactory<RecreateSpWalletUsecase>(
      () => RecreateSpWalletUsecase(
        getDefaultSeedUsecase: locator<GetDefaultSeedUsecase>(),
        repository: locator<SpAccountRepository>(),
        configRepository: locator<SpBackendConfigRepository>(),
        ensureSpSessionUsecase: locator<EnsureSpSessionUsecase>(),
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
      () => ResyncSpListenerUsecase(repository: locator<SpAccountRepository>()),
    );
    locator.registerFactory<TestSpBackendUsecase>(
      () => TestSpBackendUsecase(
        configRepository: locator<SpBackendConfigRepository>(),
      ),
    );
  }

  static void _registerFacade(GetIt locator) {
    locator.registerLazySingleton<SpFacade>(
      () => SpFacade(
        refreshSpWalletUsecase: locator<RefreshSpWalletUsecase>(),
        getSpWalletUsecase: locator<GetSpWalletUsecase>(),
        checkSpWalletSetupUsecase: locator<CheckSpWalletSetupUsecase>(),
        revokeSpWalletUsecase: locator<RevokeSpWalletUsecase>(),
        watchSpUpdatesUsecase: locator<WatchSpUpdatesUsecase>(),
        resyncSpListenerUsecase: locator<ResyncSpListenerUsecase>(),
      ),
    );
  }

  static void _registerPresentation(GetIt locator) {
    locator.registerFactory<SpCubit>(
      () => SpCubit(
        loadSpWalletDataUsecase: locator<LoadSpWalletDataUsecase>(),
        watchSpNotificationsUsecase: locator<WatchSpNotificationsUsecase>(),
        scanSpWalletUsecase: locator<ScanSpWalletUsecase>(),
        stopSpScanUsecase: locator<StopSpScanUsecase>(),
        revokeSpWalletUsecase: locator<RevokeSpWalletUsecase>(),
        generateTaprootAddressUsecase: locator<GenerateTaprootAddressUsecase>(),
      ),
    );
    locator.registerFactory<SpSendCubit>(
      () => SpSendCubit(
        prepareSpPaymentUsecase: locator<PrepareSpPaymentUsecase>(),
        sendSpPaymentUsecase: locator<SendSpPaymentUsecase>(),
        getSpNetworkUsecase: locator<GetSpNetworkUsecase>(),
        getSpBalanceUsecase: locator<GetSpBalanceUsecase>(),
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
