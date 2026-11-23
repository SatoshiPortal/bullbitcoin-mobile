import 'package:transactions/transactions.dart' show Transactions;
import 'package:bull_ark/bull_ark.dart' show ArkTransferFacade;
import 'package:sync/write.dart' show ElectrumSync;

import 'dart:async';

import 'package:ark/funding.dart';
import 'package:bull_exchange/bull_exchange.dart'
    show AccelerateTransactionListTile, BuyRoute, showSinpeReceiptBottomSheet;

import 'package:backups/backups.dart';
import 'package:notifications/payment_store.dart' show PaymentNotifications;
import 'package:bull_recoverbull/storage.dart';
import 'package:bull_recoverbull/setup.dart';
import 'package:overview/setup.dart';
import 'package:startup/setup.dart';
import 'package:startup/startup.dart';
import 'package:provisioning/provisioning.dart';
import 'package:swaps/swaps.dart' show SwapStartup;
import 'package:secrets/storage.dart';
import 'package:material_ui/material_ui.dart' show AssetImage;
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:wallet_import/setup.dart';
import 'package:labels/labels.dart';
import 'package:electrum/electrum.dart';
import 'package:secrets/bip85.dart';
import 'package:secrets/custody.dart';
import 'package:bip85/bip85.dart';
import 'package:all_seed_view/setup.dart';
import 'package:access/access.dart' show Access;
import 'package:swaps/swaps.dart' show BoltzSwaps;
import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:bull_payjoin/bull_payjoin.dart' show PayjoinLifecycle;
import 'package:fees_feature/fees_feature.dart' show FeesFeature;
import 'package:swaps/swaps.dart' show Swaps;
import 'package:swaps/order_swaps.dart';
import 'package:signers/storage.dart' show SignerDevices;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mempool/mempool.dart';
import 'package:fees/fees.dart';
import 'package:preferences/preferences.dart';
import 'package:network/network.dart' show NetworkFeature;
import 'package:bull_ark/ark_foreground_setup.dart';
import 'package:primitives/primitives.dart' show Err, Failure;
import 'package:electrum/setup.dart'
    show ElectrumServersPort, ReadElectrumPreferences, RegtestElectrumProfile;
import 'package:background_tasks/background_tasks.dart'
    show configureBackgroundTasks;
