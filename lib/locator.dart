import 'package:notifications/notifications.dart';
import 'package:bb_mobile/notification_adapters.dart';
import 'package:bull_tor/tor_adapter.dart' as bull_tor;
import 'package:bb_mobile/wallet_setup.dart' as infrastructure_wallet;
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/swaps/swaps_locator.dart';
import 'package:bb_mobile/core/storage/storage_locator.dart';
import 'package:bb_mobile/core/settings/settings_locator.dart'
    as infrastructure_settings;
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart'
    as settings;
import 'package:secrets/secrets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bb_mobile/core/recoverbull/recoverbull_locator.dart';
import 'package:bb_mobile/core/price/price_locator.dart';
import 'package:bb_mobile/core/mempool/mempool_locator.dart';
import 'package:bb_mobile/core/ledger/ledger_locator.dart'
    as infrastructure_ledger;
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/core/fees/fees_locator.dart';
import 'package:bb_mobile/core/exchange/exchange_locator.dart'
    as infrastructure_exchange;
import 'package:bb_mobile/core/electrum/frameworks/di/electrum_locator.dart';
import 'package:bb_mobile/core/blockchain/blockchain_locator.dart';
import 'package:bb_mobile/core/bitbox/bitbox_locator.dart';
import 'package:bb_mobile/core/bip85/bip85_locator.dart';
import 'package:bb_mobile/core/status/status_locator.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/payjoin_setup.dart';
import 'package:wallet/wallet.dart' show SyncWalletUsecase;
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/sync_runtime_adapters.dart';
import 'package:background_tasks/background_tasks.dart'
    show SyncCoordinator, SyncOutcome;
import 'package:bb_mobile/features/address_view/address_view_locator.dart';
import 'package:bb_mobile/features/all_seed_view/all_seed_view_locator.dart';
import 'package:bb_mobile/features/app_startup/app_startup_locator.dart';
import 'package:bb_mobile/features/announcements/announcements_locator.dart';
import 'package:bb_mobile/features/app_unlock/app_unlock_locator.dart';
import 'package:bb_mobile/features/autoswap/autoswap_locator.dart';
import 'package:bb_mobile/features/autoswap/autoswap_watcher.dart';
import 'package:bb_mobile/features/autobuy/public/autobuy_facade.dart';
import 'package:bb_mobile/features/backup_settings/backup_settings_locator.dart';
import 'package:bb_mobile/features/bip85_entropy/locator.dart';
import 'package:bb_mobile/features/bitbox/bitbox_locator.dart';
import 'package:bb_mobile/features/bitcoin_price/bitcoin_price_locator.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/locator.dart';
import 'package:bb_mobile/features/buy/buy_locator.dart';
import 'package:bb_mobile/features/coins/coins_locator.dart';
import 'package:bb_mobile/features/consolidation/consolidation_locator.dart';
import 'package:bb_mobile/features/dca/dca_locator.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:bb_mobile/features/limit_orders/public/limit_orders_facade.dart';
import 'package:bb_mobile/features/electrum_settings/electrum_settings_locator.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange_settings/public/exchange_settings_facade.dart';
import 'package:bb_mobile/features/exchange_support_chat/public/exchange_support_chat_facade.dart';
import 'package:bb_mobile/features/mempool_settings/mempool_settings_locator.dart';
import 'package:bb_mobile/features/fund_exchange/fund_exchange_locator.dart';
import 'package:bb_mobile/features/import_mnemonic/locator.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_locator.dart';
import 'package:bb_mobile/features/ledger/ledger_locator.dart';
import 'package:bb_mobile/features/onboarding/onboarding_locator.dart';
import 'package:bb_mobile/features/pay/pay_locator.dart';
import 'package:bb_mobile/features/pin_code/pin_code_locator.dart';
import 'package:bb_mobile/features/psbt_flow/psbt_flow_locator.dart';
import 'package:bb_mobile/features/receive/receive_locator.dart';
import 'package:bb_mobile/features/recipients/recipients_locator.dart';
import 'package:bb_mobile/features/replace_by_fee/locator.dart';
import 'package:bb_mobile/features/sell/sell_locator.dart';
import 'package:bb_mobile/features/send/send_locator.dart';
import 'package:bb_mobile/features/settings/settings_locator.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:bb_mobile/features/sp/sp_locator.dart';
import 'package:bb_mobile/features/status_check/locator.dart';
import 'package:bb_mobile/features/swap/order_swap_watcher.dart';
import 'package:bb_mobile/features/swap/swap_locator.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/usecases/refresh_order_swaps_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/test_wallet_backup_locator.dart';
import 'package:bb_mobile/features/tor_settings/tor_settings_locator.dart';
import 'package:bb_mobile/features/transactions/transactions_locator.dart';
import 'package:bb_mobile/features/wallet/wallet_locator.dart';
import 'package:bb_mobile/features/withdraw/withdraw_locator.dart';
import 'package:bb_mobile/features/wizard/wizard_locator.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_logs/bull_logs.dart';

