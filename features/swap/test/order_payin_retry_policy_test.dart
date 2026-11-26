import 'package:flutter_test/flutter_test.dart';
import 'package:spend/spend.dart';
import 'package:swap_feature/src/presentation/order_payin_retry_policy.dart';
import 'package:swaps/order_swaps.dart';

void main() {
  OrderSwapRecord record(
    OrderSwapLocalStatus status, {
    String id = 'order',
    String signed = 'signed',
    String? txid,
    String payin = 'pending',
    String orderStatus = 'pending',
  }) => OrderSwapRecord(
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
    signedPayinTransaction: signed,
    payinIsPsbt: true,
    localPayinTransactionId: txid,
    order: OrderSwap(
      orderId: 'server',
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
      orderStatus: orderStatus,
      payinStatus: payin,
      payoutStatus: 'pending',
      messageCode: '',
      liquidAddress: 'destination',
      createdAt: DateTime.utc(2026),
      confirmationDeadline: DateTime.utc(2100),
    ),
  );

  const rejected = SpendBroadcastRejectedFailure(
    SpendBroadcastRejection.nodeRejected,
  );
  final ready = record(OrderSwapLocalStatus.readyToBroadcast);
  final unknown = record(OrderSwapLocalStatus.broadcastUnknown);

  test('only a first explicit rejection creates ephemeral evidence', () {
    expect(RejectedOrderPayin.fromFirstAttempt(ready, rejected), isNotNull);
    expect(RejectedOrderPayin.fromFirstAttempt(unknown, rejected), isNull);
    for (final failure in <SpendFailure>[
      const SpendBroadcastOutcomeUnknownFailure(),
      const SpendAlreadyInChainFailure(),
      const SpendBroadcastConnectionFailure(),
      const SpendInvalidRequestFailure(),
    ]) {
      expect(RejectedOrderPayin.fromFirstAttempt(ready, failure), isNull);
    }
  });

  test('evidence permits only the same unfunded, nonterminal order', () {
    final evidence = RejectedOrderPayin.fromFirstAttempt(ready, rejected);
    expect(evidence, isNotNull);
    if (evidence == null) return;
    expect(evidence.allows(unknown), isTrue);
    expect(
      evidence.allows(
        record(
          OrderSwapLocalStatus.broadcastUnknown,
          payin: 'Awaiting payment',
        ),
      ),
      isTrue,
    );
    expect(
      evidence.allows(
        record(OrderSwapLocalStatus.broadcastUnknown, payin: 'In progress'),
      ),
      isFalse,
    );
    expect(
      evidence.allows(
        record(OrderSwapLocalStatus.broadcastUnknown, id: 'other'),
      ),
      isFalse,
    );
    expect(
      evidence.allows(
        record(OrderSwapLocalStatus.broadcastUnknown, signed: 'other'),
      ),
      isFalse,
    );
    expect(
      evidence.allows(
        record(OrderSwapLocalStatus.broadcastUnknown, txid: 'tx'),
      ),
      isFalse,
    );
    expect(
      evidence.allows(
        record(OrderSwapLocalStatus.broadcastUnknown, payin: 'completed'),
      ),
      isFalse,
    );
    expect(
      evidence.allows(
        record(OrderSwapLocalStatus.broadcastUnknown, orderStatus: 'failed'),
      ),
      isFalse,
    );
    expect(evidence.allows(record(OrderSwapLocalStatus.completed)), isFalse);
    expect(evidence.allows(null), isFalse);
  });
}
