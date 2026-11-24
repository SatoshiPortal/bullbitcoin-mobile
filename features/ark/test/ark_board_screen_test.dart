import 'dart:async';

import 'package:ark/ark.dart'
    show ArkOperation, ArkOperationKind, ArkOperationStatus;
import 'package:bull_ark/ark_setup.dart'
    show
        ArkBoardBelowMinimumFailure,
        ArkOperationBusyFailure,
        ArkReviewExpiredFailure,
        ArkSubmissionUncertainFailure;
import 'package:bull_ark/src/domain/usecases/confirm_ark_board_usecase.dart';
import 'package:bull_ark/src/domain/usecases/prepare_ark_board_usecase.dart';
import 'package:bull_ark/src/domain/usecases/read_ark_board_usecase.dart';
import 'package:bull_ark/src/presentation/ark_board_cubit.dart';
import 'package:bull_ark/src/ui/ark_board_amount_screen.dart';
import 'package:bull_ark/src/domain/ark_display_data_port.dart';
import 'package:bull_ark/src/ui/ark_board_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullDetailsTable,
        BullFadingLinearProgress,
        BullIcons,
        BullInfoBar,
        BullInputText,
        BullLoader,
        BullSuccessScreen,
        BullText,
        Row,
        SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_board_journey_test.dart' show minimumReader, prepared;
import 'ark_information_widget_test.dart' show app, config;
import 'ark_operations_test.dart' show Preferences;
import 'fake_ark_board_funding.dart';

class Rig {
  final funding = FakeArkBoardFunding()
    ..prepared = Ok(prepared())
    ..observed = Ok(prepared());
  late final ArkBoardCubit cubit;
  int refreshes = 0;
  final viewed = <String>[];
  int closes = 0;
  Rig() {
    final preferences = Preferences();
    cubit = ArkBoardCubit(
      PrepareArkBoardUsecase(funding, preferences),
      ReadArkBoardUsecase(funding),
      ConfirmArkBoardUsecase(funding, preferences),
      minimumReader(),
      config: config(),
    );
    addTearDown(cubit.close);
  }
  ArkBoardScreen get screen => ArkBoardScreen(
    cubit: cubit,
    onReconcile: () => refreshes++,
    onViewDetails: viewed.add,
    onClose: () => closes++,
  );
}

BullButton button(WidgetTester tester, String label) =>
    tester.widget<BullButton>(find.widgetWithText(BullButton, label));

Future<void> review(WidgetTester tester, Rig rig) async {
  await tester.pumpWidget(app(rig.screen));
  await tester.pumpAndSettle();
  tester
      .widget<ArkBoardAmountScreen>(find.byType(ArkBoardAmountScreen))
      .onReviewRequest
      ?.call(rig.cubit.config, Sats.fromInt(1000));
  await tester.pumpAndSettle();
}