final GetIt locator = GetIt.instance;

class AppLocator {
  static void _registerInfrastructureDatabase(
    GetIt locator,
    SqliteDatabase database,
  ) {
    locator.registerLazySingleton<SqliteDatabase>(() => database);
  }

  static Future<void> _registerInfrastructureDatasources(GetIt locator) async {
    await bull_tor.TorLocator.registerDatasources(
      locator,
      logger: bull_tor.TorLogger(
        configCallback: log.config,
        fineCallback: log.fine,
        warningCallback: log.warning,
      ),
    );
    BlockchainLocator.registerDatasources(locator);
    await ElectrumLocator.registerDatasources(locator);
    PriceLocator.registerDatasources(locator);
    infrastructure_exchange.ExchangeLocator.registerDatasources(locator);
    FeesLocator.registerDatasources(locator);
    await MempoolLocator.registerDatasources(locator);
    RecoverbullLocator.registerDatasources(locator);
    await StorageLocator.registerDatasources(locator);
    await SwapsLocator.registerDatasources(locator);
    await infrastructure_wallet.WalletLocator.registerDatasources(locator);
    await infrastructure_settings.SettingsLocator.registerDatasources(locator);
    Bip85DerivationsLocator.registerDatasources(locator);
    infrastructure_ledger.LedgerLocator.registerDatasources(locator);
    BitBoxCoreLocator.registerDatasources(locator);
  }

  static void _registerInfrastructurePorts(GetIt locator) {
    ElectrumLocator.registerPorts(locator);
    MempoolLocator.registerPorts(locator);
    LabelsLocator.registerPorts(locator);
  }

  static Future<void> _registerInfrastructureRepositories(GetIt locator) async {
    await infrastructure_settings.SettingsLocator.registerRepositories(locator);
    final settingsRepository = locator<settings.SettingsRepository>();
    final appSettings = await settingsRepository.fetch();
    bull_tor.TorLocator.registerRepositories(
      locator,
      initialMode: appSettings.torTransportMode,
      lastSuccessfulTransport: appSettings.lastSuccessfulTorTransport,
      onSuccessfulTransport: (transport) async {
        // Best-effort cache of the working transport; the repository already
        // logged the raw reason at its boundary.
        final stored = await settingsRepository.setLastSuccessfulTorTransport(
          transport,
        );
        if (stored case Err(:final failure)) {
          log.warning(
            'Could not persist the successful Tor transport: '
            '${failure.runtimeType}',
          );
        }
      },
    );
    BlockchainLocator.registerRepositories(locator);
    ElectrumLocator.registerRepositories(locator);
    PriceLocator.registerRepositories(locator);
    infrastructure_exchange.ExchangeLocator.registerRepositories(locator);
    FeesLocator.registerRepositories(locator);
    MempoolLocator.registerRepositories(locator);
    await infrastructure_settings.SettingsLocator.registerRepositories(locator);
    // One instance per process, as a lazy singleton: its scratch directory and its logging context are per instance. The package's lock is per isolate; the WorkManager isolate builds its own instance and must not write the keystore. The host supplies nothing about storage.
    //
    // The temporary directory, not the documents one. Signing a PSET makes lwk
    // write its wallet cache — which carries a Liquid confidential descriptor,
    // and so the seed-derived SLIP-77 blinding key — into a fresh directory
    // under this path, removed in a finally. A process killed mid-signature
    // leaves one behind; the package sweeps `lwk_sign_*` older than ten
    // minutes, and the choice of parent bounds what the sweep misses: the OS purges its temporary directory and,
    // on iOS, excludes it from backups independently of anything this app
    // does. The documents directory is neither purged nor independently
    // excluded — it relies on a single try? in AppDelegate that fails open.
    locator.registerLazySingleton<Secrets>(
      () => Secrets(
        scratchDirectory: () async => (await getTemporaryDirectory()).path,
      ),
    );
    RecoverbullLocator.registerRepositories(locator);
    SwapsLocator.registerRepositories(locator);
    await infrastructure_wallet.WalletLocator.registerRepositories(locator);
    Bip85DerivationsLocator.registerRepositories(locator);
    infrastructure_ledger.LedgerLocator.registerRepositories(locator);
    BitBoxCoreLocator.registerRepositories(locator);
  }

