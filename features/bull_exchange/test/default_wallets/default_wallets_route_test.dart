import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_exchange/src/settings/ui/exchange_settings_router.dart';
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart'
    show
        DefaultWallets,
        ExchangeAccessSignedIn,
        ExchangeEnvironment,
        ExchangeSession;
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

class _Preferences extends Mock implements Preferences {}

void main() {
  for (final environment in [null, ...Environment.values]) {
    testWidgets('default payouts use the settings slot ($environment)', (
      tester,
    ) async {
      final isAvailable =
          environment == Environment.mainnet ||
          environment == Environment.testnet;
      var loads = 0;
      final exchange = exchangeForTesting(
        access: fixedAccessForTesting(
          const ExchangeAccessSignedIn(
            ExchangeSession(
              environment: ExchangeEnvironment.mainnet,
              epoch: 1,
              sessionId: 's',
            ),
          ),
        ),
        getDefaultWallets: () async {
          loads++;
          return const Ok(DefaultWallets());
        },
      );
      final preferences = _Preferences();
      when(preferences.fetch).thenAnswer(
        (_) async => environment == null
            ? const Err(PreferencesReadFailure())
            : Ok(
                SettingsEntity(
                  environment: environment,
                  bitcoinUnit: BitcoinUnit.sats,
                  currencyCode: 'USD',
                ),
              ),
      );
      final routes = ExchangeSettingsRouter.routes(
        ExchangeSettingsHost(
          networkOf: (_) => environment?.networkEnv,
          isSuperuser: (_) => false,
          title: (_) => '',
          signedOutMessage: (_) => '',
          onOpenRecipients: (_) {},
          onOpenTransactions: (_) {},
          includeDefaultWallets: true,
        ),
        exchange: () => exchange,
        preferences: () => preferences,
        homePath: '/wallet',
        onExit: (_) {},
        payoutFields: (
          validate: (_, _) async => null,
          buildField: ({
            required type,
            required value,
            required hint,
            required enabled,
            required onChanged,
            required onValidationChanged,
          }) => const SizedBox.shrink(),
        ),
      );
      verifyNever(preferences.fetch);
      final router = GoRouter(
        initialLocation: '/settings/exchange-bitcoin-wallets',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, _) => const SizedBox.shrink(),
            routes: routes,
          ),
          GoRoute(
            path: '/wallet',
            builder: (_, _) => const Text('Wallet home'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
          supportedLocales: ExchangeLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      verify(preferences.fetch).called(greaterThanOrEqualTo(1));
      expect(loads, isAvailable ? 1 : 0);
      expect(
        find.byType(DefaultWalletsEditor),
        isAvailable ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Wallet home'),
        isAvailable ? findsNothing : findsOneWidget,
      );
    });
  }
}
