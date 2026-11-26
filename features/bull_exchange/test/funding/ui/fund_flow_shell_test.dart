import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_exchange/src/funding/domain/fund_flow.dart';
import 'package:bull_exchange/src/funding/ui/fund_flow_shell.dart';
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'a',
);

Future<void> _pump(
  WidgetTester tester,
  FundFlowState state,
  List<FundFlowEvent> events,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: testBullExtensions),
      localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
      supportedLocales: ExchangeLocalizations.supportedLocales,
      home: Navigator(
        pages: fundPagesFor(state, onEvent: events.add, onOpenLink: (_) {}),
        onDidRemovePage: (_) {},
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // Each of these is the only page of the fund flow's navigator: a back
  // implied by the navigator would show nothing there.
  for (final (name, state) in [
    ('loading', const FundLoading(_session, ContextLoading(1))),
    ('session ended', const FundSessionEnded()),
  ]) {
    testWidgets('the $name page has a back that sends FundBackPressed', (
      tester,
    ) async {
      final events = <FundFlowEvent>[];
      await _pump(tester, state, events);
      await tester.tap(find.byTooltip('Back'));
      expect(events.single, isA<FundBackPressed>());
    });
  }

  testWidgets('the session ended page leaves through the flow', (tester) async {
    final events = <FundFlowEvent>[];
    await _pump(tester, const FundSessionEnded(), events);
    final labels = ExchangeLocalizations.of(
      tester.element(find.byType(Navigator).last),
    );
    await tester.tap(find.text(labels.fundExchangeDoneButton));
    expect(events.single, isA<FundDonePressed>());
  });
}
