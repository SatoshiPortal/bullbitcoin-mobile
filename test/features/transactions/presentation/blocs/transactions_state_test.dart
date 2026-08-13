import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
