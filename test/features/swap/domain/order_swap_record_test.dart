import 'package:bb_mobile/features/swap/domain/entities/order_swap.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OrderSwapRecord buildRecord({
    BigInt? amount,
    OrderSwapNetwork outNetwork = OrderSwapNetwork.lightning,
  }) => OrderSwapRecord(
    localId: 'local-1',
    purpose: OrderSwapPurpose.sendLightning,
    environment: OrderSwapEnvironment.testnet,
    inNetwork: OrderSwapNetwork.liquid,
    outNetwork: outNetwork,
    isInAmountFixed: false,
    requestedAmountSat: amount ?? BigInt.from(1000),
    destination: 'destination',
    fallback: 'fallback',
    createdAt: DateTime.utc(2026),
    localStatus: OrderSwapLocalStatus.creating,
  );

  test('rejects a non-positive requested amount', () {
    expect(() => buildRecord(amount: BigInt.zero), throwsArgumentError);
  });

  test('rejects identical input and output networks', () {
    expect(
      () => buildRecord(outNetwork: OrderSwapNetwork.liquid),
      throwsArgumentError,
    );
  });

  test('only known final local states are terminal', () {
    expect(OrderSwapLocalStatus.completed.isTerminal, isTrue);
    expect(OrderSwapLocalStatus.refunded.isTerminal, isTrue);
    expect(OrderSwapLocalStatus.expired.isTerminal, isTrue);
    expect(OrderSwapLocalStatus.failed.isTerminal, isTrue);
    expect(OrderSwapLocalStatus.creationUnknown.isTerminal, isFalse);
    expect(OrderSwapLocalStatus.broadcastUnknown.isTerminal, isFalse);
  });

  test('requires the signed payload before entering a broadcast state', () {
    expect(
      () => OrderSwapRecord(
        localId: 'local-1',
        purpose: OrderSwapPurpose.sendLightning,
        environment: OrderSwapEnvironment.testnet,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.lightning,
        isInAmountFixed: false,
        requestedAmountSat: BigInt.from(1000),
        destination: 'destination',
        fallback: 'fallback',
        createdAt: DateTime.utc(2026),
        localStatus: OrderSwapLocalStatus.broadcastUnknown,
      ),
      throwsArgumentError,
    );
  });

  test('requires an output-fixed order to preserve the requested payout', () {
    expect(
      () => OrderSwapRecord(
        localId: 'local-1',
        purpose: OrderSwapPurpose.sendLightning,
        environment: OrderSwapEnvironment.testnet,
        inNetwork: OrderSwapNetwork.liquid,
        outNetwork: OrderSwapNetwork.lightning,
        isInAmountFixed: false,
        requestedAmountSat: BigInt.from(1000),
        destination: 'destination',
        fallback: 'fallback',
        order: _order(payoutAmountSat: BigInt.from(999)),
        createdAt: DateTime.utc(2026),
        localStatus: OrderSwapLocalStatus.awaitingUserConfirmation,
      ),
      throwsArgumentError,
    );
  });
}

OrderSwap _order({required BigInt payoutAmountSat}) => OrderSwap(
  orderId: 'order-1',
  orderNumber: 1,
  inNetwork: OrderSwapNetwork.liquid,
  outNetwork: OrderSwapNetwork.lightning,
  payinAmountSat: BigInt.from(1010),
  payoutAmountSat: payoutAmountSat,
  payinCurrency: 'LBTC',
  payoutCurrency: 'BTCLN',
  payinMethod: 'Liquid',
  payoutMethod: 'Lightning',
  orderType: 'Swap',
  orderStatus: 'Awaiting payment',
  payinStatus: 'In progress',
  payoutStatus: 'Not started',
  messageCode: 'ORDER_CREATED',
  liquidAddress: 'payin',
  createdAt: DateTime.utc(2026),
  confirmationDeadline: DateTime.utc(2026, 1, 1, 0, 5),
);
