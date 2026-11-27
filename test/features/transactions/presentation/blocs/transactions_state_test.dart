import 'package:swaps/order_swaps.dart';
import 'package:transactions/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swaps/swaps.dart';

void main() {
  for (final status in [SwapStatus.failed, SwapStatus.expired]) {
    for (final evidence in ['none', 'send', 'receive', 'refund']) {
      test('legacy $status history with $evidence evidence', () {
        final swap = Swap.chain(
          id: 'legacy',
          keyIndex: 0,
          type: SwapType.bitcoinToLiquid,
          status: status,
          environment: Environment.mainnet,
          creationTime: DateTime.utc(2026),
          sendWalletId: 'wallet-1',
          paymentAddress: 'test-only-address',
          paymentAmount: 1000,
          sendTxid: evidence == 'send' ? 'send-tx' : null,
          receiveTxid: evidence == 'receive' ? 'receive-tx' : null,
          refundTxid: evidence == 'refund' ? 'refund-tx' : null,
        );
        final transaction = Transaction(swap: swap);
        final history =
            TransactionsState(transactions: [transaction])
                .filteredTransactionsByDay
                ?.values
                .expand((items) => items)
                .toList() ??
            [];
        expect(history, evidence == 'none' ? isEmpty : [transaction]);
      });
    }
  }

  group('unfunded Boltz swaps', () {
    Swap chain({String? sendTxid, String? pendingLockupTx}) => Swap.chain(
      id: 'chain',
      keyIndex: 0,
      type: SwapType.bitcoinToLiquid,
      status: SwapStatus.pending,
      environment: Environment.mainnet,
      creationTime: DateTime.utc(2026),
      sendWalletId: 'wallet-1',
      paymentAddress: 'test-only-address',
      paymentAmount: 1000,
      sendTxid: sendTxid,
      pendingLockupTx: pendingLockupTx,
      receiveWalletId: 'wallet-2',
    );

    final unpaidInvoice = Swap.lnReceive(
      id: 'receive',
      keyIndex: 1,
      type: SwapType.lightningToLiquid,
      status: SwapStatus.pending,
      environment: Environment.mainnet,
      creationTime: DateTime.utc(2026),
      receiveWalletId: 'wallet-2',
      invoice: '',
    );

    final unsentSubmarine = Swap.lnSend(
      id: 'send',
      keyIndex: 2,
      type: SwapType.liquidToLightning,
      status: SwapStatus.pending,
      environment: Environment.mainnet,
      creationTime: DateTime.utc(2026),
      sendWalletId: 'wallet-2',
      invoice: '',
      paymentAddress: 'test-only-address',
      paymentAmount: 1000,
    );

    List<Transaction> listed(TransactionsState state) =>
        state.filteredTransactionsByDay?.values
            .expand((items) => items)
            .toList() ??
        [];

    for (final (name, swap) in [
      ('a chain swap we never locked up for', chain()),
      ('a submarine swap we never locked up for', unsentSubmarine),
      ('an invoice nobody has paid', unpaidInvoice),
    ]) {
      test('$name is not shown as in progress', () {
        final transaction = Transaction(swap: swap);
        final state = TransactionsState(transactions: [transaction]);

        expect(transaction.isUnfundedSwap, isTrue);
        expect(state.ongoingSwaps, isEmpty);
        expect(listed(state), isEmpty);
      });
    }

    for (final (name, swap) in [
      ('a broadcast lockup', chain(sendTxid: 'lockup-tx')),
      ('a signed lockup awaiting broadcast', chain(pendingLockupTx: 'hex')),
      ('a paid invoice', unpaidInvoice.copyWith(status: SwapStatus.paid)),
    ]) {
      test('$name stays in progress', () {
        final transaction = Transaction(swap: swap);
        final state = TransactionsState(transactions: [transaction]);

        expect(transaction.isUnfundedSwap, isFalse);
        expect(state.ongoingSwaps, [transaction]);
      });
    }
  });

  test('shows an ongoing Exchange payin in the ongoing section', () {
    final transaction = Transaction(orderSwap: _orderSwap());
    final state = TransactionsState(transactions: [transaction]);

    expect(state.ongoingSwaps, [transaction]);
    expect(state.filteredTransactionsByDay, isEmpty);
  });

  test('shows a completed Exchange swap in the dated list', () {
    final transaction = Transaction(
      orderSwap: _orderSwap(status: OrderSwapLocalStatus.completed),
    );
    final state = TransactionsState(transactions: [transaction]);

    expect(state.ongoingSwaps, isEmpty);
    expect(state.filteredTransactionsByDay!.values.expand((items) => items), [
      transaction,
    ]);
  });

  test('filters an Exchange chain swap without requiring a legacy swap', () {
    final transaction = Transaction(
      orderSwap: _orderSwap(
        status: OrderSwapLocalStatus.completed,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
      ),
    );
    final state = TransactionsState(
      transactions: [transaction],
      filter: TransactionsFilter.swap,
    );

    expect(state.filteredTransactionsByDay!.values.expand((items) => items), [
      transaction,
    ]);
  });

  test('keeps a funded expired Exchange swap visible', () {
    final transaction = Transaction(
      orderSwap: _orderSwap(status: OrderSwapLocalStatus.expired),
    );
    final state = TransactionsState(transactions: [transaction]);
    expect(state.filteredTransactionsByDay?.values.expand((items) => items), [
      transaction,
    ]);
  });

  test('keeps a funded failed Exchange swap visible', () {
    final transaction = Transaction(
      orderSwap: _orderSwap(status: OrderSwapLocalStatus.failed),
    );
    final state = TransactionsState(transactions: [transaction]);

    expect(state.ongoingSwaps, isEmpty);
    expect(state.filteredTransactionsByDay!.values.expand((items) => items), [
      transaction,
    ]);
  });
}

OrderSwapRecord _orderSwap({
  OrderSwapLocalStatus status = OrderSwapLocalStatus.payinBroadcast,
  OrderSwapNetwork inNetwork = OrderSwapNetwork.bitcoin,
  OrderSwapNetwork outNetwork = OrderSwapNetwork.liquid,
}) {
  final createdAt = DateTime.utc(2026, 8, 6);
  return OrderSwapRecord(
    localId: 'local-1',
    purpose: OrderSwapPurpose.sendCrossChain,
    environment: OrderSwapEnvironment.testnet,
    inNetwork: inNetwork,
    outNetwork: outNetwork,
    isInAmountFixed: false,
    requestedAmountSat: BigInt.from(120000),
    sourceWalletId: 'wallet-1',
    destination: 'destination',
    fallback: 'fallback',
    order: OrderSwap(
      orderId: 'order-1',
      orderNumber: 1,
      inNetwork: inNetwork,
      outNetwork: outNetwork,
      payinAmountSat: BigInt.from(120000),
      payoutAmountSat: BigInt.from(120000),
      payinCurrency: 'BTC',
      payoutCurrency: 'LBTC',
      payinMethod: 'Bitcoin On-Chain',
      payoutMethod: 'Liquid Network',
      orderType: 'Funding',
      orderStatus: 'In progress',
      payinStatus: 'In progress',
      payoutStatus: 'Not started',
      messageCode: 'PAYMENT_IN_PROGRESS',
      createdAt: createdAt,
      confirmationDeadline: createdAt.add(const Duration(minutes: 5)),
    ),
    localPayinTransactionId: 'payin-txid',
    createdAt: createdAt,
    localStatus: status,
  );
}
