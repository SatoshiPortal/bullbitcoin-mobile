import 'package:address_view/routes.dart' show AddressViewFeature;
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bitcoin_price/testing.dart';
import 'package:settings/testing.dart';
import 'package:overview/overview.dart' show WalletHomeAppBar;
import 'package:announcements/setup.dart' show AnnouncementDismissals;
import 'package:labels/labels.dart' show Labels;
import 'package:access/access.dart' show Access;
import 'package:all_seed_view/setup.dart';
import 'package:bip85/bip85.dart';
import 'package:secrets/custody.dart';
import 'package:provisioning/provisioning.dart';
import 'package:signers/storage.dart' show SignerDevices;
import 'package:swaps/order_swaps.dart' show OrderSwaps;
import 'package:swaps/swaps.dart' show SwapStore;
import 'package:sync/sync.dart'
    show
        PublicWalletDescriptor,
        WalletCatalogPort,
        InputReservation,
        InputReservationPort,
        ReservedAddressPort,
        SyncFailure,
        SyncNotFoundFailure,
        WalletConnection,
        WalletConnectionPort,
        WalletKey;
import 'package:sync/testing.dart' show MemoryFreezeStore;
import 'package:swaps/swaps.dart' show BoltzSwaps;
import 'package:transactions/routes.dart';
import 'package:transactions/setup.dart';

import '../transactions/support/transaction_ui_actions.dart';

import 'package:coins/setup.dart' show CoinsFeature;
import 'package:fees/fees.dart';
import 'package:electrum/electrum.dart' show Electrum, ElectrumTransactions;
import 'package:electrum/setup.dart' show ElectrumServersPort;
import 'package:wallet_import/wallet_import.dart';
import 'package:onboarding/setup.dart';
import 'package:fees_feature/fees_feature.dart' show FeesFeature;

import 'dart:io';

import 'package:access/setup.dart';
import 'package:views/setup.dart' show ViewsFeature;
import 'package:exchange/exchange.dart'
    show
        Exchange,
        ExchangeAccessSignedIn,
        ExchangeAvailability,
        ExchangeEnvironment,
        ExchangeSession,
        ExchangeAccountUnavailableFailure;
import 'package:exchange/setup.dart' show ExchangeAccessLifecycle;
import 'package:exchange/testing.dart' show exchangeForTesting;
import 'package:bull_exchange/bull_exchange.dart'
    show BullExchangeNavigation, ExchangeSessionScope, PayRoute, SellRoute;
import 'package:bull_payjoin/bull_payjoin.dart' show PayjoinSender;
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bull_ark/ark_ui.dart';
import 'package:bull_ark/bull_ark.dart' show ArkFacade, ArkAccountId;
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_quick_actions/setup.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullTopBar, bullUiLocalizationsDelegate;
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:signers/routes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network/network.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, BitcoinUnit, Fingerprint, Network, ScriptType;
import 'package:receive/setup.dart';
import 'package:secrets/secrets.dart' hide Language;
import 'package:swap_feature/swap_feature.dart' show SwapFeature;
import 'package:swap_feature/testing.dart' show swapSettingsRoute;
import 'package:swaps/swaps.dart' show SwapRouting, SwapServerSettings;
import 'package:secrets/testing.dart';
import 'package:spend/spend.dart' show Spend;
import 'package:spend/testing.dart' show FakeSpend;

import '../../support/inventory_fixture.dart';

import 'package:silent/setup.dart';
import 'package:silent/silent.dart' show Silent;
import 'package:secrets/storage.dart' show SecretsInventory;
import 'package:sync/write.dart'
    show ElectrumSync, WalletNativeLifecycle, WalletNativeRuntime;

class PricePreferences extends Mock
    implements
        ActiveEnvironmentReader,
        AmountDisplayPreferencesReader,
        RuntimeDisplayPreferencesReader {}

class ImportPreferences extends Mock implements Preferences {}

class ElectrumServers extends Mock implements ElectrumServersPort {}

