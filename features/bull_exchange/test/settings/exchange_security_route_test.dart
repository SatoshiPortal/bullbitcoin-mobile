import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_exchange/src/settings/ui/exchange_settings_router.dart';
import 'package:bull_exchange/src/settings/ui/screens/security_screen.dart';
import 'package:bull_ui/testing.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  for (final (network, expected) in <(NetworkEnv?, String?)>[
    (NetworkEnv.mainnet, 'https://accounts.bullbitcoin.com/settings'),
    (NetworkEnv.testnet, 'https://accounts05.bullbitcoin.dev/settings'),
    (null, null),
    (NetworkEnv.regtest, null),
    (NetworkEnv.signet, null),
  ]) {
    testWidgets('security route uses the exact endpoint for $network', (
      tester,
    ) async {
      final exchange = exchangeForTesting();
      final routes = ExchangeSettingsRouter.routes(
        ExchangeSettingsHost(
          networkOf: (_) => network,
          isSuperuser: (_) => false,
          title: (_) => '',
          signedOutMessage: (_) => '',
          onOpenRecipients: (_) {},
          onOpenTransactions: (_) {},
        ),
        exchange: () => exchange,
        preferences: () => throw StateError('Unexpected preferences'),
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
      final router = GoRouter(
        initialLocation: '/settings/exchange-security',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, _) => const SizedBox.shrink(),
            routes: routes,
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

      final screen = tester.widget<ExchangeSecurityScreen>(
        find.byType(ExchangeSecurityScreen),
      );
      expect(screen.securityUrl?.toString(), expected);
      if (expected == null) {
        final context = tester.element(find.byType(ExchangeSecurityScreen));
        await tester.tap(
          find.text(
            ExchangeLocalizations.of(context)
                .exchangeSecurityAccessSettingsButton,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(WebViewWidget), findsNothing);
      }
    });
  }
}
