import 'package:address_view/routes.dart' show AddressViewFeature;
import 'package:labels/labels.dart' show Labels;
import 'package:access/access.dart' show Access;
import 'package:all_seed_view/setup.dart';
import 'package:bip85/bip85.dart';
import 'package:secrets/custody.dart';
import 'package:swaps/swaps.dart' show BoltzSwaps;
import 'package:transactions/routes.dart';
import 'package:transactions/setup.dart';

import '../transactions/support/transaction_ui_actions.dart';

import 'package:fees/fees.dart';
import 'package:electrum/electrum.dart' show Electrum, ElectrumTransactions;
import 'package:electrum/setup.dart' show ElectrumServersPort;
import 'package:wallet_import/wallet_import.dart';
import 'package:onboarding/setup.dart';
import 'package:fees_feature/fees_feature.dart' show FeesFeature;

import 'dart:io';

import 'package:access/setup.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bull_ark/ark_ui.dart';
import 'package:bull_ark/bull_ark.dart' show ArkFacade, ArkAccountId;
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_ui/bull_ui.dart' show BullTopBar;
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:signers/routes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network/network.dart';
import 'package:preferences/preferences.dart';
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
import 'package:sync/write.dart' show WalletNativeLifecycle;

class PricePreferences extends Mock
    implements
        ActiveEnvironmentReader,
        AmountDisplayPreferencesReader,
        RuntimeDisplayPreferencesReader {}

class ImportPreferences extends Mock implements Preferences {}

class ElectrumServers extends Mock implements ElectrumServersPort {}

class Exchange extends Mock implements ExchangeFacade {}

class SilentPreferences extends Mock implements Preferences {}

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
    swapSettingsRoute(_UnusedSwapRouting(), _UnusedSwapServers()),
  ];

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

void main() {
  testWidgets(
    'actual shell routes keep unavailable Ark entries inert and navigable',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync('ark-route-');
      final exchange = Exchange();
      final wallets = Wallets();
      final quickActions = createQuickActionsCubit(
        storage: Memory(),
        warning: (_) {},
        exchangeVisible: const Stream.empty(),
      );
      final recovery = RecoverBullFeature.create(
        secrets: Secrets(scratchDirectory: () async => directory.path),
        wallets: wallets,
      );
      locator.registerSingleton<ExchangeFacade>(exchange);
      locator.registerSingleton<QuickActionsCubit>(quickActions);
      final exchangePrompt = createExchangePromptCubit(
        storage: Memory(),
        warning: (_) {},
        offered: const Stream.empty(),
      );
      locator.registerSingleton<ExchangePromptCubit>(exchangePrompt);
      locator.registerSingleton<RecoverBullFeature>(recovery);
      FakeSecureStoragePlatform().install();
      final inventoryFixture = await tester.runAsync(
        () => InventoryFixture.open(directory),
      );
      if (inventoryFixture == null) throw StateError('Inventory unavailable');
      final accessServices = GetIt.asNewInstance();
      locator.registerSingleton(
        AccessFeature.mount(
          services: accessServices,
          inventory: inventoryFixture.inventory,
          backupVerification: inventoryFixture.backup,
          hasVerifiedBackup: () async => false,
          onUnlocked: (_) {},
          onBackUp: (_) async {},
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
          preferences: _UnusedPreferences(),
          bindings: (
            readDefaultNetwork: () async => const Ok(null),
            isTorRequired: () async => const Ok(false),
          ),
        ),
      );
      locator.registerSingleton(
        FeesFeature.mount(fees: () => throw StateError('Unexpected fees read')),
      );
      locator.registerSingleton<SwapFeature>(_SwapRoutes());
      locator.registerSingleton(
        SilentFeature.mount(
          preferences: SilentPreferences(),
          secrets: Secrets(scratchDirectory: () async => directory.path),
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
      final secrets = Secrets(scratchDirectory: () async => directory.path);
      final inventory = inventoryFixture.inventory;
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
        ),
      );
      locator.registerSingleton(
        AllSeedViewFeature.mount(
          secrets: secrets,
          inventory: inventory,
          preferences: preferences,
          references: SeedReferences(
            _UnusedReferences(),
            admission: _UnusedCustodyAdmission(),
          ),
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
          provisionMnemonic: ({
            required parent,
            required secrets,
            required admission,
            required network,
            required scriptType,
            label,
          }) => throw StateError('Unexpected mnemonic provisioning'),
          provisionDescriptor: ({
            required descriptor,
            required signer,
            required label,
          }) => throw StateError('Unexpected descriptor provisioning'),
          provisionXpub: ({
            required xpub,
            required network,
            required scriptType,
            required label,
          }) => throw StateError('Unexpected xpub provisioning'),
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
          createWallet: () => throw StateError('Unexpected wallet creation'),
          recoverWallet: ({
            required mnemonicWords,
            required language,
            required passphrase,
          }) => throw StateError('Unexpected wallet recovery'),
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
      addTearDown(() async {
        router.dispose();
        await quickActions.close();
        await recovery.dispose();
        await locator.unregister<AccessFeature>();
        await locator.unregister<AddressViewFeature>();
        await locator.unregister<Bip85Feature>();
        await locator.unregister<AllSeedViewFeature>();
        await accessServices.reset();
        await inventoryFixture.close();
        await locator.unregister<SignersFeature>();
        await signerServices.reset();
        await locator.unregister<ExchangeFacade>();
        await locator.unregister<QuickActionsCubit>();
        await exchangePrompt.close();
        await locator.unregister<ExchangePromptCubit>();
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
        await locator.unregister<SilentFeature>();
        await locator.unregister<TransactionsFeature>();
        await locator.unregister<ReceiveFeature>();
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
      verifyZeroInteractions(wallets);
      verifyZeroInteractions(exchange);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