void main() {
  for (final (minimum, shown) in [(20000, '20,000'), (54321, '54,321')]) {
    testWidgets('Board shows the server minimum $minimum after refusal', (
      tester,
    ) async {
      final rig = Rig();
      rig.funding.prepared = Err(
        ArkBoardBelowMinimumFailure(Sats.fromInt(minimum)),
      );
      await tester.pumpWidget(app(rig.screen));
      await tester.pumpAndSettle();
      final input = tester.widget<ArkBoardAmountScreen>(
        find.byType(ArkBoardAmountScreen),
      );
      input.onReviewRequest?.call(rig.cubit.config, Sats.fromInt(1000));
      await tester.pumpAndSettle();
      expect(find.text('Minimum: $shown sats'), findsOneWidget);
      expect(rig.cubit.state, isA<ArkBoardEditing>());
      expect(rig.funding.calls, ['prepare']);
      expect(find.widgetWithText(BullButton, 'Confirm'), findsNothing);
      // A synchronous refusal can coalesce Busy and Editing into one frame.
      // The replacement input must not retain the consumed form's latch.
      rig.funding
        ..prepared = Ok(prepared(amount: minimum))
        ..observed = Ok(prepared(amount: minimum));
      final field = tester.widget<BullInputText>(find.byType(BullInputText));
      // The refused minimum is now checked while typing.
      field.onChanged('1000');
      await tester.pump();
      expect(button(tester, 'Continue').disabled, true);
      tester
          .widget<BullInputText>(find.byType(BullInputText))
          .onChanged('$minimum');
      await tester.pump();
      button(tester, 'Continue').onPressed();
      await tester.pumpAndSettle();
      expect(rig.cubit.state, isA<ArkBoardReviewed>());
      expect(rig.funding.calls, ['prepare', 'prepare', 'read']);
    });
  }
  testWidgets(
    'mount is passive; explicit review shows actual source debit and fee units',
    (tester) async {
      final rig = Rig();
      await tester.pumpWidget(app(rig.screen));
      await tester.pumpAndSettle();
      expect(rig.funding.calls, isEmpty);
      final input = tester.widget<ArkBoardAmountScreen>(
        find.byType(ArkBoardAmountScreen),
      );
      input.onReviewRequest?.call(rig.cubit.config, Sats.fromInt(1000));
      await tester.pumpAndSettle();
      expect(rig.funding.calls, ['prepare', 'read']);
      expect(find.text('Confirm board'), findsOneWidget);
      // Laid out like the send confirmation: plain rows, fees in one total.
      Finder row(String label, String value) => find.ancestor(
        of: find.text(value),
        matching: find.ancestor(
          of: find.text(label),
          matching: find.byType(Row),
        ),
      );
      expect(row('From', 'On-chain wallet'), findsOneWidget);
      expect(find.text('source-wallet'), findsNothing);
      expect(row('To', 'Ark'), findsOneWidget);
      expect(row('Amount', '1,000 sats'), findsOneWidget);
      // Each fee on its own row, as in the app's send confirmation.
      expect(row('Network fees', '100 sats'), findsOneWidget);
      expect(row('Ark boarding fee', '10 sats'), findsOneWidget);
      expect(row('Receive amount', '990 sats'), findsOneWidget);
      expect(find.byType(BullDetailsTable), findsNothing);
      expect(find.textContaining('Fee priority'), findsNothing);
      expect(find.textContaining('pays Bitcoin miners'), findsNothing);
      expect(find.text('Economy'), findsNothing);
      expect(find.text('Slow'), findsNothing);
      final confirm = button(tester, 'Confirm').onPressed;
      expect(confirm, isNotNull);
      confirm.call();
      confirm.call();
      await tester.pumpAndSettle();
      expect(rig.funding.calls, ['prepare', 'read', 'confirm']);
      // Refused before signing: the review stays, with its reason.
      expect(
        rig.cubit.state,
        isA<ArkBoardReviewed>().having((s) => s.failure, 'reason', isNotNull),
      );
      // The callback rendered for the earlier review confirms nothing.
      confirm.call();
      await tester.pumpAndSettle();
      expect(rig.funding.calls, ['prepare', 'read', 'confirm']);
    },
  );

  testWidgets(
    'same account replacement rejects old confirm without closing injected owners',
    (tester) async {
      final first = Rig(), second = Rig();
      await first.cubit.prepare(Sats.fromInt(1000));
      await tester.pumpWidget(app(first.screen));
      await tester.pumpAndSettle();
      final oldConfirm = button(tester, 'Confirm').onPressed;
      await second.cubit.prepare(Sats.fromInt(1000));
      await tester.pumpWidget(app(second.screen));
      await tester.pumpAndSettle();
      oldConfirm.call();
      await tester.pumpAndSettle();
      expect(first.funding.calls, ['prepare', 'read']);
      expect(second.funding.calls, ['prepare', 'read']);
      expect(first.cubit.isClosed, isFalse);
      expect(second.cubit.isClosed, isFalse);
      button(tester, 'Confirm').onPressed.call();
      await tester.pumpAndSettle();
      expect(second.funding.calls, ['prepare', 'read', 'confirm']);
    },
  );

  testWidgets(
    'direct disposal rejects old confirm while injected owner remains open',
    (tester) async {
      final rig = Rig();
      await rig.cubit.prepare(Sats.fromInt(1000));
      await tester.pumpWidget(app(rig.screen));
      await tester.pumpAndSettle();
      final oldConfirm = button(tester, 'Confirm').onPressed;
      await tester.pumpWidget(app(const SizedBox()));
      await tester.pumpAndSettle();
      expect(() => oldConfirm.call(), returnsNormally);
      expect(rig.cubit.isClosed, isFalse);
      expect(rig.funding.calls, ['prepare', 'read']);
    },
  );

  const fundingTxid =
      '8f3c1a7d9e2b4c6f0a1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d6d8e0fe4';
  ArkOperation submitted(
    ArkOperationStatus status, {
    String id = 'board-operation-fixture',
  }) => ArkOperation(
    id: id,
    kind: ArkOperationKind.board,
    status: status,
    nativeReference: fundingTxid,
    chainSource: Uri.parse('http://localhost:3000'),
    configGeneration: 1,
  );

  for (final status in [
    ArkOperationStatus.prepared,
    ArkOperationStatus.admitted,
    ArkOperationStatus.pending,
  ]) {
    testWidgets('a ${status.name} Board reads as started, never completed', (
      tester,
    ) async {
      final rig = Rig();
      rig.cubit.emit(ArkBoardSubmitted(submitted(status)));
      await tester.pumpWidget(app(rig.screen));
      await tester.pumpAndSettle();
      // The app's completed-flow screen.
      expect(find.byType(BullSuccessScreen), findsOneWidget);
      expect(find.text('Boarding started'), findsOneWidget);
      expect(find.text('Boarding complete'), findsNothing);
      expect(find.textContaining('moving into Ark'), findsOneWidget);
      // Not done yet: no success check.
      expect(find.byIcon(BullIcons.checkCircle), findsNothing);
      expect(find.widgetWithText(BullButton, 'Refresh'), findsNothing);
      button(tester, 'View details').onPressed();
      expect(rig.viewed, [fundingTxid]);
      // Closing leaves the finished flow through the host (its home).
      await tester.tap(find.byTooltip('Close').first);
      expect(rig.closes, 1);
    });
  }

  testWidgets('a succeeded Board reads as complete', (tester) async {
    final rig = Rig();
    rig.cubit.emit(ArkBoardSubmitted(submitted(ArkOperationStatus.succeeded)));
    await tester.pumpWidget(app(rig.screen));
    await tester.pumpAndSettle();
    expect(find.text('Boarding complete'), findsOneWidget);
    expect(find.text('Boarding started'), findsNothing);
    expect(find.textContaining('moving into Ark'), findsNothing);
    expect(find.byIcon(BullIcons.checkCircle), findsOneWidget);
    expect(find.widgetWithText(BullButton, 'View details'), findsOneWidget);
  });

  testWidgets('the success screen shows what reaches Ark', (tester) async {
    final rig = Rig()
      ..funding.confirmed = Ok(
        // The reviewed Board's own operation.
        submitted(ArkOperationStatus.pending, id: 'original-operation'),
      );
    await review(tester, rig);
    button(tester, 'Confirm').onPressed();
    await tester.pumpAndSettle();
    expect(find.text('Boarding started'), findsOneWidget);
    expect(find.text('990 sats'), findsOneWidget);
  });

  for (final status in [
    ArkOperationStatus.failed,
    ArkOperationStatus.outcomeUnknown,
    ArkOperationStatus.conflicted,
  ]) {
    testWidgets('a ${status.name} Board closes the flow with a snackbar', (
      tester,
    ) async {
      final rig = Rig();
      rig.cubit.emit(ArkBoardSubmitted(submitted(status)));
      await tester.pumpWidget(app(rig.screen));
      await tester.pumpAndSettle();
      expect(find.byType(BullSuccessScreen), findsNothing);
      expect(find.text('Boarding started'), findsNothing);
      expect(find.widgetWithText(BullButton, 'Refresh'), findsNothing);
      expect(find.textContaining('Refresh to reconcile'), findsNothing);
      expect(
        find.textContaining('couldn’t confirm whether your Board'),
        status == ArkOperationStatus.outcomeUnknown
            ? findsOneWidget
            : findsNothing,
      );
      expect(rig.refreshes, 1);
      await tester.pump(const Duration(seconds: 4)); // Snackbar timer.
    });
  }

  testWidgets('busy Board shows a loader and no actions', (tester) async {
    final rig = Rig();
    rig.cubit.emit(const ArkBoardBusy());
    await tester.pumpWidget(app(rig.screen));
    await tester.pump();
    expect(find.byType(BullLoader), findsOneWidget);
    expect(find.byType(BullButton), findsNothing);
  });

  testWidgets('an uncertain Board closes the flow and Ark checks it', (
    tester,
  ) async {
    final rig = Rig();
    rig.cubit.emit(
      const ArkBoardPending(
        'board-operation-fixture',
        ArkSubmissionUncertainFailure('board-operation-fixture'),
      ),
    );
    await tester.pumpWidget(app(rig.screen));
    await tester.pumpAndSettle();
    expect(find.byType(BullSuccessScreen), findsNothing);
    expect(find.widgetWithText(BullButton, 'Refresh'), findsNothing);
    expect(
      find.textContaining('couldn’t confirm whether your Board'),
      findsOneWidget,
    );
    expect(rig.refreshes, 1);
    await tester.pump(const Duration(seconds: 4)); // Snackbar timer.
  });

  testWidgets('an amount refusal is field help in the error colour', (
    tester,
  ) async {
    final rig = Rig();
    rig.cubit.emit(
      ArkBoardEditing(ArkBoardBelowMinimumFailure(Sats.fromInt(50000))),
    );
    await tester.pumpWidget(app(rig.screen));
    await tester.pumpAndSettle();
    final help = tester.widget<BullText>(
      find.widgetWithText(BullText, 'Minimum: 50,000 sats'),
    );
    expect(help.color, isNotNull);
    expect(find.byType(BullInfoBar), findsNothing);
  });

  testWidgets('Continue keeps the amount on screen until the review is ready', (
    tester,
  ) async {
    final rig = Rig();
    final gate = rig.funding.gate = Completer<void>();
    await tester.pumpWidget(app(rig.screen));
    await tester.pumpAndSettle();
    tester.widget<BullInputText>(find.byType(BullInputText)).onChanged('1000');
    await tester.pump();
    button(tester, 'Continue').onPressed();
    await tester.pump();
    expect(rig.cubit.state, isA<ArkBoardBusy>());
    // Still the amount screen with its amount, not a loading page.
    expect(find.byType(ArkBoardAmountScreen), findsOneWidget);
    expect(
      tester.widget<BullInputText>(find.byType(BullInputText)).value,
      '1000',
    );
    expect(button(tester, 'Continue').disabled, true);
    expect(find.byType(BullLoader), findsNothing);
    expect(
      tester
          .widget<BullFadingLinearProgress>(
            find.byType(BullFadingLinearProgress),
          )
          .trigger,
      true,
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Confirm board'), findsOneWidget);
  });

  testWidgets('a refused confirm stays on the review with the reason in red', (
    tester,
  ) async {
    final rig = Rig()..funding.confirmed = const Err(ArkOperationBusyFailure());
    await review(tester, rig);
    button(tester, 'Confirm').onPressed();
    await tester.pumpAndSettle();
    expect(find.text('Confirm board'), findsOneWidget);
    expect(find.textContaining('Ark is busy'), findsOneWidget);
    expect(find.byType(BullInfoBar), findsNothing);
    expect(button(tester, 'Confirm').disabled, false);
  });

  testWidgets('an expired review is priced again by Retry', (tester) async {
    final rig = Rig()..funding.confirmed = const Err(ArkReviewExpiredFailure());
    await review(tester, rig);
    button(tester, 'Confirm').onPressed();
    await tester.pumpAndSettle();
    expect(find.textContaining('This review has expired'), findsOneWidget);
    expect(rig.funding.calls.where((c) => c == 'prepare'), hasLength(1));
    button(tester, 'Retry').onPressed();
    await tester.pumpAndSettle();
    expect(rig.funding.calls.where((c) => c == 'prepare'), hasLength(2));
    expect(find.textContaining('This review has expired'), findsNothing);
    expect(button(tester, 'Confirm').disabled, false);
  });

  testWidgets('an unknown outcome after Confirm closes with a snackbar', (
    tester,
  ) async {
    final rig = Rig()
      ..funding.confirmed = const Err(ArkSubmissionUncertainFailure('op'));
    await review(tester, rig);
    button(tester, 'Confirm').onPressed();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.textContaining('couldn’t confirm whether your Board'),
      findsOneWidget,
    );
    expect(rig.refreshes, 1);
    await tester.pump(const Duration(seconds: 4)); // Snackbar timer.
  });

  testWidgets('Confirm keeps the review on screen while it submits', (
    tester,
  ) async {
    final rig = Rig();
    await tester.pumpWidget(app(rig.screen));
    await tester.pumpAndSettle();
    tester
        .widget<ArkBoardAmountScreen>(find.byType(ArkBoardAmountScreen))
        .onReviewRequest
        ?.call(rig.cubit.config, Sats.fromInt(1000));
    await tester.pumpAndSettle();
    final gate = rig.funding.gate = Completer<void>();
    button(tester, 'Confirm').onPressed();
    await tester.pump();
    await tester.pump();
    expect(rig.cubit.state, isA<ArkBoardBusy>());
    expect(find.text('Confirm board'), findsOneWidget);
    expect(button(tester, 'Confirm').disabled, true);
    expect(find.byType(BullLoader), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
  });

  for (final (walletId, name, shown) in [
    ('source-wallet', const ArkDefaultSourceWallet(), 'Secure Bitcoin'),
    ('source-wallet', const ArkNamedSourceWallet('My savings'), 'My savings'),
    (
      'other-wallet',
      const ArkNamedSourceWallet('My savings'),
      'On-chain wallet',
    ),
  ]) {
    testWidgets('the review names its source wallet $shown', (tester) async {
      final rig = Rig();
      await tester.pumpWidget(
        app(
          ArkBoardScreen(
            cubit: rig.cubit,
            onReconcile: () {},
            displayData: ArkDisplayData(
              account: rig.cubit.config.id,
              walletId: walletId,
              available: Sats.fromInt(5000),
              walletName: name,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<ArkBoardAmountScreen>(find.byType(ArkBoardAmountScreen))
          .onReviewRequest
          ?.call(rig.cubit.config, Sats.fromInt(1000));
      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.text(shown),
          matching: find.ancestor(
            of: find.text('From'),
            matching: find.byType(Row),
          ),
        ),
        findsOneWidget,
      );
    });
  }
}
