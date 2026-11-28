import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_exchange/src/pay/presentation/pay_flow.dart';
import 'package:bull_exchange/src/pay/ui/pay_flow_shell.dart';
import 'package:bull_exchange/src/pay/ui/screens/pay_amount_page.dart';
import 'package:bull_exchange/src/payin/exchange_payin_ui.dart';
import 'package:bull_exchange/src/payin/ui/payin_source_page.dart';
import 'package:bull_exchange/src/payin/ui/payin_view.dart';
import 'package:bull_exchange/src/payin/ui/quote_review_page.dart';
import 'package:bull_exchange/src/recipients/presentation/recipients_bloc.dart';
import 'package:bull_exchange/src/recipients/public/recipient_filter_criteria.dart';
import 'package:bull_exchange/src/recipients/public/recipient_pick_screen.dart';
import 'package:bull_exchange/src/recipients/recipients_scope.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:sync/sync.dart' show WalletKey;

import '../pay_fixtures.dart';

class _MockRecipientsBloc extends MockBloc<RecipientsEvent, RecipientsState>
    implements RecipientsBloc {}

/// The recipient page under every later pay page builds a recipients list.
RecipientsServices _recipients() {
  final bloc = _MockRecipientsBloc();
  when(() => bloc.state).thenReturn(
    RecipientsState(allowedRecipientFilters: RecipientFilterCriteria()),
  );
  return (
    createRecipientsBloc: (_, _) => bloc,
    createVirtualIbanCubit: () => throw StateError('not in this test'),
    createActivationCubit: (_) => throw StateError('not in this test'),
  );
}

final ExchangePayinUi _ui = (
  walletCards: (_, onSelected) => TextButton(
    onPressed: () => onSelected?.call((
      key: WalletKey(id: 'btc:regtest', network: BitcoinNetwork.regtest),
      label: null,
      isDefault: true,
    )),
    child: const Text('Pick Bitcoin wallet'),
  ),
  openWalletHome: (context) {},
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
        builder: (context, child) => RecipientsScope.withServices(
          services: _recipients(),
          child: child ?? const SizedBox.shrink(),
        ),
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
  testWidgets('Pay preserves the selected wallet ID and default marker', (
    tester,
  ) async {
    final events = <PayFlowEvent>[];
    await _pump(tester, paySourceState, events: events);
    await tester.tap(find.text('Pick Bitcoin wallet'));
    expect(
      (events.single as PaySourcePicked).source,
      const PayinFromAppWallet(
        'btc:regtest',
        BtcNetwork.bitcoin,
        isDefault: true,
      ),
    );
  });

  testWidgets('back cancels Pay source selection without picking a wallet', (
    tester,
  ) async {
    final events = <PayFlowEvent>[];
    await _pump(tester, paySourceState, events: events);
    await tester.tap(find.byType(BackButton));
    expect(events.single, isA<PayBackPressed>());
  });

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
    expect(find.text(labels.payPriceRefreshIn), findsOneWidget);
    expect(find.text(labels.payDepositAddress), findsOneWidget);
    expect(find.text(labels.payRecipientType), findsOneWidget);
    expect(find.text(labels.payFeePriority), findsOneWidget);
    expect(find.text(labels.payAdvancedSettings), findsOneWidget);
    await tester.ensureVisible(find.text(labels.sellConfirmPayment));
    await tester.tap(find.text(labels.sellConfirmPayment));
    expect(
      events.single,
      isA<PayConfirmPressed>().having((e) => e.at, 'at', payNow),
    );
    await _pump(tester, payDoneState);
    expect(find.text(labels.exchangePayinReceived), findsOneWidget);
    final done = payDoneState.order as FiatPaymentOrder;
    expect(
      find.text(
        labels.payPaymentInProgressDescriptionDetails(
          done.payoutAmountToDisplay,
          done.recipientToDisplay ?? labels.payNotAvailable,
        ),
      ),
      findsOneWidget,
    );
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
    final checkAgain = find.text(labels.exchangeStepCheckAgain);
    await tester.ensureVisible(checkAgain);
    await tester.tap(checkAgain);
    expect(events.single, isA<PayRetryPressed>());
  });

  // Pay opens on the recipient list, alone in the flow's navigator: its
  // back must be the flow's event, not an implied pop.
  for (final (name, state) in [
    ('loading', payLoadingState),
    ('recipient', payRecipientState),
    ('amount', payAmountState),
  ]) {
    testWidgets('the $name page has a back that sends PayBackPressed', (
      tester,
    ) async {
      final events = <PayFlowEvent>[];
      await _pump(tester, state, events: events);
      await tester.tap(find.byTooltip('Back').last);
      expect(events.single, isA<PayBackPressed>());
    });
  }

  testWidgets('an order limit refusal shows the amount page with the limit', (
    tester,
  ) async {
    final back = applyPay(payOrderingState, [
      PayOrderChanged(
        OrderCreateAnswered(
          1,
          GateAdmitted(
            WriteRefused(
              ExchangeRefusal(
                orderLimit: const ExchangeOrderLimit(
                  ExchangeOrderAmountBound.minimum,
                  20,
                  'CAD',
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
    final labels = await _pump(tester, back);
    expect(find.byType(PayAmountPage), findsOneWidget);
    expect(
      find.text(labels.exchangeOrderBelowMinimum('20.0', 'CAD')),
      findsOneWidget,
    );
  });
}
