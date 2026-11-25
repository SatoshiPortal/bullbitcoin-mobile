import 'package:bull_payjoin/bull_payjoin.dart'
    show PayjoinReceiverSession, PayjoinStatus;
import 'package:flutter_test/flutter_test.dart';
import 'package:receive/src/presentation/bloc/receive_bloc.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:transactions/transactions.dart'
    show WalletTransaction, WalletTransactionDirection, WalletTransactionStatus;
import 'package:swaps/swaps.dart'
    show Environment, LnReceiveSwap, Swap, SwapStatus, SwapType;

void main() {
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
}
