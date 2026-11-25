import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_exchange/src/pay/presentation/pay_flow.dart';
import 'package:bull_exchange/src/pay/ui/pay_flow_shell.dart';
import 'package:bull_exchange/src/payin/exchange_payin_ui.dart';
import 'package:bull_exchange/src/sell/presentation/sell_flow.dart';
import 'package:bull_exchange/src/sell/ui/sell_flow_shell.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:transactions/routes.dart';

import '../pay/pay_fixtures.dart';
import '../sell/sell_fixtures.dart';

final ExchangePayinUi _ui = (
  walletCards: (_, _) => const SizedBox.shrink(),
  openWalletHome: (_) {},
  brandAsset: 'assets/none.png',
  successAsset: 'assets/none.png',
);

void main() {
  for (final pay in [true, false]) {
    for (final scenario in [
      (bip21: false, txid: false),
      (bip21: true, txid: false),
      (bip21: true, txid: true),
      (bip21: false, txid: true),
    ]) {
      testWidgets(
        '${pay ? 'Pay' : 'Sell'} details ${scenario.bip21} ${scenario.txid}',
        (tester) async {
          final order = pay
              ? payOrder().copyWith(
                  bip21URI: scenario.bip21
                      ? 'bitcoin:bc1qdeposit?pj=https://example.com'
                      : null,
                )
              : sellOrder().copyWith(
                  bip21URI: scenario.bip21
                      ? 'bitcoin:bc1qdeposit?pj=https://example.com'
                      : null,
                );
          final txid = scenario.txid ? 'tx-1' : null;
          final pages = pay
              ? payPagesFor(
                  PayDone(
                    (payReviewState as PayOrdering).open,
                    order,
                    txid,
                    null,
                  ),
                  ui: _ui,
                  onEvent: (_) {},
                  now: () => payNow,
                )
              : sellPagesFor(
                  SellDone((sellReviewState as SellOrdering).open, order, txid),
                  ui: _ui,
                  onEvent: (_) {},
                  now: () => sellNow,
                );
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) =>
                    Navigator(pages: pages, onDidRemovePage: (_) {}),
              ),
              GoRoute(
                name: TransactionsRoute.orderTransactionDetails.name,
                path: TransactionsRoute.orderTransactionDetails.path,
                builder: (_, state) => Text(state.uri.toString()),
              ),
              GoRoute(
                name: TransactionsRoute.payjoinTransactionDetailsByTxId.name,
                path: TransactionsRoute.payjoinTransactionDetailsByTxId.path,
                builder: (_, state) => Text(state.uri.toString()),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              theme: ThemeData(extensions: testBullExtensions),
              localizationsDelegates:
                  ExchangeLocalizations.localizationsDelegates,
              supportedLocales: ExchangeLocalizations.supportedLocales,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          final context = tester.element(find.byType(Navigator).last);
          final loc = ExchangeLocalizations.of(context);
          await tester.tap(
            find.text(pay ? loc.payViewDetails : loc.sellViewDetailsButton),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          final uri = scenario.bip21 && scenario.txid
              ? '/transaction/payjoin/tx/tx-1?returnToExchange=true'
              : '/transaction/order/${pay ? 'p-1' : 's-1'}?returnToExchange=true';
          expect(find.text(uri), findsOneWidget);
          expect(router.canPop(), isTrue);
          router.pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            find.text(pay ? loc.payViewDetails : loc.sellViewDetailsButton),
            findsOneWidget,
          );
        },
      );
    }
  }
}
