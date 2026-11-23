import 'package:bull_exchange/bull_exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final feature = BullExchangeFeature.mount(
    networkUnavailable: () async => false,
    showWebsiteOnly: (_) => false,
    unavailableRedirectPath: '/wallet',
    brandAssetPath: 'unused',
    copy: (_) => fail('unexpected landing route'),
    onSignIn: (_) {},
    onExit: (_) {},
    funding: (
      exchange: () => fail('unexpected exchange operation'),
      isLoggedIn: (_) => false,
      buildVirtualIbanFunding: ({required onUseRegularSepa, required onDone}) =>
          const SizedBox.shrink(),
    ),
  );

  test('Confidential SEPA stays top level and COP input stays nested', () {
    GoRoute route(FundExchangeRoute target) => feature.routes
        .whereType<GoRoute>()
        .singleWhere((route) => route.name == target.name);

    final funding = route(FundExchangeRoute.fundExchange);
    expect(funding.path, '/fund-exchange');
    expect(
      funding.routes.whereType<GoRoute>().single.path,
      'cop-bank-transfer-input',
    );
    expect(
      route(FundExchangeRoute.fundExchangeConfidentialSepa).path,
      '/fund-exchange-confidential-sepa',
    );
  });

  testWidgets('a signed-out entry reaches the dashboard without loading data', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/fund-exchange',
      routes: [
        ...feature.routes,
        GoRoute(
          path: BullExchangeNavigation.dashboardPath,
          builder: (_, _) => const Text('Dashboard'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      WidgetsApp.router(color: const Color(0xffffffff), routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
