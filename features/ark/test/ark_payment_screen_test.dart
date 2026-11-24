import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/presentation/ark_payment_cubit.dart';
import 'package:bull_ark/src/ui/ark_payment_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullInputText,
        BullPaymentTransition,
        BullPaymentDestinationInput,
        BullTopBar,
        SizedBox,
        ValueChanged,
        ValueKey,
        VoidCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;

import 'package:bull_ark/src/ui/ark_review.dart';

import 'ark_operations_test.dart' show account;
import 'ark_payment_cubit_test.dart' show PaymentRig, paymentQuote, destination;

/// The send confirmation's rows, as label to value.
Map<String, String> details(WidgetTester tester) => {
  for (final fact in tester.widgetList<ArkReviewFact>(
    find.byType(ArkReviewFact),
  ))
    fact.label: fact.value,
  for (final address in tester.widgetList<ArkReviewAddress>(
    find.byType(ArkReviewAddress),
  ))
    address.label: address.address,
};

Future<void> frame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

BullButton action(WidgetTester tester, String label) {
  final finder = find.widgetWithText(BullButton, label);
  expect(finder, findsOneWidget, reason: 'Explicit $label action');
  return tester.widget<BullButton>(finder);
}

/// The address field (0) or the amount field (1): its value and edit callback.
({String value, ValueChanged<String> onChanged}) input(
  WidgetTester tester,
  int index,
) {
  if (index == 0) {
    final field = tester.widget<BullPaymentDestinationInput>(
      find.byKey(const ValueKey('ark-payment-address')),
    );
    return (value: field.value, onChanged: field.onChanged);
  }
  final field = tester.widget<BullInputText>(
    find.byKey(const ValueKey('ark-payment-amount')),
  );
  return (value: field.value, onChanged: field.onChanged);
}

/// The destination field's scan action.
VoidCallback scanAction(WidgetTester tester) => tester
    .widget<BullPaymentDestinationInput>(
      find.byKey(const ValueKey('ark-payment-address')),
    )
    .onScan;

VoidCallback cancelAction(WidgetTester tester) {
  final callback = tester.widget<BullTopBar>(find.byType(BullTopBar)).onBack;
  if (callback == null) throw StateError('Expected explicit back action');
  return callback;
}

Future<void> expectDestination(WidgetTester tester, String value) async {
  cancelAction(tester)();
  await frame(tester);
  expect(input(tester, 0).value, value);
  action(tester, 'Continue').onPressed();
  await frame(tester);
}

ArkPaymentScreen page(
  PaymentRig r, {
  void Function()? reconcile,
  String initial = destination,
}) => ArkPaymentScreen(
  cubit: r.cubit,
  initialDestination: initial,
  onReconcile: reconcile ?? () {},
);

