import 'dart:async';

import 'package:bb_mobile/features/app_startup/public/app_startup_facade.dart';
import 'package:secrets/storage.dart';
import 'package:labels/labels.dart';
import 'package:electrum/electrum.dart';
import 'package:bb_mobile/features/wallet/public/bip85_bindings.dart';
import 'package:bb_mobile/foreground_wallet_startup.dart';
import 'package:bull_payjoin/bull_payjoin.dart' show PayjoinLifecycle;
import 'package:fees_feature/fees_feature.dart' show FeesFeature;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mempool/mempool.dart';
import 'package:fees/fees.dart';
import 'package:exchange/exchange.dart' show Exchange;
import 'package:preferences/preferences.dart';
import 'package:network/network.dart' show NetworkFeature;
import 'package:bb_mobile/features/wallet/public/ark_foreground_setup.dart';
import 'package:primitives/primitives.dart' show Failure;
import 'package:electrum/setup.dart'
    show RegtestElectrumProfile, ReadElectrumPreferences;
import 'package:bb_mobile/background_setup.dart';
import 'package:bb_mobile/core_locator.dart';
import 'package:bb_mobile/features/settings/public/recoverbull_bindings.dart';
import 'package:bb_mobile/features/wallet/public/recoverbull_bindings.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/migration.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:bull_tor/tor.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/wallet/public/ark_funding_setup.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:transactions/routes.dart';
import 'package:transactions/setup.dart';
import 'package:bb_mobile/features/wallet/public/payjoin_setup.dart';
import 'package:bb_mobile/features/wallet/data/foreground_wallet_sync.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/address_viewer.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/replace_by_fee/router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sync/write.dart' show WalletNativeRuntime;
import 'package:bb_mobile/features/address_view/address_view_locator.dart';
import 'package:bb_mobile/features/all_seed_view/all_seed_view_locator.dart';
import 'package:bb_mobile/features/app_startup/app_startup_locator.dart';
import 'package:access/setup.dart' show AccessFeature;
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/autoswap/autoswap_locator.dart';
import 'package:bb_mobile/features/autoswap/autoswap_watcher.dart';
import 'package:bb_mobile/features/autobuy/public/autobuy_facade.dart';
import 'package:bb_mobile/features/backup_settings/backup_settings_locator.dart';
import 'package:bb_mobile/features/bip85_entropy/locator.dart';
import 'package:signers/routes.dart';
import 'package:bb_mobile/features/scanning/public/nfc_scanning.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/locator.dart';
import 'package:bb_mobile/features/buy/public/buy_facade.dart';
import 'package:bb_mobile/features/coins/coins_locator.dart';
import 'package:bb_mobile/features/consolidation/consolidation_locator.dart';
import 'package:bb_mobile/features/dca/public/dca_facade.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:bb_mobile/features/limit_orders/public/limit_orders_facade.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/fund_exchange/public/fund_exchange_facade.dart';
import 'package:bb_mobile/features/import_mnemonic/locator.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_locator.dart';
import 'package:bb_mobile/features/onboarding/onboarding_locator.dart';
import 'package:bb_mobile/features/pay/public/pay_facade.dart';
import 'package:bb_mobile/features/receive/receive_locator.dart';
import 'package:bb_mobile/features/receive/public/receive_setup.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/replace_by_fee/locator.dart';
import 'package:bb_mobile/features/sell/public/sell_facade.dart';
import 'package:bb_mobile/features/send/send_locator.dart';
import 'package:bb_mobile/features/settings/settings_locator.dart';
import 'package:bb_mobile/features/sp/sp_locator.dart';
import 'package:bb_mobile/features/swap/order_swap_watcher.dart';
import 'package:bb_mobile/features/swap/swap_locator.dart';
import 'package:bb_mobile/core/swaps/swap_engine_switcher.dart';
import 'package:bb_mobile/features/test_wallet_backup/test_wallet_backup_locator.dart';
import 'package:bb_mobile/features/wallet/wallet_locator.dart';
import 'package:bb_mobile/features/withdraw/public/withdraw_facade.dart';
import 'package:bb_mobile/features/wizard/wizard_locator.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_logs/bull_logs.dart';
import 'package:btc_map/btc_map.dart';
import 'package:path_provider/path_provider.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart'
    show
        Sync,
        Wallet,
        SyncFailure,
        SyncStorageFailure,
        WalletConnectionPort,
        WalletCatalogPort;

