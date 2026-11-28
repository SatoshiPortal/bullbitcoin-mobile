import 'dart:io' show File;

import 'package:background_tasks/background_tasks.dart';
import 'package:transactions/transactions.dart' show Transactions;
import 'package:bull_ark/bull_ark.dart' show ArkTransferFacade;
import 'package:sync/storage.dart' show SyncFreshness;
import 'package:sync/write.dart'
    show ElectrumSync, ForegroundWalletSynchronization, WalletNativeRuntime;

import 'dart:async';

import 'package:ark/funding.dart';
import 'package:bull_exchange/bull_exchange.dart'
    show
        AccelerateTransactionListTile,
        BullExchangeNavigation,
        BuyRoute,
        showSinpeReceiptBottomSheet;

import 'package:backups/backups.dart';
import 'package:notifications/payment_store.dart' show PaymentNotifications;
import 'package:bull_recoverbull/storage.dart';
import 'package:bull_recoverbull/setup.dart';
import 'package:overview/setup.dart';
import 'package:overview/catalogue.dart';
import 'package:overview/overview.dart'
    show OngoingSwaps, OverviewAmountDisplay, OverviewHomeController;
import 'package:startup/setup.dart';
import 'package:startup/startup.dart';
import 'package:provisioning/provisioning.dart';
import 'package:swaps/swaps.dart'
    show BoltzSwaps, SwapStartup, Swaps, SwapStore;
import 'package:secrets/storage.dart';
import 'package:material_ui/material_ui.dart' show AssetImage, Image;
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:wallet_import/setup.dart';
import 'package:labels/labels.dart';
import 'package:electrum/electrum.dart';
import 'package:secrets/bip85.dart';
import 'package:secrets/custody.dart';
import 'package:bip85/bip85.dart';
import 'package:all_seed_view/setup.dart';
import 'package:access/access.dart' show Access;
import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:bull_payjoin/bull_payjoin.dart'
    show PayjoinLifecycle, PayjoinPolicyAccess;
import 'package:fees_feature/fees_feature.dart' show FeesFeature;
import 'package:swaps/order_swaps.dart';
import 'package:signers/storage.dart' show SignerDevices;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mempool/mempool.dart';
import 'package:fees/fees.dart';
import 'package:exchange/exchange.dart' show Exchange, ExchangePlatform;
import 'package:preferences/preferences.dart';
import 'package:network/network.dart'
    show ExternalTorProxyDiagnostic, ExternalTorProxyStatus, NetworkFeature;
import 'package:bull_ark/ark_foreground_setup.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, Err, Failure, NetworkEnv, Ok;
import 'package:electrum/setup.dart'
    show
        ElectrumDefaultsProvisioner,
        ElectrumServersPort,
        ReadElectrumPreferences,
        RegtestElectrumProfile;
import 'package:bb_mobile/background_entrypoint.dart';
import 'package:bb_mobile/core_locator.dart';
import 'package:bb_mobile/native_runtime_setup.dart';
import 'package:settings/setup.dart' show SettingsRecoverBullBindings;
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/migration.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:bull_tor/tor.dart';
import 'package:settings/settings.dart';
import 'package:transactions/routes.dart';
import 'package:transactions/setup.dart';
import 'package:sync/sync.dart'
    show
        FrozenOutpoint,
        Wallet,
        SyncFailure,
        SyncStorageFailure,
        WalletConnectionPort,
        WalletKey,
        WalletCatalogPort;
import 'package:swap_feature/swap_feature.dart';
import 'package:address_view/address_view.dart';
import 'package:bb_mobile/address_view_setup.dart';
import 'package:access/setup.dart' show AccessFeature;
import 'package:views/setup.dart' show ViewsFeature;
import 'package:go_router/go_router.dart';
import 'package:overview/routes.dart';
import 'package:signers/routes.dart';
import 'package:scanning/scanning.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:coins/coins.dart';
import 'package:coins/setup.dart';
import 'package:onboarding/setup.dart';
import 'package:receive/receive.dart' show Receive;
import 'package:receive/setup.dart' show ReceiveFeature;
import 'package:send/send.dart' show ReplaceByFee, SendNavigation;
import 'package:bull_quick_actions/setup.dart';
import 'package:silent/silent.dart';
import 'package:silent/setup.dart';
import 'package:bb_mobile/router.dart';
import 'package:swap_feature/setup.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_logs/bull_logs.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:btc_map/btc_map.dart';
import 'package:path_provider/path_provider.dart';
import 'package:backup_metadata/setup.dart' show BackupMetadataFeature;
import 'package:secrets/secrets.dart' hide Language;
import 'package:spend/setup.dart' show SpendCatalog;
import 'package:spend/spend.dart' show Spend;