void main() {
  testWidgets('skipping a pending payment reveals status without details', (
    tester,
  ) async {
    final r = PaymentRig();
    final viewed = <String>[];
    r.client.submitted = Ok(
      ArkOperation(
        id: 'payment-1',
        kind: ArkOperationKind.payment,
        status: ArkOperationStatus.pending,
        chainSource: Uri.parse('http://localhost:3000'),
        configGeneration: 1,
      ),
    );
    await tester.pumpWidget(
      app(
        ArkPaymentScreen(
          cubit: r.cubit,
          initialDestination: destination,
          onReconcile: () {},
          onViewDetails: viewed.add,
        ),
      ),
    );
    await r.ready();
    await frame(tester);
    action(tester, 'Confirm').onPressed();
    await frame(tester);
    expect(find.byType(BullPaymentTransition), findsOneWidget);
    await tester.tap(find.text('View status'));
    await frame(tester);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Payment sent'), findsNothing);
    expect(find.widgetWithText(BullButton, 'View details'), findsNothing);
    expect(viewed, isEmpty);
    expect(r.client.calls.where((call) => call == 'submit').length, 1);
  });

  testWidgets('an unclear payment closes to home and Ark checks it', (
    tester,
  ) async {
    final r = PaymentRig(reconciliation: true);
    var reconciles = 0, homes = 0;
    await tester.pumpWidget(
      app(
        ArkPaymentScreen(
          cubit: r.cubit,
          onReconcile: () => reconciles++,
          onHome: () => homes++,
        ),
      ),
    );
    await frame(tester);
    r.cubit.emit(const ArkPaymentUncertain('original'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // No page of its own: a snackbar, Ark refreshed, back home.
    expect(find.widgetWithText(BullButton, 'Refresh'), findsNothing);
    expect(
      find.textContaining('couldn’t confirm whether your payment'),
      findsOneWidget,
    );
    expect(reconciles, 1);
    expect(homes, 1);
    expect(r.client.calls.where((c) => c == 'submit'), isEmpty);
    await tester.pump(const Duration(seconds: 4)); // Snackbar timer.
  });
  testWidgets(
    'initial destination and edits never quote; explicit Review captures current locals',
    (tester) async {
      final r = PaymentRig();
      await tester.pumpWidget(app(page(r)));
      await frame(tester);
      expect(r.client.calls, isEmpty);
      await expectDestination(tester, destination);
      input(tester, 1).onChanged('1000');
      await frame(tester);
      expect(r.client.calls, isEmpty);
      r.client.quoted = Ok(paymentQuote(r.cubit.account));
      final review = action(tester, 'Continue').onPressed;
      review();
      review();
      await frame(tester);
      expect(r.client.calls, ['quote']);
      // The app's send confirmation rows; Ark has no fee priority.
      expect(details(tester), {
        'From': 'Ark',
        'To': destination,
        'Amount': '900 sats',
        'Network fees': '100 sats',
      });
      expect(find.widgetWithText(BullButton, 'Continue'), findsNothing);
      expect(r.ids, 0);
    },
  );
  testWidgets(
    'field callback invalidates pending epoch but cannot edit current Review',
    (tester) async {
      final r = PaymentRig();
      await tester.pumpWidget(app(page(r)));
      await frame(tester);
      final oldField = input(tester, 1).onChanged;
      oldField('1000');
      await frame(tester);
      final reply = Completer<Result<ArkQuote, ArkWalletFailure>>();
      r.client.replies.add(reply);
      action(tester, 'Continue').onPressed();
      await frame(tester);
      expect(r.cubit.state, isA<ArkPaymentQuoting>());
      oldField('2000');
      await frame(tester);
      expect(input(tester, 1).value, '2000');
      reply.complete(Ok(paymentQuote(r.cubit.account)));
      await frame(tester);
      expect(r.cubit.state, isA<ArkPaymentEditing>());
      r.client.quoted = Ok(paymentQuote(r.cubit.account, amount: 2000));
      action(tester, 'Continue').onPressed();
      await frame(tester);
      oldField('9999');
      await frame(tester);
      expect(r.cubit.state, isA<ArkPaymentReview>());
      expect(details(tester)['Amount'], '1,900 sats');
      cancelAction(tester)();
      await frame(tester);
      expect(input(tester, 1).value, '2000');
      expect(r.client.calls, ['quote', 'quote']);
    },
  );
  testWidgets(
    'q1 Confirm and Cancel cannot act on same-ID q2; pending admission locks all old controls',
    (tester) async {
      final r = PaymentRig();
      await r.ready();
      await tester.pumpWidget(app(page(r)));
      await frame(tester);
      final confirm1 = action(tester, 'Confirm').onPressed;
      final cancel1 = cancelAction(tester);
      r.cubit.edit();
      await r.ready(amount: 2000);
      await frame(tester);
      confirm1();
      cancel1();
      await frame(tester);
      expect(r.cubit.state, isA<ArkPaymentReview>());
      expect(r.ids, 0);
      final pending = Completer<Result<ArkOperation, ArkWalletFailure>>();
      r.client.submission = pending;
      final confirm2 = action(tester, 'Confirm').onPressed;
      final cancel2 = cancelAction(tester);
      confirm2();
      confirm2();
      cancel2();
      await frame(tester);
      expect(r.cubit.state, isA<ArkPaymentSubmitting>());
      expect(r.ids, 1);
      expect(r.client.calls.where((c) => c == 'submit'), hasLength(1));
      pending.complete(const Err(ArkStorageFailure()));
      await frame(tester);
      expect(r.cubit.state, isA<ArkPaymentUncertain>());
      // Unclear: no page of its own, the flow closes and Ark checks it.
      expect(find.widgetWithText(BullButton, 'Refresh'), findsNothing);
      confirm1();
      cancel1();
      confirm2();
      cancel2();
      r.cubit.edit();
      await r.cubit.confirm();
      await r.cubit.review(destination: destination, amount: '2000');
      await frame(tester);
      expect(r.ids, 1);
      expect(r.client.journal.keys, ['payment-1']);
      expect(find.widgetWithText(BullButton, 'Continue'), findsNothing);
      expect(find.widgetWithText(BullButton, 'Cancel'), findsNothing);
      await tester.pump(const Duration(seconds: 4)); // Snackbar timer.
    },
  );
  for (final sameAccount in [true, false]) {
    testWidgets(
      'all old controls refuse new owner sameAccount=$sameAccount and disposal',
      (tester) async {
        final a = PaymentRig();
        var oldReconciles = 0, newReconciles = 0;
        await tester.pumpWidget(app(page(a, reconcile: () => oldReconciles++)));
        await frame(tester);
        final oldField = input(tester, 1).onChanged;
        final oldReview = action(tester, 'Continue').onPressed;
        await a.ready();
        await frame(tester);
        final oldConfirm = action(tester, 'Confirm').onPressed;
        final oldCancel = cancelAction(tester);
        a.cubit.emit(const ArkPaymentUncertain('original'));
        await frame(tester);
        final original = account();
        final b = PaymentRig(
          owner: sameAccount
              ? original
              : ArkAccountId(
                  parent: original.parent,
                  network: original.network,
                  serverIdentity: 'new-server',
                ),
        );
        await tester.pumpWidget(
          app(
            page(b, initial: 'new-initial', reconcile: () => newReconciles++),
          ),
        );
        await frame(tester);
        oldField('9999');
        oldReview();
        oldConfirm();
        oldCancel();
        await frame(tester);
        await expectDestination(tester, 'new-initial');
        expect(input(tester, 1).value, '');
        expect(b.client.calls, isEmpty);
        expect(a.client.calls, ['quote']);
        // The unclear payment refreshed Ark once, by itself; nothing else.
        expect(a.ids + b.ids + newReconciles, 0);
        expect(oldReconciles, 1);
        expect(a.cubit.isClosed, false);
        final field = input(tester, 1).onChanged;
        final review = action(tester, 'Continue').onPressed;
        await b.ready();
        await frame(tester);
        final confirm = action(tester, 'Confirm').onPressed;
        final cancel = cancelAction(tester);
        b.cubit.emit(const ArkPaymentUncertain('current'));
        await frame(tester);
        await tester.pumpWidget(app(const SizedBox.shrink()));
        field('1');
        review();
        confirm();
        cancel();
        await frame(tester);
        expect(b.client.calls, ['quote']);
        expect(b.ids, 0);
        expect(b.cubit.isClosed, false);
        await tester.pump(const Duration(seconds: 4)); // Snackbar timer.
      },
    );
  }
  testWidgets(
    'Review belongs to exact Editing state and locals cannot change after submission',
    (tester) async {
      final r = PaymentRig();
      await tester.pumpWidget(app(page(r)));
      await frame(tester);
      final field = input(tester, 1).onChanged;
      field('1000');
      await frame(tester);
      // A disabled Continue is inert, so capture it once enabled; then edit
      // again. Editing may retain its canonical state identity: Review
      // captures CURRENT locals, not the ones from the captured frame.
      final oldReview = action(tester, 'Continue').onPressed;
      field('2000');
      await frame(tester);
      r.client.quoted = Ok(paymentQuote(r.cubit.account));
      oldReview();
      await frame(tester);
      expect(r.client.calls, ['quote']);
      r.cubit.emit(const ArkPaymentEditing(ArkInvalidRequestFailure()));
      await frame(tester);
      final stale = action(tester, 'Continue').onPressed;
      r.cubit.edit();
      await frame(tester);
      stale();
      expect(r.client.calls, ['quote']);
      await r.ready();
      await frame(tester);
      final submit = Completer<Result<ArkOperation, ArkWalletFailure>>();
      r.client.submission = submit;
      action(tester, 'Confirm').onPressed();
      await frame(tester);
      field('9999');
      await frame(tester);
      expect(r.cubit.state, isA<ArkPaymentSubmitting>());
      submit.complete(const Err(ArkStorageFailure()));
      await frame(tester);
      field('9999');
      await frame(tester);
      expect(r.cubit.state, isA<ArkPaymentUncertain>());
      expect(r.client.calls, ['quote', 'quote', 'submit']);
      await tester.pump(const Duration(seconds: 4)); // Snackbar timer.
    },
  );
  testWidgets(
    'backend status and original ID remain non-rearm, including failed/conflicted',
    (tester) async {
      final r = PaymentRig();
      const started = {
        ArkOperationStatus.prepared,
        ArkOperationStatus.admitted,
        ArkOperationStatus.pending,
        ArkOperationStatus.succeeded,
      };
      for (final status in ArkOperationStatus.values) {
        r.cubit.emit(
          ArkPaymentSubmitted(
            ArkOperation(
              id: 'backend-original',
              kind: ArkOperationKind.payment,
              status: status,
              chainSource: Uri.parse('http://localhost:3000'),
              configGeneration: 1,
            ),
          ),
        );
        await tester.pumpWidget(app(page(r)));
        await frame(tester);
        // Only a completed operation can be announced as sent.
        expect(
          find.text('Payment sent'),
          status == ArkOperationStatus.succeeded
              ? findsOneWidget
              : findsNothing,
        );
        if (started.contains(status) &&
            status != ArkOperationStatus.succeeded) {
          expect(
            find.text(
              status == ArkOperationStatus.pending
                  ? 'Pending'
                  : status == ArkOperationStatus.admitted
                  ? 'Admitted'
                  : 'Prepared',
            ),
            findsOneWidget,
          );
        }
        // A submitted payment never re-arms editing, review or confirm.
        r.cubit.edit();
        await r.cubit.confirm();
        await r.cubit.review(destination: destination, amount: '1000');
        expect(r.client.calls, isEmpty);
        expect(r.ids, 0);
        await tester.pump(const Duration(seconds: 4)); // Snackbar timer.
      }
    },
  );
  testWidgets(
    'foreign quote is unavailable and never exposes confirm or cancel',
    (tester) async {
      final r = PaymentRig();
      final owner = account();
      r.cubit.emit(
        ArkPaymentReview(
          paymentQuote(
            ArkAccountId(
              parent: owner.parent,
              network: owner.network,
              serverIdentity: 'foreign',
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(page(r)));
      await frame(tester);
      expect(find.widgetWithText(BullButton, 'Confirm'), findsNothing);
      expect(find.widgetWithText(BullButton, 'Cancel'), findsNothing);
      expect(r.ids, 0);
      expect(r.client.calls, isEmpty);
    },
  );
}
