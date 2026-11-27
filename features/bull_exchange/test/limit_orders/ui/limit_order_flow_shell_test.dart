import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_exchange/src/limit_orders/domain/limit_order_state.dart';
import 'package:bull_exchange/src/limit_orders/domain/limit_order_event.dart';
import 'package:bull_exchange/src/limit_orders/ui/limit_order_flow_shell.dart';
import 'package:bull_exchange/src/limit_orders/ui/screens/limit_order_pages.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../limit_order_fixtures.dart';

import 'package:primitives/primitives.dart';

LimitFlowState _apply(LimitFlowState state, List<LimitFlowEvent> events) {
  var next = state;
  for (final event in events) {
    next = next.next(event).state;
  }
  return next;
}

const _btcOption = DestinationOptionDefaultWallet(
  BtcNetwork.bitcoin,
  limitBitcoinAddress,
);

final _intro = _apply(limitFlowStart(limitSession).state, [
  LimitContextLoaded(
    1,
    Ok(
      LimitOrderContext(
        userSummary(),
        limitDefaultWallets(),
        const [],
        const [],
      ),
    ),
  ),
]);
final _destination = _apply(_intro, [
  const LimitContinuePressed(),
  LimitTargetRateArrived(ExchangeCatalog.cad, 1, Ok(limitOrderRate())),
  const LimitContinuePressed(),
]);
final _review = _apply(_destination, const [
  LimitDestinationChanged(PickChose(_btcOption)),
  LimitContinuePressed(),
  LimitAmountChanged(AmountTyped('200')),
  LimitContinuePressed(),
]);
final _live = _apply(_review, [
  LimitReviewRateArrived(1, Ok(limitOrderRate())),
]);

Widget _payoutField({
  required BtcNetwork type,
  required String value,
  required String label,
  required String hint,
  required bool enabled,
  required ValueChanged<String> onChanged,
  required ValueChanged<String?> onValidated,
}) => TextField(onChanged: onChanged);

Future<ExchangeLocalizations> _pump(
  WidgetTester tester,
  LimitFlowState state,
  List<LimitFlowEvent> events,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: testBullExtensions),
      localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
      supportedLocales: ExchangeLocalizations.supportedLocales,
      home: limitPageFor(
        state,
        payoutField: _payoutField,
        onEvent: events.add,
        onFund: () {},
        onManageDefaultWallets: () {},
        onOpenKyc: () {},
      ),
    ),
  );
  await tester.pump();
  return ExchangeLocalizations.of(tester.element(find.byType(Scaffold).last));
}

Finder _button(String label) =>
    find.descendant(of: find.byType(BullButton), matching: find.text(label));

BullButton _buttonWidget(WidgetTester tester, String label) =>
    tester.widget<BullButton>(
      find.ancestor(of: find.text(label), matching: find.byType(BullButton)),
    );

void main() {
  testWidgets('the intro continues as an event', (tester) async {
    final events = <LimitFlowEvent>[];
    final labels = await _pump(tester, _intro, events);
    expect(find.byType(LimitIntroPage), findsOneWidget);
    await tester.tap(_button(labels.continueButton));
    expect(events.single, isA<LimitContinuePressed>());
  });

  testWidgets('the destination lists the default wallet and waits for a '
      'pick', (tester) async {
    final events = <LimitFlowEvent>[];
    final labels = await _pump(tester, _destination, events);
    expect(find.text(limitBitcoinAddress), findsOneWidget);
    expect(_buttonWidget(tester, labels.continueButton).disabled, isTrue);
    await tester.tap(find.text(limitBitcoinAddress));
    expect(
      events.single,
      isA<LimitDestinationChanged>().having(
        (e) => e.event,
        'event',
        isA<PickChose<DestinationOption, Destination>>(),
      ),
    );
  });

  testWidgets('the review offers Confirm only on a live check', (tester) async {
    final events = <LimitFlowEvent>[];
    var labels = await _pump(tester, _review, events);
    expect(_buttonWidget(tester, labels.limitOrdersConfirm).disabled, isTrue);
    labels = await _pump(tester, _live, events);
    expect(find.text(limitBitcoinAddress), findsOneWidget);
    await tester.tap(_button(labels.limitOrdersConfirm));
    expect(events.single, isA<LimitConfirmPressed>());
  });

  testWidgets('a target above the index price says so', (tester) async {
    final above = _apply(_review, [
      LimitReviewRateArrived(1, Ok(limitOrderRate(indexPrice: 90000))),
    ]);
    final labels = await _pump(tester, above, []);
    expect(find.text(labels.limitOrderInvalidTargetError), findsOneWidget);
    expect(_buttonWidget(tester, labels.limitOrdersConfirm).disabled, isTrue);
  });

  testWidgets('a create being checked offers no write and no Back', (
    tester,
  ) async {
    final verifying = _apply(_live, const [
      LimitConfirmPressed(),
      LimitConfirmChanged(
        ConfirmAnswered(1, Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
      ),
    ]);
    final labels = await _pump(tester, verifying, []);
    expect(find.text(labels.exchangeStepVerifying), findsOneWidget);
    expect(_button(labels.limitOrdersConfirm), findsNothing);
  });

  testWidgets('a refused create names the reason', (tester) async {
    final refused = _apply(_live, const [
      LimitConfirmPressed(),
      LimitConfirmChanged(
        ConfirmAnswered(
          1,
          Err(
            ExchangeWriteRefusedFailure(
              ExchangeRefusal(apiCode: 'ERR_ORDTRG_LOMAX429'),
            ),
          ),
        ),
      ),
    ]);
    final labels = await _pump(tester, refused, []);
    expect(find.text(labels.limitOrdersMaximumActiveError), findsOneWidget);
  });

  testWidgets('the done page opens the order or goes back', (tester) async {
    final events = <LimitFlowEvent>[];
    final done = _apply(_live, [
      const LimitConfirmPressed(),
      LimitConfirmChanged(ConfirmAnswered(1, Ok(limitOrder()))),
    ]);
    final labels = await _pump(tester, done, events);
    await tester.tap(_button(labels.limitOrdersViewOrder));
    await tester.tap(_button(labels.limitOrdersBackToExchange));
    expect(events, [isA<LimitViewOrderPressed>(), isA<LimitDonePressed>()]);
  });
}
