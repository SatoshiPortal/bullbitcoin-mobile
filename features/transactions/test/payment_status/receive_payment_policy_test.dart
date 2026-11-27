import 'package:bull_payjoin/bull_payjoin.dart' show PayjoinStatus;
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transactions/payment_status.dart';
import 'package:swaps/swaps.dart' show SwapStatus;

void main() {
  for (final confirmed in [false, true]) {
    test('on-chain confirmed=$confirmed', () {
      final progress = receiveOnchainProgress(
        steps: const ['Payment detected', 'Confirmed'],
        confirmed: confirmed,
      );
      expect(progress.completed, confirmed ? 1 : 0);
      expect(
        progress.currentState,
        confirmed
            ? BullPaymentStepState.active
            : BullPaymentStepState.broadcast,
      );
      expect(progress.failedAt, isNull);
      expect(
        receiveOnchainPhase(confirmed: confirmed),
        confirmed ? BullPaymentPhase.success : BullPaymentPhase.sending,
      );
    });
  }

  // status, receive txid, confirmed, completed, state, failedAt, phase
  final reverseCases =
      <
        (
          SwapStatus,
          bool,
          bool,
          int,
          BullPaymentStepState,
          int?,
          BullPaymentPhase,
        )
      >[
        (SwapStatus.pending, false, false, 0, .active, null, .sending),
        (SwapStatus.paid, false, false, 0, .active, null, .sending),
        (SwapStatus.claimable, false, false, 0, .active, null, .sending),
        (SwapStatus.paid, true, false, 1, .broadcast, null, .sending),
        (SwapStatus.completed, true, false, 2, .active, null, .success),
        (SwapStatus.completed, true, true, 2, .active, null, .success),
        (SwapStatus.paid, true, true, 2, .active, null, .success),
        (SwapStatus.completed, false, false, 1, .broadcast, null, .sending),
        (SwapStatus.failed, false, false, 0, .active, 0, .failed),
        (SwapStatus.expired, false, false, 0, .active, 0, .failed),
        (SwapStatus.refunded, false, false, 0, .active, 0, .failed),
        (SwapStatus.failed, true, false, 1, .held, null, .sending),
        (SwapStatus.refundable, false, false, 0, .held, null, .sending),
        (SwapStatus.canCoop, false, false, 0, .held, null, .sending),
        (SwapStatus.canCoop, true, false, 1, .held, null, .sending),
      ];
  for (final (status, txid, confirmed, completed, state, failedAt, phase)
      in reverseCases) {
    test('reverse $status txid=$txid confirmed=$confirmed', () {
      final progress = receiveLightningProgress(
        steps: const ['Boltz lockup', 'Claim broadcast', 'Completed'],
        status: status,
        wasDirectPayment: false,
        hasReceiveTxid: txid,
        confirmed: confirmed,
      );
      expect(progress.completed, completed);
      expect(progress.currentState, state);
      expect(progress.failedAt, failedAt);
      expect(
        receiveLightningPhase(
          status: status,
          wasDirectPayment: false,
          hasReceiveTxid: txid,
          confirmed: confirmed,
        ),
        phase,
      );
    });
  }

  for (final status in SwapStatus.values) {
    for (final confirmed in [false, true]) {
      test('direct $status confirmed=$confirmed never fails', () {
        final settled = confirmed && status == SwapStatus.completed;
        final progress = receiveLightningProgress(
          steps: const ['Payment detected', 'Confirmed'],
          status: status,
          wasDirectPayment: true,
          hasReceiveTxid: true,
          confirmed: confirmed,
        );
        expect(progress.completed, settled ? 1 : 0);
        expect(
          progress.currentState,
          settled
              ? BullPaymentStepState.active
              : BullPaymentStepState.broadcast,
        );
        expect(progress.failedAt, isNull);
        expect(
          receiveLightningPhase(
            status: status,
            wasDirectPayment: true,
            hasReceiveTxid: true,
            confirmed: confirmed,
          ),
          settled ? BullPaymentPhase.success : BullPaymentPhase.sending,
        );
      });
    }
  }

  test('direct payment with a confirmed candidate is not success until the '
      'swap is completed', () {
    final progress = receiveLightningProgress(
      steps: const ['Payment detected', 'Confirmed'],
      status: SwapStatus.paid,
      wasDirectPayment: true,
      hasReceiveTxid: true,
      confirmed: true,
    );
    expect(progress.completed, 0);
    expect(progress.currentState, BullPaymentStepState.broadcast);
    expect(
      receiveLightningPhase(
        status: SwapStatus.paid,
        wasDirectPayment: true,
        hasReceiveTxid: true,
        confirmed: true,
      ),
      BullPaymentPhase.sending,
    );
  });

  // status, original, proposal, confirmed, completed, state, skippedAt
  for (final (
        status,
        original,
        proposal,
        confirmed,
        completed,
        state,
        skippedAt,
      )
      in <(PayjoinStatus, bool, bool, bool, int, BullPaymentStepState, int?)>[
        (PayjoinStatus.started, false, false, false, 0, .active, null),
        (PayjoinStatus.requested, true, false, false, 0, .active, null),
        (PayjoinStatus.proposed, true, false, false, 1, .active, null),
        (PayjoinStatus.requested, true, true, false, 1, .active, null),
        (PayjoinStatus.completed, true, true, false, 2, .broadcast, null),
        (PayjoinStatus.completed, true, true, true, 3, .active, null),
        (PayjoinStatus.aborted, true, false, false, 2, .broadcast, 1),
        (PayjoinStatus.aborted, true, true, true, 3, .active, 1),
        (PayjoinStatus.expired, true, false, false, 0, .held, null),
        (PayjoinStatus.expired, true, true, false, 1, .held, null),
      ]) {
    test('payjoin $status original=$original proposal=$proposal '
        'confirmed=$confirmed', () {
      final progress = receivePayjoinProgress(
        steps: const ['Original', 'Proposal', 'Detected', 'Confirmed'],
        status: status,
        hasOriginal: original,
        hasProposal: proposal,
        confirmed: confirmed,
      );
      expect(progress.completed, completed);
      expect(progress.currentState, state);
      expect(progress.failedAt, isNull);
      expect(progress.skippedAt, skippedAt);
      expect(
        receivePayjoinPhase(status: status, confirmed: confirmed),
        confirmed &&
                (status == PayjoinStatus.completed ||
                    status == PayjoinStatus.aborted)
            ? BullPaymentPhase.success
            : BullPaymentPhase.sending,
      );
    });
  }
}
