import 'package:flutter_test/flutter_test.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:swap_feature/src/ui/swap_router.dart';
import 'package:swap_feature/src/ui/swap_transition_policy.dart';
import 'package:swaps/order_swaps.dart';
import 'package:swaps/swaps.dart';

void main() {
  final swap = Swap.chain(
    id: 'swap',
    keyIndex: 0,
    type: SwapType.bitcoinToLiquid,
    status: SwapStatus.paid,
    environment: SwapEnvironment.testnet,
    creationTime: DateTime.utc(2026),
    sendWalletId: 'wallet',
    paymentAddress: 'address',
    paymentAmount: 1000,
    sendTxid: 'funding',
  ) as ChainSwap;

  bool succeeded(ChainSwap candidate, {String id = 'swap'}) =>
      swapTransitionSucceeded(
        swapId: id,
        orderId: null,
        swap: candidate,
        order: null,
      );

  test('funding and an unproven completion do not show success', () {
    expect(succeeded(swap), isFalse);
    expect(succeeded(swap.copyWith(status: SwapStatus.completed)), isFalse);
    expect(
      succeeded(swap.copyWith(status: SwapStatus.completed, receiveTxid: '')),
      isFalse,
    );
  });

  test('only the same successfully paid swap can show success', () {
    final paid = swap.copyWith(
      status: SwapStatus.completed,
      receiveTxid: 'payout',
    );
    expect(succeeded(paid), isTrue);
    expect(succeeded(paid, id: 'another'), isFalse);
    expect(succeeded(paid.copyWith(refundTxid: 'refund')), isFalse);
    expect(succeeded(paid.copyWith(status: SwapStatus.refunded)), isFalse);
    expect(succeeded(paid.copyWith(status: SwapStatus.failed)), isFalse);
  });

  test('refunds and funded failures remain provisional until resolved', () {
    BullPaymentPhase phase(ChainSwap candidate) => swapTransitionPhase(
      swapId: 'swap',
      orderId: null,
      swap: candidate,
      order: null,
    );
    expect(
      phase(swap.copyWith(status: SwapStatus.refundable)),
      BullPaymentPhase.sending,
    );
    expect(
      phase(swap.copyWith(status: SwapStatus.failed)),
      BullPaymentPhase.sending,
    );
    expect(
      phase(swap.copyWith(status: SwapStatus.expired)),
      BullPaymentPhase.sending,
    );
    expect(
      phase(swap.copyWith(status: SwapStatus.refunded)),
      BullPaymentPhase.failed,
    );
    expect(
      phase(swap.copyWith(status: SwapStatus.failed, sendTxid: null)),
      BullPaymentPhase.failed,
    );
    expect(
      swapTransitionPhase(
        swapId: 'swap',
        orderId: null,
        swap: swap.copyWith(status: SwapStatus.failed, sendTxid: null),
        order: null,
        fundingTxId: 'funding',
      ),
      BullPaymentPhase.sending,
    );
  });

  test('a late cross-chain funding txid cannot take over navigation', () {
    const before = TransferState(sendToExternal: true);
    const after = TransferState(sendToExternal: true, txId: 'funding');
    expect(shouldNavigateOnTransferBroadcast(before, after), isFalse);
  });

  test('exchange success uses the same durable completed order', () {
    OrderSwapRecord order(String id, OrderSwapLocalStatus status) =>
        OrderSwapRecord(
          localId: id,
          purpose: OrderSwapPurpose.transfer,
          environment: OrderSwapEnvironment.testnet,
          inNetwork: OrderSwapNetwork.bitcoin,
          outNetwork: OrderSwapNetwork.liquid,
          isInAmountFixed: true,
          requestedAmountSat: BigInt.from(1000),
          destination: 'destination',
          fallback: 'fallback',
          createdAt: DateTime.utc(2026),
          localStatus: status,
          order: OrderSwap(
            orderId: 'server-$id',
            orderNumber: 1,
            inNetwork: OrderSwapNetwork.bitcoin,
            outNetwork: OrderSwapNetwork.liquid,
            payinAmountSat: BigInt.from(1000),
            payoutAmountSat: BigInt.from(990),
            payinCurrency: 'BTC',
            payoutCurrency: 'L-BTC',
            payinMethod: 'bitcoin',
            payoutMethod: 'liquid',
            orderType: 'swap',
            orderStatus: status.name,
            payinStatus: status == OrderSwapLocalStatus.broadcastUnknown
                ? 'pending'
                : 'completed',
            payoutStatus: status.name,
            messageCode: '',
            liquidAddress: 'destination',
            createdAt: DateTime.utc(2026),
            confirmationDeadline: DateTime.utc(2026, 1, 2),
          ),
          signedPayinTransaction: 'signed',
          payinIsPsbt: true,
        );
    final paid = swap.copyWith(status: SwapStatus.completed);
    bool check(OrderSwapRecord candidate) => swapTransitionSucceeded(
      swapId: 'swap',
      orderId: 'order',
      swap: paid,
      order: candidate,
    );
    expect(check(order('order', OrderSwapLocalStatus.completed)), isTrue);
    expect(check(order('other', OrderSwapLocalStatus.completed)), isFalse);
    expect(
      check(order('order', OrderSwapLocalStatus.broadcastUnknown)),
      isFalse,
    );
    expect(check(order('order', OrderSwapLocalStatus.refunded)), isFalse);
  });
}