  static void _registerInfrastructureServices(GetIt locator) {
    infrastructure_exchange.ExchangeLocator.registerServices(locator);
    MempoolLocator.registerServices(locator);
  }

  static void _registerInfrastructureUsecases(GetIt locator) {
    bull_tor.TorLocator.registerUsecases(locator);
    LabelsLocator.registerUseCases(locator);
    ElectrumLocator.registerUsecases(locator);
    BlockchainLocator.registerUsecases(locator);
    PriceLocator.registerUseCases(locator);
    infrastructure_exchange.ExchangeLocator.registerUseCases(locator);
    FeesLocator.registerUseCases(locator);
    MempoolLocator.registerUsecases(locator);
    RecoverbullLocator.registerUsecases(locator);
    infrastructure_settings.SettingsLocator.registerUsecases(locator);
    SwapsLocator.registerUsecases(locator);
    infrastructure_wallet.WalletLocator.registerUsecases(locator);
    Bip85DerivationsLocator.registerUsecases(locator);
    infrastructure_ledger.LedgerLocator.registerUsecases(locator);
    BitBoxCoreLocator.registerUsecases(locator);
  }

  static void _registerInfrastructureFacades(GetIt locator) {
    LabelsLocator.registerFacade(locator);
    locator.registerLazySingleton<NotificationPermissionsFacade>(
      () => NotificationPermissionsFacade(
        gateway: FlutterNotificationPermissionGateway(
          channelId: paymentNotificationChannelId,
        ),
      ),
    );
  }

  static void _registerInfrastructureFrameworks(GetIt locator) {
    LabelsLocator.registerFrameworks(locator);
  }

