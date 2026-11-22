import 'package:fees_feature/fees_feature.dart' show FeesFeature;

import 'dart:io';

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
import 'package:secrets/secrets.dart';

class PricePreferences extends Mock
    implements
        ActiveEnvironmentReader,
        AmountDisplayPreferencesReader,
        RuntimeDisplayPreferencesReader {}

class Exchange extends Mock implements ExchangeFacade {}

class Wallets extends Mock implements RecoverBullWalletPort {}

class Memory implements QuickActionsStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> remove(String key) async {}
}

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
      locator.registerSingleton<RecoverBullFeature>(recovery);
      final signerServices = GetIt.asNewInstance();
      locator.registerSingleton(
        SignersFeature.mount(
          services: signerServices,
          writeNfc: (_, _, _, _) async {},
        ),
      );
      final networkServices = GetIt.asNewInstance();
      locator.registerSingleton(
        NetworkFeature.mount(
          services: networkServices,
          bindings: (
            readDefaultNetwork: () async => const Ok(null),
            readEnvironment: () async =>
                throw StateError('Unexpected environment read'),
            readMempoolEnvironment: () async =>
                throw StateError('Unexpected Mempool environment read'),
            checkBitcoinFees: (_) async {},
            isTorRequired: () async => const Ok(false),
            readTorPreferences: () async =>
                throw StateError('Unexpected Tor read'),
            saveTorProxy: ({required enabled, required port}) async => false,
            saveTorMode: (_) async => const Ok(null),
          ),
        ),
      );
      locator.registerSingleton(
        FeesFeature.mount(fees: () => throw StateError('Unexpected fees read')),
      );
      final preferences = PricePreferences();
      locator.registerSingleton(
        BitcoinPriceFeature.mount(
          environment: preferences,
          amountDisplay: preferences,
          display: preferences,
        ),
      );
      final router = AppRouter.router;
      addTearDown(() async {
        router.dispose();
        await quickActions.close();
        await recovery.dispose();
        await locator.unregister<SignersFeature>();
        await signerServices.reset();
        await locator.unregister<ExchangeFacade>();
        await locator.unregister<QuickActionsCubit>();
        await locator.unregister<RecoverBullFeature>();
        await locator.unregister<NetworkFeature>();
        await locator.unregister<FeesFeature>();
        await locator.unregister<BitcoinPriceFeature>();
        await networkServices.reset();
        directory.deleteSync(recursive: true);
      });
      // Exercise the actual production route configuration, not a test GoRouter.
      expect(router.configuration.findMatch(Uri.parse('/ark')).isError, false);
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
