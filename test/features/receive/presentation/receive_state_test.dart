import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the Exchange invoice as Lightning QR data', () {
    final state = ReceiveState(
      type: ReceiveType.lightning,
      confirmedAmountSat: 100000,
      orderSwap: _record(OrderSwapLocalStatus.awaitingUserConfirmation),
    );

    expect(state.qrData, 'LNTB-INVOICE');
    expect(state.getSwap?.id, 'order-1');
    expect(state.transaction.orderSwap?.localId, 'local-1');
  });

  test('maps Exchange payout progress to the receive progress screen', () {
    final state = ReceiveState(
      type: ReceiveType.lightning,
      orderSwap: _record(OrderSwapLocalStatus.payoutInProgress),
    );

    expect(state.isPaymentInProgress, isTrue);
    expect(state.isPaymentReceived, isFalse);
    expect(state.getSwap?.status, SwapStatus.paid);
  });

  test('maps an Exchange completion to payment received', () {
    final state = ReceiveState(
      type: ReceiveType.lightning,
      orderSwap: _record(OrderSwapLocalStatus.completed),
    );

    expect(state.isPaymentInProgress, isFalse);
    expect(state.isPaymentReceived, isTrue);
    expect(state.getSwap?.status, SwapStatus.completed);
    expect(state.txId, 'liquid-tx');
  });
}

OrderSwapRecord _record(OrderSwapLocalStatus status) => OrderSwapRecord(
  localId: 'local-1',
  purpose: OrderSwapPurpose.receiveLightning,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.lightning,
  outNetwork: OrderSwapNetwork.liquid,
  isInAmountFixed: true,
  requestedAmountSat: BigInt.from(100000),
  destinationWalletId: 'wallet-1',
  destination: 'tlq1-destination',
  fallback: 'tlq1-destination',
  order: OrderSwap(
    orderId: 'order-1',
    orderNumber: 1,
    inNetwork: OrderSwapNetwork.lightning,
    outNetwork: OrderSwapNetwork.liquid,
    payinAmountSat: BigInt.from(100000),
    payoutAmountSat: BigInt.from(99000),
    payinCurrency: 'BTCLN',
    payoutCurrency: 'LBTC',
    payinMethod: 'Lightning',
    payoutMethod: 'Liquid',
    orderType: 'Swap',
    orderStatus: status == OrderSwapLocalStatus.completed
        ? 'Completed'
        : 'In_pending',
    payinStatus: status == OrderSwapLocalStatus.awaitingUserConfirmation
        ? 'Awaiting payment'
        : 'Completed',
    payoutStatus: status == OrderSwapLocalStatus.completed
        ? 'Completed'
        : 'In progress',
    messageCode: 'PAYMENT_NOT_DETECTED',
    lightningInvoice: 'lntb-invoice',
    liquidAddress: 'tlq1-destination',
    liquidTransactionId: status == OrderSwapLocalStatus.completed
        ? 'liquid-tx'
        : null,
    createdAt: DateTime.utc(2026),
    confirmationDeadline: DateTime.utc(2026, 1, 1, 0, 5),
    completedAt: status == OrderSwapLocalStatus.completed
        ? DateTime.utc(2026, 1, 1, 0, 3)
        : null,
  ),
  createdAt: DateTime.utc(2026),
  localStatus: status,
);