class _ExchangeAccess extends Mock implements ExchangeAccessLifecycle {}

class _WalletHomeBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

class _WalletSettingsCubit extends MockCubit<SettingsState>
    implements SettingsCubit {}

class SilentPreferences extends Mock implements Preferences {}

class _Silent extends Mock implements Silent {}

class Wallets extends Mock implements RecoverBullWalletPort {}

class Memory implements QuickActionsStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> remove(String key) async {}
}

class _UnusedPreferences extends Mock implements Preferences {}

class _MockFees extends Mock implements Fees {}

class _MockElectrum extends Mock implements Electrum {}

class _MockElectrumTransactions extends Mock implements ElectrumTransactions {}

class _UnusedSwapRouting extends Mock implements SwapRouting {}

class _UnusedSwapServers extends Mock implements SwapServerSettings {}

class _SwapRoutes extends Fake implements SwapFeature {
  @override
  final List<GoRoute> routes = [
    swapSettingsRoute(
      _UnusedSwapRouting(),
      _UnusedSwapServers(),
      _UnusedSwaps(),
    ),
  ];

  @override
  final List<GoRoute> recoveryRoutes = const [];

  @override
  GoRoute get autoswapSettingsRoute => GoRoute(
    name: 'autoswapSettings',
    path: 'autoswap-settings',
    builder: (_, _) => const SizedBox.shrink(),
  );
}

class _UnusedLabels extends Mock implements Labels {}

class _UnusedNative extends Mock implements WalletNativeLifecycle {}

class _UnusedReferences extends Mock implements SeedReferencePort {}

class _UnusedCustodyAdmission extends Mock
    implements ParentCustodyAdmissionPort {}

class _UnusedSwaps extends Mock implements BoltzSwaps {}

class _UnusedSwapStore extends Mock implements SwapStore {}

class _UnusedOrders extends Mock implements OrderSwaps {}

class _UnusedDismissals extends Mock implements AnnouncementDismissals {}

class _UnusedReserved implements ReservedAddressPort {
  @override
  Future<Result<bool, SyncFailure>> isReserved(WalletKey key, String address) =>
      throw StateError('Unexpected address reservation read');
}

class _UnusedInputReservations implements InputReservationPort {
  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() =>
      throw StateError('Unexpected input reservation read');
}

class _UnusedConnections implements WalletConnectionPort {
  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) => throw StateError('Unexpected sync connection');
}

class _UnusedAccounts implements WalletProvisioning {
  @override
  Future<Result<void, WalletProvisioningFailure>> resume() =>
      throw StateError('Unexpected provisioning resume');

  @override
  Future<Result<String, WalletProvisioningFailure>> createDefault(
    Secret secret,
    Network network, {
    DateTime? birthday,
  }) => throw StateError('Unexpected default provisioning');

  @override
  Future<Result<void, ParentCustodyFailure>> importMnemonic({
    required Fingerprint parent,
    required Secrets secrets,
    required ParentCustodyAdmissionPort admission,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    String? label,
  }) => throw StateError('Unexpected mnemonic provisioning');

  @override
  Future<Result<void, WalletProvisioningFailure>> importDescriptor(
    WatchOnlyAccount account,
  ) => throw StateError('Unexpected descriptor provisioning');

  @override
  Future<Result<void, WalletProvisioningFailure>> importXpub({
    required String xpub,
    required BitcoinNetwork network,
    required ScriptType scriptType,
    required String label,
  }) => throw StateError('Unexpected xpub provisioning');
}

class _UnusedProvisioning extends Mock implements DefaultWalletProvisioning {}

final class _EmptyWalletCatalog implements WalletCatalogPort {
  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      const Ok([]);

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async => const Err(SyncNotFoundFailure());
}

