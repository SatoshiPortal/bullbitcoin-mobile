import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_exchange/src/buy/domain/buy_accelerate_flow.dart';
import 'package:bull_exchange/src/buy/ui/buy_accelerate_shell.dart';
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

import '../buy_fixtures.dart';

const _fee = AccelerateFee(satPerVbyte: 2.5, sats: 350, fiatPerBitcoin: 50000);

Future<void> _pump(
  WidgetTester tester,
  AccelerateFlowState state,
  List<AccelerateFlowEvent> events,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: testBullExtensions),
      localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
      supportedLocales: ExchangeLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => accelerateViewFor(
          context,
          state,
          unit: BitcoinUnit.sats,
          onEvent: events.add,
          openOrder: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final loading = accelerateFlowStart(buySession, 'b-1').state;
  final quote = AccelerateQuote(
    buyOrder(status: OrderStatus.inProgress),
    _fee,
    const [],
  );
  final ready = transitionAccelerateFlow(
    loading,
    AccelerateLoaded(1, ReadGot(quote)),
  ).state;

  // The accelerate route is often opened with nothing under it (from an
  // order's details): its back is the flow's event, never implied.
  for (final (name, state) in [('loading', loading), ('fee', ready)]) {
    testWidgets('the $name page has a back that sends AccelerateBackPressed', (
      tester,
    ) async {
      final events = <AccelerateFlowEvent>[];
      await _pump(tester, state, events);
      await tester.tap(find.byTooltip('Back'));
      expect(events.single, isA<AccelerateBackPressed>());
    });
  }
}
