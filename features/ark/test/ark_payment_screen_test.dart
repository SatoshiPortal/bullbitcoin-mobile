import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/presentation/ark_payment_cubit.dart';
import 'package:bull_ark/src/ui/ark_payment_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullInputText, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_operation_review_screen_test.dart' show details;
import 'ark_operations_test.dart' show account;
import 'ark_payment_cubit_test.dart' show PaymentRig, paymentQuote, destination;

Future<void> frame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

BullButton action(WidgetTester tester, String label) {
  final finder = find.widgetWithText(BullButton, label);
  expect(finder, findsOneWidget, reason: 'Explicit $label action');
  return tester.widget<BullButton>(finder);
}

BullInputText input(WidgetTester tester, int index) => tester
    .widgetList<BullInputText>(find.byType(BullInputText))
    .elementAt(index);
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
  testWidgets(
    'initial destination and edits never quote; explicit Review captures current locals',
    (tester) async {
      final r = PaymentRig();
      await tester.pumpWidget(app(page(r)));
      await frame(tester);
      expect(r.client.calls, isEmpty);
      expect(input(tester, 0).value, destination);
      input(tester, 1).onChanged('1000');
      await frame(tester);
      expect(r.client.calls, isEmpty);
      r.client.quoted = Ok(paymentQuote(r.cubit.account));
      final review = action(tester, 'Review').onPressed;
      review();
      review();
      await frame(tester);
      expect(r.client.calls, ['quote']);
      expect(details(tester), {
        'Ark address or BOLT11 invoice': destination,
        'Amount in sats': '1000',
        'Fee (sats)': '100',
        'Net amount (sats)': '900',
      });
      expect(find.widgetWithText(BullButton, 'Review'), findsNothing);
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
      action(tester, 'Review').onPressed();
      await frame(tester);
      expect(r.cubit.state, isA<ArkPaymentQuoting>());
      oldField('2000');
      await frame(tester);
      expect(input(tester, 1).value, '2000');
      reply.complete(Ok(paymentQuote(r.cubit.account)));
      await frame(tester);
      expect(r.cubit.state, isA<ArkPaymentEditing>());
      r.client.quoted = Ok(paymentQuote(r.cubit.account, amount: 2000));
      action(tester, 'Review').onPressed();
      await frame(tester);
      oldField('9999');
      await frame(tester);
      expect(r.cubit.state, isA<ArkPaymentReview>());
      expect(details(tester)['Amount in sats'], '2000');
      action(tester, 'Cancel').onPressed();
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
      final cancel1 = action(tester, 'Cancel').onPressed;
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
      final cancel2 = action(tester, 'Cancel').onPressed;
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
      expect(details(tester)['Identifier'], 'payment-1');
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
      expect(find.widgetWithText(BullButton, 'Review'), findsNothing);
      expect(find.widgetWithText(BullButton, 'Cancel'), findsNothing);
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
        final oldReview = action(tester, 'Review').onPressed;
        await a.ready();
        await frame(tester);
        final oldConfirm = action(tester, 'Confirm').onPressed;
        final oldCancel = action(tester, 'Cancel').onPressed;
        a.cubit.emit(const ArkPaymentUncertain('original'));
        await frame(tester);
        final oldRefresh = action(tester, 'Refresh').onPressed;
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
        oldRefresh();
        await frame(tester);
        expect(input(tester, 0).value, 'new-initial');
        expect(input(tester, 1).value, '');
        expect(b.client.calls, isEmpty);
        expect(a.client.calls, ['quote']);
        expect(a.ids + b.ids + oldReconciles + newReconciles, 0);
        expect(a.cubit.isClosed, false);
        final field = input(tester, 1).onChanged;
        final review = action(tester, 'Review').onPressed;
        await b.ready();
        await frame(tester);
        final confirm = action(tester, 'Confirm').onPressed;
        final cancel = action(tester, 'Cancel').onPressed;
        b.cubit.emit(const ArkPaymentUncertain('current'));
        await frame(tester);
        final refresh = action(tester, 'Refresh').onPressed;
        await tester.pumpWidget(app(const SizedBox.shrink()));
        field('1');
        review();
        confirm();
        cancel();
        refresh();
        await frame(tester);
        expect(b.client.calls, ['quote']);
        expect(b.ids + newReconciles, 0);
        expect(b.cubit.isClosed, false);
      },
    );
  }
  testWidgets(
    'Review belongs to exact Editing state and locals cannot change after submission',
    (tester) async {
      final r = PaymentRig();
      await tester.pumpWidget(app(page(r)));
      await frame(tester);
      final oldReview = action(tester, 'Review').onPressed;
      final field = input(tester, 1).onChanged;
      field('1000');
      await frame(tester);
      // Editing may retain its canonical state identity: Review captures CURRENT locals.
      r.client.quoted = Ok(paymentQuote(r.cubit.account));
      oldReview();
      await frame(tester);
      expect(r.client.calls, ['quote']);
      r.cubit.emit(const ArkPaymentEditing(ArkInvalidRequestFailure()));
      await frame(tester);
      final stale = action(tester, 'Review').onPressed;
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
    },
  );
  testWidgets(
    'reconcile uses current handler and exact displayed original state',
    (tester) async {
      final r = PaymentRig();
      var old = 0, current = 0;
      r.cubit.emit(const ArkPaymentUncertain('original'));
      await tester.pumpWidget(app(page(r, reconcile: () => old++)));
      await frame(tester);
      final refresh = action(tester, 'Refresh').onPressed;
      await tester.pumpWidget(app(page(r, reconcile: () => current++)));
      await frame(tester);
      refresh();
      expect(current, 1);
      expect(old, 0);
      r.cubit.emit(const ArkPaymentUncertain('replacement'));
      await frame(tester);
      refresh();
      expect(current, 1);
      expect(r.client.calls, isEmpty);
      expect(r.ids, 0);
    },
  );
  testWidgets(
    'backend status and original ID remain non-rearm, including failed/conflicted',
    (tester) async {
      final r = PaymentRig();
      final labels = [
        'Prepared',
        'Admitted',
        'Pending',
        'Completed',
        'Failed',
        'Outcome unknown',
        'Conflicting transaction observed',
      ];
      for (var i = 0; i < ArkOperationStatus.values.length; i++) {
        r.cubit.emit(
          ArkPaymentSubmitted(
            ArkOperation(
              id: 'backend-original',
              kind: ArkOperationKind.payment,
              status: ArkOperationStatus.values[i],
              chainSource: Uri.parse('http://localhost:3000'),
              configGeneration: 1,
            ),
          ),
        );
        await tester.pumpWidget(app(page(r)));
        await frame(tester);
        expect(
          details(tester).values,
          containsAll(['backend-original', labels[i]]),
        );
        r.cubit.edit();
        await r.cubit.confirm();
        await r.cubit.review(destination: destination, amount: '1000');
        expect(r.client.calls, isEmpty);
        expect(r.ids, 0);
        expect(
          tester.widgetList<BullButton>(find.byType(BullButton)),
          hasLength(1),
        );
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
