import 'package:ark/ark.dart';
import 'package:bull_ark/src/ui/ark_exit_request_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullInputText, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_operations_test.dart' show account;

ArkSnapshot inventory({bool stale = false, bool complete = true}) =>
    ArkSnapshot(
      account: account(),
      revision: 1,
      observedAt: DateTime.utc(2026),
      stale: stale,
      tipHeight: 100,
      recovery: ArkRecoveryStatus.complete,
      exits: ArkExitStatus.none,
      vtxoCompleteness: complete
          ? ArkSectionCompleteness.complete
          : ArkSectionCompleteness.unknown,
      vtxos: [
        ArkVtxo(
          id: 'selected',
          amount: Sats.fromInt(1000),
          expiryHeight: 200,
          state: ArkVtxoState.spendable,
        ),
        ArkVtxo(
          id: 'locked',
          amount: Sats.fromInt(1000),
          expiryHeight: 200,
          state: ArkVtxoState.locked,
        ),
      ],
      exitDetails: [
        ArkExit(
          id: 'claimable',
          amount: Sats.fromInt(1000),
          status: ArkExitStatus.claimable,
        ),
      ],
    );
BullButton review(WidgetTester tester) =>
    tester.widget<BullButton>(find.widgetWithText(BullButton, 'Review'));
Future<void> edit(WidgetTester tester, String hint, String value) async {
  tester
      .widgetList<BullInputText>(find.byType(BullInputText))
      .singleWhere((input) => input.hint == hint)
      .onChanged(value);
  await tester.pump();
}

Future<void> fill(WidgetTester tester, {bool claim = false}) async {
  await edit(tester, 'On-chain return address', 'bcrt1-return');
  if (!claim) await edit(tester, 'Fee rate (sat/vB)', '2');
  await edit(tester, 'Maximum claim fee (sats)', '500');
}

void main() {
  testWidgets(
    'one explicit exit request uses current spendable ids and reviewed fee inputs',
    (tester) async {
      final requests = <ArkQuoteRequest>[];
      await tester.pumpWidget(
        app(
          ArkExitRequestScreen(snapshot: inventory(), onReview: requests.add),
        ),
      );
      expect(requests, isEmpty);
      expect(review(tester).disabled, true);
      await fill(tester);
      expect(review(tester).disabled, false);
      final callback = review(tester).onPressed;
      callback();
      callback();
      await tester.pump();
      expect(requests, hasLength(1));
      final request = requests.single as ArkEmergencyExitQuoteRequest;
      expect(request.ids, ['selected']);
      expect(request.destination, 'bcrt1-return');
      expect(request.feeRate.satsPerVbyte, 2);
      expect(request.maxClaimFee, Sats.fromInt(500));
      expect(() => request.ids.add('other'), throwsUnsupportedError);
    },
  );
  testWidgets(
    'claim uses only supplied currently claimable ids with no automatic submission',
    (tester) async {
      final requests = <ArkQuoteRequest>[];
      await tester.pumpWidget(
        app(
          ArkExitRequestScreen(
            snapshot: inventory(),
            claimIds: const ['claimable'],
            onReview: requests.add,
          ),
        ),
      );
      await fill(tester, claim: true);
      review(tester).onPressed();
      final request = requests.single as ArkClaimQuoteRequest;
      expect(request.ids, ['claimable']);
      expect(request.maxFee, Sats.fromInt(500));
    },
  );
  for (final snapshot in [inventory(stale: true), inventory(complete: false)]) {
    testWidgets(
      'stale or incomplete inventory refuses exit ${snapshot.stale}',
      (tester) async {
        final requests = <ArkQuoteRequest>[];
        await tester.pumpWidget(
          app(ArkExitRequestScreen(snapshot: snapshot, onReview: requests.add)),
        );
        await fill(tester);
        expect(review(tester).disabled, true);
        review(tester).onPressed();
        expect(requests, isEmpty);
      },
    );
  }
  testWidgets(
    'old callbacks cannot cross a replaced snapshot or disposed form',
    (tester) async {
      final requests = <ArkQuoteRequest>[];
      await tester.pumpWidget(
        app(
          ArkExitRequestScreen(snapshot: inventory(), onReview: requests.add),
        ),
      );
      await fill(tester);
      final old = review(tester).onPressed;
      await tester.pumpWidget(
        app(
          ArkExitRequestScreen(
            snapshot: inventory(stale: true),
            onReview: requests.add,
          ),
        ),
      );
      old();
      expect(requests, isEmpty);
      await tester.pumpWidget(app(const SizedBox.shrink()));
      old();
      expect(requests, isEmpty);
    },
  );
  for (final value in ['0', '-1', '1.5', '9007199254740992']) {
    testWidgets('unsupported rate $value refuses request', (tester) async {
      final requests = <ArkQuoteRequest>[];
      await tester.pumpWidget(
        app(
          ArkExitRequestScreen(snapshot: inventory(), onReview: requests.add),
        ),
      );
      await fill(tester);
      await edit(tester, 'Fee rate (sat/vB)', value);
      expect(review(tester).disabled, true);
      review(tester).onPressed();
      expect(requests, isEmpty);
    });
  }
}
