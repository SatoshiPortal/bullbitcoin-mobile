import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_exchange/src/autobuy/domain/autobuy_flow.dart';
import 'package:bull_exchange/src/autobuy/ui/autobuy_flow_shell.dart';
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../autobuy_fixtures.dart';

import 'package:primitives/primitives.dart';

AutoBuyFlowState _apply(AutoBuyFlowState state, List<AutoBuyFlowEvent> events) {
  var next = state;
  for (final event in events) {
    next = transitionAutoBuyFlow(next, event).state;
  }
  return next;
}

AutoBuyFlowState _review({bool active = false}) =>
    _apply(autoBuyFlowStart(autoBuySession).state, [
      AutoBuyContextLoaded(1, Ok(autoBuyContext(active: active))),
      const AutoBuyGetStartedPressed(),
      const AutoBuyWalletsContinued(autoBuyWallets),
    ]);

Widget _field({
  required BtcNetwork type,
  required String value,
  required String hint,
  required bool enabled,
  required ValueChanged<String> onChanged,
  required ValueChanged<bool> onValidationChanged,
}) => const SizedBox.shrink();

Future<ExchangeLocalizations> _pump(
  WidgetTester tester,
  AutoBuyFlowState state,
  List<AutoBuyFlowEvent> events,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: testBullExtensions),
      localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
      supportedLocales: ExchangeLocalizations.supportedLocales,
      home: autoBuyPageFor(
        state,
        host: (
          exchange: exchangeForTesting(),
          payoutFields: (validate: (_, _) async => null, buildField: _field),
          addressViewer: (_, address) => Text(address),
          terms: Uri.parse('https://example.com/terms'),
        ),
        onEvent: events.add,
        onOpenKyc: () {},
      ),
    ),
  );
  await tester.pump();
  return ExchangeLocalizations.of(tester.element(find.byType(Scaffold).last));
}

void main() {
  testWidgets('the review lists the wallets and activates as an event', (
    tester,
  ) async {
    final events = <AutoBuyFlowEvent>[];
    final labels = await _pump(tester, _review(), events);
    expect(find.text('bc1qauto'), findsOneWidget);
    await tester.tap(find.text(labels.autoBuyActivate));
    expect(events.single, isA<AutoBuyActivatePressed>());
  });

  testWidgets('an active account sees it is active and Done (AB-2)', (
    tester,
  ) async {
    final events = <AutoBuyFlowEvent>[];
    final labels = await _pump(tester, _review(active: true), events);
    expect(find.text(labels.autoBuyAlreadyActive), findsOneWidget);
    expect(find.text(labels.autoBuyActivate), findsNothing);
    await tester.tap(find.text(labels.doneButton));
    expect(events.single, isA<AutoBuyDonePressed>());
  });

  testWidgets('an activation being checked offers no write', (tester) async {
    final verifying = _apply(_review(), const [
      AutoBuyActivatePressed(),
      AutoBuyConfirmChanged(
        ConfirmAnswered(
          1,
          GateAdmitted(Err(ExchangeWriteOutcomeUnknownFailure('lost'))),
        ),
      ),
    ]);
    final labels = await _pump(tester, verifying, []);
    expect(find.text(labels.exchangeStepVerifying), findsOneWidget);
    expect(find.text(labels.autoBuyActivate), findsNothing);
  });

  testWidgets('a restricted intro offers no Get started', (tester) async {
    final restricted = _apply(autoBuyFlowStart(autoBuySession).state, [
      AutoBuyContextLoaded(
        1,
        Ok(
          autoBuyContext(
            groups: const ['KYC_IDENTITY_VERIFIED', 'RESTRICTED_FULL'],
          ),
        ),
      ),
    ]);
    final labels = await _pump(tester, restricted, []);
    expect(find.text(labels.fundExchangeRestrictedTitle), findsOneWidget);
    expect(find.text(labels.autoBuyGetStarted), findsNothing);
  });
}