import 'package:bb_mobile/background_entrypoint.dart';
import 'package:bb_mobile/core_locator.dart';
import 'package:bb_mobile/features/settings/public/recoverbull_bindings.dart';
import 'package:bb_mobile/features/wallet/public/recoverbull_bindings.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/migration.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:bull_tor/tor.dart';
import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:transactions/routes.dart';
import 'package:transactions/setup.dart';
import 'package:bb_mobile/features/wallet/data/foreground_wallet_sync.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:swap_feature/swap_feature.dart';
import 'package:send/send.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sync/write.dart' show WalletNativeRuntime;
import 'package:address_view/address_view.dart';
import 'package:bb_mobile/address_view_setup.dart';
import 'package:access/setup.dart' show AccessFeature;
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:signers/routes.dart';
import 'package:scanning/scanning.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bb_mobile/features/coins/coins_locator.dart';
import 'package:bb_mobile/features/limit_orders/public/limit_orders_facade.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/onboarding/onboarding_locator.dart';
import 'package:receive/receive.dart' show Receive;
import 'package:receive/setup.dart' show ReceiveFeature;
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/settings/settings_locator.dart';
import 'package:silent/silent.dart';
import 'package:silent/setup.dart';
import 'package:bb_mobile/router.dart';
import 'package:swap_feature/setup.dart';
import 'package:bb_mobile/features/wallet/wallet_locator.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_logs/bull_logs.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:btc_map/btc_map.dart';
import 'package:path_provider/path_provider.dart';
import 'package:secrets/secrets.dart';
import 'package:spend/setup.dart' show SpendCatalog;
import 'package:spend/spend.dart' show Spend;
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
  static Future<void> startWalletsAfterUnlock(GetIt locator) async {
    await locator<ForegroundWalletStartup>().start();
    unawaited(locator<RecoverBullFacade>().checkAtColdStart());
  }

  /// Foreground-only composition. Headless setup never opens this database.
  static Future<void> setupRecoverBull(
    GetIt locator, {
    required String databasePath,
  }) async {
    final settings = await SettingsRecoverBullBindings.setup(
      locator,
      databasePath: databasePath,
    );
    final wallets = RecoverBullWalletAdapter(
      locator<SecretsInventory>(),
      locator<DeveloperEnvironmentReader>(),
      locator<Secrets>(),
      (secret, network) => WalletRecoverBullBindings.restoreDefaults(
        locator<DefaultWalletProvisioning>(),
        secret,
        network,
      ),
    );
    locator.registerSingleton<RecoverBullWalletPort>(wallets);
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
        authority: switch (arkFunding) {
          Ok(:final value) => value,
          Err() => null,
        },
        installation: arkFundingDatabasePath == null ? null : installation,
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
    final swaps = await SwapEngineSetup.open(
      locator,
      inventory: locator<SecretsInventory>(),
    );
    if (swaps case Err()) return swaps;
    CoreLocator.registerUsecases(locator);
    mountPayjoin(locator, startRecovery: false);

    // Register feature-specific dependencies
    final inventory = locator<SecretsInventory>();
    locator.registerLazySingleton<OverviewSynchronization>(
      () => OverviewSynchronization.open(
        inventory: inventory,
        environment: locator<ActiveEnvironmentReader>(),
        catalog: () => locator<WalletCatalogPort>(),
        synchronize: locator<ForegroundWalletSync>().synchronizeDescriptor,
        refreshRevisions: locator<WalletNativeRuntime>().refreshAll,
        swaps: () => locator<SwapActivity>(),
        silent: () => locator<Silent>(),
      ),
      dispose: (synchronization) => synchronization.close(),
    );
    locator.registerLazySingleton<SwapSyncPort>(
      () => locator<OverviewSynchronization>().swapPolling,
    );
    locator.registerLazySingleton<Spend>(
      () => Spend.open(
        sync: locator<WalletNativeRuntime>(),
        secrets: locator<Secrets>(),
        arkFunding: locator<ArkFundingSigningGuard>(),
        catalog: SpendCatalog.fromInventory(inventory),
      ),
    );
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
          await startWalletsAfterUnlock(locator);
          if (!context.mounted) return;
          locator<StartupFeature>().completeUnlock(context);
          context.goNamed(WalletRoute.walletHome.name);
        },
        onBackUp: BackupsNavigation.open,
      ),
    );
    locator.registerLazySingleton(
      () => StartupFeature.mount(
        preferences: locator(),
        secrets: locator(),
        inventory: inventory,
        repair: locator<DefaultWalletRepair>(),
        backupLookup: MainnetBackupLookup(
          inventory,
          locator<RecoverBullWalletBackups>(),
          () => locator<RecoverBullFacade>(),
        ),
        tor: locator<Tor>(),
        swapStartup: locator<SwapStartup>(),
      ),
    );
    OnboardingLocator.setup(locator);
    final bip85 = inventory.bip85(locator<Secrets>());
    locator.registerSingleton<Bip85Derivations>(bip85);
    locator.registerSingleton(
      Bip85Feature.mount(
        derivations: bip85,
        inventory: inventory,
        preferences: locator<ActiveEnvironmentReader>(),
      ),
    );
    // Wallet's SP use cases resolve the facade lazily, after registration.
    WalletLocator.setup(locator);
    mountAddressView(locator);
    // Inventory survives disabled routing and missing endpoint build defines.
    final _ = await prepareArkCustodyReferences(
      locator,
      initializeNew: initializeArkFunding && installation.wasNeverProvisioned,
    );
    final silent = AppRouter.mountSilent(
      locator: locator,
      readDefaultFingerprint: readSilentDefaultFromInventory(inventory),
    );
    locator.registerSingleton<SilentFeature>(
      silent,
      dispose: (feature) async {
        if (await feature.close() case Err()) {
          log.warning('Silent feature close did not release the live account');
        }
      },
    );
    locator.registerLazySingleton<Silent>(() => silent.silent);
    SettingsLocator.setup(locator);
    setupBackgroundPreferences(
      locator,
      () => configureBackgroundTasks(backgroundTasksHandler),
      notificationChannelId: PaymentNotifications.channelId,
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
    final native = locator<WalletNativeRuntime>();
    final electrumSync = locator<ElectrumSync>();
    OverviewSynchronization overviewSync() =>
        locator<OverviewSynchronization>();
    locator.registerSingleton(
      TransactionsFeature.mount(
        locator,
        inventory: inventory,
        loadWallet: (key) => locator<WalletNativeRuntime>().loadWallet(key),
        findDescriptor: (key) => locator<WalletCatalogPort>().find(key),
        synchronize: (descriptor) =>
            locator<ForegroundWalletSync>().synchronizeDescriptor(descriptor),
        events: WalletHistoryEvents.foreground(
          revisions: native.changes,
          finished: electrumSync.finished,
          watchSyncPassActivity: () =>
              overviewSync().coordinator.syncPassActivity,
          isSyncPassActive: () => overviewSync().coordinator.isSyncPassActive,
        ),
        syncStarted: () => locator<ForegroundWalletSync>().started,
        syncFinished: () => locator<ForegroundWalletSync>().finished,
        orderSwaps: () => locator<OrderSwaps>(),
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
              ReplaceByFee.openForTransaction(
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
    locator.registerSingleton(
      ReceiveFeature.mount(
        locator,
        rootNavigatorKey: AppRouter.rootNavigatorKey,
        inventory: inventory,
        loadWallet: (key) => locator<WalletNativeRuntime>().loadWallet(key),
        readSigner: locator<SignerDevices>().read,
        poll: (id, {required isActive}) =>
            overviewSync().coordinator.pollWallet(id, isActive: isActive),
        refreshAfterLightningPayment: () async {
          final _ = await locator<GetWalletsUsecase>().execute(sync: true);
        },
        orderSwaps: () => locator<OrderSwaps>(),
        createOrder: ({required wallet, required amountSat, note}) =>
            locator<SwapFeature>().createReceiveOrder(
              wallet: wallet,
              amountSat: amountSat,
              note: note,
            ),
        setPayjoinEnabled: locator<SettingsFacade>().setPayjoinReceiveEnabled,
        openHome: (context) => context.goNamed(WalletRoute.walletHome.name),
        openPayjoinSettings: (context) =>
            context.pushNamed(SettingsRoute.payjoinSettings.name),
        successAnimation: AssetImage(Assets.animations.successTick.path),
        orderSwapUnderReview: (order) =>
            OrderSwapUnderReviewCard(orderSwap: order),
      ),
    );
    CoinsLocator.setup(
      locator,
      pollWallet: (id) =>
          overviewSync().coordinator.pollWallet(id, isActive: () => true),
    );
    locator.registerSingleton(
      SwapFeature.mount(
        swaps: locator<Swaps>(),
        orders: locator<OrderSwaps>(),
        inventory: inventory,
        sync: locator<WalletNativeRuntime>(),
        synchronize: (key) => locator<ForegroundWalletSync>().synchronizeKey(
          key,
          locator<WalletCatalogPort>(),
        ),
        finished: locator<ElectrumSync>().finished.map((event) => event.key),
        signerDevices: () => locator<SignerDevices>(),
        preferences: locator<Preferences>(),
        fees: locator<Fees>(),
        spend: locator<Spend>(),
        addresses: locator<AddressView>(),
        receive: locator<Receive>(),
        labels: locator<Labels>(),
        transactions: locator<Transactions>(),
        scheduler: () => locator<SwapSyncPort>(),
        ark: () => locator.isRegistered<ArkTransferFacade>()
            ? locator<ArkTransferFacade>()
            : null,
      ),
      dispose: (feature) => feature.dispose(),
    );
    locator.registerLazySingleton<SwapActivity>(() => locator<SwapFeature>());
    locator.registerLazySingleton(
      () => AllSeedViewFeature.mount(
        secrets: locator<Secrets>(),
        inventory: inventory,
        preferences: locator<ActiveEnvironmentReader>(),
        references: locator<SeedReferences>(),
        swaps: locator<BoltzSwaps>(),
        access: const Access(),
      ),
    );

    ExchangeLocator.setup(locator);
    LimitOrdersLocator.setup(locator);
    locator.registerSingleton(
      NetworkFeature.mount(
        services: locator,
        preferences: locator<Preferences>(),
        inventory: inventory,
        readBackup: (id) => locator<RecoverBullWalletBackups>().read(id),
      ),
    );

    locator.registerLazySingleton(() {
      final operations = WalletLocator.importOperations(locator);
      return ImportFeature.mount(
        preferences: locator<Preferences>(),
        servers: locator<ElectrumServersPort>(),
        secrets: locator<Secrets>(),
        inventory: inventory,
        admission: locator<ParentCustodyAdmissionPort>(),
        provisionMnemonic: operations.mnemonic,
        provisionDescriptor: operations.descriptor,
        provisionXpub: operations.xpub,
        networkOf: SettingsFacade.networkOf,
        onImported: (context) {
          context.read<WalletBloc>().add(const WalletStarted());
          context.goNamed(WalletRoute.walletHome.name);
        },
        onExit: (context) => context.goNamed(WalletRoute.walletHome.name),
        qrIllustration: AssetImage(Assets.misc.qRPlaceholder.path),
      );
    });

    locator.registerSingleton(
      ForegroundWalletStartup(
        initialize: () async {
          // Startup continues when native stores are unavailable.
          final _ = await locator<WalletNativeRuntime>().initialize();
        },
        startWatchers: () {
          locator<SilentFeature>().startForegroundWatchers();
          locator<SwapFeature>().start(
            watchOrders: startOrderSwapWatcher,
            watchAutoswap: startAutoswapWatcher,
          );
          SwapEngineSetup.followEnvironment(locator);
        },
        payjoin: startPayjoinRecovery
            ? () => locator<PayjoinLifecycle>()
            : null,
      ),
    );
    return const Ok(null);
  }
}
