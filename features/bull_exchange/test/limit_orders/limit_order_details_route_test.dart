import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_exchange/src/bull_exchange_feature.dart';
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import 'limit_order_fixtures.dart';

class _Orders extends Mock implements LimitOrdersRepository {}

void main() {
  testWidgets('the mounted details route loads the selected active order', (
    tester,
  ) async {
    final orders = _Orders();
    when(() => orders.get(limitSession, 'selected'))
        .thenAnswer((_) async => Ok(limitOrder(id: 'selected')));
    final exchange = exchangeForTesting(
      limitOrders: orders,
      access: fixedAccessForTesting(const ExchangeAccessSignedIn(limitSession)),
    );
    final feature = mountBullExchange(
      networkUnavailable: () async => false,
      showWebsiteOnly: (_) => false,
      unavailableRedirectPath: '/wallet',
      brandAssetPath: 'unused',
      onExit: (_) {},
      limitOrders: () => exchange,
    );
    final router = GoRouter(
      initialLocation: '/limit-orders/selected',
      routes: [?feature.limitOrderDetails],
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
    verify(() => orders.get(limitSession, 'selected')).called(1);
    expect(find.text('LO-1'), findsOneWidget);
  });
}
