import 'dart:async';

import 'package:bull_ark/src/ui/ark_exits_screen.dart';
import 'package:ark/ark.dart';
import 'package:bull_ark/src/presentation/ark_operation_cubit.dart';
import 'package:bull_ark/src/ui/ark_account_screen.dart';
import 'package:bull_ark/src/ui/ark_exit_request_screen.dart';
import 'package:bull_ark/src/ui/ark_exit_progress_fee_screen.dart';
import 'package:bull_ark/src/ui/ark_operation_review_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullInputText, BullTopBar;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_module_composition_test.dart' show Rig, accountPage, frame;
import 'ark_operations_test.dart' show account;
import 'ark_exit_request_screen_test.dart' as inputs;

Rig rigFor(String kind) {
  final r = Rig();
  r.client.snapshot = Ok(
    ArkSnapshot(
      account: account(),
      revision: 1,
      observedAt: DateTime.utc(2026),
      stale: false,
      tipHeight: 100,
      exits: kind == 'claim' ? ArkExitStatus.claimable : ArkExitStatus.pending,
      vtxoCompleteness: ArkSectionCompleteness.complete,
      vtxos: [
        ArkVtxo(
          id: 'v',
          amount: Sats.fromInt(1000),
          expiryHeight: 200,
          state: ArkVtxoState.spendable,
        ),
      ],
      exitDetails: [
        ArkExit(
          id: 'v',
          amount: Sats.fromInt(1000),
          status: kind == 'claim'
              ? ArkExitStatus.claimable
              : ArkExitStatus.pending,
        ),
      ],
    ),
  );
  r.client.quoted = Ok(quoteFor(kind));
  return r;
}

ArkQuote quoteFor(String kind, {String id = 'first', DateTime? until}) =>
    ArkQuote(
      id: id,
      account: account(),
      generation: 2,
      chainSource: Uri.parse('http://localhost:3000'),
      configGeneration: 1,
      kind: switch (kind) {
        'claim' => ArkOperationKind.claim,
        'progress' => ArkOperationKind.exitProgress,
        _ => ArkOperationKind.emergencyExit,
      },
      amount: Sats.fromInt(1000),
      fee: Sats.fromInt(42),
      net: Sats.fromInt(958),
      selectedIds: ['v'],
      destination: kind == 'progress' ? null : 'bcrt1-return',
      feeRate: kind == 'claim' ? null : FeeRate(2),
      maxClaimFee: kind == 'progress' ? null : Sats.fromInt(500),
      confirmedReserveExposure: kind == 'claim' ? null : Sats.fromInt(500),
      observedTip: 100,
      validUntil: until ?? DateTime.utc(2030),
    );

Finder formFor(String kind) => find.byType(
  kind == 'progress' ? ArkExitProgressFeeScreen : ArkExitRequestScreen,
);
BullButton review(WidgetTester tester, String kind) =>
    tester.widget<BullButton>(
      find.descendant(
        of: formFor(kind),
        matching: find.widgetWithText(BullButton, 'Review'),
      ),
    );

Future<void> openForm(WidgetTester tester, Rig r, String kind) async {
  await accountPage(tester, r);
  tester.widget<ArkAccountScreen>(find.byType(ArkAccountScreen)).onExits();
  await frame(tester);
  final label = switch (kind) {
    'start' => 'Start emergency exit',
    'claim' => 'Claim',
    _ => 'Progress emergency exits',
  };
  tester
      .widget<BullButton>(find.widgetWithText(BullButton, label).first)
      .onPressed();
  await frame(tester);
  if (kind == 'progress') {
    tester.widget<BullInputText>(find.byType(BullInputText)).onChanged('2');
    await tester.pump();
  } else {
    await inputs.fill(tester, claim: kind == 'claim');
  }
}

void cancel(WidgetTester tester) => tester
    .widget<BullTopBar>(
      find.descendant(
        of: find.byType(ArkOperationReviewScreen),
        matching: find.byType(BullTopBar),
      ),
    )
    .onBack
    ?.call();

