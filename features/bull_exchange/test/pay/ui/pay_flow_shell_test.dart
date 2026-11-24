import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_exchange/src/pay/presentation/pay_flow.dart';
import 'package:bull_exchange/src/pay/ui/pay_flow_shell.dart';
import 'package:bull_exchange/src/pay/ui/screens/pay_amount_page.dart';
import 'package:bull_exchange/src/payin/exchange_payin_ui.dart';
import 'package:bull_exchange/src/payin/ui/payin_source_page.dart';
import 'package:bull_exchange/src/payin/ui/payin_view.dart';
import 'package:bull_exchange/src/payin/ui/quote_review_page.dart';
import 'package:bull_exchange/src/recipients/public/recipient_pick_screen.dart';
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../pay_fixtures.dart';

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
  PayFlowState state, {
  List<PayFlowEvent>? events,
}) async {
  await tester.pumpWidget(
    RepositoryProvider.value(
      value: _ui,
      child: MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
        supportedLocales: ExchangeLocalizations.supportedLocales,
        home: Navigator(
          pages: payPagesFor(
            state,
            ui: _ui,
            onEvent: (event) => events?.add(event),
            now: () => payNow,
          ),
          onDidRemovePage: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  return ExchangeLocalizations.of(tester.element(find.byType(Navigator).last));
}

void main() {
  testWidgets('each step shows its page on top', (tester) async {
    await _pump(tester, payAmountState);
    expect(find.byType(PayAmountPage), findsOneWidget);
    await _pump(tester, paySourceState);
    expect(find.byType(PayinSourcePage), findsOneWidget);
    await _pump(tester, payReviewState);
    expect(find.byType(QuoteReviewPage), findsOneWidget);
    await _pump(tester, payPayingState);
    expect(find.byType(PayinView), findsOneWidget);
  });

  testWidgets('the recipient comes first', (tester) async {
    await _pump(tester, payRecipientState);
    expect(find.byType(RecipientPickScreen), findsOneWidget);
  });

  testWidgets('the description is sent to the amount step', (tester) async {
    final events = <PayFlowEvent>[];
    await _pump(tester, payAmountState, events: events);
    await tester.enterText(find.byType(TextField).last, 'Rent');
    expect(
      (events.last as PayAmountChanged).event,
      isA<AmountDescriptionTyped>().having((e) => e.text, 'text', 'Rent'),
    );
  });

  testWidgets('Confirm sends its time; done says the payment was received', (
    tester,
  ) async {
    final events = <PayFlowEvent>[];
    final labels = await _pump(tester, payReviewState, events: events);
    await tester.tap(find.text(labels.sellConfirmPayment));
    expect(
      events.single,
      isA<PayConfirmPressed>().having((e) => e.at, 'at', payNow),
    );
    await _pump(tester, payDoneState);
    expect(find.text(labels.exchangePayinReceived), findsOneWidget);
  });

  testWidgets('a stalled receipt watch offers Check again', (tester) async {
    final events = <PayFlowEvent>[];
    final receipt = payReceiptState;
    final labels = await _pump(
      tester,
      PayDone(
        receipt.open,
        receipt.order,
        receipt.txid,
        WatchTimedOut<Order>(receipt.order, 2),
      ),
      events: events,
    );
    await tester.tap(find.text(labels.exchangeStepCheckAgain));
    expect(events.single, isA<PayRetryPressed>());
  });
}
