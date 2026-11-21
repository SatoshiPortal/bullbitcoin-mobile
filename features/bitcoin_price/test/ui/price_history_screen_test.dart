import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

class _Preferences extends Mock
    implements
        ActiveEnvironmentReader,
        AmountDisplayPreferencesReader,
        RuntimeDisplayPreferencesReader {}

void main() {
  testWidgets('history opens, retries and returns to settings', (tester) async {
    final preferences = _Preferences();
    when(preferences.readActiveEnvironment)
        .thenAnswer((_) async => const Ok(Environment.testnet));
    when(preferences.readCurrency).thenAnswer((_) async => const Ok('CAD'));
    when(() => preferences.currencyChangeStream)
        .thenAnswer((_) => const Stream.empty());
    when(preferences.watchDisplayPreferences)
        .thenAnswer((_) => const Stream.empty());
    final requests = <({BitcoinNetwork network, SupportedCurrency currency})>[];
    final feature = BitcoinPriceFeature.mount(
      environment: preferences,
      amountDisplay: preferences,
      display: preferences,
      getIndexPrice: ({required network, required currency}) async =>
          const Err(PricerNetworkFailure()),
      getPriceHistory: ({required network, required currency}) async {
        requests.add((network: network, currency: currency));
        return const Err(PricerNetworkFailure());
      },
    );
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => BitcoinPriceFeature.openHistory(context),
              child: const Text('Open history'),
            ),
          ),
          routes: feature.routes,
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      feature.providePrices(
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(extensions: testBullExtensions),
          localizationsDelegates:
              BitcoinPriceLocalizations.localizationsDelegates,
          supportedLocales: BitcoinPriceLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open history'));
    await tester.pumpAndSettle();
    final historyTitle = find.text('Price history');
    expect(historyTitle, findsOneWidget);
    expect(requests, [
      (network: BitcoinNetwork.mainnet, currency: SupportedCurrency.cad),
    ]);
    expect(
      find.text('Price chart data could not be loaded. Please try again.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Retry'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Open history'), findsOneWidget);
  });
}