void main() {
  for (final kind in ['start', 'claim', 'progress']) {
    for (final systemBack in [false, true]) {
      testWidgets(
        '$kind cancel system=$systemBack preserves draft and only a new intent requotes',
        (tester) async {
          final r = rigFor(kind);
          await openForm(tester, r, kind);
          final original = tester.state(formFor(kind));
          final old = review(tester, kind).onPressed;
          old();
          await frame(tester);
          expect(r.client.calls.where((call) => call == 'quote'), hasLength(1));
          expect(r.client.calls.where((call) => call == 'submit'), isEmpty);
          if (systemBack) {
            await tester.binding.handlePopRoute();
          } else {
            cancel(tester);
          }
          await frame(tester);
          expect(find.byType(ArkOperationReviewScreen), findsNothing);
          expect(tester.state(formFor(kind)), same(original));
          expect(review(tester, kind).disabled, false);
          old();
          await frame(tester);
          expect(r.client.calls.where((call) => call == 'quote'), hasLength(1));
          final fields = tester.widgetList<BullInputText>(
            find.byType(BullInputText),
          );
          expect(
            fields.map((field) => field.value),
            contains(kind == 'progress' ? '2' : 'bcrt1-return'),
          );
          r.client.quoted = Ok(quoteFor(kind, id: 'second'));
          review(tester, kind).onPressed();
          await frame(tester);
          expect(r.client.calls.where((call) => call == 'quote'), hasLength(2));
          expect(r.client.calls.where((call) => call == 'submit'), isEmpty);
          expect(
            (tester
                        .widget<ArkOperationReviewScreen>(
                          find.byType(ArkOperationReviewScreen),
                        )
                        .cubit
                        .state
                    as ArkOperationReview)
                .quote
                .id,
            'second',
          );
        },
      );
    }
  }

  testWidgets(
    'confirm failure then retry and cancel never rearms the original form',
    (tester) async {
      final r = rigFor('start');
      r.client.quoted = Ok(quoteFor('start', until: DateTime.utc(2020)));
      await openForm(tester, r, 'start');
      review(tester, 'start').onPressed();
      await frame(tester);
      final owner = tester
          .widget<ArkOperationReviewScreen>(
            find.byType(ArkOperationReviewScreen),
          )
          .cubit;
      // Exercise the public controller admission boundary with an expired quote.
      // This is not evidence that the UI emitted or the native client was called.
      await owner.confirm();
      await frame(tester);
      expect(owner.state, isA<ArkOperationFailed>());
      r.client.quoted = Ok(quoteFor('start', id: 'after-failure'));
      tester
          .widget<BullButton>(
            find.descendant(
              of: find.byType(ArkOperationReviewScreen),
              matching: find.widgetWithText(BullButton, 'Review'),
            ),
          )
          .onPressed();
      await frame(tester);
      expect(owner.state, isA<ArkOperationReview>());
      cancel(tester);
      await frame(tester);
      expect(review(tester, 'start').disabled, true);
      expect(r.client.calls.where((call) => call == 'quote'), hasLength(2));
      expect(r.client.calls.where((call) => call == 'submit'), isEmpty);
    },
  );
  for (final kind in ['start', 'claim', 'progress']) {
    testWidgets('$kind Done returns to the existing exits route once', (
      tester,
    ) async {
      final r = rigFor(kind);
      await openForm(tester, r, kind);
      r.client.submitted = Ok(
        ArkOperation(
          id: 'submitted-operation',
          kind: quoteFor(kind).kind,
          status: ArkOperationStatus.pending,
          chainSource: quoteFor(kind).chainSource,
          configGeneration: 1,
          actualIds: ['v'],
        ),
      );
      review(tester, kind).onPressed();
      await frame(tester);
      final oldCancel = tester
          .widget<BullTopBar>(
            find.descendant(
              of: find.byType(ArkOperationReviewScreen),
              matching: find.byType(BullTopBar),
            ),
          )
          .onBack;
      if (kind == 'start') {
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Hold to start exit')),
        );
        await tester.pump(const Duration(milliseconds: 1520));
        await gesture.up();
      } else {
        await tester.tap(find.widgetWithText(BullButton, 'Confirm'));
      }
      await frame(tester);
      expect(r.client.calls.where((call) => call == 'submit'), hasLength(1));
      final done = tester
          .widget<BullButton>(find.widgetWithText(BullButton, 'Done'))
          .onPressed;
      await tester.tap(find.widgetWithText(BullButton, 'Done'));
      await frame(tester);
      expect(find.byType(ArkExitsScreen), findsOneWidget);
      expect(formFor(kind), findsNothing);
      expect(find.byType(ArkOperationReviewScreen), findsNothing);
      done();
      oldCancel?.call();
      await frame(tester);
      expect(find.byType(ArkExitsScreen), findsOneWidget);
      expect(r.client.calls.where((call) => call == 'quote'), hasLength(1));
      expect(r.client.calls.where((call) => call == 'submit'), hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Back during loading cannot rearm when its quote settles later', (
    tester,
  ) async {
    final r = rigFor('start');
    final reply = Completer<Result<ArkQuote, ArkWalletFailure>>();
    r.client.quoteReply = reply;
    await openForm(tester, r, 'start');
    review(tester, 'start').onPressed();
    await frame(tester);
    expect(find.byType(ArkOperationReviewScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    reply.complete(Ok(quoteFor('start')));
    await frame(tester);
    expect(find.byType(ArkOperationReviewScreen), findsNothing);
    expect(review(tester, 'start').disabled, true);
    expect(r.client.calls.where((call) => call == 'quote'), hasLength(1));
    expect(r.client.calls.where((call) => call == 'submit'), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
