import 'package:bull_payjoin/bull_payjoin.dart'
    show PayjoinReceiverSession, PayjoinStatus;
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receive/src/presentation/bloc/receive_bloc.dart';
import 'package:receive/src/presentation/receive_payment_progress.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:transactions/transactions.dart'
    show WalletTransaction, WalletTransactionDirection, WalletTransactionStatus;
import 'package:swaps/swaps.dart'
    show Environment, LnReceiveSwap, Swap, SwapStatus, SwapType;

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
        (SwapStatus.completed, true, false, 1, .broadcast, null, .sending),
        (SwapStatus.completed, true, true, 2, .active, null, .success),
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
        steps: const ['Boltz lockup', 'Claim broadcast', 'Confirmed'],
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

  test(
    'lightning settlement is the claim transaction in the receive wallet',
    () {
      LnReceiveSwap swap(String? receiveTxid) => Swap.lnReceive(
        id: 'swap',
        keyIndex: 0,
        type: SwapType.lightningToLiquid,
        status: SwapStatus.completed,
        environment: Environment.testnet,
        creationTime: DateTime.utc(2026),
        receiveWalletId: 'wallet',
        invoice: 'invoice',
        receiveTxid: receiveTxid,
      ) as LnReceiveSwap;
      ReceiveState state(String? receiveTxid) => ReceiveState(
        type: ReceiveType.lightning,
        lightningSwap: swap(receiveTxid),
      );
      expect(state(null).settlement, isNull);
      expect(state('').settlement, isNull);
      expect(state('claim').settlement, (walletId: 'wallet', txId: 'claim'));
      expect(state('claim').settlementConfirmed, isFalse);
    },
  );

  test('completed payjoin without a txid never borrows the address tx', () {
    WalletTransaction tx() => WalletTransaction(
      walletId: 'w',
      network: BitcoinNetwork.mainnet,
      direction: WalletTransactionDirection.incoming,
      status: WalletTransactionStatus.confirmed,
      txId: 'unrelated',
      amountSat: 1,
      feeSat: 0,
      vsize: 1,
      inputs: const [],
      outputs: const [],
      isRbf: false,
    );
    for (final status in [PayjoinStatus.completed, PayjoinStatus.aborted]) {
      final state = ReceiveState(
        type: ReceiveType.bitcoin,
        payjoin: PayjoinReceiverSession(
          status: status,
          id: 'pj',
          network: BitcoinNetwork.mainnet,
          walletId: 'w',
          payjoinUri: 'bitcoin:x',
          createdAt: DateTime(2026),
          expiresAt: DateTime(2027),
          hasOriginalTransaction: true,
          hasProposal: true,
        ),
        tx: tx(),
        settlementTx: tx(),
      );
      expect(state.settlement, isNull);
      expect(state.settlementConfirmed, isFalse);
    }
  });

  test('direct payment is not routed away on a failed swap status', () {
    ReceiveState state({required bool direct}) => ReceiveState(
      type: ReceiveType.lightning,
      lightningSwap: Swap.lnReceive(
        id: 'swap',
        keyIndex: 0,
        type: SwapType.lightningToLiquid,
        status: SwapStatus.failed,
        environment: Environment.testnet,
        creationTime: DateTime.utc(2026),
        receiveWalletId: 'wallet',
        invoice: 'invoice',
        wasDirectPayment: direct,
      ) as LnReceiveSwap,
    );
    expect(state(direct: true).hasTerminalLightningSwapFailure, isFalse);
    expect(state(direct: false).hasTerminalLightningSwapFailure, isTrue);
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
