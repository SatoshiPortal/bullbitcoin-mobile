import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/ark_display_data_port.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/presentation/ark_board_cubit.dart';
import 'package:bull_ark/src/presentation/ark_operation_cubit.dart';
import 'package:bull_ark/src/ui/ark_board_amount_screen.dart';
import 'package:bull_ark/src/ui/ark_vtxos_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_account_screen_test.dart' as wallet;
import 'ark_board_screen_test.dart' as board;
import 'ark_exit_request_screen_test.dart' as request;
import 'ark_exits_screen_test.dart' as exits;
import 'ark_information_widget_test.dart' as info;
import 'ark_operation_review_screen_test.dart' as review;
import 'ark_operations_test.dart' show account;
import 'ark_vtxos_screen_test.dart' as vtxos;

/// Each frame is a real screen with public, synthetic native observations.
/// No fixture registers a wallet, opens a client or possesses signing keys.
final class ArkFlowFrame {
  final String name;
  final Widget screen;
  final Future<void> Function(WidgetTester)? arrange;
  const ArkFlowFrame(this.name, this.screen, {this.arrange});
}

ArkOperation operation(ArkOperationKind kind, ArkOperationStatus status) =>
    ArkOperation(
      id: 'public-operation-fixture',
      kind: kind,
      status: status,
      chainSource: Uri.parse('http://localhost:3000'),
      configGeneration: 1,
    );

Future<List<ArkFlowFrame>> arkFlowFrames() async {
  final frames = <ArkFlowFrame>[];
  final empty = wallet.controller(
    wallet.Client()
      ..snapshot = Ok(
        ArkSnapshot(
          account: account(),
          revision: 2,
          observedAt: DateTime.utc(2026, 11, 18),
          stale: false,
          spendable: Sats.zero,
          pending: Sats.zero,
          confirmedReserve: Sats.zero,
          recovery: ArkRecoveryStatus.complete,
          renewal: ArkRenewalStatus.current,
        ),
      ),
  );
  frames.add(ArkFlowFrame('SendArkWalletEmpty', wallet.screen(empty, [])));
  final refused = board.Rig();
  refused.cubit.emit(
    ArkBoardEditing(ArkBoardBelowMinimumFailure(Sats.fromInt(50000))),
  );
  frames.add(
    ArkFlowFrame(
      'BoardAmountError',
      refused.screen,
      arrange: (tester) async {
        tester
            .widget<BullInputText>(find.byType(BullInputText))
            .onChanged('30000');
        await tester.pump();
      },
    ),
  );
  frames.add(
    ArkFlowFrame(
      'BoardNoFunds',
      ArkBoardAmountScreen(
        config: info.config(),
        onReviewRequest: (_, _) {},
        displayData: ArkDisplayData(
          account: account(),
          walletId: 'public-source',
          available: Sats.zero,
        ),
      ),
      arrange: (tester) async {
        tester
            .widget<BullInputText>(find.byType(BullInputText))
            .onChanged('1000');
        await tester.pump();
      },
    ),
  );
  final pending = board.Rig();
  pending.cubit.emit(
    ArkBoardSubmitted(
      operation(ArkOperationKind.board, ArkOperationStatus.pending),
    ),
  );
  frames.add(ArkFlowFrame('BoardPending', pending.screen));
  frames.add(
    ArkFlowFrame(
      'VtxoFlowDetails',
      ArkVtxosScreen(
        snapshot: vtxos.view(),
        renewalThresholdBlocks: 1008,
        onRenew: (_) async => false,
      ),
      arrange: (tester) async {
        await tester.tap(find.byKey(const ValueKey('vtxo-details-shared')));
        await tester.pump();
      },
    ),
  );
  final renewal = review.Rig();
  renewal.client.quoted = Ok(
    ArkQuote(
      id: 'public-renewal-quote',
      account: account(),
      generation: 2,
      chainSource: Uri.parse('http://localhost:3000'),
      configGeneration: 1,
      kind: ArkOperationKind.renewal,
      amount: Sats.fromInt(1000),
      fee: Sats.fromInt(100),
      net: Sats.fromInt(900),
      selectedIds: ['selected-vtxo'],
      observedTip: 100,
      validUntil: DateTime.utc(2030),
    ),
  );
  await renewal.cubit.load();
  frames.add(ArkFlowFrame('VtxoFlowConfirm', renewal.screen));
  final renewed = review.Rig();
  renewed.cubit.emit(
    ArkOperationSubmitted(
      operation(ArkOperationKind.renewal, ArkOperationStatus.succeeded),
    ),
  );
  frames.add(ArkFlowFrame('VtxoFlowRenewed', renewed.screen));
  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();
  Future<void> openStart(WidgetTester tester) async {
    await tester.pumpAndSettle();
    request.review(tester).onPressed();
    await tester.pumpAndSettle();
  }

  frames.add(
    ArkFlowFrame(
      'ExitFlowChoose',
      request.exitScreen(request.ExitClient()),
      arrange: settle,
    ),
  );
  frames.add(
    ArkFlowFrame(
      'ExitFlowReview',
      request.exitScreen(request.ExitClient()),
      arrange: openStart,
    ),
  );
  frames.add(
    ArkFlowFrame(
      'ExitFlowReviewOther',
      request.exitScreen(request.ExitClient()),
      arrange: (tester) async {
        await openStart(tester);
        tester
            .widget<BullPickerRow>(
              find.widgetWithText(BullPickerRow, 'Another Bitcoin wallet'),
            )
            .onPressed
            ?.call();
        await tester.pumpAndSettle();
        await request.edit(
          tester,
          'Bitcoin address',
          'bcrt1qotherpublicreturnfixture',
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
      },
    ),
  );
  frames.add(
    ArkFlowFrame(
      'ExitFlowNoFunds',
      request.exitScreen(
        request.ExitClient()..failure = const ArkInsufficientFundsFailure(),
      ),
      arrange: settle,
    ),
  );
  for (final entry in [
    ('ExitFlowStarted', ArkExitStatus.pending),
    ('ExitFlowClaimable', ArkExitStatus.claimable),
    ('ExitFlowDone', ArkExitStatus.claimed),
  ]) {
    frames.add(
      ArkFlowFrame(
        entry.$1,
        exits.Harness(
          exits.view(
            exits: entry.$2,
            rows: [exits.exitRow(status: entry.$2)],
          ),
        ).screen,
        arrange: (tester) async {
          final row = exits.exitRows();
          await tester.tap(row.first);
          await tester.pump();
        },
      ),
    );
  }
  return frames;
}
