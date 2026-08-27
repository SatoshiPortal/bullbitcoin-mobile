import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/presentation/receive_navigation.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'does not reuse a confirmed Lightning amount without an active order',
    () {
      const state = ReceiveState(
        type: ReceiveType.lightning,
        inputAmount: '1000',
        inputAmountCurrencyCode: 'sats',
        confirmedAmountSat: 1000,
      );

      expect(canReuseConfirmedReceiveDetails(state), isFalse);
    },
  );

  test('opens order swap details when that is the available transaction', () {
    final state = ReceiveState(
      type: ReceiveType.lightning,
      orderSwap: _record(OrderSwapLocalStatus.completed),
    );

    expect(
      receiveDetailsTarget(state)?.kind,
      ReceiveDetailsTargetKind.orderSwap,
    );
    expect(receiveDetailsTarget(state)?.id, 'local-1');
  });

  test('detects every unsuccessful terminal order status', () {
    for (final status in [
      OrderSwapLocalStatus.expired,
      OrderSwapLocalStatus.failed,
      OrderSwapLocalStatus.refunded,
    ]) {
      final state = ReceiveState(
        type: ReceiveType.lightning,
        orderSwap: _record(status),
      );

      expect(state.hasTerminalOrderSwapFailure, isTrue);
    }
  });
}

OrderSwapRecord _record(OrderSwapLocalStatus status) => OrderSwapRecord(
  localId: 'local-1',
  purpose: OrderSwapPurpose.receiveLightning,
  environment: OrderSwapEnvironment.testnet,
  inNetwork: OrderSwapNetwork.lightning,
  outNetwork: OrderSwapNetwork.liquid,
  isInAmountFixed: true,
  requestedAmountSat: BigInt.from(1000),
  destinationWalletId: 'wallet-1',
  destination: 'tlq1-destination',
  fallback: 'tlq1-destination',
  order: OrderSwap(
    orderId: 'order-1',
    orderNumber: 1,
    inNetwork: OrderSwapNetwork.lightning,
    outNetwork: OrderSwapNetwork.liquid,
    payinAmountSat: BigInt.from(1000),
    payoutAmountSat: BigInt.from(990),
    payinCurrency: 'BTCLN',
    payoutCurrency: 'LBTC',
    payinMethod: 'Lightning',
    payoutMethod: 'Liquid',
    orderType: 'Swap',
    orderStatus: status.name,
    payinStatus: 'Completed',
    payoutStatus: status.name,
    messageCode: 'STATUS',
    lightningInvoice: 'lntb-invoice',
    liquidAddress: 'tlq1-destination',
    createdAt: DateTime.utc(2026),
    confirmationDeadline: DateTime.utc(2026, 1, 1, 0, 5),
  ),
  createdAt: DateTime.utc(2026),
  localStatus: status,
);