void main() {
  testWidgets(
    'actual shell routes keep unavailable Ark entries inert and navigable',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync('ark-route-');
      final exchange = _ExchangeAccess();
      final wallets = Wallets();
      var promptFactories = 0;
      final quickActions = QuickActionsFeature.mount(
        storage: Memory(),
        warning: (_) {},
        isIOS: false,
        exchangeVisible: () => const Stream.empty(),
        exchangeEntry: () => const Stream.empty(),
        exchangeOffered: () {
          promptFactories++;
          return const Stream.empty();
        },
      );
      final recovery = RecoverBullFeature.create(
        secrets: Secrets(
          authority: unlockedSessionAuthority(),
          scratchDirectory: () async => directory.path,
        ),
        wallets: wallets,
      );
      locator.registerSingleton<Exchange>(
        exchangeForTesting(
          access: exchange,
          getAccount: (_) async =>
              const Err(ExchangeAccountUnavailableFailure()),
          listAnnouncements: (_) async => const Ok([]),
        ),
      );
      locator.registerSingleton<QuickActionsFeature>(
        quickActions,
        dispose: (owner) => owner.close(),
      );
      locator.registerSingleton<RecoverBullFeature>(recovery);
      FakeSecureStoragePlatform().install();
      final inventoryFixture = await tester.runAsync(
        () => InventoryFixture.open(directory, withSignerDevices: true),
      );
      if (inventoryFixture == null) throw StateError('Inventory unavailable');
      final signerDevices = inventoryFixture.signerDevices;
      if (signerDevices == null) throw StateError('Signer devices unavailable');
      final accessServices = GetIt.asNewInstance();
      locator.registerSingleton(
        AccessFeature.mount(
          services: accessServices,
          inventory: inventoryFixture.inventory,
          onUnlocked: (_) {},
          onBackUp: (_) async {},
        ),
      );
      locator.registerSingleton<ViewsFeature>(
        ViewsFeature.mount(
          inventory: inventoryFixture.inventory,
          enabled: false,
        ),
      );
      final signerServices = GetIt.asNewInstance();
      locator.registerSingleton(
        SignersFeature.mount(
          services: signerServices,
          writeNfc: (_, _, _, _) async {},
        ),
      );
      final networkServices = GetIt.asNewInstance();
      final fees = _MockFees();
      networkServices.registerSingleton<Fees>(fees);
      locator.registerSingleton(
        NetworkFeature.mount(
          services: networkServices,
          silent: _Silent(),
          preferences: _UnusedPreferences(),
          inventory: inventoryFixture.inventory,
          readBackup: (_) async => const Ok(null),
        ),
      );
      locator.registerSingleton(
        FeesFeature.mount(fees: () => throw StateError('Unexpected fees read')),
      );
      locator.registerSingleton<SwapFeature>(_SwapRoutes());
      locator.registerSingleton(
        SilentFeature.mount(
          preferences: SilentPreferences(),
          secrets: Secrets(
            authority: unlockedSessionAuthority(),
            scratchDirectory: () async => directory.path,
          ),
          readDefaultFingerprint: (_) async => const Ok(null),
          readRouteAccess: (_) =>
              (environment: null, isSuperuser: false, isDevModeEnabled: false),
          walletHomePath: '/wallet-home',
          openSend: (_) {},
          balanceBuilder: (_, _) => const SizedBox(),
          settingsIconBuilder: (_) => const SizedBox(),
        ),
      );
      final preferences = PricePreferences();
      final electrum = _MockElectrum();
      when(() => electrum.transactions).thenReturn(_MockElectrumTransactions());
      locator.registerSingleton<Spend>(FakeSpend());
      locator.registerSingleton<Fees>(fees);
      locator.registerSingleton<Electrum>(electrum);
      locator.registerSingleton<ActiveEnvironmentReader>(preferences);
      locator.registerSingleton(
        BitcoinPriceFeature.mount(
          environment: preferences,
          amountDisplay: preferences,
          display: preferences,
        ),
      );
      locator.registerSingleton(
        CoinsFeature.mount<String>(
          inventory: inventoryFixture.inventory,
          loadWallet: (_) async =>
              throw StateError('Unexpected coins wallet read'),
          readFrozenOutpoints: () => fail('Unexpected freeze read'),
          freezeWalletOutpoints: (_, _) => fail('Unexpected freeze'),
          unfreezeOutpoints: (_) => fail('Unexpected unfreeze'),
          labels: _UnusedLabels(),
          preferences: preferences,
          poll: (_) async {},
          watchRevisions: (_) => const Stream.empty(),
          watchStartedSyncs: (_) => const Stream.empty(),
          watchFinishedSyncs: (_) => const Stream.empty(),
          walletId: (id) => id,
          missingWalletRedirect: '/wallet-home',
          onSend: (_, _, _) async {},
          onSweep: (_, _, _) async {},
        ),
      );
      final secrets = Secrets(
        authority: unlockedSessionAuthority(),
        scratchDirectory: () async => directory.path,
      );
      final inventory = inventoryFixture.inventory;
      final references = SeedReferences(
        _UnusedReferences(),
        admission: _UnusedCustodyAdmission(),
        backupVerification: const FakeInventoryBackups(),
      );
      // The router resolves the settings details page at construction: every
      // owner it reads there must be present, even though this test never
      // opens the page.
      locator.registerSingleton<SecretsInventory>(inventory);
      locator.registerSingleton<Secrets>(secrets);
      locator.registerSingleton<SignerDevices>(signerDevices);
      locator.registerSingleton<SwapStore>(_UnusedSwapStore());
      locator.registerSingleton<OrderSwaps>(_UnusedOrders());
      locator.registerSingleton<AnnouncementDismissals>(_UnusedDismissals());
      locator.registerSingleton<SeedReferences>(references);
      final electrumSync = ElectrumSync(
        connections: _UnusedConnections(),
        documentsDirectory: () async => directory.path,
        readRevision: (_) async => const Err(SyncNotFoundFailure()),
      );
      locator.registerSingleton<ElectrumSync>(electrumSync);
      final nativeRuntime = WalletNativeRuntime.open(
        catalog: _EmptyWalletCatalog(),
        reserved: _UnusedReserved(),
        inputReservations: _UnusedInputReservations(),
        deleteCatalogEntry: (_) async => const Ok(null),
        sync: electrumSync,
        documentsDirectory: () async => directory.path,
        freezes: MemoryFreezeStore(),
        connections: _UnusedConnections(),
      );
      locator.registerSingleton<WalletNativeRuntime>(nativeRuntime);
      locator.registerSingleton(
        AddressViewFeature.mount(
          labels: _UnusedLabels(),
          inventory: inventory,
          native: _UnusedNative(),
          loadWallet: (_) => throw StateError('Unexpected address wallet read'),
          revisions: const Stream.empty(),
        ),
      );
      locator.registerSingleton(
        Bip85Feature.mount(
          derivations: inventory.bip85(secrets),
          inventory: inventory,
          preferences: preferences,
          lockChanges: inventory.lockedChanges,
        ),
      );
      locator.registerSingleton(
        AllSeedViewFeature.mount(
          secrets: secrets,
          inventory: inventory,
          preferences: preferences,
          references: references,
          swaps: _UnusedSwaps(),
          access: const Access(),
        ),
      );
      locator.registerSingleton(
        ImportFeature.mount(
          preferences: ImportPreferences(),
          servers: ElectrumServers(),
          secrets: secrets,
          inventory: inventory,
          admission: _UnusedCustodyAdmission(),
          accounts: _UnusedAccounts(),
          networkOf: (_) => null,
          onExit: (_) {},
          onImported: (_) {},
          qrIllustration: const AssetImage('unused.png'),
        ),
      );
      final transactionServices = GetIt.asNewInstance();
      locator.registerSingleton(
        TransactionsFeature.mount(
          transactionServices,
          inventory: inventoryFixture.inventory,
          loadWallet: (_) =>
              throw StateError('Unexpected transaction history read'),
          findDescriptor: (_) => throw StateError('Unexpected descriptor read'),
          synchronize: (_) => throw StateError('Unexpected wallet sync'),
          events: WalletHistoryEvents(
            watchRevisions: ({walletId}) => const Stream.empty(),
            watchSyncPassActivity: () => const Stream.empty(),
            watchSyncFinished: () => const Stream.empty(),
            isSyncPassActive: () => false,
          ),
          syncStarted: () => const Stream.empty(),
          syncFinished: () => const Stream.empty(),
          orderSwaps: () => throw StateError('Unexpected swap history read'),
          pollSettlement: (_, {required isActive}) async {},
          actions: transactionUiActions,
          scope: (child) => child,
        ),
      );
      final receiveServices = GetIt.asNewInstance()
        ..registerSingleton<ActiveEnvironmentReader>(preferences);
      locator.registerSingleton(
        ReceiveFeature.mount(
          receiveServices,
          rootNavigatorKey: AppRouter.rootNavigatorKey,
          inventory: inventory,
          loadWallet: (_) => throw StateError('Unexpected receive wallet read'),
          readSigner: (_) => throw StateError('Unexpected receive signer read'),
          poll: (_, {required isActive}) async {},
          refreshAfterLightningPayment: () async {},
          orderSwaps: () => throw StateError('Unexpected receive order read'),
          createOrder: ({required wallet, required amountSat, note}) =>
              throw StateError('Unexpected receive order creation'),
          setPayjoinEnabled: (_, {required requestConsent}) =>
              throw StateError('Unexpected Payjoin consent change'),
          openHome: (_) {},
          openPayjoinSettings: (_) {},
          successAnimation: const AssetImage('unused.gif'),
          orderSwapUnderReview: (_) => const SizedBox(),
        ),
      );
      const unusedImage = AssetImage('unused.png');
      locator.registerSingleton(
        OnboardingFeature.mount(
          defaultWallets: _UnusedProvisioning(),
          records: (_) => throw StateError('Unexpected backup records'),
          walletImport: locator<ImportFeature>(),
          onWalletReady: (_) {},
          languageOf: (_) => Language.unitedStatesEnglish,
          changeLanguage: (_, _) {},
          logo: const SizedBox.shrink(),
          background: unusedImage,
          encryptedBackupIcon: unusedImage,
          physicalBackupIcon: unusedImage,
        ),
      );
      final router = AppRouter.router;
      expect(locator.isRegistered<PayjoinSender>(), isFalse);
      expect(router.namedLocation(PayRoute.pay.name), PayRoute.pay.path);
      expect(router.namedLocation(SellRoute.sell.name), SellRoute.sell.path);
      expect(promptFactories, 0);
      addTearDown(() async {
        router.dispose();
        await recovery.dispose();
        await locator.unregister<AccessFeature>();
        await locator.unregister<ViewsFeature>();
        await locator.unregister<AddressViewFeature>();
        await locator.unregister<Bip85Feature>();
        await locator.unregister<AllSeedViewFeature>();
        await accessServices.reset();
        await locator.unregister<SignersFeature>();
        await signerServices.reset();
        await locator.unregister<Exchange>();
        await locator.unregister<QuickActionsFeature>();
        await locator.unregister<RecoverBullFeature>();
        await locator.unregister<NetworkFeature>();
        await locator.unregister<FeesFeature>();
        await locator.unregister<Spend>();
        await locator.unregister<Fees>();
        await locator.unregister<Electrum>();
        await locator.unregister<ActiveEnvironmentReader>();
        await locator.unregister<SwapFeature>();
        await locator.unregister<ImportFeature>();
        await locator.unregister<OnboardingFeature>();
        await locator.unregister<BitcoinPriceFeature>();
        await locator.unregister<CoinsFeature>();
        await locator.unregister<SilentFeature>();
        await locator.unregister<TransactionsFeature>();
        await locator.unregister<ReceiveFeature>();
        await locator.unregister<WalletNativeRuntime>();
        await nativeRuntime.close();
        await locator.unregister<ElectrumSync>();
        await locator.unregister<AnnouncementDismissals>();
        await locator.unregister<SeedReferences>();
        await locator.unregister<OrderSwaps>();
        await locator.unregister<SwapStore>();
        await locator.unregister<SignerDevices>();
        await locator.unregister<Secrets>();
        await locator.unregister<SecretsInventory>();
        await inventoryFixture.close();
        await receiveServices.reset();
        await transactionServices.reset();
        await networkServices.reset();
        directory.deleteSync(recursive: true);
      });
      // Exercise the actual production route configuration, not a test GoRouter.
      expect(router.configuration.findMatch(Uri.parse('/ark')).isError, false);
      expect(router.namedLocation('receiveBitcoin'), '/receive/bitcoin');
      expect(router.namedLocation('receiveLightning'), '/receive/lightning');
      expect(router.namedLocation('receiveLiquid'), '/receive/liquid');
      expect(router.namedLocation('settings'), '/settings');
      expect(router.namedLocation('search'), '/settings/search');
      expect(
        router.namedLocation(
          'walletDetailsSelectedWallet',
          pathParameters: {'walletId': 'watch-only'},
        ),
        '/settings/wallet-details/watch-only',
      );
      expect(
        router.namedLocation('backupSettings'),
        '/settings/backup-settings',
      );
      expect(
        router.namedLocation('backupOptions'),
        '/settings/backup-settings/backup-options',
      );
      expect(
        router.namedLocation('testPhysicalBackupFlow'),
        '/settings/backup-settings/test-physical-backup-flow',
      );
      expect(
        router.namedLocation('torSettings'),
        '/settings/app-settings/tor-settings',
      );
      expect(
        router.configuration
            .findMatch(Uri.parse('/bitcoin-fee-source'))
            .isError,
        false,
      );
      expect(router.namedLocation('priceHistory'), '/settings/price-history');
      expect(router.namedLocation('swapSettings'), '/swap-settings');
      expect(
        router.namedLocation('autoswapSettings'),
        '/settings/autoswap-settings',
      );
      expect(router.namedLocation('spSetup'), '/sp-setup');
      expect(router.namedLocation('spWalletDetail'), '/sp-wallet-detail');
      expect(
        router.namedLocation('spTransactionDetails'),
        '/sp-transaction-details',
      );
      for (final device in QrImportDevice.values) {
        expect(router.namedLocation(device.routeName), device.path);
        expect(
          router.configuration.findMatch(Uri.parse(device.path)).isError,
          false,
        );
      }
      expect(
        router.namedLocation(ImportNavigation.watchOnlyScannerName),
        ImportNavigation.watchOnlyScannerPath,
      );
      expect(
        router.namedLocation(ImportNavigation.watchOnlyConfirmationName),
        ImportNavigation.watchOnlyConfirmationPath,
      );
      router.go('/ark');
      await tester.pumpWidget(
        MaterialApp.router(
          theme: ThemeData(extensions: testBullExtensions),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();
      String currentPath() =>
          GoRouterState.of(tester.element(find.byType(BullTopBar))).uri.path;
      const unavailable = 'This Ark action is unavailable in this build.';
      expect(find.text(unavailable), findsOneWidget);
      expect(tester.widget<BullTopBar>(find.byType(BullTopBar)).onBack, isNull);
      final account = ArkAccountId(
        parent: Fingerprint('00112233'),
        network: BitcoinNetwork.regtest,
        serverIdentity: 'private-route-server',
      );
      final context = tester.element(find.byType(BullTopBar));
      ArkNavigation.send(
        context,
        account,
        destination: 'private-route-destination',
      );
      await tester.pumpAndSettle();
      expect(currentPath(), '/ark/pay');
      expect(find.text(unavailable), findsOneWidget);
      expect(find.text('private-route-destination'), findsNothing);
      expect(
        tester.widget<BullTopBar>(find.byType(BullTopBar)).onBack,
        isNotNull,
      );
      tester.widget<BullTopBar>(find.byType(BullTopBar)).onBack?.call();
      await tester.pumpAndSettle();
      expect(currentPath(), '/ark');
      ArkNavigation.reviewClaimRecovery(
        tester.element(find.byType(BullTopBar)),
        account,
        'private-route-operation',
      );
      await tester.pumpAndSettle();
      expect(currentPath(), '/ark/claim-recovery');
      expect(find.text(unavailable), findsOneWidget);
      expect(find.text('private-route-operation'), findsNothing);
      expect(find.text('private-route-server'), findsNothing);
      router.go(
        '/ark/pay?destination=private-query&operationId=private-id',
        extra: Object(),
      );
      await tester.pumpAndSettle();
      expect(find.text(unavailable), findsOneWidget);
      expect(find.textContaining('private-query'), findsNothing);
      expect(find.textContaining('private-id'), findsNothing);
      expect(locator.isRegistered<ArkFacade>(), false);
      expect(promptFactories, 0);
      verifyZeroInteractions(wallets);
      verifyZeroInteractions(exchange);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());

      const session = ExchangeSession(
        environment: ExchangeEnvironment.mainnet,
        epoch: 1,
        sessionId: 'tab-navigation',
      );
      when(() => exchange.current)
          .thenReturn(const ExchangeAccessSignedIn(session));
      when(exchange.watch).thenAnswer((_) => const Stream.empty());
      when(exchange.tradingAvailability)
          .thenAnswer((_) async => const Ok(ExchangeAvailability.ready));
      when(locator<OrderSwaps>().watchAppUpdateRequired)
          .thenAnswer((_) => const Stream.empty());
      when(() => locator<OrderSwaps>().isAppUpdateRequired).thenReturn(false);
      when(locator<AnnouncementDismissals>().read)
          .thenAnswer((_) async => const Ok([]));
      final wallet = _WalletHomeBloc();
      final settings = _WalletSettingsCubit();
      addTearDown(wallet.close);
      addTearDown(settings.close);
      const display = (
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
        hideAmounts: false,
      );
      whenListen(
        wallet,
        const Stream<WalletState>.empty(),
        initialState: const WalletState(
          amountDisplay: display,
          status: WalletStatus.success,
        ),
      );
      whenListen(
        settings,
        const Stream<SettingsState>.empty(),
        initialState: const SettingsState(),
      );
      router.goNamed(WalletRoute.walletHome.name);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<WalletBloc>.value(value: wallet),
            BlocProvider<SettingsCubit>.value(value: settings),
            BitcoinPriceFixture.prices(
              amountDisplay: display,
              currency: 'CAD',
              bitcoinPrice: 100000,
            ),
          ],
          child: ExchangeSessionScope(
            exchange: locator.call<Exchange>,
            preferences: _UnusedPreferences.new,
            child: MaterialApp.router(
              routerConfig: router,
              theme: ThemeData(extensions: testBullExtensions),
              localizationsDelegates: const [
                QuickActionsLocalizations.delegate,
                bullUiLocalizationsDelegate,
                ...appLocalizationsDelegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final appBar = find.byType(WalletHomeAppBar);
      expect(
        router.routeInformationProvider.value.uri.path,
        WalletRoute.walletHome.path,
      );
      expect(appBar, findsOneWidget);
      expect(
        tester
            .widget<Scaffold>(
              find.ancestor(of: appBar, matching: find.byType(Scaffold)).first,
            )
            .extendBodyBehindAppBar,
        isTrue,
      );
      router.goNamed(BullExchangeNavigation.dashboardName);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        router.routeInformationProvider.value.uri.path,
        BullExchangeNavigation.dashboardPath,
      );
      expect(appBar, findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        router.routeInformationProvider.value.uri.path,
        WalletRoute.walletHome.path,
      );
      expect(appBar, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
