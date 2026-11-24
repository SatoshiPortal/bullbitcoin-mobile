import 'package:bull_exchange/src/payin/spend_options.dart';
import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_exchange/src/payin/exchange_payin_ui.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/ui/payin_source_page.dart';
import 'package:bull_exchange/src/payin/ui/payin_view.dart';
import 'package:bull_exchange/src/payin/ui/quote_review_page.dart';
import 'package:bull_exchange/src/sell/presentation/sell_flow.dart';
import 'package:bull_exchange/src/sell/ui/screens/sell_amount_page.dart';
import 'package:bull_exchange/src/sell/ui/screens/sell_payout_page.dart';
import 'package:bull_exchange/src/sell/ui/sell_flow_shell.dart';
import 'package:bull_ui/bull_ui.dart' show BullQrCode;
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show FormatAmount;

import '../sell_fixtures.dart';

final ExchangePayinUi _ui = (
  walletCards: (context, onSelected) => const SizedBox(key: Key('wallets')),
  addressViewer: (context, text, {style, color, textAlign}) =>
      Text(text, style: style),
  openWalletHome: (context) {},
  openOrder: (context, orderId, {required returnToExchange}) {},
  openPayjoinTransaction: (context, txid) {},
  brandAsset: 'assets/none.png',
  successAsset: 'assets/none.png',
);

Future<ExchangeLocalizations> _pump(
  WidgetTester tester,
  SellFlowState state, {
  List<SellFlowEvent>? events,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: testBullExtensions),
      localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
      supportedLocales: ExchangeLocalizations.supportedLocales,
      home: Navigator(
        pages: sellPagesFor(
          state,
          ui: _ui,
          onEvent: (event) => events?.add(event),
          now: () => sellNow,
        ),
        onDidRemovePage: (_) {},
      ),
    ),
  );
  await tester.pump();
  return ExchangeLocalizations.of(tester.element(find.byType(Navigator).last));
}

SellFlowState _reviewWith(QuoteStatus status) {
  final review = sellReviewState as SellOrdering;
  return SellOrdering(
    review.open,
    review.request,
    OrderQuoted(QuotedOrder<Order>('s-1', sellOrder()), status),
    review.spend,
  );
}

