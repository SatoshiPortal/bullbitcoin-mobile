import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bull_exchange/src/withdraw/presentation/withdraw_flow.dart';
import 'package:bull_exchange/src/withdraw/ui/screens/withdraw_amount_page.dart';
import 'package:bull_exchange/src/withdraw/ui/screens/withdraw_review_page.dart';
import 'package:bull_exchange/src/withdraw/ui/withdraw_flow_shell.dart';
import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../withdraw_fixtures.dart';

Future<ExchangeLocalizations> _pump(
  WidgetTester tester,
  WithdrawFlowState state, {
  List<WithdrawFlowEvent>? events,
  List<String>? opened,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: testBullExtensions),
      localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
      supportedLocales: ExchangeLocalizations.supportedLocales,
      home: Navigator(
        pages: withdrawPagesFor(
          state,
          brandAsset: 'assets/none.png',
          onEvent: (event) => events?.add(event),
          openOrder: (id) => opened?.add(id),
        ),
        onDidRemovePage: (_) {},
      ),
    ),
  );
  await tester.pump();
  return ExchangeLocalizations.of(tester.element(find.byType(Navigator).last));
}

WithdrawConfirming _confirming(WithdrawConfirmState confirm) {
  final review = withdrawReviewState as WithdrawReview;
  return WithdrawConfirming(
    review.open,
    review.amount,
    review.recipient,
    review.order,
    confirm,
  );
}

void main() {
  testWidgets('the amount page sends the typed text and Continue', (
    tester,
  ) async {
    final events = <WithdrawFlowEvent>[];
    final labels = await _pump(tester, withdrawAmountState, events: events);
    expect(find.byType(WithdrawAmountPage), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '12');
    await tester.tap(find.text(labels.withdrawAmountContinue));
    expect(
      events.map((e) => (e as WithdrawAmountChanged).event),
      [
        isA<AmountTyped>().having((e) => e.text, 'text', '12'),
        isA<AmountContinuePressed>(),
      ],
    );
  });

  testWidgets('review offers Confirm; confirming shows no live Confirm', (
    tester,
  ) async {
    final events = <WithdrawFlowEvent>[];
    final labels = await _pump(tester, withdrawReviewState, events: events);
    expect(find.byType(WithdrawReviewPage), findsOneWidget);
    await tester.tap(find.text(labels.withdrawConfirmButton));
    expect(events.single, isA<WithdrawConfirmPressed>());

    events.clear();
    final review = withdrawReviewState as WithdrawReview;
    await _pump(
      tester,
      _confirming(ConfirmConfirming(review.target, 1)),
      events: events,
    );
    await tester.tap(find.text(labels.withdrawConfirmButton));
    expect(events, isEmpty);
  });

  testWidgets('an unverified confirm offers Check again, never Confirm', (
    tester,
  ) async {
    final review = withdrawReviewState as WithdrawReview;
    final labels = await _pump(
      tester,
      _confirming(
        ConfirmUnverified(
          review.target,
          1,
          const ReadProblemUnreachable(isNetwork: true),
        ),
      ),
    );
    expect(find.text(labels.withdrawConfirmCheckAgainButton), findsOneWidget);
    expect(find.text(labels.withdrawConfirmButton), findsNothing);
  });

  testWidgets('done opens the order', (tester) async {
    final opened = <String>[];
    final review = withdrawReviewState as WithdrawReview;
    final labels = await _pump(
      tester,
      WithdrawDone(review.open, withdrawOrder(status: OrderStatus.inProgress)),
      opened: opened,
    );
    await tester.tap(find.text(labels.withdrawSuccessOrderDetails));
    expect(opened, ['w-1']);
  });

  testWidgets('a failed load shows why with a Retry', (tester) async {
    final events = <WithdrawFlowEvent>[];
    final labels = await _pump(
      tester,
      const WithdrawLoading(
        withdrawSession,
        ContextFailed(1, ReadProblemUnreachable(isNetwork: true)),
      ),
      events: events,
    );
    expect(find.text(labels.exchangeErrorNetwork), findsOneWidget);
    await tester.tap(find.text(labels.retry));
    expect(events.single, isA<WithdrawRetryPressed>());
  });
}