  /// Call this in the `main` function **before** `runApp()`
  static Future<void> setup(
    GetIt locator,
    SqliteDatabase database, {
    required String payjoinDatabasePath,
    bool startPayjoinRecovery = true,
    bool startOrderSwapWatcher = true,
    bool startAutoswapWatcher = true,
  }) async {
    locator.enableRegisteringMultipleInstancesOfOneType();

    // Register core dependencies first
    _registerInfrastructureDatabase(locator, database);
    await _registerInfrastructureDatasources(locator);
    // Note: since the WalletLocator repositories depend on ports for electrum servers,
    // we need to make sure the ports are registered before the repositories
    // This is a hack though as normally repositories should not depend on ports
    // The proper solution is to refactor the code to remove this dependency
    _registerInfrastructurePorts(locator);
    await _registerInfrastructureRepositories(locator);
    _registerInfrastructureServices(locator);
    _registerInfrastructureUsecases(locator);
    _registerInfrastructureFrameworks(locator);
    _registerInfrastructureFacades(locator);
    PayjoinSetup.setup(
      locator,
      database,
      payjoinDatabasePath,
      startRecovery: startPayjoinRecovery,
    );

    locator.registerLazySingleton<SyncCoordinator>(
      () => createForegroundSyncCoordinator(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        syncWalletUsecase: locator<SyncWalletUsecase>(),
        syncSwapsOutcome: () async {
          final result = await locator<RefreshOrderSwapsUsecase>().execute();
          switch (result) {
            case Ok(:final value):
              final rateLimited = value.failures
                  .whereType<SwapRateLimitedFailure>()
                  .firstOrNull;
              if (rateLimited != null) {
                return SyncOutcome.rateLimited(
                  retryAfter: rateLimited.retryAfter,
                  failure: _SwapSyncException(rateLimited.runtimeType),
                );
              }
              return value.pollableOrderCount == 0
                  ? const SyncOutcome.idle()
                  : const SyncOutcome.active();
            case Err(:final failure):
              return failure is SwapRateLimitedFailure
                  ? SyncOutcome.rateLimited(
                      retryAfter: failure.retryAfter,
                      failure: _SwapSyncException(failure.runtimeType),
                    )
                  : SyncOutcome.rateLimited(
                      failure: _SwapSyncException(failure.runtimeType),
                    );
          }
        },
        // Lazy, like the swap callback above: SpLocator runs after this, and the
        // closure only resolves the facade when a sync tick actually fires.
        syncSp: () async {
          final result = await locator<SpFacade>().syncWallet();
          if (result case Err(:final failure)) {
            throw SpSyncException(failure.logMessage);
          }
        },
      ),
    );

    // Register feature-specific dependencies
    ElectrumSettingsLocator.setup(locator);
    MempoolSettingsLocator.setup(locator);
    TorSettingsLocator.setup(locator);
    PinCodeLocator.setup(locator);
    WizardLocator.setup(locator);
    AppStartupLocator.setup(locator);
    AppUnlockLocator.setup(locator);
    OnboardingLocator.setup(locator);
    AllSeedViewLocator.setup(locator);
    // SP must register before settings/wallet: their wrapper use cases
    // resolve locator<SpFacade>().
    SpLocator.setup(locator);
    SettingsLocator.setup(locator);
    const LogsFeature().setup(locator);
    BitcoinPriceLocator.setup(locator);
    WalletLocator.setup(locator);
    TransactionsLocator.registerAdapters(locator);
    TransactionsLocator.registerUsecases(locator);
    TransactionsLocator.registerBlocs(locator);
    ReceiveLocator.setup(locator);
    SendLocator.setup(locator);
    CoinsLocator.setup(locator);
    ConsolidationLocator.setup(locator);
    BackupSettingsLocator.setup(locator);
    TestWalletBackupLocator.setup(locator);
    ImportWatchOnlyLocator.setup(locator);
    BroadcastSignedTxLocator.setup(locator);
    PsbtFlowLocator.setup(locator);
    SwapLocator.setup(locator);
    AutoSwapLocator.setup(locator);
    AnnouncementsLocator.setup(locator);
    // Lifecycle side effect lives in the composition root, not in DI
    // registration: the background handler opts out via
    // [startOrderSwapWatcher] so polling only runs in the foreground app.
    if (startOrderSwapWatcher) {
      locator<OrderSwapWatcher>().start();
    }
    if (startAutoswapWatcher) {
      locator<AutoswapWatcher>().start();
    }

    ExchangeLocator.setup(locator);
    DefaultWalletsLocator.setup(locator);
    AutoBuyLocator.setup(locator);
    LimitOrdersLocator.setup(locator);
    ExchangeSettingsLocator.setup(locator);
    ExchangeSupportChatLocator.setup(locator);
    BuyLocator.setup(locator);
    SellLocator.setup(locator);
    WithdrawLocator.setup(locator);
    PayLocator.setup(locator);
    StatusLocator.setup(locator);
    StatusCheckLocator.setup(locator);

    FundExchangeLocator.setup(locator);
    AddressViewLocator.setup(locator);
    ImportMnemonicLocator.setup(locator);
    DcaLocator.setup(locator);
    ReplaceByFeeLocator.setup(locator);
    Bip85EntropyLocator.setup(locator);
    LedgerLocator.setup(locator);
    RecipientsLocator.setup(locator);
    BitBoxLocator.setup(locator);
  }
}

final class _SwapSyncException implements Exception {
  final Type failureType;

  const _SwapSyncException(this.failureType);
}
