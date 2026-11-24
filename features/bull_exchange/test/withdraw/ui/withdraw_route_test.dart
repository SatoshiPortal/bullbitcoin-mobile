import 'package:bull_exchange/bull_exchange.dart';
import 'package:bull_exchange/src/bull_exchange_feature.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('a signed-out withdrawal opens Trade without loading context', (
    tester,
  ) async {
    final feature = mountBullExchange(
      networkUnavailable: () async => false,
      showWebsiteOnly: (_) => false,
      unavailableRedirectPath: '/wallet',
      brandAssetPath: 'unused',
      onExit: (_) {},
      withdrawal: (
        exchange: () => fail('withdrawal must not load while signed out'),
        preferences: () => fail('must not read preferences while signed out'),
        isLoggedIn: (_) => false,
        openOrder: (_, _) => fail('unexpected order navigation'),
      ),
    );
    final router = GoRouter(
      initialLocation: WithdrawRoute.withdraw.path,
      routes: [
        ?feature.withdrawalRoute,
        GoRoute(
          path: BullExchangeNavigation.dashboardPath,
          builder: (_, _) => const Text('Trade'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      WidgetsApp.router(color: const Color(0xffffffff), routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trade'), findsOneWidget);
  });
}
