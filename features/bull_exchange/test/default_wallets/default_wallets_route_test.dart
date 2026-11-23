import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_exchange/src/bull_exchange_feature.dart';
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart' show DefaultWallets;
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

void main() {
  for (final isAvailable in [false, true]) {
    testWidgets('default payouts use the settings slot ($isAvailable)', (
      tester,
    ) async {
      var loads = 0;
      final exchange = exchangeForTesting(
        getDefaultWallets: () async {
          loads++;
          return const Ok(DefaultWallets());
        },
      );
      final feature = mountBullExchange(
        networkUnavailable: () async => false,
        showWebsiteOnly: (_) => false,
        unavailableRedirectPath: '/wallet',
        brandAssetPath: 'unused',
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
        settings: ExchangeSettingsHost(
          exchange: () => exchange,
          savePreferences: ({language, currency, emailNotificationsEnabled}) =>
              fail('unexpected preference change'),
          refreshSession: (_) async {},
          isSuperuser: (_) => false,
          securityUrl: (_) => null,
          title: (_) => '',
          signedOutMessage: (_) => '',
          hasAccount: (_) => false,
          accountFailureMessage: (_, _) => fail('unexpected account failure'),
          onOpenRecipients: (_) {},
          onOpenTransactions: (_) {},
          onOpenDefaultWallets: DefaultWalletsNavigation.open,
          onOpenExchange: (_) {},
          defaultWallets: (
            isAvailable: () async => isAvailable,
            unavailableRedirectPath: '/wallet',
          ),
        ),
      );
      final router = GoRouter(
        initialLocation: '/settings/exchange-bitcoin-wallets',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, _) => const SizedBox.shrink(),
            routes: feature.settingsRoutes,
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
