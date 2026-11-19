import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/presentation/ark_operation_cubit.dart';
import 'package:bull_ark/src/ui/ark_operation_review_screen.dart';
import 'package:bull_ark/src/ui/ark_exit_hold_button.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullDetailsTable;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show Dialog, Navigator, SizedBox, showDialog;
import 'package:primitives/primitives.dart';

import 'ark_exit_review_cycle_test.dart' show quoteFor;
import 'ark_information_widget_test.dart' show app;
import 'ark_operation_review_screen_test.dart' show Rig, pumpState;

ArkQuoteRequest request() => ArkQuoteRequest.emergencyExit(
  ids: ['v'],
  destination: 'bcrt1-return',
  feeRate: FeeRate(2),
  maxClaimFee: Sats.fromInt(500),
);
BullButton retry(WidgetTester tester) => tester.widget<BullButton>(
  find.ancestor(
    of: find.textContaining(RegExp(r'^(Retry|Review)$')),
    matching: find.byType(BullButton),
  ),
);
Future<Rig> refused(
  WidgetTester tester, {
  ArkQuoteRequest? intent,
  ArkWalletFailure failure = const ArkInsufficientFundsFailure(),
}) async {
  final r = Rig(request: intent ?? request());
  r.client.quoted = Err(failure);
  await r.cubit.load();
  await tester.pumpWidget(app(r.screen));
  await pumpState(tester);
  return r;
}

void main() {
  testWidgets(
    'initial typed exit refusal is explicit and offers current-page Retry',
    (tester) async {
      final r = await refused(tester);
      expect(find.text('Exit not started'), findsOneWidget);
      expect(find.widgetWithText(BullButton, 'Retry'), findsOneWidget);
      expect(find.text('Insufficient funds, including fees.'), findsOneWidget);
      expect(find.widgetWithText(BullButton, 'Confirm'), findsNothing);
      expect(find.byType(ArkExitHoldButton), findsNothing);
      expect(find.byType(BullDetailsTable), findsNothing);
      expect(r.client.calls, ['quote']);
      r.client.quoted = Ok(quoteFor('start'));
      final old = retry(tester).onPressed;
      old();
      old();
      await pumpState(tester);
      expect(r.client.calls, ['quote', 'quote']);
      expect(r.cubit.state, isA<ArkOperationReview>());
      expect(r.ids, 0);
      old();
      expect(r.client.calls, ['quote', 'quote']);
    },
  );
  testWidgets('a covered refusal cannot retry until its page is current', (
    tester,
  ) async {
    final r = await refused(tester);
    final old = retry(tester).onPressed;
    final context = tester.element(find.byType(ArkOperationReviewScreen));
    final cover = showDialog<void>(
      context: context,
      builder: (_) => const Dialog(child: SizedBox(width: 30, height: 30)),
    );
    await tester.pumpAndSettle();
    late List<String> coveredCalls;
    try {
      old();
      await pumpState(tester);
      coveredCalls = List.of(r.client.calls);
    } finally {
      Navigator.of(context).pop();
      await cover;
      await tester.pumpAndSettle();
    }
    expect(coveredCalls, ['quote']);
    retry(tester).onPressed();
    await pumpState(tester);
    expect(r.client.calls, ['quote', 'quote']);
    expect(r.ids, 0);
  });
  testWidgets(
    'delayed retry is single-flight and never submits or reuses a stale action',
    (tester) async {
      final r = await refused(tester);
      final old = retry(tester).onPressed;
      final reply = Completer<Result<ArkQuote, ArkWalletFailure>>();
      r.client.quoteReply = reply;
      old();
      old();
      await pumpState(tester);
      expect(r.client.calls, ['quote', 'quote']);
      expect(r.cubit.state, isA<ArkOperationLoading>());
      reply.complete(Ok(quoteFor('start')));
      await pumpState(tester);
      old();
      expect(r.client.calls, ['quote', 'quote']);
      expect(r.ids, 0);
    },
  );
  testWidgets(
    'owner replacement and disposal retire the original failure callback',
    (tester) async {
      final first = await refused(tester);
      final old = retry(tester).onPressed;
      final second = Rig(request: request());
      second.client.quoted = const Err(ArkInsufficientFundsFailure());
      await second.cubit.load();
      await tester.pumpWidget(app(second.screen));
      old();
      await pumpState(tester);
      expect(first.client.calls, ['quote']);
      expect(second.client.calls, ['quote']);
      retry(tester).onPressed();
      await pumpState(tester);
      expect(second.client.calls, ['quote', 'quote']);
      final disposed = retry(tester).onPressed;
      await tester.pumpWidget(app(const SizedBox.shrink()));
      disposed();
      expect(second.client.calls, ['quote', 'quote']);
      expect(first.ids + second.ids, 0);
    },
  );
  for (final intent in [
    ArkQuoteRequest.claim(
      ids: ['v'],
      destination: 'bcrt1-return',
      maxFee: Sats.fromInt(500),
    ),
    ArkQuoteRequest.renewal(ids: ['v']),
    ArkQuoteRequest.payment(
      destination: ArkPaymentDestination(
        kind: ArkDestinationKind.ark,
        value: 'ark-destination',
      ),
      amount: Sats.fromInt(1000),
    ),
  ]) {
    testWidgets(
      'insufficient failure for ${intent.runtimeType} keeps generic presentation',
      (tester) async {
        final r = await refused(tester, intent: intent);
        expect(find.text('Exit not started'), findsNothing);
        expect(find.widgetWithText(BullButton, 'Retry'), findsNothing);
        expect(r.client.calls, ['quote']);
      },
    );
  }
  for (final failure in [
    const ArkUnavailableFailure(),
    const ArkValidationFailure(),
    const ArkWriterBusyFailure(),
  ]) {
    testWidgets('unrelated ${failure.runtimeType} is not NoFunds', (
      tester,
    ) async {
      final r = await refused(tester, failure: failure);
      expect(find.text('Exit not started'), findsNothing);
      expect(r.ids, 0);
    });
  }
  testWidgets(
    'failure after confirmation never becomes an initial quote refusal',
    (tester) async {
      final r = Rig(request: request());
      r.client.quoted = Ok(quoteFor('start'));
      await r.cubit.load();
      r.client.submitted = const Err(ArkInsufficientFundsFailure());
      await r.cubit.confirm();
      await tester.pumpWidget(app(r.screen));
      await pumpState(tester);
      expect(r.cubit.confirmationAttempted, isTrue);
      expect(r.cubit.state, isA<ArkOperationUncertain>());
      expect(find.text('Exit not started'), findsNothing);
      // Inject a late typed failure publication after a real attempted confirm.
      // The production use case conservatively maps submit errors to Uncertain.
      r.cubit.emit(
        const ArkOperationFailed(ArkPaymentInsufficientFundsFailure()),
      );
      await pumpState(tester);
      expect(find.text('Exit not started'), findsNothing);
      expect(find.widgetWithText(BullButton, 'Retry'), findsNothing);
      expect(r.client.calls, ['quote', 'submit']);
      expect(r.ids, 1);
    },
  );
}
