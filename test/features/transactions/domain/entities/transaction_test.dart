import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies a broadcast Bitcoin to Lightning order as an ongoing swap', () {
    final transaction = Transaction(orderSwap: _orderSwap());

    expect(transaction.isSwap, isTrue);
    expect(transaction.isLnSwap, isTrue);
    expect(transaction.isChainSwap, isFalse);
    expect(transaction.isOngoingSwap, isTrue);
    expect(transaction.isOutgoing, isTrue);
    expect(transaction.isBitcoin, isTrue);
    expect(transaction.isTestnet, isTrue);
    expect(transaction.txId, 'payin-txid');
    expect(transaction.walletId, 'wallet-1');
    expect(transaction.swapListAmountSat, 100000);
    expect(transaction.swapDisplayAmountSat, 100000);
  });

  test('classifies terminal order swap states as no longer ongoing', () {
    for (final status in [
      OrderSwapLocalStatus.completed,
      OrderSwapLocalStatus.refunded,
      OrderSwapLocalStatus.expired,
      OrderSwapLocalStatus.failed,
    ]) {
      expect(
        Transaction(orderSwap: _orderSwap(status: status)).isOngoingSwap,
        isFalse,
      );
    }
  });

  test('identifies a Liquid to Bitcoin order as a chain swap', () {
    final transaction = Transaction(
      orderSwap: _orderSwap(
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.bitcoin,
      ),
    );

    expect(transaction.isChainSwap, isTrue);
    expect(transaction.isLnSwap, isFalse);
    expect(transaction.isLiquidToBitcoinSwap, isTrue);
  });
}

OrderSwapRecord _orderSwap({
  OrderSwapLocalStatus status = OrderSwapLocalStatus.payinBroadcast,
  OrderSwapNetwork inNetwork = OrderSwapNetwork.bitcoin,
  OrderSwapNetwork outNetwork = OrderSwapNetwork.lightning,
}) {
  final createdAt = DateTime.utc(2026, 8, 6);
  return OrderSwapRecord(
    localId: 'local-1',
    purpose: OrderSwapPurpose.sendLightning,
    environment: OrderSwapEnvironment.testnet,
    inNetwork: inNetwork,
    outNetwork: outNetwork,
    isInAmountFixed: false,
    requestedAmountSat: BigInt.from(100000),
    sourceWalletId: 'wallet-1',
    destination: 'invoice',
    fallback: 'fallback',
    order: OrderSwap(
      orderId: 'order-1',
      orderNumber: 1,
      inNetwork: inNetwork,
      outNetwork: outNetwork,
      payinAmountSat: BigInt.from(101000),
      payoutAmountSat: BigInt.from(100000),
      payinCurrency: inNetwork.name,
      payoutCurrency: outNetwork.name,
      payinMethod: inNetwork.name,
      payoutMethod: outNetwork.name,
      orderType: 'Swap',
      orderStatus: 'In progress',
      payinStatus: 'Completed',
      payoutStatus: 'In progress',
      messageCode: 'PAYOUT_IN_PROGRESS',
      createdAt: createdAt,
      confirmationDeadline: createdAt.add(const Duration(minutes: 5)),
    ),
    localPayinTransactionId: 'payin-txid',
    createdAt: createdAt,
    localStatus: status,
  );
}