final GetIt locator = GetIt.instance;

class AppLocator {
  /// Foreground-only composition. Headless setup never opens this database.
  static Future<void> setupRecoverBull(
    GetIt locator, {
    required String databasePath,
  }) async {
    final settings = await SettingsRecoverBullBindings.setup(
      locator,
      databasePath: databasePath,
    );
    WalletRecoverBullBindings.setup(locator);
    final family = settings.path == databasePath ? null : 'regtest';
    final feature = await RecoverBullFeature.mount(
      server: settings.server,
      secrets: locator<Secrets>(),
      wallets: locator<RecoverBullWalletPort>(),
      environment: locator<RecoverBullEnvironmentPort>(),
      permission: locator<RecoverBullPermissionPort>(),
      routes: locator<RecoverBullRoutePort>(),
      clients: locator<TorHttpClientFactory>(),
      admission: locator<RuntimeAdmission>(),
      cutover: locator<RecoverBullCutover>(instanceName: family),
    );
    locator.registerSingleton<RecoverBullFeature>(
      feature,
      dispose: (value) => value.dispose(),
    );
    locator.registerSingleton<RecoverBullFacade>(feature.facade);
  }

  /// Call this in the `main` function **before** `runApp()`
  static Future<Result<void, Failure>> setup(
    GetIt locator,
    SqliteDatabase database, {
    required Future<Result<Labels, LabelFailure>> Function(
      Future<Sync> Function() sync,
      Future<Wallet> Function(String) openWallet,
    )
    openLabels,
    required Future<Result<Electrum, ElectrumFailure>> Function(
      ReadElectrumPreferences readPreferences,
      Tor Function() tor,
    )
    openElectrum,
    required Future<Result<Preferences, PreferencesFailure>> Function(
      SqliteDatabase legacy,
    )
    openPreferences,
    required Future<Result<Mempool, MempoolFailure>> Function(
      Tor Function() tor,
      TorHttpClientFactory http,
    )
    openMempool,
    Secrets? secrets,
    bool startPayjoinRecovery = true,
    bool startOrderSwapWatcher = true,
    bool startAutoswapWatcher = true,
    String? arkFundingDatabasePath,
    bool initializeArkFunding = false,
    RegtestElectrumProfile? regtestProfile,
  }) async {
    locator.enableRegisteringMultipleInstancesOfOneType();
    locator.registerSingleton(
      SignersFeature.mount(
        services: locator,
        writeNfc: (context, title, data, onSuccess) =>
            NfcBottomSheet.showWriteNfc(
              context: context,
              title: title,
              data: data,
              onSuccess: onSuccess,
            ),
      ),
    );

    // One instance per isolate; background tasks must not use its keystore.
    // Liquid signing removes its temporary children after use. Stale caches
    // contain blinding material, so keep them in the OS's non-backed-up cache.
    locator.registerLazySingleton<Secrets>(
      () =>
          secrets ??
          Secrets(
            scratchDirectory: () async => (await getTemporaryDirectory()).path,
          ),
    );

    // One Ark funding authority for the app, opened before any repository:
    // Sync, ordinary signing and Ark Board funding must share this instance.
    // Without it the guard refuses signing on networks where Ark is admitted.
    final documents = await getApplicationDocumentsDirectory();
    final installation = await ArkInstallationState.inspect(
      documents: documents,
      fundingPath:
          arkFundingDatabasePath ?? '${documents.path}/ark-funding.sqlite',
    );
    locator.registerSingleton<ArkInstallationState>(installation);
    final arkFunding = arkFundingDatabasePath == null
        ? const Err<SqliteArkFundingReservations, SyncFailure>(
            SyncStorageFailure(),
          )
        : SqliteArkFundingReservations.open(
            arkFundingDatabasePath,
            foreground: true,
            initializeNew:
                initializeArkFunding && installation.wasNeverProvisioned,
          );
    locator.registerSingleton<ArkFundingSigningGuard>(
      ArkFundingSigningGuard(
        arkFunding,
        arkFundingDatabasePath == null ? null : installation,
      ),
    );
    if (arkFunding case Ok(:final value)) {
      locator.registerSingleton<SqliteArkFundingReservations>(
        value,
        dispose: (authority) => authority.close(),
      );
    }

    // Register core dependencies first
    CoreLocator.register(locator, database);
    await CoreLocator.registerDatasources(locator);
    final electrum = await openElectrum(
      () => locator<ConnectionPreferencesReader>().readConnectionPreferences(),
      () => locator<Tor>(),
    );
    if (electrum case Err(:final failure)) return Err(failure);
    CoreLocator.setupElectrum(
      locator,
      (electrum as Ok<Electrum, ElectrumFailure>).value,
    );
    // Lazy registrations only; storage is prepared before network repositories.
    // Note: since the WalletLocator repositories depend on ports for electrum servers,
    // we need to make sure the ports are registered before the repositories
    // This is a hack though as normally repositories should not depend on ports
    // The proper solution is to refactor the code to remove this dependency
    final labels = await CoreLocator.registerPorts(
      locator,
      openLabels: openLabels,
    );
    if (labels case Err(:final failure)) return Err(failure);
    final openedPreferences = await openPreferences(database);
    if (openedPreferences case Err(:final failure)) return Err(failure);
    final preferences =
        (openedPreferences as Ok<Preferences, PreferencesFailure>).value;
    final repositories = await CoreLocator.registerRepositories(
      locator,
      preferences: preferences,
      regtestProfile: regtestProfile,
    );
    if (repositories case Err()) return repositories;
    final mempool = await openMempool(
      () => locator<Tor>(),
      locator<TorHttpClientFactory>(),
    );
    if (mempool case Err(:final failure)) return Err(failure);
    locator.registerSingleton<Mempool>(
      (mempool as Ok<Mempool, MempoolFailure>).value,
      dispose: (value) async {
        final _ = await value.close();
      },
    );
    locator.registerLazySingleton(() {
      final preferences = SharedPreferencesAsync();
      return Fees.open(
        connections: locator<WalletConnectionPort>(),
        mempool: locator<Mempool>(),
        readPreference: preferences.getString,
        writePreference: preferences.setString,
      );
    });
    locator.registerSingleton(FeesFeature.mount(fees: () => locator<Fees>()));
    CoreLocator.registerUsecases(locator);
    PayjoinSetup.setup(locator, startRecovery: false);

    SyncLocator.setupForeground(locator);

    // Register feature-specific dependencies
    final inventory = locator<SecretsInventory>();
    final backupVerification = locator<InventoryBackupVerification>();
    locator.registerSingleton<AccessFeature>(
      AccessFeature.mount(
        services: locator,
        inventory: inventory,
        backupVerification: backupVerification,
        hasVerifiedBackup: () async =>
            switch (await inventory.hasVerifiedBackups(backupVerification)) {
              Ok(:final value) => value,
              Err() => false,
            },
        onUnlocked: (context) async {
          await locator<ForegroundWalletStartup>().start();
          if (!context.mounted) return;
          unawaited(locator<RecoverBullFacade>().checkAtColdStart());
          completeAppStartupUnlock(context);
          context.goNamed(WalletRoute.walletHome.name);
        },
        onBackUp: (context) =>
            context.pushNamed<void>(SettingsRoute.backupSettings.name),
      ),
    );
    WizardLocator.setup(locator);
    AppStartupLocator.setup(locator);
    OnboardingLocator.setup(locator);
    AllSeedViewLocator.setup(locator);
    Bip85EntropyLocator.setup(
      locator,
      readParent: WalletBip85Bindings.reader(locator),
    );
    // Wallet's SP use cases resolve the facade lazily, after registration.
    WalletLocator.setup(
      locator,
      receiveAddress: (id) =>
          locator<GetTransferReceiveAddressUsecase>().execute(id),
      nextReceiveAddress: (id, {excludedAddresses = const {}}) =>
          locator<NextUnusedReceiveAddressUsecase>().execute(
            id,
            excludedAddresses: excludedAddresses,
          ),
    );
    AddressViewLocator.setup(locator);
    // Inventory survives disabled routing and missing endpoint build defines.
    final _ = await prepareArkCustodyReferences(
      locator,
      initializeNew: initializeArkFunding && installation.wasNeverProvisioned,
    );
    SpLocator.setup(locator);
    SettingsLocator.setup(locator);
    setupBackgroundPreferences(
      locator,
      configureBackgroundTasks,
      notificationChannelId: paymentNotificationChannelId,
    );
    const LogsFeature().setup(locator);
    BtcMapFeature.setup(locator);
    locator.registerLazySingleton<BitcoinPriceFeature>(
      () => BitcoinPriceFeature.mount(
        environment: locator<ActiveEnvironmentReader>(),
        amountDisplay: locator<AmountDisplayPreferencesReader>(),
        display: locator<RuntimeDisplayPreferencesReader>(),
      ),
    );
    WalletFacade wallet() => locator<WalletFacade>();
    locator.registerSingleton(
      TransactionsFeature.mount(
        locator,
        inventory: inventory,
        loadWallet: (key) => locator<WalletNativeRuntime>().loadWallet(key),
        findDescriptor: (key) => locator<WalletCatalogPort>().find(key),
        synchronize: (descriptor) =>
            locator<ForegroundWalletSync>().synchronizeDescriptor(descriptor),
        events: WalletHistoryEvents(
          watchRevisions: ({walletId}) =>
              wallet().watchRevisions(walletId: walletId),
          watchSyncPassActivity: () => wallet().watchSyncPassActivity(),
          watchSyncFinished: () => wallet().watchSyncFinished(),
          isSyncPassActive: () => wallet().isSyncPassActive,
        ),
        syncStarted: () => locator<ForegroundWalletSync>().started,
        syncFinished: () => locator<ForegroundWalletSync>().finished,
        orderSwaps: () => locator<SwapFacade>(),
        actions: TransactionUiActions(
          openExchange: (context) =>
              context.goNamed(ExchangeRoute.exchangeHome.name),
          openWalletHome: (context) =>
              context.goNamed(WalletRoute.walletHome.name),
          refreshWallets: (context) => context.read<WalletBloc>().refresh(),
          accelerateOrder: (context, orderId) => AccelerateTransactionListTile(
            orderId: orderId,
            onTap: () => context.pushNamed(
              BuyRoute.buyAccelerate.name,
              pathParameters: {'orderId': orderId},
            ),
          ),
          showReceipt: showSinpeReceiptBottomSheet,
          accelerateWalletTransaction: (context, transaction) =>
              ReplaceByFeeRouter.openForTransaction(
                context,
                walletId: transaction.walletId,
                txId: transaction.txId,
                network: transaction.network,
                feeSat: transaction.feeSat,
                vsize: transaction.vsize,
              ),
          addressViewer: (address, style) =>
              AddressViewer(address, style: style),
          orderSwapUnderReview: (orderSwap) =>
              OrderSwapUnderReviewCard(orderSwap: orderSwap),
        ),
        scope: (child) => ActiveNetworkScope(child: child),
      ),
    );
    ReceiveLocator.setup(locator);
    SendLocator.setup(locator);
    CoinsLocator.setup(locator);
    ConsolidationLocator.setup(locator);
    BackupSettingsLocator.setup(locator);
    TestWalletBackupLocator.setup(locator);
    ImportWatchOnlyLocator.setup(locator);
    BroadcastSignedTxLocator.setup(locator);
    SwapLocator.setup(locator);
    AutoSwapLocator.setup(locator);

    ExchangeLocator.setup(locator);
    locator.registerLazySingleton<DefaultWalletsFacade>(
      () => DefaultWalletsFacade(locator<Exchange>()),
    );
    AutoBuyLocator.setup(locator);
    LimitOrdersLocator.setup(locator);
    BuyLocator.setup(locator);
    SellLocator.setup(locator);
    WithdrawLocator.setup(locator);
    PayLocator.setup(locator);
    locator.registerSingleton(
      NetworkFeature.mount(
        services: locator,
        preferences: locator<Preferences>(),
        bindings: (
          readDefaultNetwork: () =>
              locator<WalletFacade>().defaultWalletNetwork(),
          isTorRequired: () => locator<WalletFacade>().isTorRequired(),
        ),
      ),
    );

    FundExchangeLocator.setup(locator);
    ImportMnemonicLocator.setup(locator);
    DcaLocator.setup(locator);
    ReplaceByFeeLocator.setup(locator);
    RecipientsLocator.setup(locator);

    locator.registerSingleton(
      ForegroundWalletStartup(
        initialize: () => initializeWalletRuntime(locator),
        startWatchers: () {
          SpLocator.startForegroundWatchers(locator);
          if (startOrderSwapWatcher) locator<OrderSwapWatcher>().start();
          if (startAutoswapWatcher) locator<AutoswapWatcher>().start();
          locator<SwapEngineSwitcher>().start();
        },
        payjoin: startPayjoinRecovery
            ? () => locator<PayjoinLifecycle>()
            : null,
      ),
    );
    return const Ok(null);
  }
}