final GetIt locator = GetIt.instance;

/// Requests a mounted wallet refresh without recreating a catalog aggregate.
Future<void> refreshMountedWallets({bool user = false}) async {
  final home = locator<OverviewHomeController>();
  if (user) {
    await home.refresh();
    return;
  }
  home.refreshVisible();
  await home.waitForRefresh();
}

class AppLocator {
  static Future<void> startWalletsAfterUnlock(GetIt locator) async {
    final startup = locator<ForegroundWalletStartup>();
    startup.confirmUnlock();
    await startup.start();
    locator<OverviewHomeController>().startBackupChecks();
    unawaited(locator<RecoverBullFacade>().checkAtColdStart());
  }

  /// Data backup: always composed, inert until the user turns it on and
  /// confirms a destination, an account and wallets. The setting is the
  /// selection kept in its encrypted journal: off by default, persistent.
  static void setupDataBackup(GetIt locator, {required String journalPath}) {
    final secrets = locator<Secrets>();
    final keys = secrets.databaseKeys(module: 'backup_metadata');
    final feature = BackupMetadataFeature.open(
      locator: locator,
      inventory: locator<SecretsInventory>(),
      secrets: secrets,
      labels: locator<Labels>(),
      journal: File(journalPath),
      journalKey: () async => switch (await keys.getOrCreate(name: 'journal')) {
        Ok(:final value) => value.pragma,
        Err() => null,
      },
      hasSilentPaymentsWallet: () async =>
          (await readSilentDefaultFromInventory(locator<SecretsInventory>())(
            BitcoinNetwork.mainnet,
          )).fold((value) => value != null, (_) => false),
      backupVerified: (fingerprint, network) async =>
          switch (await locator<RecoverBullWalletBackups>(
            instanceName: network.env == NetworkEnv.regtest ? 'regtest' : null,
          ).projection(fingerprint)) {
            Ok(:final value) =>
              value.physicalBackupTested || value.encryptedVaultTested,
            Err() => false,
          },
    );
    feature.trigger.start();
    locator.registerSingleton<BackupMetadataFeature>(
      feature,
      dispose: (value) => value.trigger.dispose(),
    );
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
      locator<DefaultWalletProvisioning>(),
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
      inventory: locator<SecretsInventory>(),
      activeEnvironment: locator<ActiveEnvironmentReader>(),
      normalBackups: locator<RecoverBullWalletBackups>(),
      regtestBackups: locator<RecoverBullWalletBackups>(
        instanceName: 'regtest',
      ),
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
    GetIt locator, {
    required Future<Result<Labels, LabelFailure>> Function(
      Future<Result<List<FrozenOutpoint>, SyncFailure>> Function() listFreezes,
      Future<Result<void, SyncFailure>> Function(List<FrozenOutpoint>) freeze,
      Future<Wallet> Function(String) openWallet,
    )
    openLabels,
    required Future<Result<Electrum, ElectrumFailure>> Function(
      ReadElectrumPreferences readPreferences,
      Tor Function() tor,
    )
    openElectrum,
    required Future<Result<Preferences, PreferencesFailure>> Function()
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
    Future<Result<void, Failure>> Function(
      Preferences,
      ElectrumDefaultsProvisioner,
    )?
    prepareInitialNetwork,
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
            // Without a composed authority nothing has authenticated: locked.
            authority: locator.isRegistered<SessionAuthority>()
                ? locator<SessionAuthority>()
                : SessionAuthority(),
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
    final openedPreferences = await openPreferences();
    if (openedPreferences case Err(:final failure)) return Err(failure);
    final preferences =
        (openedPreferences as Ok<Preferences, PreferencesFailure>).value;
    if (prepareInitialNetwork case final prepare?) {
      var prepared = false;
      try {
        final result = await prepare(
          preferences,
          locator<ElectrumDefaultsProvisioner>(),
        );
        if (result case Err()) return result;
        prepared = true;
      } finally {
        if (!prepared) await preferences.close();
      }
    }
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
        readInSession: inventory.readInSession,
        environment: locator<ActiveEnvironmentReader>(),
        catalog: () => locator<WalletCatalogPort>(),
        synchronize: locator<ForegroundWalletSynchronization>().execute,
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
    locator.registerSingleton<AccessFeature>(
      AccessFeature.mount(
        services: locator,
        inventory: inventory,
        onUnlocked: (context) async {
          await startWalletsAfterUnlock(locator);
          if (!context.mounted) return;
          locator<StartupFeature>().completeUnlock(context);
          context.goNamed(WalletRoute.walletHome.name);
        },
        onBackUp: BackupsNavigation.open,
      ),
    );
    locator.registerSingleton<ViewsFeature>(
      ViewsFeature.mount(inventory: inventory, enabled: multiViewSupported),
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
    locator.registerLazySingleton(
      () => OnboardingFeature.mount(
        defaultWallets: locator<DefaultWalletProvisioning>(),
        records: (network) => locator<RecoverBullWalletBackups>(
          instanceName: network.env == NetworkEnv.regtest ? 'regtest' : null,
        ),
        walletImport: locator<ImportFeature>(),
        onWalletReady: (context) {
          unawaited(refreshMountedWallets());
          context.goNamed(WalletRoute.walletHome.name);
        },
        languageOf: (context) =>
            Settings.languageOf(context) ?? Language.unitedStatesEnglish,
        changeLanguage: Settings.changeLanguage,
        logo: SuperuserTapUnlocker(
          child: Image.asset(Assets.logos.bbLogoWhite.path, height: 127),
        ),
        background: AssetImage(Assets.backgrounds.bgLong.path),
        encryptedBackupIcon: AssetImage(Assets.misc.encryptedVault.path),
        physicalBackupIcon: AssetImage(Assets.misc.physicalBackup.path),
      ),
    );
    final bip85 = inventory.bip85(locator<Secrets>());
    locator.registerSingleton<Bip85Derivations>(bip85);
    locator.registerSingleton(
      Bip85Feature.mount(
        derivations: bip85,
        inventory: inventory,
        preferences: locator<ActiveEnvironmentReader>(),
        lockChanges: inventory.lockedChanges,
      ),
    );
    registerNativeRuntime(
      locator,
      overview: () => locator<OverviewSynchronization>(),
    );
    locator.registerFactory<NetworkWalletProvisioning>(
      () => NetworkWalletProvisioning(
        settings: locator<DeveloperEnvironmentReader>(),
        inventory: locator<SecretsInventory>(),
        defaults: locator<DefaultWalletProvisioning>(),
        secrets: locator<Secrets>(),
      ),
    );
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
    Stream<bool> watchExchangeOffer({required bool onlyWhileOff}) =>
        locator<Exchange>().watchActivationOffer(
          platform: ExchangePlatform.current,
          currentSuperuser: () => locator<Settings>().isSuperuser,
          superuserChanges: locator<Settings>().watchSuperuser(),
          onlyWhileOff: onlyWhileOff,
        );
    locator.registerLazySingleton<QuickActionsFeature>(
      () => QuickActionsFeature.mount(
        isIOS: ExchangePlatform.current == ExchangePlatform.ios,
        warning: log.warning,
        exchangeVisible: () => locator<Exchange>().watchTradingVisibility(
          platform: ExchangePlatform.current,
          superuserChanges: locator<Settings>().watchSuperuser(),
        ),
        exchangeEntry: () => watchExchangeOffer(onlyWhileOff: false),
        exchangeOffered: () => watchExchangeOffer(onlyWhileOff: true),
      ),
      dispose: (feature) => feature.close(),
    );
    locator.registerSingleton(
      BackgroundSchedule.open(dispatcher: backgroundTasksHandler),
    );
    locator.registerLazySingleton(
      () => Settings.open(
        preferences: locator<Preferences>(),
        electrum: locator<ElectrumDefaultsProvisioner>(),
        exchange: locator<Exchange>(),
        silent: locator<Silent>(),
        payjoin: locator<PayjoinPolicyAccess>(),
        backgroundSchedule: locator<BackgroundSchedule>(),
        notificationChannelId: PaymentNotifications.channelId,
      ),
      dispose: (settings) => settings.close(),
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
    locator.registerSingleton(
      locator<SyncFreshness>().recordCompletions(
        electrumSync.finished.map((event) => event.key),
        inventory,
      ),
      instanceName: 'syncFreshness',
      dispose: (subscription) => subscription.cancel(),
    );
    OverviewSynchronization overviewSync() =>
        locator<OverviewSynchronization>();
    locator.registerSingleton(
      TransactionsFeature.mount(
        locator,
        inventory: inventory,
        loadWallet: (key) => locator<WalletNativeRuntime>().loadWallet(key),
        findDescriptor: (key) => locator<WalletCatalogPort>().find(key),
        synchronize: (descriptor) =>
            locator<ForegroundWalletSynchronization>().execute(descriptor),
        events: WalletHistoryEvents.foreground(
          revisions: native.changes,
          finished: electrumSync.finished,
          watchSyncPassActivity: () =>
              overviewSync().coordinator.syncPassActivity,
          isSyncPassActive: () => overviewSync().coordinator.isSyncPassActive,
        ),
        syncStarted: () => electrumSync.started.map((key) => key.id),
        syncFinished: () => electrumSync.finished.map((event) => event.key.id),
        orderSwaps: () => locator<OrderSwaps>(),
        pollSettlement: (id, {required isActive}) =>
            overviewSync().coordinator.pollWallet(id, isActive: isActive),
        actions: TransactionUiActions(
          openExchange: (context) =>
              context.goNamed(BullExchangeNavigation.dashboardName),
          openWalletHome: (context) =>
              context.goNamed(WalletRoute.walletHome.name),
          refreshWallets: (context) =>
              locator<OverviewHomeController>().refresh(),
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
        refreshAfterLightningPayment: () =>
            locator<OverviewHomeController>().refresh(),
        orderSwaps: () => locator<OrderSwaps>(),
        createOrder: ({required wallet, required amountSat, note}) =>
            locator<SwapFeature>().createReceiveOrder(
              wallet: wallet,
              amountSat: amountSat,
              note: note,
            ),
        // Resolved on use: Settings depends on Exchange, registered below.
        setPayjoinEnabled: (enabled, {required requestConsent}) =>
            locator<Settings>().setPayjoinReceiveEnabled(
              enabled,
              requestConsent: requestConsent,
            ),
        openHome: (context) => context.goNamed(WalletRoute.walletHome.name),
        openPayjoinSettings: (context) =>
            context.pushNamed(SettingsRoute.payjoinSettings.name),
        successAnimation: AssetImage(Assets.animations.successTick.path),
        orderSwapUnderReview: (order) =>
            OrderSwapUnderReviewCard(orderSwap: order),
      ),
    );
    locator.registerLazySingleton(
      () => CoinsFeature.mount<WalletKey>(
        inventory: inventory,
        loadWallet: locator<WalletNativeRuntime>().loadWallet,
        readFrozenOutpoints: native.readFrozenOutpoints,
        freezeWalletOutpoints: native.freezeWalletOutpoints,
        unfreezeOutpoints: native.unfreezeOutpoints,
        labels: locator<Labels>(),
        preferences: locator<AmountDisplayPreferencesReader>(),
        poll: (id) =>
            overviewSync().coordinator.pollWallet(id, isActive: () => true),
        watchRevisions: (id) => native.changes
            .map((revision) => revision.stamp.key.id)
            .where((walletId) => walletId == id),
        watchStartedSyncs: (id) => electrumSync.started
            .map((key) => key.id)
            .where((walletId) => walletId == id),
        watchFinishedSyncs: (id) => electrumSync.finished
            .map((event) => event.key.id)
            .where((walletId) => walletId == id),
        walletId: (wallet) => wallet.id,
        missingWalletRedirect: WalletRoute.walletHome.path,
        onSend: SendNavigation.openSelected,
        onSweep: SendNavigation.openSweep,
      ),
    );
    locator.registerLazySingleton<Coins>(() => locator<CoinsFeature>().coins);
    locator.registerSingleton(
      SwapFeature.mount(
        swaps: locator<Swaps>(),
        orders: locator<OrderSwaps>(),
        inventory: inventory,
        sync: locator<WalletNativeRuntime>(),
        synchronize: (key) => locator<ForegroundWalletSynchronization>()
            .executeKey(key, locator<WalletCatalogPort>()),
        finished: locator<ElectrumSync>().finished.map((event) => event.key),
        signerDevices: () => locator<SignerDevices>(),
        preferences: locator<Preferences>(),
        fees: locator<Fees>(),
        spend: locator<Spend>(),
        addresses: locator<AddressView>(),
        receive: locator<Receive>(),
        labels: locator<Labels>(),
        transactions: locator<Transactions>(),
        pollSettlement: (id, {required isActive}) =>
            overviewSync().coordinator.pollWallet(id, isActive: isActive),
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

    locator.registerSingleton(
      NetworkFeature.mount(
        services: locator,
        silent: locator<Silent>(),
        preferences: locator<Preferences>(),
        inventory: inventory,
        readBackup: (id) => locator<RecoverBullWalletBackups>().read(id),
      ),
    );

    locator.registerLazySingleton(
      () => ImportFeature.mount(
        preferences: locator<Preferences>(),
        servers: locator<ElectrumServersPort>(),
        secrets: locator<Secrets>(),
        inventory: inventory,
        admission: locator<ParentCustodyAdmissionPort>(),
        accounts: locator<WalletProvisioning>(),
        networkOf: Settings.networkOf,
        onImported: (context) {
          unawaited(refreshMountedWallets());
          context.goNamed(WalletRoute.walletHome.name);
        },
        onExit: (context) => context.goNamed(WalletRoute.walletHome.name),
        qrIllustration: AssetImage(Assets.misc.qRPlaceholder.path),
      ),
    );

    WalletNativeRuntime walletRuntime() => locator<WalletNativeRuntime>();
    final balances = ForegroundBalanceStartup.mount(
      runtime: walletRuntime,
      inventory: inventory,
      preferences: locator<Preferences>(),
    );
    locator.registerSingleton(
      ForegroundWalletStartup(
        initialize: () => walletRuntime().initialize(),
        balances: balances,
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
        engines: SessionEngines([
          if (startPayjoinRecovery)
            SessionEngine(
              name: 'payjoin',
              suspend: () => locator<PayjoinLifecycle>().suspend(),
              resume: () {
                locator<PayjoinLifecycle>().reopen();
                unawaited(locator<PayjoinLifecycle>().resume());
              },
            ),
          SessionEngine(
            name: 'swaps',
            suspend: () => locator<Swaps>().suspend(),
            resume: () => locator<Swaps>().resume(),
          ),
          SessionEngine(
            name: 'swap-watchers',
            suspend: () => locator<SwapFeature>().suspend(),
            resume: () => locator<SwapFeature>().resume(),
          ),
          SessionEngine(
            name: 'silent',
            suspend: () => locator<SilentFeature>().suspend(),
            resume: () => locator<SilentFeature>().resume(),
          ),
          SessionEngine(
            name: 'ark',
            suspend: () => locator.isRegistered<ArkForegroundHost>()
                ? locator<ArkForegroundHost>().suspend()
                : Future<void>.value(),
            resume: () {
              if (!locator.isRegistered<ArkForegroundHost>()) return;
              final host = locator<ArkForegroundHost>()..reopen();
              unawaited(host.resume());
            },
          ),
        ]),
      ),
      dispose: (startup) => startup.dispose(),
    );
    final catalogue = OverviewCatalogue.mount(
      balances: balances.observation,
      inventory: inventory,
    );
    locator.registerSingleton(catalogue, dispose: (value) => value.close());
    final torProxy = ExternalTorProxyDiagnostic(
      locator<TorProxyPreferencesReader>(),
      locator<Tor>(),
    );
    locator.registerSingleton<OverviewHomeController>(
      OverviewHomeController(
        catalogue: CatalogueHomeSource(catalogue),
        sync: CoordinatedHomeSync(overviewSync().coordinator),
        amountDisplay: OverviewAmountDisplay(
          locator<AmountDisplayPreferencesReader>(),
        ),
        ongoingSwaps: OngoingSwaps(locator<SwapStore>()),
        swapActivity: locator<SwapActivity>(),
        swapServerCheck: SwapHomeServerCheck(locator<BoltzSwaps>()),
        readBackupWarning: () => BackupsFeature.readWarningNeeded(
          locator<RecoverBullFacade>().backupWarningNeeded,
        ),
        readPhysicalBackup: (key) async {
          final store = locator<RecoverBullWalletBackups>(
            instanceName: key.network.env == NetworkEnv.regtest
                ? 'regtest'
                : null,
          );
          return switch (await store.read(key.id)) {
            Ok(:final value) => value?.physicalBackupTested ?? false,
            Err() => null,
          };
        },
        proxyNeedsAttention: () async {
          final status = await torProxy.check();
          return status == ExternalTorProxyStatus.unavailable ||
              status == ExternalTorProxyStatus.unreadable;
        },
        silentHome: SilentHomeObservation(locator<Silent>()),
        syncStarted: electrumSync.runsStarted.map(
          (event) => (key: event.key, runId: event.runId),
        ),
        syncFinished: electrumSync.finished.map((event) => event.key),
        electrumResults: ElectrumSyncResult.watch(electrumSync.finished).map(
          (result) => (
            key: result.key,
            runId: result.runId,
            isLiquid: result.isLiquid,
            success: result.success,
          ),
        ),
      ),
      dispose: (controller) => controller.close(),
    );
    return const Ok(null);
  }
}
