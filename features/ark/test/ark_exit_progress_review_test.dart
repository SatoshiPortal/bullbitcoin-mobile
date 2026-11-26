import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/usecases/confirm_ark_operation_usecase.dart';
import 'package:bull_ark/src/domain/usecases/quote_ark_operation_usecase.dart';
import 'package:bull_ark/src/presentation/ark_operation_cubit.dart';
import 'package:bull_ark/src/ui/ark_operation_review_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_information_widget_test.dart' show app;
import 'ark_operation_review_screen_test.dart'
    show Client, button, details, pumpState;
import 'ark_operations_test.dart' show account, Preferences;

ArkQuote observation({
  ArkOperationKind kind = ArkOperationKind.exitProgress,
  FeeRate? rate,
  Sats? exposure,
  List<String> coins = const [],
  int fee = 12,
}) => ArkQuote(
  id: 'same-review-id',
  account: account(),
  generation: 1,
  chainSource: Uri.parse('https://esplora.example'),
  configGeneration: 1,
  kind: kind,
  amount: Sats.fromInt(500),
  fee: Sats.fromInt(fee),
  net: Sats.fromInt(500),
  selectedIds: const ['quoted-exit'],
  reserveOutpoints: coins,
  observedTip: 100,
  validUntil: DateTime.utc(2030),
  feeRate: rate,
  confirmedReserveExposure: exposure,
);

class _Rig {
  final client = Client();
  late final ArkOperationCubit cubit;
  int ids = 0;
  _Rig({bool progress = true}) {
    final repository = ArkRepositoryImpl(client);
    final preferences = Preferences()..enabled = false;
    cubit = ArkOperationCubit(
      QuoteArkOperationUsecase(repository, preferences),
      ConfirmArkOperationUsecase(repository, preferences),
      () => 'attempt-${++ids}',
      account: account(),
      request: progress
          ? ArkQuoteRequest.exitProgress(feeRate: FeeRate(1))
          : ArkQuoteRequest.renewal(ids: ['quoted-exit']),
    );
    addTearDown(cubit.close);
  }
  ArkOperationReviewScreen get screen =>
      ArkOperationReviewScreen(cubit: cubit, onReconcile: () {});
  Future<void> load(ArkQuote quote) async {
    client.quoted = Ok(quote);
    await cubit.load();
  }

  int get submissions => client.calls.where((c) => c == 'submit').length;
}

void main() {
  final missing = <(String, bool, ArkQuote)>[
    ('both absent', true, observation()),
    ('rate absent', true, observation(exposure: Sats.fromInt(90))),
    ('exposure absent', true, observation(rate: FeeRate(2))),
    (
      'coins do not replace exposure',
      true,
      observation(rate: FeeRate(2), coins: ['public-coin:0:90']),
    ),
    (
      'progress request with renewal quote',
      true,
      observation(
        kind: ArkOperationKind.renewal,
        rate: FeeRate(2),
        exposure: Sats.fromInt(90),
      ),
    ),
    (
      'renewal request with progress quote',
      false,
      observation(rate: FeeRate(2), exposure: Sats.fromInt(90)),
    ),
  ];
  for (final (label, progress, quote) in missing) {
    testWidgets('$label disables Confirm for an incomplete review', (
      tester,
    ) async {
      final r = _Rig(progress: progress);
      await r.load(quote);
      await tester.pumpWidget(app(r.screen));
      await pumpState(tester);
      // No warning bar any more: Confirm itself stays unavailable.
      expect(button(tester, 'Confirm').disabled, true);
      expect(r.client.calls, ['quote']);
      expect(r.ids, 0);
    });
    testWidgets('$label manually invoked Confirm refuses without submitting', (
      tester,
    ) async {
      final r = _Rig(progress: progress);
      await r.load(quote);
      await tester.pumpWidget(app(r.screen));
      await pumpState(tester);
      final confirm = button(tester, 'Confirm').onPressed;
      confirm();
      await pumpState(tester);
      expect(r.submissions, 0);
      expect(r.ids, 0);
      expect(r.cubit.state, isA<ArkOperationReview>());
      expect(r.client.calls, ['quote']);
    });
  }

  testWidgets(
    'missing nullable facts display Unavailable rather than invented zero',
    (tester) async {
      final r = _Rig();
      await r.load(observation());
      await tester.pumpWidget(app(r.screen));
      await pumpState(tester);
      expect(details(tester)['Fee rate (sat/vB)'], 'Unavailable');
      expect(
        details(tester)['Confirmed reserve at risk (sats)'],
        'Unavailable',
      );
      expect(details(tester)['Estimated fee (sats)'], '12');
    },
  );

  for (final reserve in [0, 90]) {
    testWidgets(
      'known reserve $reserve with empty coin list is not missing or an eligibility claim',
      (tester) async {
        final r = _Rig();
        final q = observation(
          rate: FeeRate(2.5),
          exposure: Sats.fromInt(reserve),
          fee: 0,
        );
        await r.load(q);
        await tester.pumpWidget(app(r.screen));
        await pumpState(tester);
        expect(details(tester)['Fee rate (sat/vB)'], '2.5');
        expect(details(tester)['Confirmed reserve at risk (sats)'], '$reserve');
        expect(details(tester)['Estimated fee (sats)'], '0');
        expect(q.reserveOutpoints, isEmpty);
        expect(button(tester, 'Confirm').disabled, false);
        expect(r.client.calls, [
          'quote',
        ]); // Passive mount never submits or requotes.
        final confirm = button(tester, 'Confirm').onPressed;
        confirm();
        confirm();
        await pumpState(tester);
        expect(r.submissions, 1);
        expect(r.ids, 1);
        expect(r.cubit.state, isA<ArkOperationUncertain>());
        await r.cubit.load();
        expect(r.client.calls.where((c) => c == 'quote'), hasLength(1));
        await tester.pump(const Duration(seconds: 4)); // Snackbar timer.
      },
    );
  }

  for (final completeFirst in [true, false]) {
    testWidgets(
      'same-ID immutable q1 to q2 preserves identity gate, complete first $completeFirst',
      (tester) async {
        final r = _Rig();
        final complete = observation(
          rate: FeeRate(3),
          exposure: Sats.fromInt(99),
        );
        final incomplete = observation(rate: FeeRate(3));
        final q1 = completeFirst ? complete : incomplete;
        final q2 = completeFirst ? incomplete : complete;
        expect(q1.id, q2.id);
        expect(identical(q1, q2), false);
        await r.load(q1);
        await tester.pumpWidget(app(r.screen));
        await pumpState(tester);
        final old = button(tester, 'Confirm').onPressed;
        await r.load(q2);
        await pumpState(tester);
        old();
        await pumpState(tester);
        expect(r.submissions, 0);
        expect(r.ids, 0);
        expect(button(tester, 'Confirm').disabled, completeFirst);
        button(tester, 'Confirm').onPressed();
        await pumpState(tester);
        expect(r.submissions, completeFirst ? 0 : 1);
        expect(r.ids, completeFirst ? 0 : 1);
        await tester.pump(const Duration(seconds: 4)); // Snackbar timer.
      },
    );
  }
}