void main() {
  testWidgets('each step shows its page on top', (tester) async {
    await _pump(tester, sellAmountState);
    expect(find.byType(SellAmountPage), findsOneWidget);
    await _pump(tester, sellSourceState);
    expect(find.byType(PayinSourcePage), findsOneWidget);
    await _pump(tester, sellPayoutState);
    expect(find.byType(SellPayoutPage), findsOneWidget);
    await _pump(tester, sellReviewState);
    expect(find.byType(QuoteReviewPage), findsOneWidget);
    await _pump(tester, sellPayingState);
    expect(find.byType(PayinView), findsOneWidget);
  });

  testWidgets('an external rail is a payin source', (tester) async {
    final events = <SellFlowEvent>[];
    final labels = await _pump(tester, sellSourceState, events: events);
    await tester.tap(find.text(labels.sellLiquidNetwork));
    expect(
      (events.single as SellSourcePicked).source,
      const PayinFromExternal(BtcNetwork.liquid),
    );
  });

  testWidgets('Confirm only on a live quote', (tester) async {
    final events = <SellFlowEvent>[];
    final labels = await _pump(
      tester,
      _reviewWith(const QuoteLive()),
      events: events,
    );
    await tester.ensureVisible(find.text(labels.sellConfirmPayment));
    await tester.tap(find.text(labels.sellConfirmPayment));
    expect(
      events.single,
      isA<SellConfirmPressed>().having((e) => e.at, 'at', sellNow),
    );
    events.clear();
    await _pump(tester, _reviewWith(const QuoteRefreshing(0)), events: events);
    await tester.ensureVisible(find.text(labels.sellConfirmPayment));
    await tester.tap(find.text(labels.sellConfirmPayment));
    expect(events, isEmpty);
    await _pump(tester, _reviewWith(const QuoteUnavailable()), events: events);
    await tester.ensureVisible(find.text(labels.retry));
    await tester.tap(find.text(labels.retry));
    expect(events.single, isA<SellRetryPressed>());
  });

  testWidgets('the review shows the deposit, payout and spend options', (
    tester,
  ) async {
    final labels = await _pump(tester, sellReviewState);
    expect(find.text(labels.sellPriceWillRefreshIn), findsOneWidget);
    expect(find.text(labels.sellDepositAddress), findsOneWidget);
    expect(find.text('bc1qdeposit'), findsOneWidget);
    expect(find.text(labels.sellPayoutRecipient), findsOneWidget);
    expect(find.text(labels.sellCadBalance), findsOneWidget);
    expect(find.text(labels.sellFeePriority), findsOneWidget);
    expect(find.text(labels.sellFastest), findsOneWidget);
    expect(find.text(labels.sellSendPaymentNetworkFees), findsOneWidget);
    expect(find.text(labels.sellAdvancedSettings), findsOneWidget);
  });

  testWidgets('Confirm waits for the fee estimates; a failure offers Retry', (
    tester,
  ) async {
    final review = sellReviewState as SellOrdering;
    final events = <SellFlowEvent>[];
    final labels = await _pump(
      tester,
      SellOrdering(
        review.open,
        review.request,
        review.order,
        const SpendFeesUnavailable('w-1', 1),
      ),
      events: events,
    );
    expect(find.text(labels.sellErrorFeesUnavailable), findsOneWidget);
    await tester.ensureVisible(find.text(labels.sellConfirmPayment));
    await tester.tap(find.text(labels.sellConfirmPayment));
    expect(events, isEmpty);
    await tester.ensureVisible(find.text(labels.retry));
    await tester.tap(find.text(labels.retry));
    expect(
      events.single,
      isA<SellSpendChanged>().having(
        (e) => e.event,
        'event',
        isA<SpendRetryPressed>(),
      ),
    );
  });

  testWidgets('an external payin offers the countdown, copy and the QR code', (
    tester,
  ) async {
    final paying = sellPayingState as SellPaying;
    final labels = await _pump(
      tester,
      SellPaying(
        paying.open,
        paying.request,
        paying.quoted,
        PayinExternal<PayinSpend>(
          sellOrder(),
          const OnchainDeposit('bc1qdeposit'),
          WatchWatching<Order>(sellOrder(), 0, 0, 1),
        ),
        paying.spend,
      ),
    );
    expect(find.text(labels.sellPriceWillRefreshIn), findsOneWidget);
    expect(find.text(labels.sellCopyInvoice), findsOneWidget);
    await tester.ensureVisible(find.text(labels.sellShowQrCode));
    await tester.tap(find.text(labels.sellShowQrCode));
    await tester.pumpAndSettle();
    expect(find.byType(BullQrCode), findsOneWidget);
  });

  testWidgets('a refused payin shows Leave, never a send', (tester) async {
    final paying = sellPayingState as SellPaying;
    final events = <SellFlowEvent>[];
    final labels = await _pump(
      tester,
      SellPaying(
        paying.open,
        paying.request,
        paying.quoted,
        PayinRefusedByExchange<PayinSpend>(sellOrder(), 'tx-1'),
        paying.spend,
      ),
      events: events,
    );
    expect(find.text(labels.exchangePayinRefusedByExchange), findsOneWidget);
    expect(find.text(labels.sellConfirmPayment), findsNothing);
    await tester.tap(find.text(labels.exchangePaymentSentLeave));
    expect(events.single, isA<SellDonePressed>());
  });

  testWidgets('done says the payment was received', (tester) async {
    final labels = await _pump(tester, sellDoneState);
    expect(find.text(labels.exchangePayinReceived), findsOneWidget);
    expect(
      find.text(
        labels.sellYouSold(
          FormatAmount.btc(0.0002),
          FormatAmount.fiat(10, 'CAD'),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(labels.sellBalanceWillBeCredited), findsOneWidget);
  });
}
