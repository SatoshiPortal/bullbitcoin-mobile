import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:bull_ark/src/domain/usecases/confirm_ark_board_usecase.dart';
import 'package:bull_ark/src/domain/usecases/prepare_ark_board_usecase.dart';
import 'package:bull_ark/src/domain/usecases/read_ark_board_usecase.dart';
import 'package:bull_ark/src/presentation/ark_board_cubit.dart';
import 'package:bull_ark/src/ui/ark_board_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullThemeX;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_board_journey_test.dart' show prepared;
import 'ark_board_screen_test.dart' show Rig, button;
import 'ark_information_widget_test.dart' show app, config;
import 'ark_operations_test.dart' show Preferences;
import 'fake_ark_board_funding.dart';

// Presentation boundary: the host's positive reply follows a durable guarded
// receipt. Native receipt persistence itself is qualified by wallet tests.
class _ReceiptFunding implements ArkBoardFundingPort {
  final delegate = FakeArkBoardFunding()..observed = Ok(prepared());
  final receipt = Completer<({String txid, bool durable, bool guarded})>();
  @override
  Future<Result<ArkBoardPreparation, ArkFailure>> prepare(
    ArkAccountConfig config,
    Sats amount,
  ) async => Ok(prepared());
  @override
  Future<Result<ArkBoardPreparation, ArkFailure>> readPrepared(
    ArkAccountId account,
    String operationId,
  ) => delegate.readPrepared(account, operationId);
  @override
  Future<Result<ArkOperation, ArkFailure>> confirm(
    ArkAccountId account,
    String operationId,
    String reviewBinding,
  ) async {
    final saved = await receipt.future;
    if (!saved.durable ||
        !saved.guarded ||
        saved.txid != prepared().unsignedTxid) {
      return Err(ArkSubmissionUncertainFailure(operationId));
    }
    return Ok(
      ArkOperation(
        id: operationId,
        kind: ArkOperationKind.board,
        status: ArkOperationStatus.pending,
        nativeReference: saved.txid,
        chainSource: config().primaryEsploraUrl,
        configGeneration: 2,
      ),
    );
  }
}

void main() {
  testWidgets('Board parity Confirm uses primary theme tokens', (tester) async {
    final rig = Rig();
    await rig.cubit.prepare(Sats.fromInt(1000));
    await tester.pumpWidget(app(rig.screen));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(BullButton, 'Confirm');
    final colors = tester.element(confirm).bull;
    expect(button(tester, 'Confirm').bgColor, colors.primary);
    expect(button(tester, 'Confirm').textColor, colors.onPrimary);
  });

  for (final durable in [false, true]) {
    testWidgets(
      'Board parity started follows confirm receipt durable=$durable',
      (tester) async {
        final funding = _ReceiptFunding();
        addTearDown(() {
          if (!funding.receipt.isCompleted) {
            funding.receipt.complete((
              txid: prepared().unsignedTxid,
              durable: false,
              guarded: true,
            ));
          }
        });
        final preferences = Preferences();
        final owner = ArkBoardCubit(
          PrepareArkBoardUsecase(funding, preferences),
          ReadArkBoardUsecase(funding),
          ConfirmArkBoardUsecase(funding, preferences),
          config: config(),
        );
        addTearDown(owner.close);
        await owner.prepare(Sats.fromInt(1000));
        await tester.pumpWidget(
          app(ArkBoardScreen(cubit: owner, onReconcile: () {})),
        );
        await tester.pumpAndSettle();
        button(tester, 'Confirm').onPressed();
        await tester.pump();
        expect(owner.state, isA<ArkBoardBusy>());
        expect(find.text('Boarding started'), findsNothing);
        funding.receipt.complete((
          txid: prepared().unsignedTxid,
          durable: durable,
          guarded: true,
        ));
        await tester.pumpAndSettle();
        if (durable) {
          expect(owner.state, isA<ArkBoardSubmitted>());
          expect(find.text('Boarding started'), findsOneWidget);
          expect(find.text('Funding transaction'), findsOneWidget);
          expect(find.widgetWithText(BullButton, 'Done'), findsOneWidget);
        } else {
          expect(owner.state, isA<ArkBoardPending>());
          expect(find.text('Boarding started'), findsNothing);
        }
      },
    );
  }
}
