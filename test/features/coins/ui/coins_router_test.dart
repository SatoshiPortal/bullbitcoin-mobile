import 'package:bb_mobile/features/coins/ui/coins_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('a Coins deep link without a wallet uses the supplied fallback', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/coins',
      routes: [
        CoinsRouter.route(
          missingWalletRedirect: '/fallback',
          onSend: (_, _, _) async => fail('unexpected Send navigation'),
          onSweep: (_, _, _) async => fail('unexpected Sweep navigation'),
        ),
        GoRoute(
          path: '/fallback',
          builder: (_, _) => const Text('wallet fallback'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('wallet fallback'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
